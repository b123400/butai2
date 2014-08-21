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
Url = require 'url'
util = require 'util'
validator = require 'validator'
Q = require 'q'
async = require 'async'
ImageUploader = require './ImageUploader'

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
        Photoset.find().limit(10).skip(req.param('p')*10||0).sort('id DESC').done (err, photosets)->
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
          title : photoset.artwork?.name || ""

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
          p.captureURL = p.getImageURL 'capture', 200
          p.realityURL = p.getImageURL 'reality', 200
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

    if req.param('reality') is "" and req.param('capture') is ""
      return serverResponse.json
        success : false
        message : 'No file'

    isUrl = validator.isURL req.param 'url'
      
    if not isUrl and req.param 'url' isnt ""
      return serverResponse.json
        success : false
        message : 'URL not correct'
    
    serverResponse.json
      success: true
      message: 'hello'

    getOrCreateArtwork = (name)->
      #find artwork

      if not name or name is ""
        return Q.resolve()

      deferred = Q.defer()
      Artwork.getOrCreate name, (err, artwork)->
        if err
          deferred.resolve()
        else
          deferred.resolve artwork

      return deferred.promise

    createPhotoset = (capture, reality, artwork)->
      Photoset.create
        reality : reality
        capture : capture
        url     : req.param 'url'
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

    processParam = (which)->
      deferred = Q.defer()
      thatDefer = null
      val = req.param which

      if val is "file"
        uploader = new ImageUploader.WebsocketImageUploader
        thatDefer = uploader.uploadWithSocket req.socket, which, req.param("#{which}-file-type"), req.param("#{which}-file-size")
      else if val isnt ""
        uploader = new ImageUploader.URLImageUploader
        thatDefer = uploader.uploadWithURL val
      else
        return Q.resolve()

      thatDefer.then deferred.resolve, ((message)-> deferred.reject {which, message}), deferred.notify

      return deferred.promise

    Q.all([
      processParam('capture'),
      processParam('reality'),
      getOrCreateArtwork req.param 'artwork'
    ])
    .then (results)->
      createPhotoset results[0], results[1], results[2]
    
    # fail
    , (reason)->
      console.log 'error', reason
      setTimeout ->
        req.socket.emit 'fail', reason
        
    # progress
    , (result)->
      which  = if result.index is 0 then 'capture' else 'reality'
      req.socket.emit 'progress', {percent : result.value, which}
      
}