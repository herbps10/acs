require "rubygems"
require "sinatra"
require "haml"
require "erb"
require "rest-client"
require "json"
require "rest-graph"
require "base64"
require "uri"

configure do
	require "redis"
	uri = URI.parse(ENV["REDISTOGO_URL"])
	$redis = Redis.new :host => uri.host, :port => uri.port, :password => uri.password
end

$app_id = 109163289177099

helpers do
	def decode_data data
		encoded_signature, payload = data.split('.')

		payload = payload.gsub('-', '+').gsub('_', '/')
		payload += "=" * (4 - payload.length.modulo(4))

		return Base64.decode64 payload
	end

	def logged_in?
		return get_cookie != nil
	end

	def get_cookie
		return request.cookies["fbs_" + $app_id.to_s]
	end

	def get_token
		get_cookie.split("=").at(1).split("&").at(0)
	end
end

get "/" do
	#$rq = RestGraph.new :app_id => $app_id, :access_token => get_token
	@logged_in = logged_in?
	puts logged_in?
	haml :index
end

get "/register" do
	haml :register
end

post "/register" do
	data = JSON.parse(decode_data(params["signed_request"]))

	$redis.incr("nextid")
	id = $redis.get("nextid")
	{  
		:name => data["registration"]["name"],
		:content => data["registration"]["content"],
		:location => data["registration"]["location"]["name"],
		:location_id => data["registration"]["location"]["id"],
		:fbid => data["user_id"]
	}.each_pair { |key, value| $redis.hset(id, key, value) }

	$redis.sadd "ids", id

	redirect "/"
end

post "/update" do
	id = params["id"]

	redirect "/"
end

get '/maps.js' do
	rq = RestGraph.new :app_id => $app_id

	@markers = []
	$redis.smembers("ids").each do |id|
		location = rq.get($redis.hget(id, "location_id"))
		name = $redis.hget(id, "name")

		@markers.push({
			"longitude" => location["location"]["longitude"],
			"latitude" => location["location"]["latitude"],
			"location_name" => location["name"],
			"name" => $redis.hget(id, "name")
		})
	end
	
	erb :maps
end
