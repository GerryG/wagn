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

      data = wagn_live.findContent titledCard.find('.card-content:not(.closed-content)')
      wagn_live.shareConnect data[0], data[1]

      $("div.live-title").hover wagn_live.showTitleWidget, wagn_live.hideTitleWidget
      $('div.titled-view span.cardtype').on 'mouseup click', wagn_live.showTypeSelector
      $('div.card-content:not(.closed-content)').on 'focusin', wagn_live.editElementText
      $('div.titled-view span.card-title').on 'focusin', wagn_live.editCardname
      $('div.titled-view span.card-title').attr('contenteditable', true)
      #$('div.titled-view span.card-title, div.card-content:not(.closed-content)').attr('contenteditable', true)
      true

  findContent: (nodes) ->
    editableContent = {}
    mainKey = null
    for node in nodes
      if key = wagn_live.selfClass node
        unless mainKey then mainKey = key
        if !editableContent[key]
          editableContent[key] = wagn_live.contentDoc( node )
        #console.log(key + ' => ' + wagn_live.cardInspect(editableContent[key]))
      else
        console.log('no cardname')
        console.log(node)
    [ mainKey, editableContent ]

  selfClass: (node) ->
    if match = node.getAttribute('class').match(/\bSELF-[\S]+/)
      match[0].slice(5)

  attrHash: (node) ->
    obj = {}
    for attr in node.attributes
      obj[attr.name] = attr.value
    obj

  contentDoc: (node) ->
    $(node).sortable( wagn_live.sortOptions )
    for node in node.childNodes
      jnode = $(node)
      type = node.nodeType
      if type == 3 # text
        node.textContent
      else if type == 1
        tag = node.tagName
        if tag == 'DIV' && (jnode.hasClass('card-content') || jnode.hasClass('titled-view'))
          if jnode.hasClass('titled-view')
            node = jnode.find('.card-content')[0]
          data = JSON.parse(node.getAttribute('data-slot'))
          ['inclusion', data]
        else if tagType = wagn_live.tagTypes[ tag ]
          if tagType != 4
            jnode.draggable( wagn_live.dragOptions )
            jnode.draggable( 'option', 'connectToSortable', wagn_live.connectToSortable( tag ) )

          if tagType == 1
            jnode.sortable( wagn_live.sortOptions )
          else if tagType == 2
            jnode.attr('contenteditable', true)

          children = wagn_live.contentDoc(node)
          children.unshift(tag, wagn_live.attrHash(node))
          children
        else
          console.log("Unexpected tag: " + tag)
      else if type == 8
        console.log("Comment")
      else
        console.log("Unexpected node type: " + type)

  connectToSortable: (tag) ->
    if wagn_live.flowTarget[tag]
      wagn_live.flowTags + wagn_live.inlineTags
    else if wagn_live.inlineTarget[tag]
      wagn_live.inlineTags
    else if tags = wagn_live.allowedDragTarget[tag]
      tags
    else
      ''

  dragOptions:
    helper: 'clone'
    stop: (event, ui) ->
      console.log('drag stop')
      console.log(event)
      console.log(ui)
    start: (event, ui) ->
      console.log('drag start')
      console.log(event)
      console.log(ui)


  sortOptions:
    helper: 'clone',
    start: (event, ui) ->
      wagn_live.dragFrom = ui.item.index()
      ui.item.remove()
    update: (event, ui) ->
      console.log('update', ui.item.index())
      wagn_live.dragFrom = null
    change: (event, ui) ->
      newPos = ui.placeholder.index()
      console.log('sending move', wagn_live.dragFrom, newPos)
      wagn_live.shareDoc.at().move(wagn_live.dragFrom, newPos)
      wagn_live.dragFrom = newPos
    beforeStop: (event, ui) ->
      console.log(ui.item)
      ui.placeholder.before(ui.item)
    #hoverClass: 'drop-hover'


  # flow P, H?, OL, UL, PRE, DIV, BLOCKQUOTE, TABLE, text, I, B, EM, STRONG, CODE, CITE, SUP, SPAN
  #  block: P, H?, OL, UL, PRE, DIV, BLOCKQUOTE, TABLE
  #  inline: text, I, B, EM, STRONG, CODE, CITE, SUP, SPAN
  flowTarget: { DIV:1, TD:1, TH:1, LI:1, BLOCKQUOTE:1 }
  inlineTarget: P:1, I:1, B:1, SUB:1, SUP:1, CITE:1, STRONG:1, EN:1, H1:1, H2:1, H3:1, H4:1, H5:1, H6:1,
    SPAN:1, PRE:1
  flowTags: 'div td th li blockquote pre'
  inlineTags: 'p i b a sub sup cite strong en h1 h2 h3 h4 h5 h6 span img' # plus text(pcdata)
  allowedDragTarget:
    #TABLE: TBODY, THEAD (neither are draggable, just table as a whole is draggable)
    TR: 'TBODY THEAD'
    UL: 'li'
    OL: 'li'
    PRE: ''
    INS: 2
    DEL: 2
    CAPTION: 'table'
    A: 'p i b sub sup cite strong en h1 h2 h3 h4 h5 h6 span img' # plus text(pcdata)
    THEAD: 'tr'
    TBODY: 'tr'

  tagTypes:
    TABLE: 1, TR: 1, UL: 1, OL: 1, DIV: 1,
    P: 2, SPAN: 2, TD: 2, TH: 2, LI: 2, H1: 2, H2: 2, H3: 2, H4: 2, H5: 2, H6: 2,
    B: 2, EM: 2, STRONG: 2, I: 2, INS: 2, DEL: 2, SUB: 2, SUP: 2, CITE: 2, CAPTION: 2,
    CODE: 2, PRE: 2, A: 2, BLOCKQUOTE: 2, IMG: 3, HR: 3, THEAD: 4, TBODY: 4, BR: 4

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
      thisq.find('select').on('focusout change', (event) ->
        selectedType = this.value
        that.innerHTML= selectedType
        wagn_live.showTitleWidget.call($(that).parents('div.live-title')) )

      thisq.find('option[value="'+typeName+'"]').prop('selected', true)
      wagn_live.editElement = this
    false

  editCardname: (event) ->
    target = event.target
    #console.log('edit name')
    #console.log(event)
    targetq = $(target)
    originalName = target.innerText
    targetq.on('change focusout', (event) -> wagn_live.changeCardname( event, target, originalName ) )
    #this.focus()
    false

  changeCardname: (event, nameElement, originalName) ->
    #console.log(event)
    #console.log(this)
    #console.log(nameElement)
    newName = nameElement.innerText
    #console.log('change name: ' + originalName + " -> " + newName)
    if newName != originalName
      console.log("Rename card: " + originalName + " -> " + newName)
    #nameElement.removeAttribute('contenteditable')

  editElementText: (event) ->
    target = event.target
    targetq = $(target)
    console.log(event)
    if target.nodeType == 1
      if target.tagName == "SPAN"
        if targetq.hasClass('card-title')
          return true
      else if target.parentElement.tagName == "A" ||
              target.tagName == 'INPUT' # process a button normally
        return true
    console.log('edit content')
    #thisq.attr('contenteditable', true)
    targetq.on 'change focusout', (event) ->
      wagn_live.changeContent( event, target, target.innerHTML )
    #this.focus()
    false

  changeContent: (event, element, originalContent) ->
    console.log('change content')
    console.log(event)
    console.log(this)
    console.log(element)
    newContent = element.innerHTML
    if newContent != originalContent
      console.log("Changed content: " + originalContent + " -> " + newContent)

  register: (state, klass, text) ->
    wagn_live.connection.on state, ->
      wagn_live.status.className = 'label ' + klass
      wagn_live.status.innerHTML = text
    null

  setupShare: ->
    $('#logging').before( wagn_live.shareStatus )
    wagn_live.status = document.getElementById 'share-status'
    wagn_live.register 'ok', 'success', 'Online'
    wagn_live.register 'connecting', 'warning', 'Connecting...'
    wagn_live.register 'disconnected', 'important', 'Offline'
    wagn_live.register 'stopped', 'important', 'Error'
  
  shareStatus: '<span class="label warning" id="share-status">Loading...</span>'

  shareConnect: (doc_name, to_edit) ->
    wagn_live.connection = sharejs.open doc_name, 'json', 'http://74.0.57.155:8000/channel', (error, doc) ->
      if error
        if console
          console.error error
      else if doc.created
        wagn_live.shareDoc = doc
        doc.set to_edit
      null
    wagn_live.setupShare()

