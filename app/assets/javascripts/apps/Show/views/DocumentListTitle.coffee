define [ 'jquery', 'underscore', 'backbone', 'i18n' ], ($, _, Backbone, i18n) ->
  t = i18n.namespaced('views.DocumentSet.show.DocumentListTitle')

  getTitleHtml = (nDocuments, titleString) ->
    if nDocuments?
      nDocumentsHtml = "<strong>#{_.escape(t('num_documents', nDocuments))}</strong>"
      if titleString
        _.escape(titleString).replace('%s', nDocumentsHtml)
      else
        nDocuments
    else
      _.escape(t('loading'))

  documentListToSettings = (documentList) ->
    params = documentList.params
    nDocuments = documentList.get('length')

    editTagId = params.params?.tags?[0]
    if editTagId?
      editTagHtml = "<a href='#' data-type='tag' data-id='#{editTagId}' class='edit'>#{t('tag.edit')}</a>"

    editNodeId = params.params?.nodes?[0]
    if editNodeId?
      editNodeHtml = "<a href='#' data-type='node' data-id='#{editNodeId}' class='edit'>#{t('node.edit')}</a>"

    editLinkHtml: editTagHtml || editNodeHtml || ''
    titleHtml: getTitleHtml(nDocuments, params.title)
    className: if nDocuments? then 'loaded' else 'loading'
    nDocuments: nDocuments

  # Shows what's currently selected
  #
  # Usage:
  #
  #   documentList = new DocumentList(...)
  #   view = new SelectionTitle({
  #     documentList: documentList
  #   })
  #   documentList2 = new DocumentList(...)
  #   view.setDocumentList(documentList2)
  #
  # Events:
  #
  # * edit-tag: (tag) indicates the user requests a tag edit
  # * edit-node: (node) indicates the user requests a node edit
  class DocumentListTitleView extends Backbone.View
    id: 'document-list-title'

    template: _.template('''
      <span class="show-list-link">
        <a href="#" class="show-list"><i class="icon-chevron-left"></i> <%- t('list') %></a>
      </span>
      <h4></h4>
      <span class="edit-link"></span>
    ''')

    events:
      'click a.edit': '_onClickEdit'
      'click .show-list': '_onClickShowList'

    initialize: ->
      throw 'Must supply options.documentList, a DocumentList' if 'documentList' not of @options
      throw 'Must supply options.state, a State' if 'state' not of @options

      @initialRender()

      @state = @options.state
      @listenTo(@state, 'change:oneDocumentSelected', @render)
      @setDocumentList(@options.documentList)

    initialRender: ->
      @$el.html(@template(t: t))
      @ui =
        title: @$('h4')
        editLink: @$('.edit-link')
        showList: @$('.show-list')

    render: ->
      checked = !@state.get('oneDocumentSelected')
      settings = if @documentList?
        documentListToSettings(@documentList)
      else
        editLinkHtml: ''
        titleHtml: ''
        className: ''
        nDocuments: null

      @ui.title.html(settings.titleHtml)
      @ui.editLink.html(settings.editLinkHtml)
      @$el.attr(class: settings.className)
      @

    _onClickEdit: (e) ->
      e.preventDefault()
      params = @documentList.params

      $el = $(e.currentTarget)
      type = $el.attr('data-type')
      id = Number($el.attr('data-id'))

      switch type
        when 'node' then @trigger('edit-node', params.view?.onDemandTree?.getNode?(id))
        when 'tag' then @trigger('edit-tag', params.documentSet.tags?.get?(id))

    _onClickShowList: (e) ->
      e.preventDefault()
      @state.set(oneDocumentSelected: false)

    setDocumentList: (documentList) ->
      for object in (@transientObjectsToListenTo || [])
        @stopListening(object)
      @transientObjectsToListenTo = []
      @documentList = documentList
      if @documentList?
        # Listen for number of docs changing and to know when we're loading)
        @listenTo(@documentList, 'change', @render)
        @transientObjectsToListenTo.push(@documentList)

        # Listen for tag/node name change.
        #
        # HUGE HACK ahead!
        #
        # We want to re-render the title when a node name or tag name changes.
        # But we do _not_ want to change the document list! So our huge hack
        # is to set the title on the existing, supposedly-immutable params.
        #
        # To correct it, we need a way of setting a title without changing
        # the rest of a documentListParams. We can either make
        # documentListParams mutable or alter other code such that a title
        # change doesn't trigger a refresh.
        if @documentList.params?.view?.onDemandTree?.getNode?
          for nodeId in (@documentList.params.params?.nodes || [])
            if (node = @documentList.params.view.onDemandTree.getNode(nodeId))?
              @transientObjectsToListenTo.push(node)
              @listenTo node, 'change', (node) =>
                title = @documentList.params.reset.byNode(node).title
                @documentList.params.title = title
                @render()

        if @documentList.params?.documentSet?.tags?.get?
          for tagId in (@documentList.params.params?.tags || [])
            if (tag = @documentList.params.documentSet.tags.get(tagId))?
              @transientObjectsToListenTo.push(tag)
              @listenTo tag, 'change', (tag) =>
                title = @documentList.params.reset.byTag(tag).title
                @documentList.params.title = title
                @render()

      @render()
