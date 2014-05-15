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

  enableInput = =>
    $(@).find('input').prop 'disabled', false

  fetchImage = (realityURL, captureURL)->
    socket.get '/photoset/create', {socket:true, realityURL, captureURL}, (result)->
      if result.success
        socket.on 'progress', updateProgress
        socket.on 'done', (id)->
          location.href = '/photoset/find/'+id
        socket.on 'fail', (err)->
          alert err
          enableInput()
      else
        enableInput()

  updateProgress = (progress)->
    if progress.which is "reality"
      $('form input.reality + div.progressbar-background').css 'width', progress.percent+'%'
    else if progress.which is "capture"
      $('form input.capture + div.progressbar-background').css 'width', progress.percent+'%'

  fetchImage $('#create-photoset input.reality').val(), $('#create-photoset input.capture').val()