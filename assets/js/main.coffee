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

  uploadPercentage = 0.5
  waitPercentage = 0.5

  $(@).find('input').prop 'disabled', true
  $('form .error').removeClass 'error'
  $('.error-message').fadeOut()
  socket.removeAllListeners 'fail'

  enableInput = =>
    $(@).find('input').prop 'disabled', false

  submitForm = (formData)->
    startData = $.extend socket : true, formData

    if formData.reality instanceof File
      startData.reality = "file"
      startData['reality-file-type'] = formData.reality.type
      startData['reality-file-size'] = formData.reality.size

    if formData.capture instanceof File
      startData.capture = "file"
      startData['capture-file-type'] = formData.capture.type
      startData['capture-file-size'] = formData.capture.size

    console.log startData

    socket.get '/photoset/create', startData, (result)->
      if result.success
        socket.on 'progress', updateProgress
        socket.on 'fail', handleFail
        socket.once 'done', (id)->
          location.href = '/photoset/find/'+id
      else
        if result.message
          alert result.message
        enableInput()

    upload = (which, file)->
      readBlob = (start, end, callback)->
        defer = $.Deferred()
        reader = new FileReader
        reader.onprogress = (e)->
          # console.log 'progress', e
        reader.onload = (e)->
          callback reader.result.replace(/^data:(.*)base64,/, "")
          defer.resolve()
        reader.readAsDataURL file.slice start, end
        return defer

      defer = $.Deferred().resolve();
      start = 0
      chunkSize = 400000 #400KB
      # Read file part by part
      while start < file.size
        end = Math.min start + chunkSize, file.size
        do (start,end)->
          defer = defer.then ->
            console.log start, end
            readBlob start, end, (blobData)->
              console.log blobData.substring(0,40)
              socket.emit 'file', {which, data:blobData}
        start += chunkSize
      defer.done ->
        console.log('done')
        socket.emit 'file-done', {which}

    upload 'reality', formData.reality if formData.reality instanceof File
    upload 'capture', formData.capture if formData.capture instanceof File

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

  submitForm
    reality : $('input[type=file].reality')[0].files[0] || $('#create-photoset input.reality').val()
    capture : $('input[type=file].capture')[0].files[0] || $('#create-photoset input.capture').val()
    url : $('input.url').val()
    lat : $('.map-canvas').data('location')?.lat?()
    lng : $('.map-canvas').data('location')?.lng?()
    address : $('.map-canvas').data('address')
    artwork : $('.artwork').val()

$('.select-file').on 'click', ->
  $(@).siblings('input[type=file]').click()
$('input[type=file]').on 'change', ->
  $(@).siblings('input[type=text]').prop
    disabled : true
    placeholder : "選択した"

$('#create-photoset .map-canvas').each (index, mapDiv)->
  initialize =->
    mapOptions = 
      center: new google.maps.LatLng(-34.397, 150.644),
      zoom: 8

    map = new google.maps.Map(mapDiv,mapOptions)

    thisMarker = undefined
    placeMarker= (location) ->
      if !thisMarker
        thisMarker = new google.maps.Marker
          position: location,
          map: map
      else
        thisMarker.setPosition location
      $(mapDiv).data 'location',location
      geocoder = new google.maps.Geocoder
      geocoder.geocode {'latLng':location}, (results, status) ->
        $(mapDiv).data 'address', results[0]?.formatted_address
    # panorama.setPosition location
    # google.maps.event.trigger map, 'picked_location', location

    google.maps.event.addListener map, 'rightclick', (event) ->
      placeMarker event.latLng
  
  google.maps.event.addDomListener window, 'load', initialize

$('.map-canvas[data-map]').each (index, mapDiv)->
  mapData = $.parseJSON($(@).attr('data-map'))
  initialize =->
    map = new google.maps.Map mapDiv,
      center: new google.maps.LatLng(mapData.lat , mapData.lng),
      zoom: 8
    $(mapDiv).data 'map', map
    #add marker
    thisMarker = new google.maps.Marker
      position: new google.maps.LatLng(mapData.lat, mapData.lng)
      map: map

  google.maps.event.addDomListener(window, 'load', initialize);

$('.map-canvas.browser').each (index, mapDiv)->
  map = null
  allPhotosets = []
  
  notAddedPhotosets = (photosets)->
    allIds = allPhotosets.map (p)-> p.id
    photosets.filter (p)-> p.id not in allIds

  addPhotosets = (photosets)->
    photosets.forEach (p)-> allPhotosets.push p
    return photosets

  filterAndAddPhotosets = (photosets)->
    addPhotosets notAddedPhotosets photosets

  getPhotosetsAt = (max_lat, max_lng, min_lat, min_lng, cb)->
    url = "/photoset/findWithLocation?max_lat="+max_lat+"&max_lng="+max_lng+"&min_lat="+min_lat+"&min_lng="+min_lng
    $.get(url,"json").done (photosets)->
      filterAndAddPhotosets(photosets).forEach (photoset)->
        thisLatlng = new google.maps.LatLng photoset.lat , photoset.lng
        marker = new google.maps.Marker
          position: thisLatlng
          map:map
        console.log 'added', photoset.id, photoset.lat, photoset.lng
        # marker.photoset = photoset
        # map.markers.push marker
      cb? photosets

    # google.maps.event.trigger map, 'added_marker', marker

  boundChanged =->
    bound = map.getBounds()
    return if not bound
    northeast = bound.getNorthEast()
    southwest = bound.getSouthWest()

    getPhotosetsAt northeast.lat(), northeast.lng(), southwest.lat(), southwest.lng(), refreshSidebar
    refreshSidebar()

  visiblePhotosets =->
    bounds = map.getBounds()
    allPhotosets.filter (p)-> bounds.contains new google.maps.LatLng p.lat, p.lng

  refreshSidebar =->
    # $('#test-output').html visiblePhotosets().map((p)-> p.id).join(',')
    divs = visiblePhotosets().map (photoset)->
      $('<div>')
      .addClass('map-photoset')
      .css('background-image','url('+(photoset.realityURL || photoset.captureURL || "")+')')
      .append( $('<p>').addClass('caption').html(photoset.artwork?.name) )
    $('.map-photosets').empty().append divs

  initialize =->
    # todo fetch a random photoset
    mapOptions =
      center: new google.maps.LatLng(36.35632878402529, 137.49508184814454)
      zoom: 7

    map = new google.maps.Map mapDiv, mapOptions
    google.maps.event.addListener map, 'bounds_changed', boundChanged

    $('mapDiv').data 'map', map
    window.map = map
  
  google.maps.event.addDomListener(window, 'load', initialize);