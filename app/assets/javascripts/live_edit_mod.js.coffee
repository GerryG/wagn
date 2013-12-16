window.wagn ||= {} #needed to run w/o *head.  eg. jasmine

$.extend wagn,
  finishEdit: (newElement) ->
    if (wagn.editElement && newElement != wagn.editElement)
      $(wagn.editElement).attr('contenteditable', true)
      console.log('changed element?')
      # send update on this element
    wagn.editElement = null



$(window).ready ->
  $("div.live-title").hover( (event) ->
      $(this).find(".live-title-function").attr("style", "visibility: visible")
      false
    , (event) ->
      $(this).find(".live-title-function").attr("style", "visibility: hidden")
      false
    )

  $('.live-type-field').focusout (event) ->
    console.log('focusout')
    selection = $(this).parent().parent().find(".live-type-selection")
    selection.attr("style", "display:none")
    display = $(this).parent().parent().find(".live-type-display")
    display.attr("style", "display:visible")
    display.html( selection.find('select').attr('value') )
    wagn.finishEdit(this)

  $('.live-edit, .live-title, .live-type').on 'mouseup click', (event) ->
    thisq = $(this)
    wagn.finishEdit(this)
    if thisq.hasClass('live-type')
      console.log('enable type selection')
      selection = thisq.find(".live-type-selection")
      selection.attr("style", "display:visible")
      if selection.hasClass('no-edit')
        timeout_function = ->
           console.log('no edit (timeout expired)')
           console.log(selection)
           selection.attr("style", "display:none")
        console.log('no edit (timeout)')
        setTimeout( timeout_function, 5000 )
        return false
      else
        thisq.find(".live-type-display").attr("style", "display:none")

    else
      thisq.attr('contenteditable', true)
      console.log("add editable")

    wagn.editElement = this
    wagn.editElementContent = this.innerHTML
    console.log(wagn.editElement)
    #console.log(wagn.editElementContent)
    console.log(event)
    false

  $('body').on 'click', (event) ->
    console.log(event)
    wagn.finishEdit()
    true

  # etherpad mod
  $('body').on 'click', '.etherpad-submit-button', ->
    wagn.padform = $(this).closest('form')

    padsrc = $(wagn.padform).find('iframe')[0].src
    if (qindex = padsrc.indexOf('?')) != -1
      padsrc = padsrc.slice(0,qindex)

    # perform an ajax call on contentsUrl and write it to the parent
    $.get padsrc + '/export/html', (data) ->
       $(wagn.padform).find('.etherpad-textarea')[0].value = data
       $(wagn.padform)[0].submit()
    false

  #wagn_org mod (for now)
  $('body').on 'click', '.shade-view h1', ->
    toggleThis = $(this).slot().find('.shade-content').is ':hidden'
    toggleShade $(this).closest('.pointer-list').find('.shade-content:visible').parent()
    if toggleThis
      toggleShade $(this).slot()


  if firstShade = $('.shade-view h1')[0]
    $(firstShade).trigger 'click'
    

  #wikirate mod
  $('body').on 'mouseenter', '#wikirate-nav > a', ->
    ul = $(this).find 'ul'
    if ul[0]
      ul.css 'display', 'inline-block'
    else
      link = $(this)
      $.ajax link.attr('href'), {
        data : { view: 'navdrop', layout: 'none', index: $('#wikirate-nav > a').index(link) },
#        type : 'POST',
        success: (data) ->
          #alert 'success!'
          wagn.d = data
          link.prepend $(data).menu()
      }
  
  $('body').on 'mouseleave', '#wikirate-nav ul', ->
    $(this).hide()
      
#  $('body').on 'change', '.TYPE-claim .card-editor fieldset.RIGHT-source_type', ->
#    f = $(this).closest 'form' 
#    val = $(this).find('input:checked').val()
#    
#    new_field      = f.find 'fieldset.RIGHT-source_link'
#    existing_field = f.find 'fieldset.RIGHT-source'
#    
#    if val == 'existing'
#      existing_field.show()
#      new_field.hide()
#    else
#      existing_field.hide()
#      new_field.show()
#
#  $('.TYPE-claim .card-editor fieldset.RIGHT-source_type').trigger 'change'

  # following not in use??
  
  $('body').on 'change', '.go-to-selected select', ->
    val = $(this).val()
    if val != ''
      window.location = wagn.rootPath + escape( val )

$(document).bind 'mobileinit', ->
  $.mobile.autoInitializePage = false
  $.mobile.ajaxEnabled = false

toggleShade = (shadeSlot) ->
  shadeSlot.find('.shade-content').slideToggle 1000
  shadeSlot.find('.ui-icon').toggleClass 'ui-icon-triangle-1-e ui-icon-triangle-1-s'  

permissionsContent = (ed) ->
  return '_left' if ed.find('#inherit').attr('checked')
  groups = ed.find('.perm-group input:checked').map( -> $(this).val() )
  indivs = ed.find('.perm-indiv input'        ).map( -> $(this).val() )
  pointerContent $.makeArray(groups).concat($.makeArray(indivs))

pointerContent = (vals) ->
  list = $.map $.makeArray(vals), (v)-> if v then '[[' + v + ']]'
  $.makeArray(list).join "\n"

#navbox mod
reqIndex = 0 #prevents race conditions

navbox_results = (request, response) ->
  f = this.element.closest 'form'
  formData = f.serialize() + '&view=complete'
  
  this.xhr = $.ajax {
    url: wagn.prepUrl wagn.rootPath + '/:search.json'
    data: formData
    dataType: "json"
    wagReq: ++reqIndex
    success: ( data, status ) ->
      response navboxize(request.term, data) if this.wagReq == reqIndex
    error: () ->
      response [] if this.wagReq == reqIndex
    }

navboxize = (term, results)->
  items = []

  $.each ['search', 'add', 'new'], (index, key)->
    if val = results[key]
      i = { value: term, prefix: key, icon: 'plus', label: '<strong class="highlight">' + term + '</strong>' }
      if key == 'search'
        i.icon = key
        i.term = term
      else if key == 'add'
        i.href = '/card/new?card[name]=' + encodeURIComponent(val)
      else if key == 'new'
        i.type = 'add' # for icon
        i.href = '/new/' + val[1]

      items.push i

  $.each results['goto'], (index, val) ->
    items.push { icon: 'arrowreturnthick-1-e', prefix: 'go to', value: val[0], label: val[1], href: '/' + val[2] }

  $.each items, (index, i) ->
    i.label =
      '<span class="navbox-item-label"><a class="ui-icon ui-icon-'+ i.icon + '"></a>' + i.prefix + ':</span> ' +
      '<span class="navbox-item-value">' + i.label + '</span>'

  items

navbox_select = (event, ui) ->
  if ui.item.term
    $(this).closest('form').submit()
  else
    window.location = wagn.rootPath + ui.item.href

  $(this).attr('disabled', 'disabled')


  
