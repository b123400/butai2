###
 * UserController
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
async = require 'async'
validator = require 'validator'
sails = require 'sails'

PredictionIO = null
predictionClient = null
try
  PredictionIO = require 'predictionio-driver'
  predictionClient = new PredictionIO.Events
    url : sails.config.predictionio.eventUrl
    appId: sails.config.predictionio.appId
    accessKey: sails.config.predictionio.accessKey

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to UserController)
  ###
  _config: {}

  add : (req, res)->
    res.view 'user/create'

  create : (req, res)->
    showError = (err)->
      res.view 'user/create',
        error : err
        username : req.param 'username'
        password : req.param 'password'
        email : req.param 'email'

    if not req.param('username')
      return showError 'ユーザーネームがないです'
    if not req.param('password')
      return showError 'パスワードがないです'
    if not req.param('email')
      return showError 'Emailがないです'
    if not validator.isEmail req.param 'email'
      return showError 'Emailのフォマットが間違ってます'

    User.findOne {username : req.param 'username'}, (err, user)->
      return console.log err if err

      if user
        return showError 'ユーザーネームが使われてます'

      User.create
        username : req.param 'username'
        password : req.param 'password'
        email : req.param 'email'
      .exec (err, user)->
        return showError JSON.stringify(err) if err

        req.logIn user, (err)->
          return showError err if err
          res.view 'user/thanks'

        predictionClient?.createUser {
          uid: 'u'+(req.user?[0]?.id || 0)
          iid: "p"+photoset.id
        }, (err, predictionEvent)->

  findOne : (req, res)->
    async.parallel
      user      : (cb)-> User.findOne {id: req.param 'id'}, cb
      photosets : (cb)-> Photoset.find({user_id: req.param 'id'}).limit(10).skip(req.param('p')*10||0).exec(cb)
    , (err, results)->
      return res.send 404 if err or not results.user

      results.photosets.forEach (p)-> p.user = results.user

      res.view 'photoset/index',
        photosets : results.photosets
        sidebarPartial : 'user/findSidebar'
        sidebarContent :
          user : results.user

  edit : (req, res)->
    res.view 'user/edit'

  update : (req, res)->
    okToUpdate = (cb)->
      return cb 'ログインしてない'              if not req.user?[0]?
      return cb 'パスワードがないです'           if not req.param 'password'
      return cb 'Emailがないです'              if not req.param 'email'
      return cb 'Emailのフォマットが間違ってます' if not validator.isEmail req.param 'email'

      req.user[0].validPassword req.param('password'), (err, result)->
        return cb err if err
        return cb 'パスワードが間違ってます' if not result
        cb null, true

    okToUpdate (err, result)->
      return res.view 'user/edit', {error: err} if err
      req.user[0].email = req.param 'email'
      req.user[0].password = req.param 'new-password'
      req.user[0].save (err)->
        return res.view 'user/edit', {error: err} if err
        res.view 'user/edit', {message:'okです'}
}