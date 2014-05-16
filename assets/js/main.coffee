if $('.capture').length > 0
  try
    BackgroundCheck.init
      targets: '.caption'
      images: '.capture, .photo'
      minComplexity: 20

    $('.artwork').on 'mouseenter mouseleave', (e)->
      capture = $(@).children '.capture'
      capture.stop().fadeToggle 500, ->
        caption = $(@).children('.caption').get(0)
        BackgroundCheck.refresh caption
  catch e
    #pass

$('#create-photoset').on 'submit', (e)->
  e.preventDefault()

  $(@).find('input').prop 'disabled', true
  $('form .error').removeClass 'error'
  $('.error-message').fadeOut()
  socket.removeAllListeners 'fail'

  enableInput = =>
    $(@).find('input').prop 'disabled', false

  fetchImage = (realityURL, captureURL)->
    socket.get '/photoset/create', {socket:true, realityURL, captureURL}, (result)->
      if result.success
        socket.on 'progress', updateProgress
        socket.on 'fail', handleFail
        socket.once 'done', (id)->
          location.href = '/photoset/find/'+id
      else
        enableInput()

  updateProgress = (progress)->
    if progress.which is "reality"
      $('form input.reality + div.progressbar-background').css 'width', progress.percent+'%'
    else if progress.which is "capture"
      $('form input.capture + div.progressbar-background').css 'width', progress.percent+'%'

  handleFail = (err)->
    if err.which is "reality"
      $('form input.reality').addClass 'error'
      $('form input.reality').siblings('.error-message').fadeIn().html err.message
    else if err.which is "capture"
      $('form input.capture').addClass 'error'
      $('form input.capture').siblings('.error-message').fadeIn().html err.message
    enableInput()

  fetchImage $('#create-photoset input.reality').val(), $('#create-photoset input.capture').val()