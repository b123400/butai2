###
 * Artwork
 *
 * @module      :: Model
 * @description :: A short summary of how this model works and what it represents.
 * @docs        :: http://sailsjs.org/#!documentation/models
 ###

module.exports = {

  attributes: {
    
    ### e.g.
    nickname: 'string'
    ###
    name : 'string'

    getPhotosets : (count=1, cb)->
      console.log arguments
      Photoset.find()
      .where('artwork_id':@id)
      .limit(count)
      .sort('id DESC')
      .exec(cb)

    preparePhotosets : (count=1, cb)->
      @getPhotosets count, (err, @photosets)=>
        cb? err, @photosets
  }

  getOrCreate : (name, cb)->
    @findOne {name}, (err, artwork)->
      if err
        return cb? err
      if artwork
        return cb? null, artwork
      
      # no such artwork, create now
      @create
        name : name
      .done (err, artwork)->
        if err
          cb? err
        else
          cb? null, artwork
}