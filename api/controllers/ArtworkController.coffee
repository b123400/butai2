###
 * ArtworkController
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
Q = require 'q'

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to ArtworkController)
   ###
  _config: {}

  find : (req, res)->
    Photoset.find { artwork_id: req.param 'id' }, (err, photosets)->
      res.view 'photoset/index', {photosets}

  index : (req, res)->
    Artwork.find().done (err, artworks)->
      promises = artworks.map (thisArtwork)->
        Q.ninvoke(thisArtwork,"preparePhotosets",1) # count = 1
      console.log promises

      Q.all(promises).done ->
        res.view 'artwork/index', {
          artworks,
          extraClass : 'extend-right'
        }

  create : (req, res)->
    Artwork.create
      name : req.param 'name'
    .done (err, result)->
      res.json result
}