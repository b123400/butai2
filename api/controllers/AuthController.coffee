###
 * AuthController
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

passport = require 'passport'

module.exports = {
    
  


  ###
   * Overrides for the settings in `config/controllers.js`
   * (specific to AuthController)
  ###
  _config: {}

  login : (req, res)->
    res.view()

  process : (req, res)->
    passport.authenticate('local', (err, user, info)->

      if err
        console.log 'process', err
        res.view 'auth/login',
          error : err
        return

      if not user
        res.view 'auth/login',
          error : info?.message
        return

      req.logIn user, (err)->
        console.log 'called login', arguments
        if err
          console.log err
          res.view 'auth/login',
            error : err
          return

        res.view 'auth/loggedin'

    )(req, res)

      # passport.authenticate('local', (err, user, info)->
      #   if err or not user
      #     console.log err
      #     # res.redirect('/login');
      #     return
        
      #   req.logIn user, (err)->
      #     if err
      #       res.redirect('/login');
      #     else
      #       res.redirect('/')
      # )(req, res)

  logout : (req, res)->
    req.logout()
    res.redirect '/'
}