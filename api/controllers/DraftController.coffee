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

    val = req.param 'image'
    if val is "file"
      uploader = new ImageUploader.WebsocketImageUploader
      thatDefer = uploader.uploadWithSocket req.socket, which, req.param("file-type"), req.param("file-size")
    else if val isnt ""
      uploader = new ImageUploader.URLImageUploader
      thatDefer = uploader.uploadWithURL val
}