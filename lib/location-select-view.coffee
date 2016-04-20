{SelectListView} = require 'atom-space-pen-views'
path = require 'path'

module.exports =
class LocationSelectList extends SelectListView
  initialize: (editor, callback)->
    super
    @addClass('overlay from-top')
    @editor = editor
    @callback = callback
    @storeFocusedElement()
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()

  viewForItem: (item) ->
    if item[0] is '<stdin>'
      "<li class=\"event\">#{item[1]}:#{item[2]}</li>"
    else
      f = path.join(item[0])
      "<li class=\"event\">#{f}  #{item[1]}:#{item[2]}</li>"

  hide: -> @panel?.hide()

  show: ->
    @storeFocusedElement()
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    @focusFilterEditor()

  toggle: ->
    if @panel?.isVisible()
      @cancel()
    else
      @show()

  confirmed: (item) ->
    @cancel()
    @callback(@editor, item)

  cancelled: ->
    @hide()
