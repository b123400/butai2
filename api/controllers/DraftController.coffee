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

module.exports = {
  
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to DraftController)
  ###
  _config: {}

  create : (req, serverResponse)->

    if not req.param 'socket'
      Artwork.find().limit().sort('id DESC').done (err, artworks)->
        serverResponse.view 'draft/create',
          sidebarPartial : 'draft/createSidebar',
          artworks : artworks
      return

    handleError = (reason)->
      req.socket.emit 'fail', reason

    if req.param('url')? && not validator.isURL req.param 'url'
      return handleError 'Not a URL'

    val = req.param 'image'
    uploadDefer = null

    if val is "file"
      uploader = new ImageUploader.WebsocketImageUploader
      uploadDefer = uploader.uploadWithSocket req.socket, which, req.param("file-type"), req.param("file-size")
    else if validator.isURL val
      uploader = new ImageUploader.URLImageUploader
      uploadDefer = uploader.uploadWithURL val

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
      .done (err, draft)->
        if err
          console.log err
          handleError err
          return
        req.socket.emit 'done', draft.id
}