# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
@checkFileSize = ->
  
  x = document.getElementById("file_tag")
  if 'files' of x
    if x.files.length is 0
      txt = "Select one or more files."
      alert txt
      e.preventDefault();
    else
      for item in x.files
        if 'size' of item
          size =  item.size 
          if size > 10000000
            txt = "Maximum size is 10 mb"
            alert txt
            e.preventDefault();
          else
    
$ ->
  $("#submit_tag").click (e) ->
    
    checkFileSize()