###
 * Photoset
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
    reality : 'string'
    capture : 'string'
    url     : 'url'
    address : 'string'
    lat : 'float'
    lng : 'float'
    artwork_id : 'integer'
    user_id : 'integer'
    
    getImageURL : (which)->
      baseURL = "https://s3-ap-northeast-1.amazonaws.com/b123400test2/"
      if which is 'reality'
        return null if not @reality
        baseURL + @reality
      else
        return null if not @capture
        baseURL + @capture

    getArtwork : (cb)->
      Artwork.findOne({id : @artwork_id}).done(cb)

    getUser : (cb)->
      User.findOne({id: @user_id}).done(cb)
  }

  findWithinBounds : (maxLat, minLat, maxLng, minLng, cb)->
    @find
      lat : 
        '>=' : minLat
        '<=' : maxLat
      lng :
        '>=' : minLng
        '<=' : maxLng
    , cb
}