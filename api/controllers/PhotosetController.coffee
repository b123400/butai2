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

    upload = (which, imageURL)->
      imageRequest = http.get imageURL, (res)->
        uploadToS3 res
      imageRequest.on 'error', (err)->
        handleError 'cannot fetch'+err

      uploadToS3 = (res)->
        headers =
          'Content-Length': res.headers['content-length']
          'Content-Type': res.headers['content-type']

        client.putStream(res, '/doodle'+Math.random()+'.png', headers, handleUploadResult)
        .on 'progress', (result)->
          req.socket.emit 'progress', {percent: result.percent, which}

      handleUploadResult = (err, res)->
        return handleError 'upload error'+err if err
        finished++
        if finished is 2 #both finished
          Photoset.create
            reality : req.param 'realityURL'
            capture : req.param 'captureURL'
            address : req.param 'address'
          .done (err, photoset)->
            req.socket.emit 'done', photoset.id

      handleError = (err)->
        console.log err
        socket.emit 'fail', err

    upload 'reality', req.param 'realityURL'
    upload 'capture', req.param 'captureURL'
}