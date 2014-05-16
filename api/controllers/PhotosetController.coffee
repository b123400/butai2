###
 * PhotosetController
 *
 * @module      :: Controller
 * @description	:: A set of functions called `actions`.
 *
 *                 Actions contain code telling Sails how to respond to a certain type of request.
 *                 (i.e. do stuff, then send some JSON, show an HTML page, or redirect to another URL)
 *
 *                 You can configure the blueprint URLs which trigger these actions (`config/controllers.js`)
 *                 and/or override them with custom routes (`config/routes.js`)
 *
 *                 NOTE: The code you write here supports both HTTP and Socket.io automatically.
 *
 * @docs        :: http://sailsjs.org/#!documentation/controllers
###

http = require 'http'
knox = require 'knox'
sails = require 'sails'
Url = require 'url'
uuid = require 'node-uuid'
Request = require 'request'

client = knox.createClient sails.config.aws

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to PhotosetController)
  ###
  _config: {}

  # index : (req, res)->
  #   res.view 'photoset/index'

  index : (req, res)->
    res.view 'photoset/index',
      sidebarPartial : 'photoset/indexSidebar'

  find : (req, res)->
    Photoset.findOne(req.param('id')).exec (err, photoset)->
      res.view 'photoset/find',
        sidebarPartial : 'photoset/findSidebar'
        sidebarContent :
          hello : 'world'
        photoset : photoset
        error : err

  create : (req, serverResponse)->

    if not req.param 'socket'
      return serverResponse.view 'photoset/create',
        sidebarPartial : 'photoset/createSidebar'

    fetchCount = 0
    fetchCount++ if req.param('realityURL')?
    fetchCount++ if req.param('captureURL')?

    if fetchCount is 0
      return serverResponse.json success : false
    
    serverResponse.json
      success: true
      message: 'hello'

    finished = 0
    allowedContentType =
      'image/gif'  : 'gif'
      'image/jpg'  : 'jpg'
      'image/jpeg' : 'jpg'
      'image/pjpeg': 'jpg'
      'image/png'  : 'png'

    maxFilesize = 5*1024*1024 #5MB

    realityFilename = uuid.v4() if req.param('realityURL')?
    captureFilename = uuid.v4() if req.param('captureURL')?

    upload = (which, imageURL)->
      handleError = (err)->
        console.log err
        setTimeout ->
          req.socket.emit 'fail', {which, message:err}

      urlDetails = Url.parse imageURL
      console.log urlDetails
      return handleError 'Protocol Wrong, accept http/https only' if urlDetails.protocol not in ['http:','https:']

      imageRequest = Request imageURL

      imageRequest.on 'response', (res)->
        return handleError 'Wrong format' if not allowedContentType[res.headers['content-type']]
        return handleError 'Too large, max 5MB' if res.headers['content-length'] > maxFilesize
        uploadToS3 res

      imageRequest.on 'error', (err)->
        handleError 'Cannot fetch: '+err

      uploadToS3 = (res)->
        headers =
          'Content-Length': res.headers['content-length']
          'Content-Type': res.headers['content-type']
          'x-amz-acl': 'public-read'

        extension = allowedContentType[res.headers['content-type']]
        thisFilename = ""
        if which is 'reality'
          thisFilename = realityFilename += '.'+extension
        else
          thisFilename = captureFilename += '.'+extension

        client.putStream(res, thisFilename, headers, handleUploadResult)
        .on 'progress', (result)->
          req.socket.emit 'progress', {percent: result.percent, which}

      handleUploadResult = (err, res)->
        return handleError 'Upload error: '+err if err
        finished++
        if finished is fetchCount #all finished
          Photoset.create
            reality : realityFilename
            capture : captureFilename
            address : req.param 'address'
          .done (err, photoset)->
            req.socket.emit 'done', photoset.id

    upload 'reality', req.param 'realityURL' if req.param 'realityURL'
    upload 'capture', req.param 'captureURL' if req.param 'captureURL'
}