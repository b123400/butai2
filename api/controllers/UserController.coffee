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

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to UserController)
  ###
  _config: {}

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
      .done (err, user)->
        return showError JSON.stringify(err) if err

        req.logIn user, (err)->
          return showError err if err
          res.view 'user/thanks'

  find : (req, res)->
    async.parallel
      user      : (cb)-> User.findOne {id: req.param 'id'}, cb
      photosets : (cb)-> Photoset.find {user_id: req.param 'id'}, cb
    , (err, results)->
      return res.send 404 if err or results.length is 0

      results.photosets.forEach (p)-> p.user = results.user

      res.view 'photoset/index',
        photosets : results.photosets
        sidebarPartial : 'user/findSidebar'
        sidebarContent :
          user : results.user
}
