ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def create_users_document
    File.open(File.join(users_path, "users.yaml"), "w") do |file|
      file.write("admin: #{hash_password('secret')}")
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => { username: "admin" } }
  end

  def test_index
    create_document("about.txt")
    create_document("changes.txt")

    get "/"

    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.txt")
    assert_includes(last_response.body, "changes.txt")
  end

  def test_history
    create_document("history.txt", "history")
    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "history")
  end

  def test_markdown
    create_document("about.md", "#This is markdown")
    get "/about.md"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<h1>This is markdown</h1>")
  end

  def test_edit_file_logged_in
    create_document("history.txt")
    get "/history.txt/edit", {}, admin_session
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<p>Edit the contents of history.txt</p>")
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, '<button type="submit"')
  end

  def test_edit_file_not_logged_in
    create_document("history.txt")
    get "/history.txt/edit"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
    get(last_response["Location"])
    assert_includes(last_response.body, "history.txt")
  end

  def test_submit_file_edits_logged_in
    create_document("history.txt")
    post "/history.txt/edit", {file_contents: "new content"}, admin_session
    
    assert_equal(302, last_response.status)
    assert_equal("history.txt has been updated.", session[:success])

    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content")
  end

  def test_submit_file_edits_not_logged_in
    create_document("history.txt")
    post "/history.txt/edit"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
    get(last_response["Location"])
    assert_includes(last_response.body, "history.txt")
  end

  def test_create_new_document_form_logged_in
    get "/new", {}, admin_session
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<form")
    assert_includes(last_response.body, "<label>Add a new document:</label></br>")
    assert_includes(last_response.body, '<input type="text"')
    assert_includes(last_response.body, '<button type="submit"')
    assert_includes(last_response.body, "</form>")
  end

  def test_create_new_document_form_not_logged_in
    get "/new"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
    get(last_response["Location"])
    assert_includes(last_response.body, '<a href="/new"')
  end

  def test_submit_create_new_document_form_logged_in
    post "/create", {new_document: "test.txt"}, admin_session
    
    assert_equal(302, last_response.status)
    assert_equal("test.txt has been created.", session[:success])

    get "/test.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "")
  end

  def test_submit_create_new_document_form_not_logged_in
    post "/create"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
    get(last_response["Location"])
    assert_includes(last_response.body, '<a href="/new"')
  end

  def test_delete_file_logged_in
    create_document("test.txt")
    
    post "/test.txt/delete", {}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("test.txt has been deleted.", session[:success])

    get(last_response["Location"])
    assert_equal(200, last_response.status)

    get "/"
    refute_includes(last_response.body, "test.txt")
  end

  def test_delete_file_not_logged_in
    create_document("test.txt")
    post "/test.txt/delete"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:error])
    get(last_response["Location"])
    assert_includes(last_response.body, 'test.txt')
  end

  def test_signin
    get "/users/signin"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<form")
    assert_includes(last_response.body, '<label for="username"')
    assert_includes(last_response.body, '<input type="text"')
    assert_includes(last_response.body, '<label for="password"')
    assert_includes(last_response.body, '<input type="password"')
    assert_includes(last_response.body, '<input type="submit"')
    assert_includes(last_response.body, '<label for="username"')
    assert_includes(last_response.body, "</form>")
  end

  def test_user_login_successful
    create_users_document
    post "/users/signin", username: "admin", password: "secret"
    assert_equal(302, last_response.status)
    assert_equal("Welcome!", session[:success])

    get(last_response["Location"])
    assert_equal(200, last_response.status)
  end

  def test_user_login_unsuccessful
    create_users_document
    post "/users/signin", username: "user", password: "wrong"
    assert_equal(422, last_response.status)
    assert_nil(session[:username])
    assert_includes(last_response.body, "Incorrect username or password.")
  end

  def test_user_account_creation_successful
    create_users_document
    post "/users/signup", username: "test", password:"password", verify_password: "password"
    assert_equal("Account created successfully.", session[:success])
    assert_equal(302, last_response.status)
    get(last_response["Location"])
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<form")
    assert_includes(last_response.body, '<label for="username"')
  end

  def test_user_account_creation_invalid_username
    create_users_document
    post "/users/signup", username: "admin", password: "anything", verify_password: "anything"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Username is already taken.")
  end

  def test_user_account_creation_invalid_password
    create_users_document
    post "/users/signup", username: "not_admin", password: "anything", verify_password: "anything_else"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Passwords do not match.")
  end

  def test_signout
    get "/", {}, admin_session

    post "/users/signout"

    assert_nil(session[:username])
    assert_equal("You have been signed out.", session[:success])
    get(last_response["Location"])
  end

  def test_file_does_not_exist
    get "/not_a_file.txt"
    assert_equal(302, last_response.status)
    assert_equal("not_a_file.txt does not exist.", session[:error])

    get last_response["location"]

    assert_equal(200, last_response.status)
  end
end