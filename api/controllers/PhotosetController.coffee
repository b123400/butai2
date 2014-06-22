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
Q = require 'q'
async = require 'async'

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

currentUploads = {}

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to PhotosetController)
  ###
  _config: {}

  # index : (req, res)->
  #   res.view 'photoset/index'

  index : (req, res)->
    async.parallel
      artworks : (cb)-> Artwork.find().limit().done cb
      photosets : (cb)->
        Photoset.find().limit().sort('id DESC').done (err, photosets)->
          return cb err if err

          userFields = photosets
          .map    (photoset)       -> photoset.user_id
          .filter (id, index, self)-> id? and index is self.indexOf id #unique

          artworkFields = photosets
          .map    (photoset)       -> photoset.artwork_id
          .filter (id, index, self)-> id? and index is self.indexOf id #unique

          async.parallel
            users    : (cb)->
              if not userFields.length
                cb null, []
              else
                User.find {id:userFields}, cb
            artworks : (cb)->
              if not artworkFields.length
                cb null, []
              else
                Artwork.find {id:artworkFields}, cb
          , (err, results)->
            return cb err if err

            _users = {}
            results.users.forEach (u)-> _users[u.id] = u
            photosets.forEach (p)-> p.user = _users[p.user_id]
            
            _artworks = {}
            results.artworks.forEach (a)-> _artworks[a.id] = a
            photosets.forEach (p)-> p.artwork = _artworks[p.artwork_id]

            cb null, photosets
    , (err, results)->
      console.log err if err
      res.view 'photoset/index',
        sidebarPartial : 'photoset/indexSidebar'
        sidebarContent : {
          artworks : results.artworks
        }
        photosets : results.photosets

  find : (req, res)->
    Photoset.findOne(req.param('id')).exec (err, photoset)->

      console.log err if err
      return res.send 404 if not photoset

      async.parallel
        user    : (cb)-> photoset.getUser cb
        artwork : (cb)-> photoset.getArtwork cb
        nearby  : (cb)-> photoset.getNearBy 1, cb
        related : (cb)->
          return cb null, null if not photoset.artwork_id
          Photoset.findOne {
            artwork_id: photoset.artwork_id
            id : {'not': photoset.id}
          }, cb
      , (err, result)->
        photoset.user = result.user
        photoset.artwork = result.artwork

        res.view 'photoset/find',
          sidebarPartial : 'photoset/findSidebar'
          sidebarContent :
            photoset : photoset
          photoset : photoset
          related : result.related
          nearby : result.nearby?[0]
          error : err

  findWithLocation : (req, res)->
    Photoset.findWithinBounds req.param('max_lat'), req.param('min_lat'), req.param('max_lng'), req.param('min_lng'), (err, photosets)->
      return res.json err, 500 if err

      artworkFields = photosets
      .map    (photoset)       -> photoset.artwork_id
      .filter (id, index, self)-> id? and index is self.indexOf id #unique

      done =(err, artworks)->
        return res.json err, 500 if err

        _artworks = {}
        artworks.forEach (a)-> _artworks[a.id] = a
        photosets.forEach (p)->
          p.artwork = _artworks[p.artwork_id]
          p.captureURL = p.getImageURL 'capture'
          p.realityURL = p.getImageURL 'reality'
        res.json photosets

      if not artworkFields.length
        done null, []
      else
        Artwork.find {id:artworkFields}, done

  'delete' : (req, res)->
    Photoset.findOne(req.param('id')).exec (err, photoset)->
      if req.method.toLowerCase() isnt 'post'
        return res.view 'photoset/delete', {photoset}

      photoset.deleteFileAndDestroy (error)->
        return res.view 'photoset/delete', {error} if err
        res.view 'photoset/deleted'

  edit : (req, res)->
    Photoset.findOne(req.param('id')).exec (err, photoset)->
      res.view 'photoset/edit'

  create : (req, serverResponse)->
    # fs = require 'fs'
    # photosets = fs.readFileSync("/Users/b123400/Desktop/dump.json")
    # photosets = JSON.parse photosets

    # allArtworks = photosets
    # .map (p)-> p.artwork
    # .forEach (artwork)->
    #   Artwork.create
    #     name : artwork.name
    #     id : artwork.id
    #   , (err)->
    #     console.log err if err

    # photosets.forEach (p)->
    #   Photoset.create
    #     id : p.id
    #     lat : p.latitude
    #     lng : p.longitude
    #     reality : p.photo.original.replace("http://s3-ap-northeast-1.amazonaws.com/butai/","")
    #     capture : p.capture.original.replace("http://s3-ap-northeast-1.amazonaws.com/butai/","")
    #     user_id : p.user.id
    #     artwork_id : p.artwork.id
    #     address : p.address
    #   , (err)->
    #     console.log err if err


    if not req.param 'socket'
      Artwork.find().limit().sort('id DESC').done (err, artworks)->
        serverResponse.view 'photoset/create',
          sidebarPartial : 'photoset/createSidebar',
          artworks : artworks
      return

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

    realityFilename = uuid.v4() if req.param('reality') isnt ""
    captureFilename = uuid.v4() if req.param('capture') isnt ""

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

      Artwork.getOrCreate req.param('artwork'), (err, artwork)->
        if err
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
        user_id : req.user?[0]?.id
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