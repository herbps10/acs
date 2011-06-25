
(function() {
var e = document.createElement('script');
e.type = 'text/javascript';
e.src = document.location.protocol +
  '//connect.facebook.net/en_US/all.js';
e.async = true;
document.getElementById('fb-root').appendChild(e);
}());

var logged_in = false;
window.fbAsyncInit = function() {
	FB.init({appId: '109163289177099', status: true, cookie: true,
	 	xfbml: true});


	checkLoggedIn();

	updateFromFacebook();
};

function onLogin() {
	$("#already-registered").show("slow");
}

function checkLoggedIn() {
	FB.getLoginStatus(function(response) {
		if(response.session) {
			//$(".login").remove();
			logged_in = true;
		}
		else {
			//$(".login").show();
			logged_in = false;
		}
	});
}

function updateFromFacebook() {
	FB.api('/me', function(user) {
		if(user != null) {
			$(".name").text(user.name);

			updateForm(user);
		}
	});
};

function updateForm(user) {
	$("form #facebook-id").val(user.id);
}
