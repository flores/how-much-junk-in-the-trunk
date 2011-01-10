//this is all stuff from jquery howtos
// wait for the DOM to be loaded 
$(document).ready(function() { 
	$( "#accordion" ).accordion({ autoHeight: false });
        var options={
                target: '#result',
		beforeSubmit: function(){ $('#loading').fadeIn('fast')},
		success: function(){
			$('#loading').fadeOut('fast'); 
			$('#result').fadeIn('fast'); 
		},
	};
        $('#eiform').ajaxForm(options); 
		
}); 

