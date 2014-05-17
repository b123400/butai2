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
    address : 'string'
    
    getImageURL : (which)->
      baseURL = "https://s3-ap-northeast-1.amazonaws.com/b123400test2/"
      if which is 'reality'
        baseURL + @reality
      else
        baseURL + @capture
  }
}