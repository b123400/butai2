/**
 * isAuthenticated
 *
 * @module      :: Policy
 * @description :: Simple policy to allow any authenticated user
 *                 Assumes that your login action in one of your controllers sets `req.session.authenticated = true;`
 * @docs        :: http://sailsjs.org/#!documentation/policies
 *
 */
// module.exports = function(req, res, next) {

//   // User is allowed, proceed to the next policy, 
//   // or if this is the last policy, the controller
//   if (req.session.authenticated) {
//     return next();
//   }

//   // User is not allowed
//   // (default res.forbidden() behavior can be overridden in `config/403.js`)
//   return res.forbidden('You are not permitted to perform this action.');
// };


var app = require('sails').express.app,
        // app = express(),
   passport = require('passport'),
      local = require('../../config/local');
 
app.use(passport.initialize());
 
/**
 * Allow any authenticated user.
 */
module.exports = function(req, res, ok) {
  // User is allowed, proceed to controller
  passport.authenticate('local', function(err, user, info) {
    if (err || !user) {
      // return res.send("You are not permitted to perform this action.", 403);
    }
    return ok();
  })(req, res, ok);
}