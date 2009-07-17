Event.observe(window,'load',function() {
  /* 
  If we're viewing a tag or branch, don't display it in the
  revision box
  */
  if ($('rev').getValue() == $('branch').getValue() || $('rev').getValue() == $('tag').getValue()) {
    $('rev').setValue('');
  }

  /* 
  Copy the branch/tag value into the revision box, then disable
  the dropdowns before submitting the form
  */
  $$('#branch,#tag').each(function(e) {
    e.observe('change',function(e) {
      $('rev').setValue(e.element().getValue());
      $$('#branch,#tag').invoke('disable');
      e.element().parentNode.submit();
    });
  });

  /*
  Disable the branch/tag dropdowns before submitting the revision form
  */
  $('revision_selector').observe('submit', function() {
    $$('#branch,#tag').invoke('disable');
  });
})
