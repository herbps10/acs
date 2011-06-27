require "rubygems"
require "bundler/setup"
require "sinatra"
require "haml"
require "erb"
require "rest-client"
require "json"
require "rest-graph"
require "base64"
require "uri"

configure do
	set :environment, :production

	require "redis"
	if settings.environment == :production
		uri = URI.parse("redis://herbps10:1d6933e71738f36484d4781c406a6567@bluegill.redistogo.com:9350/")
		$redis = Redis.new :host => uri.host, :port => uri.port, :password => uri.password
	else
		$redis = Redis.new
	end
end

if settings.environment == :production
	set :base, "http://lacsalumni.com/"
	set :app_id, 195546887162731 # This is for official lacsalumni.com
else
	set :base, "http://acs:4567/"
	set :app_id, 109163289177099 # This is http://acs:4567
end

helpers do
	# Decodes data that is returned from facebook registration plugin
	def decode_data data
		encoded_signature, payload = data.split('.')

		payload = payload.gsub('-', '+').gsub('_', '/')
		payload += "=" * (4 - payload.length.modulo(4))

		return Base64.decode64 payload
	end

	# When the user logs in via facebook, a cookie named
	# "fbs_APPID" is set. This cookie is only set once the
	# user clicks on our facebook button; it isn't set if
	# the user is simply already logged into the facebook
	# site.
	def get_cookie
		return request.cookies["fbs_" + settings.app_id.to_s]
	end

	# Checks to see if the facebook cookie is set
	def logged_in?
		return get_cookie != nil
	end

	# The facebook cookie contains an authentication
	# token called an oath token that is used whenever
	# you make calls to the Facebook Graph API regarding
	# non-public information. For example, when you want
	# to retrieve information about the currently logged
	# in user.
	#
	# This function Parses out the oath token from the
	# facebook cookie.
	def get_token
		get_cookie.split("=").at(1).split("&").at(0)
	end
end

get "/" do
	# make sure we're on the appropriate domain.
	# all the facebook stuff won't work if we're not
	# on domain registered with the App ID
	if request.host == "acs.heroku.com"
		redirect "http://lacsalumni.com"
	end

	@logged_in = logged_in?
	
	# If the user is logged in, query facebook for more specific
	# information about the user
	if @logged_in
		begin
			$rq = RestGraph.new :app_id => settings.app_id, :access_token => get_token
			@me = $rq.get('me')
		rescue RestGraph::Error::InvalidAccessToken
			# Ignore this error
		end
	end

	haml :index
end

get "/register" do
	haml :register
end

# Register a new listing
post "/register" do
	# Parse out the data from the Facebook registration plugin
	data = JSON.parse(decode_data(params["signed_request"]))

	# Query Facebook for more location information
	rq = RestGraph.new :app_id => settings.app_id
	location = rq.get(data["registration"]["location"]["id"])

	$redis.incr("nextid")
	id = $redis.get("nextid")

	{  
		:name => data["registration"]["name"],
		:content => data["registration"]["content"],
		:year => data["registration"]["year"],
		:first_name_only => data["registration"]["first_name_only"],
		:location => data["registration"]["location"]["name"],
		:location_id => data["registration"]["location"]["id"],
		:location_longitude => location["longitude"],
		:location_latitude => location["latitude"],
		:history => data["registration"]["history"],
		:future => data["registration"]["future"],
		:opportunities => data["registration"]["opportunities"],
		:fbid => data["user_id"]
	}.each_pair { |key, value| $redis.hset(id, key, value) }

	$redis.sadd "ids", id

	redirect "/"
end

# Update's the current user's listing
post '/update' do
	redirect "/" if !logged_in? # This obviously won't work if their is no logged in user
	
	$rq = RestGraph.new :app_id => settings.app_id, :access_token => get_token
	@me = $rq.get('me')

	# Walk through all the ids until we reach the current user's listing
	$redis.smembers('ids').each do |id|
		if $redis.hget(id, 'fbid') == @me['id']

			# Check to see if the user updated their location.
			old_location = $redis.hget(id, "location")

			if old_location != params["location"]

				# Query the Google Geocoding API to retrieve the latitude and longitude of the new location

				location_str = params['location'].gsub(' ', '+') # Encode the location in a format appropriate for a URL
				api_url = "http://maps.googleapis.com/maps/api/geocode/json?address=#{location_str}&sensor=false"

				results = JSON.parse(RestClient.get(api_url).to_str) 

				# Grab the location out of the JSON
				# Documentation and a sample JSON response can be found here:
				# http://code.google.com/apis/maps/documentation/geocoding/index.html
				longitude = results["results"][0]["geometry"]["location"]["lng"]
				latitude = results["results"][0]["geometry"]["location"]["lat"]

				$redis.hset(id, "location_longitude", longitude)
				$redis.hset(id, "location_latitude", latitude)

			end

			# Update all the fields with the new content
			{
				:content => params['content'],
				:history => params['history'],
				:future => params['future'],
				:opportunities => params['opportunities'],
				:location => params['location'],
				:year => params['year']
			}.each_pair { |key, value| $redis.hset(id, key, value) }

			redirect "/"

		end
	end
end

# Generates the google maps api code to create the map
# with markers for each person in the database
get '/maps.js' do
	# We put all the markers into an array
	@markers = []
	$redis.smembers("ids").each do |id|
		# This is for backwards compatability.
		# Originally, I just saved the Facebook ID for the person's
		# location. When I added the update feature, this was a
		# problem because users could update their location and I
		# had no way of getting a facebook location ID for their
		# new location. As such, I resorted to retrieving a latitude
		# and longitude for the new location using the google geolocator
		# API.

		# Long story short, some listing include explicit latitude
		# and longitudes, others do not. So I check to see if the
		# lat/lon is there, and if it is, we use that. Otherwise,
		# we look up the location from the facebook location ID.
		lon = $redis.hget(id, "location_longitude")
		
		if lon == nil or lon == ""
			rq = RestGraph.new :app_id => settings.app_id
			location = rq.get($redis.hget(id, "location_id")) # Retrieves location information from facebook

			lat = location["location"]["latitude"]
			lon = location["location"]["longitude"]
		else
			lat = $redis.hget(id, "location_latitude")
			lon = $redis.hget(id, "location_longitude")
		end

		name = $redis.hget(id, "name") # Person's name

		@markers.push({
			"longitude" => lon,
			"latitude" => lat,
			"location_name" => $redis.hget(id, "location"),
			"name" => $redis.hget(id, "name")
		})
	end
	
	erb :maps
end

get '/script.js' do
	erb :script
end

# Resets the database.
get '/flush' do
	$redis.flushdb
	redirect "/"
end

# Deletes the listing of the user who is currently logged in
get '/delete' do
	if logged_in?
		rq = RestGraph.new :app_id => settings.app_id, :access_token => get_token
		@me = rq.get('me')

		# Walk through all the listings until you find the listing
		# of the current user. 
		$redis.smembers('ids').each do |id|
			if $redis.hget(id, 'fbid') == @me['id']
				$redis.del(id) # Delete the hash key for that user
				$redis.srem("ids", id) # Delete the id from the list of all ids
			end
		end
	end

	redirect "/"
end
