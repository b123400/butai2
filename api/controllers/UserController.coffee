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

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to UserController)
  ###
  _config: {}

  create : (req, res)->
    if not req.param('username') or not req.param('password')
      return res.view()

    User.findOne {username : req.param 'username'}, (err, user)->
      return console.log err if err

      if user
        return res.view '/user/create',
          error : 'ユーザーネームが使われてます'

      User.create
        username : req.param 'username'
        password : req.param 'password'
      .done (err, user)->
        return console.log err if err

        res.view 'user/thanks'

  find : (req, res)->
    User.findOne {id: req.param 'id'}, (err, user)->
      res.view '/user/find', {user}
}
