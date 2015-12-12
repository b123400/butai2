###
 * Photoset
 *
 * @module      :: Model
 * @description :: A short summary of how this model works and what it represents.
 * @docs        :: http://sailsjs.org/#!documentation/models
###

sails = require 'sails'
async = require 'async'
crypto = require 'crypto'
knox = require 'knox'
client = knox.createClient sails.config.aws

PredictionIO = null
predictionEngine = null
try
  PredictionIO = require 'predictionio-driver'
  predictionEngine = new PredictionIO.Engine url: sails.config.predictionio.engineUrl

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
        urlToHash = "#{sizeString}/#{url}"

        hash = crypto.createHmac('sha1',sails.config.thumbor.key)
          .update(urlToHash)
          .digest('base64')
          .replace(/\+/g, '-')
          .replace(/\//g, '_')

        url = "http://media.but.ai/#{hash}/#{urlToHash}"
      return url

    getArtwork : (cb)->
      Artwork.findOne({id : @artwork_id}).exec cb

    getUser : (cb)->
      User.findOne({id: @user_id}).exec(cb)

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
        return cb null, [] if not results.length

        ids = results.map (r)-> r.id
        Photoset.find().where({id: ids}).exec (err, photosets)->
          return cb err if err
          photosets.sort (a, b)->
            ids.indexOf(a)-ids.indexOf(b)
          cb null, photosets

    getRelated : (count=1, cb)->
      return cb? null, null if not @artwork_id
      return cb? null, [] if count is 0

      count = Number count
      # @getPrediction count, (err, results)=>
        # return cb null, results if not err and results.length isnt 0 #return prediction

        # failed to get prediction
      Photoset.find({
        artwork_id: @artwork_id
        id : {'not': @id}
        })
        .limit(count)
        .exec(cb)

    getPrediction : (count=1, cb)->
      return cb "PredictionIO Engine not found", null if not predictionEngine
      return cb null, [] if count is 0

      predictionEngine.sendQuery {
        items : ['p'+@id]
        categories : ['a'+@artwork_id]
        num : count
      }, (err, result)->
        return cb err if err
        {itemScores} = result
        id = itemScores.map (i)-> Number i.item.replace('p','')
        Photoset.find {id}, cb

    toJSON : ->
      obj = @toObject()
      obj.user = @user.toJSON()
      obj.reality = @getImageURL 'reality', 800, 600
      obj.capture = @getImageURL 'capture', 800, 600
      return obj
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