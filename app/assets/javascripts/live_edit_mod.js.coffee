window.wagn_live ||= {} #needed to run w/o *head.  eg. jasmine

$(window).ready -> wagn_live.setupLiveEdit()

$.extend wagn_live,

  liveTitle: # titled -> live edit layout
    '<div class="live-title"></div>'
  liveTitleLeft:
    '<div class="left-live-title-function live-title-function">
         <a class="ui-icon ui-icon-gear"></a></div>'
  liveTitleRight:
    '<span class="clearfix"></span>'
  liveType:
    '<div class="right-live-title-function live-title-function"><span class="live-type cardtype"></span></div>'
  liveTypeLeft:
    '<a class="ui-icon ui-icon-gear"> </a>'
  liveTypeRight:
    '<div class="clearfix"></div>
     <div class="icon-row"><a class="ui-icon ui-icon-cancel"> </a>
     <a class="ui-icon ui-icon-close"> </a>
     <a class="ui-icon ui-icon-pencil"> </a>
     <a class="ui-icon ui-icon-person"> </a></div>
     <div class="clearfix"></div>'
  setupLiveEdit: ->
    wagn_live.typeSelection = $('head script[type="text/template"].live-type-selection')
    if wagn_live.typeSelection.length > 0
      wagn_live.typeSelection = wagn_live.typeSelection[0].innerHTML
      titledCard = $ 'div.titled-view'
      titleDiv = titledCard.children 'h1.card-header'
      titleDiv.wrapInner wagn_live.liveTitle
      titleDiv = titleDiv.children 'div.live-title'
      titleDiv.unwrap()
      titleDiv.children('span.card-title').before( wagn_live.liveTitleLeft )
      titleDiv.after( wagn_live.liveTitleRight )
      typeDiv = titleDiv.children('a.cardtype')
      typeDiv.wrapInner( wagn_live.liveType )
      titleDiv.find('a.cardtype.no-edit > div > span.live-type').addClass('no-edit')
      typeDiv = typeDiv.children('div.right-live-title-function')
      typeDiv.unwrap()
      typeSpan = typeDiv.children("span.live-type")
      typeSpan.before( wagn_live.liveTypeLeft )
      typeSpan.after( wagn_live.liveTypeRight )

      #wagn_live.findContent titleDiv.find('.card-content')

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
        childNodes = node.childNodes
        if (childNodes.length == 1 && childNodes[0].tagName == 'DIV' &&
             $(childNodes[0]).hasClass('card-content'))
          childNodes = childNodes[0].childNodes
        wagn_live.editableContent[key] = wagn_live.contentDoc( childNodes )
    null


  contentDoc: (nodes) ->
    for node in nodes
      jnode = $(node)
      type = node.nodeType
      if type == 3 # text
      else if type == 1
        tag = node.tagName
        if tag == 'DIV' && (jnode.hasClass('card-content') || jnode.hasClass('live-view'))
          [{'inclusion': JSON.parse(node.getAttribute('data-slot'))}, wagn_live.findContent(jnode)]
        else if -1 != wagn_live.containerTags.indexOf tag
        else if -1 != wagn_live.contentTags.indexOf tag
        else
          console.log("Unexpected tag: " + tag)
      else
        console.log("Unexpected node type: " + type)

  selfClass: (node) ->
    if match = node.getAttribute('class').match(/\bSELF-[\S]+/)
      match[0].slice(5)

  containerTags: ['TABLE', 'TR', 'UL', 'OL', 'DIV']
  contentTags: ['P', 'SPAN', 'TD', 'TH', 'LI', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6',
                'B', 'EM', 'STRONG', 'I', 'INS', 'DEL', 'SUB', 'SUP', 'CITE', 'CAPTION',
                'CODE', 'PRE']

  showTitleWidget: (event) ->
    $(this).find(".live-title-function").attr("style", "visibility: visible")
    false

  hideTitleWidget: (event) ->
    $(this).find(".live-title-function").attr("style", "visibility: hidden")
    false

  showTypeSelector: (event) ->
    that = this
    thisq = $(this)
    typeName = this.innerHTML
    wagn_live.finishEdit(this)
    console.log('enable type selection')
    #selection = thisq.find(".live-type-selection")
    #selection.attr("style", "display:visible")
    if thisq.hasClass('no-edit')
      cardName = thisq.parents('div.titled-view').attr('id')
      this.innerHTML= ("<span>Can't change type, " + cardName + " cards exits.</span>")
      timeout_function = ->
        that.innerHTML = typeName
      setTimeout( timeout_function, 5000 )
    else
      this.innerHTML = wagn_live.typeSelection
      #thisq = $(this)
      thisq.find('select').on('change', (event) ->
        selectedType = this.value
        that.innerHTML= selectedType
        wagn_live.showTitleWidget.call($(that).parents('div.live-title'))
        wagn_live.finishEdit(that) )

      thisq.find('option[value="'+typeName+'"]').prop('selected', true)
      wagn_live.editElement = this
    false

  editElementText: (event) ->
    console.log(event)
    if this.parentElement.tagName == "A"
      return true
    if this.tagName == 'INPUT' # process a button normally
      return true
    target = $(this).children('span.card-title')
    that = this
    if target.length > 0
      that = target[0]
    thisq = $(that)
    wagn_live.finishEdit(that)
    thisq.attr('contenteditable', true)
    wagn_live.editElement = that
    wagn_live.editElementContent = that.innerHTML
    false

  closeElementText: (event) ->
    console.log(event)
    wagn_live.finishEdit()
    true

  finishEdit: (newElement) ->
    if (wagn_live.editElement && newElement != wagn_live.editElement)
      wagn_live.editElement.removeAttribute('contenteditable')
      console.log('changed element?' + wagn_live.editElement.innerHTML)
      # send update on this element
    wagn_live.editElement = null

