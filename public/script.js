
(function() {
var e = document.createElement('script');
e.type = 'text/javascript';
e.src = document.location.protocol +
  '//connect.facebook.net/en_US/all.js';
e.async = true;
document.getElementById('fb-root').appendChild(e);
}());

window.fbAsyncInit = function() {
	FB.init({appId: '109163289177099', status: true, cookie: true,
	 	xfbml: true});

	checkLoggedIn();

	updateFromFacebook();
};

function checkLoggedIn() {
	FB.getLoginStatus(function(response) {
		if(response.session) {
			$(".login").remove();
		}
		else {
			$(".login").show();
		}
	});
}

function updateFromFacebook() {
	FB.api('/me', function(user) {
		if(user != null) {
			$(".name").text(user.name);
		}
	});
};
