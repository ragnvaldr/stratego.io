define (require) ->

  $        = require 'jquery'
  _        = require 'underscore'
  Backbone = require 'backbone'
  Pace     = require 'pace'

  Pace.on 'done', ->
    $(document.body).append "<div>I guess we're done.</div>"
