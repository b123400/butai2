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

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to UserController)
  ###
  _config: {}

  create : (req, res)->
    if not req.param('username') or not req.param('password') or not req.param('email')
      return res.view()

    User.findOne {username : req.param 'username'}, (err, user)->
      return console.log err if err

      if user
        return res.view '/user/create',
          error : 'ユーザーネームが使われてます'

      User.create
        username : req.param 'username'
        password : req.param 'password'
        email : req.param 'email'
      .done (err, user)->
        if err
          res.view '/user/create',
            error : err
          return

        res.view 'user/thanks'

  find : (req, res)->
    async.parallel
      user      : (cb)-> User.findOne {id: req.param 'id'}, cb
      photosets : (cb)-> Photoset.find {user_id: req.param 'id'}, cb
    , (err, results)->
      console.log results
      results.photosets.forEach (p)-> p.user = results.user

      res.view 'photoset/index',
        photosets : results.photosets
}
