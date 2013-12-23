window.wagn_live ||= {} #needed to run w/o *head.  eg. jasmine

$(window).ready -> wagn_live.setupLiveEdit()

$.extend wagn_live,
  setupLiveEdit: ->
    titleDiv = $('div.live-view')
    titledCard = titleDiv.children('div.live-title')
    titledCard.children('span.card-title').before( wagn_live.liveTitleLeft )
    typeSpan = titledCard.children('span.live-type')
    typeSpan.wrap( wagn_live.liveType )
    #typeSpan = titledCard.children('span.live-type')
    typeSpan.before( wagn_live.liveTypeLeft )
    typeSpan.after( wagn_live.liveTypeRight )
    $('div.live-title').after( wagn_live.liveTitleRight )

    wagn_live.findContent titleDiv.find('.card-content')

    #titleDiv.find('table, ul, ol').addClass('live-container')
    #groups = $('div.live-view').find('span, p, div, tr')
    #groups.addClass('live-group')
    #all_items = groups.find('b, i, td, pre, cite, caption, strong, em, ins, sup, sub, del, li, h1, h2, h3, h4, h5, h6, td, th')
    #items = all_items.find(':not(a.missing-content)')
    #items.addClass('live-content')

    $("div.live-title").hover wagn_live.showTitleWidget, wagn_live.hideTitleWidget
    $('.live-type-field').focusout wagn_live.closeTypeSelector
    $('.live-type').on 'mouseup click', wagn_live.showTypeSelector
    $('.live-container, .live-content, .live-title').on 'mouseup click', wagn_live.editElementText
    $('body').on 'click', wagn_live.closeElementText

  findContent: (nodes) ->
    if !wagn_live.editableContent
      wagn_live.editableContent = {}
    for node in nodes
      key = wagn_live.selfClass node
      if !wagn_live.editableContent[key]
        childNodes = node.children
        if (childNodes.length == 1 && childNodes[0].tagName == 'DIV' &&
             $(childNodes[0]).hasClass('card-content'))
          childNodes = childNodes[0].children
        wagn_live.editableContent[key] = wagn_live.contentDoc( childNodes )
    null
     

  contentDoc: (nodes) ->
    for node in nodes
      console.log(node)
    null
    
  selfClass: (node) ->
    if match = node.getAttribute('class').match(/\bSELF-[\S]+/)
      match[0].slice(5)

  liveTitle:
    '<div class="live-title"></div>'
  liveTitleLeft:
    '<span class="left-live-title-function live-title-function">
         <a class="ui-icon ui-icon-gear"></a></span>'
  liveTitleRight:
    '<span class="clearfix"></span>'
  liveType:
    '<span class="right-live-title-function live-title-function"></span>'
  liveTypeLeft:
    '<a class="ui-icon ui-icon-gear"> </a>'
  liveTypeRight:
    '<a class="ui-icon ui-icon-cancel"> </a>
     <a class="ui-icon ui-icon-close"> </a>
     <a class="ui-icon ui-icon-pencil"> </a>
     <a class="ui-icon ui-icon-person"> </a>'

  showTitleWidget: (event) ->
    $(this).find(".live-title-function").attr("style", "visibility: visible")
    false

  hideTitleWidget: (event) ->
    $(this).find(".live-title-function").attr("style", "visibility: hidden")
    false

  closeTypeSelector: (event) ->
    console.log('focusout')
    selection = $(this).parent().parent().find(".live-type-selection")
    selection.attr("style", "display:none")
    display = $(this).parent().parent().find(".live-type-display")
    display.attr("style", "display:visible")
    display.html( selection.find('select').attr('value') )
    wagn_live.finishEdit(this)

  showTypeSelector: (event) ->
    thisq = $(this)
    wagn_live.finishEdit(this)
    console.log('enable type selection')
    selection = thisq.find(".live-type-selection")
    selection.attr("style", "display:visible")
    if selection.hasClass('no-edit')
      timeout_function = ->
        selection.attr("style", "display:none")
      setTimeout( timeout_function, 5000 )
    else
      thisq.find(".live-type-display").attr("style", "display:none")
      wagn_live.editElement = this
      wagn_live.editElementContent = this.innerHTML
    false

  editElementText: (event) ->
    console.log(event)
    if event.target.parentElement.tagName == "A"
      return true
    thisq = $(this)
    wagn_live.finishEdit(this)
    thisq.attr('contenteditable', true)
    wagn_live.editElement = this
    wagn_live.editElementContent = this.innerHTML
    false

  closeElementText: (event) ->
    console.log(event)
    wagn_live.finishEdit()
    true

  finishEdit: (newElement) ->
    if (wagn_live.editElement && newElement != wagn_live.editElement)
      $(wagn_live.editElement).attr('contenteditable', true)
      console.log('changed element?')
      # send update on this element
    wagn_live.editElement = null

