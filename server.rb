require "rubygems"
require "sinatra"
require "redis"
require "haml"

get "/" do
	haml :index
end
