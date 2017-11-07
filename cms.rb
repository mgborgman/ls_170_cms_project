require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
require "fileutils"


configure do
  enable :sessions
  set :session_secret, 'secret'
  #set :erb, :escape_html => true
end

before do
  session[:signed_in] ||= false
end

def root
  File.expand_path("..", __FILE__)
end

def image_file_extensions
  %w(.jpeg .png .gif .jpg)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def image_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/images", __FILE__)
  else
    File.expand_path("../public/images", __FILE__)
  end
end

def load_file_content(file)
  extension = File.extname(file)
  case extension
  when '.md'
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @contents = markdown.render(File.read(file))
    erb :file
  when '.html'
    @contents = File.read(file)
    erb :file
  when *image_file_extensions
    image_name = File.basename(file)
    @image = "./images/#{image_name}"

    erb :file
  else
    @plain_text = true
    # headers['Content-Type'] = 'text/html'
    @contents = File.readlines(file)
    erb :file
  end
end

def users_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test", __FILE__)
  else
    root
  end
end

def list_of_users
  @users = YAML.load_file(File.join(users_path, "/users.yaml"))
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

def valid_login?(username, password)
  users = list_of_users
  if list_of_users.key?(username)
    test_password(password, users[username])
  else
    false
  end
end

def hash_password(password)
  BCrypt::Password.create(password).to_s
end

def test_password(password, hash)
  BCrypt::Password.new(hash) == password
end

def is_image?(file)
  image_file_extensions.include?(File.extname(file).downcase)
end

def get_path(file)
  if is_image?(file)
    File.join(image_path, file)
  else
    File.join(data_path, file)
  end
end

get "/" do
  @index = true
  file_pattern = File.join(data_path, "*")
  image_pattern = File.join("./public/images/", "*")
  @files = Dir.glob(file_pattern).map do |path|
    File.basename(path)
  end
  @images = Dir.glob(image_pattern).map { |path| File.basename(path) }
  erb :index
end

get "/:file/edit" do
  if user_not_signed_in
    redirect_to_homepage
  else
    file_path = File.join(data_path, params[:file])
    @contents = File.read(file_path)
    @extension = File.extname(params[:file])
    @images = Dir.glob("#{image_path}/*.*").map{|image| File.basename(image)}
    erb :edit_file
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

post "/:file/insert-image" do
  if user_not_signed_in
    redirect_to_homepage
  else
    file_path = File.join(data_path, params[:file])
    extension = File.extname(params[:file])
    if extension == '.md'
      # add image formatted for markdown
      File.open(file_path, "a+") { |file| file.write("![image](#{params[:image_select]})") }
      redirect "/#{params[:file]}/edit"
    elsif extension == '.html'
      # add image formatted for HTML
      File.open(file_path, "a+") { |file| file.write("<img src=#{params[:image_select]}>") }
      redirect "/#{params[:file]}/edit"      
    else
      # we should not be adding images to any other file types at this time
      # throw error
      session[:error] = "This file type is not able to accept images."
      redirect "/#{params[:fle]}/edit"
    end
  end
end

get "/new" do
  if user_not_signed_in
    redirect_to_homepage
  else
    erb :new_document
  end
end

post "/create" do
  if user_not_signed_in
    redirect_to_homepage
  else
    if params[:new_document].strip.empty?
      session[:error] = "You must enter a document."
      erb :new_document
    else
      submit_new_document_form(params[:new_document])
    end
  end
end

get "/upload" do
  if user_not_signed_in
    redirect_to_homepage
  else
    erb :upload
  end
end

post "/upload" do
  if user_not_signed_in
    redirect_to_homepage
  else
    if params[:file] && is_image?(params[:file][:filename])
      # user is uploading an image
      filename = params[:file][:filename]
      tempfile = params[:file][:tempfile]
      target = File.join(image_path, filename)

      File.open(target, 'wb') {|file| file.write(tempfile.read) }
      session[:success] = "Image was uploaded."
      redirect "/"
    elsif params[:file]
      # user is uploading a non-image
      session[:error] = "File must be an image."
      erb :upload
    else
      # user hit upload but did not choose a file
      session[:error] = "You must choose a file."
      erb :upload
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

post "/:file/duplicate" do
  if user_not_signed_in
    redirect_to_homepage
  else
    file_path = File.join(data_path, params[:file])
    contents = File.read(file_path)
    File.open(File.join(data_path, "copy_#{params[:file]}" ), "w") do |copy|
      copy.write(contents)
    end
    session[:success] = "File duplicated."
    redirect "/"
  end
end

get "/:file/rename" do
  if user_not_signed_in
    redirect_to_homepage
  else
    erb :rename
  end
end

post "/:file/rename" do
  FileUtils.copy(File.join(data_path, params[:file]), File.join(data_path, params[:new_file_name]))
  FileUtils.remove(File.join(data_path, params[:file]))
  session[:success] = "File has been renamed."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  if valid_login?(params[:username], params[:password])
    session[:username] = params[:username]
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Incorrect username or password."
    status 422
    erb :signin
  end
end

get "/users/signup" do
  erb :signup
end

post "/users/signup" do
  users = list_of_users if File.exist?(File.join(users_path, "/users.yaml"))
  if users && users.include?(params[:username])
    session[:error] = "Username is already taken."
    status 422
    erb :signup
  elsif params[:password] != params[:verify_password]
    session[:error] = "Passwords do not match."
    status 422
    erb :signup
  else
    hash = hash_password(params[:password])
    File.open(File.join(users_path, "/users.yaml"), "a+") do |file|
      file.write("\n#{params[:username]}: #{hash}")
    end
    session[:success] = "Account created successfully."
    redirect "/users/signin"
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end

get "/:file" do
  file_path = get_path(params[:file])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:file]} does not exist."
    redirect "/"
  end
end