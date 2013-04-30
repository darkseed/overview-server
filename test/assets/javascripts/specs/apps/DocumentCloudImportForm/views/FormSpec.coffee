require [
  'backbone'
  'apps/DocumentCloudImportForm/views/Form'
  'i18n'
], (Backbone, FormView, i18n) ->
  describe 'apps/DocumentCloudImportForm/views/Form', ->
    model = undefined
    view = undefined

    beforeEach ->
      model = new Backbone.Model({
        project: new Backbone.Model({
          id: 123
          title: 'title'
          description: null
          document_ids: []
        }),
        credentials: undefined
        status: 'fetched'
      })
      i18n.reset_messages({
        'views.DocumentCloudImportJob.new.form_preamble': 'form_preamble'
        'views.DocumentCloudImportJob.new.title.label': 'title.label'
        'views.DocumentCloudImportJob.new.title.placeholder': 'title.placeholder'
        'views.DocumentCloudImportJob.new.title.value': 'title.value,{0}'
        'views.DocumentCloudImportJob.new.split_documents.label': 'split_documents.label'
        'views.DocumentCloudImportJob.new.submit.label': 'submit.label'
      })
      view = new FormView({ model: model })

    it 'should not render anything when status is not fetched', ->
      model.set('status', 'unknown')
      expect(view.$el.is(':visible')).toBe(false)
      model.set('status', 'fetching')
      expect(view.$el.is(':visible')).toBe(false)
      model.set('status', 'error')
      expect(view.$el.is(':visible')).toBe(false)

    it 'should render the title by default', ->
      expect(view.$('input[name=title]').val()).toEqual("title.value,title")

    it 'should change the title when the status changes to fetched', ->
      model.set('status', 'fetching')
      model.get('project').set('title', 'title2')
      model.set('status', 'fetched')
      expect(view.$('input[name=title]').val()).toEqual("title.value,title2")