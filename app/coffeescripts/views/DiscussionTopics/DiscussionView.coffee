define [
  'i18n!discussions'
  'jquery'
  'underscore'
  'Backbone'
  'jsx/shared/conditional_release/CyoeHelper'
  'jst/DiscussionTopics/discussion'
  'compiled/views/PublishIconView'
  'compiled/views/ToggleableSubscriptionIconView'
  'compiled/views/assignments/DateDueColumnView'
  'compiled/views/MoveDialogView'
], (I18n, $, _, {View}, CyoeHelper, template, PublishIconView, ToggleableSubscriptionIconView, DateDueColumnView, MoveDialogView) ->

  class DiscussionView extends View
    # Public: View template (discussion).
    template: template

    # Public: Wrap everything in an <li />.
    tagName: 'li'

    # Public: <li /> class name(s).
    className: 'discussion'

    # Public: I18n translations.
    messages:
      confirm:     I18n.t('confirm_delete_discussion_topic', 'Are you sure you want to delete this discussion topic?')
      delete:       I18n.t('delete', 'Delete')
      user_subscribed: I18n.t('subscribed_hint', 'You are subscribed to this topic. Click to unsubscribe.')
      user_unsubscribed: I18n.t('unsubscribed_hint', 'You are not subscribed to this topic. Click to subscribe.')
      deleteSuccessful: I18n.t('flash.removed', 'Discussion Topic successfully deleted.')
      deleteFail: I18n.t('flash.fail', 'Discussion Topic deletion failed.')

    events:
      'click .icon-lock':  'toggleLocked'
      'click .icon-pin':   'togglePinned'
      'click .icon-trash': 'onDelete'
      'click':             'onClick'

    # Public: Option defaults.
    defaults:
      pinnable: false

    els:
      '.screenreader-only': '$title'
      '.discussion-row': '$row'
      '.move_item': '$moveItemButton'
      '.discussion-actions .al-trigger': '$gearButton'

    # Public: Topic is able to be locked/unlocked.
    @optionProperty 'lockable'

    # Public: Topic is able to be pinned/unpinned.
    @optionProperty 'pinnable'

    @child 'publishIcon', '[data-view=publishIcon]' if ENV.permissions.publish

    @child 'toggleableSubscriptionIcon', '[data-view=toggleableSubscriptionIcon]'

    @child 'dateDueColumnView', '[data-view=date-due]'

    initialize: (options) ->
      @attachModel()
      options.publishIcon = new PublishIconView(model: @model) if ENV.permissions.publish
      options.toggleableSubscriptionIcon = new ToggleableSubscriptionIconView(model: @model)
      if @model.get('assignment')
        options.dateDueColumnView = new DateDueColumnView(model: @model.get('assignment'))
      @moveItemView = new MoveDialogView
        model: @model
        nested: true
        closeTarget: @$el.find('a[id=manage_link]')
        saveURL: -> @model.collection.reorderURL()
      super

    render: ->
      super
      @$el.attr('data-id', @model.get('id'))
      @moveItemView.setTrigger @$moveItemButton
      this

    # Public: Lock or unlock the model and update it on the server.
    #
    # e - Event object.
    #
    # Returns nothing.
    toggleLocked: (e) =>
      e.preventDefault()
      locked = !@model.get('locked')
      pinned = if locked then false else @model.get('pinned')
      @model.updateBucket(locked: locked, pinned: pinned)
      @render()
      @$gearButton.focus()

    # Public: Confirm a request to delete and then complete it if needed.
    #
    # e - Event object.
    #
    # Returns nothing.
    onDelete: (e) =>
      e.preventDefault()
      if confirm(@messages.confirm)
        @goToPrevItem()
        @delete()
      else
        @$el.find('a[id=manage_link]').focus()

    # Public: Delete the model and update the server.
    #
    # Returns nothing.
    delete: ->
      @model.destroy
        success : =>
          $.flashMessage @messages.deleteSuccessful
        error : =>
          $.flashError @messages.deleteFail

    goToPrevItem: =>
      if @previousDiscussionInGroup()?
        $('#' + @previousDiscussionInGroup().id + '_discussion_content').attr("tabindex",-1).focus()
      else if @model.get('pinned')
        $('.pinned&.discussion-list').attr("tabindex",-1).focus()
      else if @model.get('locked')
        $('.locked&.discussion-list').attr("tabindex",-1).focus()
      else
        $('.open&.discussion-list').attr("tabindex",-1).focus()

    previousDiscussionInGroup: =>
      current_index = @model.collection.models.indexOf(@model)
      @model.collection.models[current_index - 1]

    # Public: Pin or unpin the model and update it on the server.
    #
    # e - Event object.
    #
    # Returns nothing.
    togglePinned: (e) =>
      e.preventDefault()
      @model.updateBucket(pinned: !@model.get('pinned'))

    # Public: Treat the whole <li /> as a link.
    #
    # e - Event handler.
    #
    # Returns nothing.
    onClick: (e) ->
      # Workaround a behavior of FF 15+ where it fires a click
      # after dropping a sortable item.
      return if @model.get('preventClick')
      return if _.contains(['A', 'I'], e.target.nodeName)
      window.location = @model.get('html_url')

    # Public: Toggle the view model's "hidden" attribute.
    #
    # Returns nothing.
    hide: =>
      @$el.toggle(!@model.get('hidden'))

    # Public: Generate JSON to pass to the view.
    #
    # Returns an object.
    toJSON: ->
      base = _.extend(@model.toJSON(), @options)
      # handle a student locking their own discussion (they should lose permissions).
      if @model.get('locked') and !_.intersection(ENV.current_user_roles, ['teacher', 'ta', 'admin']).length
        base.permissions.delete = false

      if base.last_reply_at
        base.display_last_reply_at = I18n.l "#date.formats.medium", base.last_reply_at
      base.ENV = ENV
      base.discussion_topic_menu_tools = ENV.discussion_topic_menu_tools
      _.each base.discussion_topic_menu_tools, (tool) =>
        tool.url = tool.base_url + "&discussion_topics[]=#{@model.get("id")}"

      base.cannot_delete_by_master_course = @model.get('is_master_course_child_content') && @model.get('restricted_by_master_course')

      base.cyoe = CyoeHelper.getItemData(base.assignment_id)
      base.return_to = encodeURIComponent window.location.pathname
      base

    # Internal: Re-render for publish state change preserving focus
    #
    # Returns nothing.
    renderPublishChange: =>
      @publishIcon?.render()
      if ENV.permissions.publish
        if @model.get('published')
          @$row.removeClass('discussion-unpublished')
          @$row.addClass('discussion-published')
        else
          @$row.removeClass('discussion-published')
          @$row.addClass('discussion-unpublished')

    # Internal: Add event handlers to the model.
    #
    # Returns nothing.
    attachModel: ->
      @model.on('change:hidden', @hide)
      @model.on('change:published', @renderPublishChange)
