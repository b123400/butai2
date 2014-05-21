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
stream = require 'stream'
util = require 'util'
validator = require 'validator'

# class Forwarder extends stream.Transform
#   _transform: (chunk, encoding, callback) ->
#     this.push(chunk);
#     callback();
#   constructor: ->
#     @writable = true
#   write: (chunk, encoding) ->
#     @emit 'data', chunk
#   end: ->
#     @emit 'end'

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
    Photoset.find().limit().done (err, photosets)->
      res.view 'photoset/index',
        sidebarPartial : 'photoset/indexSidebar',
        photosets : photosets

  find : (req, res)->
    Photoset.findOne(req.param('id')).exec (err, photoset)->
      res.view 'photoset/find',
        sidebarPartial : 'photoset/findSidebar'
        sidebarContent :
          hello : 'world'
          photoset : photoset
        photoset : photoset
        error : err

  create : (req, serverResponse)->

    if not req.param 'socket'
      return serverResponse.view 'photoset/create',
        sidebarPartial : 'photoset/createSidebar'

    fileCount = 0
    fileCount++ if req.param('reality') isnt ""
    fileCount++ if req.param('capture') isnt ""

    isUrl = validator.isURL req.param 'url'
    if fileCount is 0
      return serverResponse.json
        success : false
        message : 'No file'
    if not isUrl and req.param 'url' isnt ""
      return serverResponse.json
        success : false
        message : 'URL not correct'
    
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

    realityFilename = uuid.v4() if req.param('reality')?
    captureFilename = uuid.v4() if req.param('capture')?

    handleError = (which, err)->
      console.log err
      setTimeout ->
        req.socket.emit 'fail', {which, message:err}

    fetchImage = (which, imageURL)->
      urlDetails = Url.parse imageURL
      console.log urlDetails
      return handleError which, 'Protocol Wrong, accept http/https only' if urlDetails.protocol not in ['http:','https:']

      imageRequest = Request imageURL

      imageRequest.on 'response', (res)->
        uploadToS3 which, res

      imageRequest.on 'error', (err)->
        handleError 'Cannot fetch: '+err

    uploadToS3 = (which, stream)->
      return handleError which, 'Wrong format' if not allowedContentType[stream.headers['content-type']]
      return handleError which, 'Too large, max 5MB' if stream.headers['content-length'] > maxFilesize
      headers =
        'Content-Length': stream.headers['content-length']
        'Content-Type': stream.headers['content-type']
        'x-amz-acl': 'public-read'

      extension = allowedContentType[stream.headers['content-type']]
      thisFilename = ""
      if which is 'reality'
        thisFilename = realityFilename += '.'+extension
      else
        thisFilename = captureFilename += '.'+extension

      client.putStream(stream, thisFilename, headers, handleUploadResult.bind(null,which))
      .on 'progress', (result)->
        # console.log result
        req.socket.emit 'progress', {percent: result.percent, which}
      .on 'error', (e)->
        console.log e
        throw e

    handleUploadResult = (which, err, res)->
      return handleError which, 'Upload error: '+err if err
      finished++
      return if finished isnt fileCount #all finished

      #find artwork
      if not req.param('artwork') or req.param('artwork') is ""
        return createPhotoset()

      Artwork.findOne {name: req.param 'artwork'}, (err, artwork)->
        if err
          console.log err
          return createPhotoset()
        if artwork
          return createPhotoset artwork
        
        # no such artwork, create now
        Artwork.create
          name : req.param 'artwork'
        .done (err, artwork)->
          if err
            console.log err
            createPhotoset()
          else
            createPhotoset artwork

    createPhotoset = (artwork)->
      Photoset.create
        reality : realityFilename
        capture : captureFilename
        url     : if validator.isURL req.param 'url' then req.param 'url' else null
        address : req.param 'address'
        lat     : req.param 'lat'
        lng     : req.param 'lng'
        artwork_id : artwork?.id
      .done (err, photoset)->
        if err
          console.log err
          req.socket.emit 'fail', err
          return
        req.socket.emit 'done', photoset.id

    processParam =(which)->
      val = req.param which
      if val is "file"
        customStream = stream.PassThrough();
        customStream.headers =
          'content-type' : req.param "#{which}-file-type"
          'content-length' : req.param "#{which}-file-size"
        req.socket.on 'file', (file)->
          return if file.which isnt which
          file.data = new Buffer(file.data,'base64');
          console.log 'write', file.data.length
          customStream.write file.data
        req.socket.on 'file-done', (data)->
          console.log 'end', data, which
          return if data.which isnt which
          customStream.end()
        uploadToS3 which, customStream
      else if val isnt ""
        fetchImage which, val

    processParam 'reality'
    processParam 'capture'
}