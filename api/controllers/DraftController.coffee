###
 * DraftController
 *
 * @module      :: Controller
 * @description :: A set of functions called `actions`.
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
ImageUploader = require './ImageUploader'
validator = require 'validator'
Q = require 'q'
Async = require 'async'

module.exports = {
  
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to DraftController)
  ###
  _config: {}

  index : (req, res)->
    
    handleError = (err)->
      throw err

    Draft.find().limit(10).skip(req.param('p')*10||0).sort('id DESC').exec (err, drafts)->
      return handleError err if err

      userFields = drafts
      .map    (draft)          -> draft.user_id
      .filter (id, index, self)-> id? and index is self.indexOf id #unique

      artworkFields = drafts
      .map    (draft)          -> draft.artwork_id
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
        return handleError err if err

        _users = {}
        results.users.forEach (u)-> _users[u.id] = u
        drafts.forEach (p)-> p.user = _users[p.user_id]
        
        _artworks = {}
        results.artworks.forEach (a)-> _artworks[a.id] = a
        drafts.forEach (p)-> p.artwork = _artworks[p.artwork_id]

        res.view 'draft/index',
          sidebarPartial : 'draft/indexSidebar',
          sidebarContent :
            artworks : results.artworks
          drafts : drafts


  create : (req, serverResponse)->

    if not req.param 'socket'
      Artwork.find().limit().sort('id DESC').exec (err, artworks)->
        serverResponse.view 'draft/create',
          # sidebarPartial : 'draft/createSidebar',
          artworks : artworks
      return


    handleError = (reason)->
      req.socket.emit 'fail', reason


    if req.param('url')? && req.param('url') != "" && not validator.isURL req.param 'url'
      return handleError 'Not a URL'


    val = req.param 'capture'
    uploadDefer = null


    if val is "file"
      uploader = new ImageUploader.WebsocketImageUploader
      uploadDefer = uploader.uploadWithSocket req.socket, 'capture', req.param("capture-file-type"), req.param("capture-file-size")
    else if validator.isURL val
      uploader = new ImageUploader.URLImageUploader
      uploadDefer = uploader.uploadWithURL val

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

    Q.all([
      uploadDefer,
      getOrCreateArtwork req.param 'artwork'
    ])
    .spread (filename, artwork)->
      console.log arguments
      Draft.create
        capture : filename
        url     : req.param 'url'
        address : req.param 'address'
        lat     : req.param 'lat'
        lng     : req.param 'lng'
        artwork_id : artwork?.id
        user_id : req.user?[0]?.id
      .exec (err, draft)->
        if err
          handleError err
          return
        console.log 'done: '+'/draft/find/'+draft.id
        req.socket.emit 'done', '/draft/find/'+draft.id
}