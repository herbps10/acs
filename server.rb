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
	require "redis"
	uri = URI.parse("redis://herbps10:1d6933e71738f36484d4781c406a6567@bluegill.redistogo.com:9350/")
	$redis = Redis.new :host => uri.host, :port => uri.port, :password => uri.password
end

$base = "http://acs.heroku.com/"

#$app_id = 109163289177099 # This is http://acs:4567
#$app_id = 219828024724404 # This is for acs.heroku.com
$app_id = 195546887162731 # This is for official lacsalumni.com

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
	return request.server_name
	return request["SERVER_NAME"] == "acs.heroku.com" ? "yes" : "no"
	if request["SERVER_NAME"] == "acs.heroku.com"
		redirect "http://lacsalumni.com"
	end

	@logged_in = logged_in?
	
	if @logged_in
		begin
			$rq = RestGraph.new :app_id => $app_id, :access_token => get_token
			@me = $rq.get('me')
		rescue RestGraph::Error::InvalidAccessToken
			
		end
	end

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
		:year => data["registration"]["year"],
		:first_name_only => data["registration"]["first_name_only"],
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

get '/flush' do
	$redis.flushdb
	redirect "/"
end

get '/delete' do
	if logged_in?
		rq = RestGraph.new :app_id => $app_id, :access_token => get_token

		@me = rq.get('me')

		$redis.smembers('ids').each do |id|
			if $redis.hget(id, 'fbid') == @me['id']
				$redis.del(id)
				$redis.srem("ids", id)
			end
		end
	end

	redirect "/"
end
