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

client = knox.createClient sails.config.aws

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to PhotosetController)
  ###
  _config: {}

  # index : (req, res)->
  #   res.view 'photoset/index'

  add : (req, res)->
    res.view 'photoset/add'

  create : (req, serverResponse)->
    request = http.get 'http://s3-ap-northeast-1.amazonaws.com/butai/112/photos_original.JPG', (res)->
      headers =
        'Content-Length': res.headers['content-length']
        'Content-Type': res.headers['content-type']

      client.putStream res, '/doodle.png', headers, (err, res)->
        if err
          console.log err
          serverResponse.send 'upload error'+err
          return

        Photoset.create
          reality : req.param 'reality'
          capture : req.param 'capture'
          address : req.param 'address'
        .done (err, photoset)->
          serverResponse.redirect 'photoset/find/'+photoset.id

    request.on 'error', (err)->
      serverResponse.send 'not a url'
}