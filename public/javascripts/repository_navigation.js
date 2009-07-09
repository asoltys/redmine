Event.observe(window,'load',function() {
  /* 
  If we're viewing a named branch, don't display it in the
  revision box
  */
  if ($('rev').getValue() == $('branch').getValue() || $('rev').getValue() == $('tag').getValue()) {
    $('rev').setValue('');
  }

  /* 
  Temporarily disable the revision box if the branch drop-down
  is changed since both fields are named 'rev'
  */
  $$('#branch,#tag').each(function(e) {
    e.observe('change',function(e) {
      $('rev').setValue(e.element().getValue());
      e.element().disable();
      e.element().parentNode.submit();
    });
  });
})
