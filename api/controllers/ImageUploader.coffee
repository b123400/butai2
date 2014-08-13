knox = require 'knox'
sails = require 'sails'
client = knox.createClient sails.config.aws
events = require 'events'

class ImageUploader extends events.EventEmitter
  allowedContentType =
    'image/gif'  : 'gif'
    'image/jpg'  : 'jpg'
    'image/jpeg' : 'jpg'
    'image/pjpeg': 'jpg'
    'image/png'  : 'png'

  upload : (stream)->
    headers =
      'Content-Length': stream.headers['content-length']
      'Content-Type': stream.headers['content-type']
      'x-amz-acl': 'public-read'

    extension = allowedContentType[stream.headers['content-type']]
    if not extension
      @emit 'error', 'Wrong content-type: '+stream['content-type']
      return

    thisFilename = __filename__ += '.'+extension

    client.putStream(stream, thisFilename, headers, @handleUploadResult)
    .on 'progress', (result)=>
      # console.log result
      @emit 'progress', result
      # req.socket.emit 'progress', {percent: result.percent, which}
    .on 'error', (e)=>
      @emit 'error', e
      console.log e
      throw e

  handleUploadResult : (err, res)->
    return @emit 'error', err if err
    console.log res

class WebsocketImageUploader extends ImageUploader
  uploadWithSocket : (socket, identifier, type, fileSize)->
    customStream = stream.PassThrough();
    customStream.headers =
      'content-type' : type
      'content-length' : fileSize
    socket.on 'file', (file)->
      return if file.which isnt identifier
      file.data = new Buffer(file.data,'base64');
      console.log 'write', file.data.length
      customStream.write file.data
    socket.on 'file-done', (data)->
      console.log 'end', data, identifier
      return if data.which isnt which
      customStream.end()
    @upload customStream

module.exports = {
  ImageUploader,
  WebsocketImageUploader
}