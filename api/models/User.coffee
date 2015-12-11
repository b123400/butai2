###
 * User
 *
 * @module      :: Model
 * @description :: A short summary of how this model works and what it represents.
 * @docs        :: http://sailsjs.org/#!documentation/models
###

bcrypt = require 'bcrypt'
crypto = require 'crypto'

module.exports = {

  attributes: {
    
    ### e.g.
    nickname: 'string'
    ###
    username : 
      type : 'string'
      required : true
      unique : true

    password : 
      type : 'string'
      required : true

    email :
      type : 'email'
      required : true

    toJSON : ->
      obj = @toObject()
      delete obj.password
      delete obj.email
      return obj

    validPassword: (password, callback)->
      obj = this.toObject()
      return if not callback
      bcrypt.compare password, obj.password, callback
    
    avatarURL: (size)->
      hash = crypto.createHash('md5').update(@email||"").digest('hex')
      "http://www.gravatar.com/avatar/"+hash+"?d=retro&s="+size
  }

  beforeCreate: (user, cb)->
    bcrypt.genSalt 10, (err, salt)->
      bcrypt.hash user.password, salt, (err, hash)->
        if err
          console.log err
          cb err
        else
          user.password = hash
          cb null, user

  beforeUpdate: (user, cb)->
    if not user.password
      return cb null, user
      
    bcrypt.genSalt 10, (err, salt)->
      bcrypt.hash user.password, salt, (err, hash)->
        if err
          console.log err
          cb err
        else
          user.password = hash
          cb null, user

}