Event.observe(window,'load',function() {
  /* 
  If we're viewing a named branch, don't display it in the
  revision box
  */
  if ($('rev').getValue() == $('branch').getValue()) {
    $('rev').setValue('');
  }

  /* 
  Temporarily disable the revision box if the branch drop-down
  is changed since both fields are named 'rev'
  */
  $('branch').observe('change',function(e) {
    $('rev').disable();
    e.element().parentNode.submit();
    $('rev').enable();
  })

  /* 
  Temporarily disable the branch drop-down if 'Enter' is pressed 
  in the revision box since both fields are named 'rev'
  */
  $('rev').observe('keydown',function(e) {
    if (e.keyCode == 13) {
      $('branch').disable();
      e.element().parentNode.submit();
      $('branch').enable();
    }
  })
})
