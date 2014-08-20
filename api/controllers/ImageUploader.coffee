knox = require 'knox'
sails = require 'sails'
events = require 'events'
Q = require 'q'
uuid = require 'node-uuid'
stream = require 'stream'
Url = require 'url'
Request = require 'request'

client = knox.createClient sails.config.aws

class ImageUploader
  allowedContentType:
    'image/gif'  : 'gif'
    'image/jpg'  : 'jpg'
    'image/jpeg' : 'jpg'
    'image/pjpeg': 'jpg'
    'image/png'  : 'png'

  maxFilesize : 5*1024*1024 #5MB

  upload : (stream)->
    return Q.reject 'Wrong format' if not @allowedContentType[stream.headers['content-type']]
    return Q.reject 'Too large, max 5MB' if stream.headers['content-length'] > @maxFilesize

    headers =
      'Content-Length': stream.headers['content-length']
      'Content-Type': stream.headers['content-type']
      'x-amz-acl': 'public-read'

    extension = @allowedContentType[stream.headers['content-type']]
    if not extension
      return Q.reject 'Wrong content-type: '+stream['content-type']

    thisFilename = uuid.v4() + '.'+extension

    deferred = Q.defer()

    client.putStream(stream, thisFilename, headers, (err, res)->
      # console.log 'finish', arguments
      return deferred.reject err if err
      deferred.resolve thisFilename
    )
    .on 'progress', (result)=>
      # console.log result
      deferred.notify result.percent
    .on 'error', (e)=>
      deferred.reject e

    return deferred.promise

class WebsocketImageUploader extends ImageUploader
  uploadWithSocket : (socket, identifier, type, fileSize)->
    customStream = stream.PassThrough();

    customStream.headers =
      'content-type' : type
      'content-length' : fileSize

    socket.on 'file', (file)->
      return if file.which isnt identifier
      file.data = new Buffer( file.data,'base64' )
      # console.log 'write', file.data.length
      customStream.write file.data

    socket.on 'file-done', (data)->
      # console.log 'end', data, identifier
      return if data.which isnt identifier
      customStream.end()
    @upload customStream

class URLImageUploader extends ImageUploader
  uploadWithURL : (url)->
    urlDetails = Url.parse url
    # console.log urlDetails
    return Q.reject ' Protocol Wrong, accept http/https only' if urlDetails.protocol not in ['http:','https:']

    deferred = Q.defer()

    imageRequest = Request url
    imageRequest.on 'response', (res)=>
      @upload(res)
      .progress deferred.notify
      .done deferred.resolve

    imageRequest.on 'error', (err)->
      deferred.reject err if err

    return deferred.promise

module.exports = {
  Uploader : ImageUploader,
  WebsocketImageUploader,
  URLImageUploader
}