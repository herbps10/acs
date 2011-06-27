// jQuery Code
// Anything related to the Facebook buttons
// should NOT be done here
$(document).ready(function() {
	$("a.update").click(function() {
		$(this).remove();
		$("form.update").show("slow");

		return false;
	});
});


// Facebook initialization
(function() {
var e = document.createElement('script');
e.type = 'text/javascript';
e.src = document.location.protocol +
  '//connect.facebook.net/en_US/all.js';
e.async = true;
document.getElementById('fb-root').appendChild(e);
}());

window.fbAsyncInit = function() {
	// acs:4567
	//FB.init({appId: '109163289177099', status: true, cookie: true,
	 	//xfbml: true});

	// lacsalumni.com
	FB.init({appId: '195546887162731', status: true, cookie: true,
	 	xfbml: true});

	// Code that relies on Facebook can be called from here
};

// Fired when the user clicks on the facebook button
// when already logged into facebook
function onLogin() {
	$("#already-registered").show("slow");
}
