var passport = require('passport'),
    LocalStrategy = require('passport-local').Strategy;

passport.serializeUser(function(user, done) {
  done(null, user.id);
});

passport.deserializeUser(function(id, done) {
  User.findById(id, function (err, user) {
    done(err, user);
  });
});

passport.use(new LocalStrategy(
  function(username, password, done) {
    User.findByUsername(username).exec(function(err, users) {
        var user = users[0]
        if (err) {
            return done(null, err);
        }
        if (!user || user.length < 1) {
            return done(null, false, { message: 'Incorrect User'});
        }
        user.validPassword(password,function(err, result){
            if (!result) {
                return done(null, false, { message: 'Invalid Password'});
            }
            done(null, user);
        });
    });
  }
));