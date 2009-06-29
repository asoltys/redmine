Event.observe(window,'load',function() {
  $('branch').observe('change',function(e) {
    $('rev').disable()
    e.element().parentNode.submit()
    $('rev').enable()
  })
})
