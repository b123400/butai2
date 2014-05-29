###
 * User
 *
 * @module      :: Model
 * @description :: A short summary of how this model works and what it represents.
 * @docs        :: http://sailsjs.org/#!documentation/models
###

bcrypt = require 'bcrypt'

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

    # toJSON: ->
    #   obj = this.toObject()
    #   delete obj.password
    #   return obj

    validPassword: (password, callback)->
      obj = this.toObject()
      return if not callback
      bcrypt.compare password, obj.password, callback
    
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