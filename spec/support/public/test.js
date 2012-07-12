$(function() {
  $("#datepicker").datepicker();

  $('#remove').click(function() {
    $('#remove_me').remove()
  })

  var increment = function(index, oldText) {
    return parseInt(oldText || 0) + 1;
  }

  $('#change_me')
    .change(function(event) {
      $('#changes').text($(this).val())
    })
    .bind('input', function(event) {
      $('#changes_on_input').text($(this).val())
    })
    .keydown(function(event) {
      $('#changes_on_keydown').text(increment)
    })
    .keyup(function(event) {
      $('#changes_on_keyup').text(increment)
    })
    .keypress(function() {
      $('#changes_on_keypress').text(increment)
    })    
    .focus(function(event) {
      $('#changes_on_focus').text('Focus')
    })
    .blur(function() {
      $('#changes_on_blur').text('Blur')
    })
})
