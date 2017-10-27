require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"

configure do
  enable :sessions
  set :session_secret, 'secret'
  #set :erb, :escape_html => true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_file_content(file)
  case File.extname(file)
  when '.md'
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @contents = markdown.render(File.read(file))
    erb :file, layout: :layout
  else
    headers['Content-Type'] = 'text/plain'
    @contents = File.read(file)
    erb :file, layout: false
  end
end

def list_of_users
  @users = YAML.load_file(File.join(data_path, "../users.yaml"))
end

def create_empty_document(file)
  File.write(File.join(data_path, file), "")
end

def submit_new_document_form(file)
  if File.extname(file).empty?
    file << ".txt"
    create_empty_document(file)
    session[:success] = "#{file} has been created."
    redirect "/"
  else
    create_empty_document(file)
    session[:success] = "#{file} has been created."
    redirect "/"
  end
end

def user_not_signed_in
  !session[:username]
end

def redirect_to_homepage
  session[:error] = "You must be signed in to do that."
  redirect "/"
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

get "/:file/edit" do
  if user_not_signed_in
    redirect_to_homepage
  else
    file_path = File.join(data_path, params[:file])
    @contents = File.read(file_path)
    erb :edit_file, layout: :layout
  end
end

post "/:file/edit" do
  if user_not_signed_in
    redirect_to_homepage
  else
    file_path = File.join(data_path, params[:file])
    File.open(file_path, "w+") { |file| file.write(params[:file_contents]) }
    session[:success] = "#{params[:file]} has been updated."
    redirect "/"
  end
end

get "/new" do
  if user_not_signed_in
    redirect_to_homepage
  else
    erb :new_document, layout: :layout
  end
end

post "/create" do
  if user_not_signed_in
    redirect_to_homepage
  else
    if params[:new_document].strip.empty?
      session[:error] = "You must enter a document."
      erb :new_document, layout: :layout
    else
      submit_new_document_form(params[:new_document])
    end
  end
end

post "/:file/delete" do
  if user_not_signed_in
    redirect_to_homepage
  else
    File.delete(File.join(data_path, params[:file]))
    session[:success] = "#{params[:file]} has been deleted."
    redirect "/"
  end
end

get "/users/signin" do
  erb :signin, layout: :layout
end

post "/signin" do
  if list_of_users.keys.include?(params[:username]) && list_of_users[params[:username]] == (params[:password])
    session[:username] = params[:username]
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Incorrect username or password."
    status 422
    erb :signin, layout: :layout
  end
end

post "/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end

get "/:file" do
  file_path = File.join(data_path, params[:file])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file]} does not exist."
    redirect "/"
  end
end