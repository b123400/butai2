###
 * Photoset
 *
 * @module      :: Model
 * @description :: A short summary of how this model works and what it represents.
 * @docs        :: http://sailsjs.org/#!documentation/models
###

sails = require 'sails'
async = require 'async'
knox = require 'knox'
client = knox.createClient sails.config.aws

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
    
    getImageURL : (which, width=0, height=0)->
      baseURL = sails.config.aws.urlPrefix #"http://s3-ap-northeast-1.amazonaws.com/butai/"
      url = undefined
      if which is 'reality'
        return null if not @reality
        url = baseURL + @reality
      else
        return null if not @capture
        url = baseURL + @capture

      if width instanceof Object
        height = width.height
        width = width.width

      if width? or size?
        url = url.replace 'http://', ''
        sizeString = width+'x'+height
        url = "http://media.but.ai/unsafe/#{sizeString}/#{url}"
      return url

    getArtwork : (cb)->
      Artwork.findOne({id : @artwork_id}).done cb

    getUser : (cb)->
      User.findOne({id: @user_id}).done(cb)

    deleteFileAndDestroy : (cb)->
      filesToDelete = [@reality, @capture].filter (e)-> e

      client.deleteMultiple filesToDelete, (err)=>
        return cb err if err
        @destroy cb

    getNearBy : (count=1, cb)->
      return cb? null, null if not @lat or not @lng
      count = Number count
      query = """SELECT POW(lat-#{@lat},2) + POW(lng-#{@lng},2) AS "d", id
      FROM photoset 
      WHERE lat IS NOT NULL AND id != #{@id}
      ORDER BY d
      LIMIT #{count};"""
      Photoset.query query, (err, results)->
        return cb err if err
        ids = results.map (r)-> r.id
        Photoset.find().where({id: ids}).exec (err, photosets)->
          return cb err if err
          photosets.sort (a, b)->
            ids.indexOf(a)-ids.indexOf(b)
          cb null, photosets
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