# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$ ->
    Morris.Bar
      element: 'message-by-each'
      data: $('#message-by-each').data('messages')
      xkey: 'name'
      ykeys: ['count']
      labels: ['Series A']