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
    res.view 'photoset/find',
      sidebarPartial : 'photoset/findSidebar'
      sidebarContent :
        hello : 'world'

  create : (req, serverResponse)->

    if not req.param 'socket'
      return serverResponse.view 'photoset/create',
        sidebarPartial : 'photoset/createSidebar'

    if not req.param('realityURL') or not req.param('captureURL')
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

    realityFilename = uuid.v4()
    captureFilename = uuid.v4()

    upload = (which, imageURL)->
      handleError = (err)->
        console.log err
        req.socket.emit 'fail', {which, message:err}

      urlDetails = Url.parse imageURL
      console.log urlDetails
      return handleError 'Protocol Wrong, accept http/https only' if urlDetails.protocol.replace(/[:\/]/g,"") not in ['http','https']

      imageRequest = Request imageURL

      imageRequest.on 'response', (res)->
        return handleError 'Wrong format' if not allowedContentType[res.headers['content-type']]
        return handleError 'Too large, max 5MB' if res.headers['content-length'] > maxFilesize
        uploadToS3 res

      imageRequest.on 'error', (err)->
        handleError 'Cannot fetch: '+err

      getFilename =->
        if which is 'reality' then realityFilename else captureFilename

      uploadToS3 = (res)->
        headers =
          'Content-Length': res.headers['content-length']
          'Content-Type': res.headers['content-type']

        extension = allowedContentType[res.headers['content-type']]

        client.putStream(res, getFilename()+'.'+extension, headers, handleUploadResult)
        .on 'progress', (result)->
          req.socket.emit 'progress', {percent: result.percent, which}

      handleUploadResult = (err, res)->
        return handleError 'Upload error: '+err if err
        finished++
        if finished is 2 #both finished
          Photoset.create
            reality : realityFilename
            capture : captureFilename
            address : req.param 'address'
          .done (err, photoset)->
            req.socket.emit 'done', photoset.id

    upload 'reality', req.param 'realityURL'
    upload 'capture', req.param 'captureURL'
}