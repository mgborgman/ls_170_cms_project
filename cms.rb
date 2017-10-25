require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'secret'
  #set :erb, :escape_html => true
end

before do
  @root = File.expand_path("..", __FILE__)
  @documents = Dir.entries(@root + "/data/").select{|file| !File.directory?(file)}
end

get "/" do
  erb :index, layout: :layout
end

get "/:file" do
  if !@documents.include?(params[:file])
    session[:error] = "#{params[:file]} does not exist"
    redirect "/"
  elsif File.extname(params[:file]) == '.md'
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @contents = markdown.render(File.read(@root + "/data/" + params[:file]))
    # erb :file, layout: :layout
  else
    headers['Content-Type'] = 'text/plain'
    @contents = File.read(@root + "/data/" + params[:file])
    erb :file, layout: false
  end
end

get "/:file/edit" do
  @contents = File.read(@root + "/data/" + params[:file])
  erb :edit_file, layout: :layout
end

post "/:file" do
  file_name = File.basename(params[:file], ".*")
  File.open(@root + "/data/" + params[:file], "w+") { |file| file.write(params[:file_contents]) }
  session[:success] = "#{file_name} has been updated"
  redirect "/"
end
