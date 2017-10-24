require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

root = File.expand_path("..", __FILE__)

get "/" do
  @documents = Dir.entries("./data").select{|file| !File.directory?(file)}
  erb :index, layout: :layout
end

get "/:file" do
  headers['Content-Type'] = 'text/plain'
  @contents = File.read(root + "/data/" + params[:file])
  erb :file, layout: false
end