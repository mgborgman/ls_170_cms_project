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

  def session
    last_request.env["rack.session"]
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
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "history")
  end

  def test_markdown
    create_document("about.md", "#This is markdown")
    get "/about.md"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<h1>This is markdown</h1>")
  end

  def test_edit_file
    create_document("history.txt")
    get "/history.txt/edit"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<p>Edit the contents of history.txt</p>")
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, '<button type="submit"')
  end

  def test_submit_file_edits
    create_document("history.txt")
    post "/history.txt/edit", file_contents: "new content"
    
    assert_equal(302, last_response.status)
    assert_equal("history.txt has been updated.", session[:success])

    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content")
  end

  def test_create_new_document_form
    get "/new"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<form")
    assert_includes(last_response.body, "<label>Add a new document:</label></br>")
    assert_includes(last_response.body, '<input type="text"')
    assert_includes(last_response.body, '<button type="submit"')
    assert_includes(last_response.body, "</form>")
  end

  def test_submit_create_new_document_form
    post "/create", new_document: "test.txt"
    
    assert_equal(302, last_response.status)
    assert_equal("test.txt has been created.", session[:success])

    get "/test.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "")
  end

  def test_delete_file
    create_document("test.txt")
    
    post "/test.txt/delete"
    assert_equal(302, last_response.status)
    assert_equal("test.txt has been deleted.", session[:success])

    get(last_response["Location"])
    assert_equal(200, last_response.status)

    get "/"
    refute_includes(last_response.body, "test.txt")
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

  def test_user_login_success
    post "/signin", username: "admin", password: "secret"
    assert_equal(302, last_response.status)
    assert_equal("Welcome!", session[:success])

    get(last_response["Location"])
    assert_equal(200, last_response.status)
  end

  def test_user_login_unsuccessful
    post "/signin", username: "user", password: "wrong"
    assert_equal(422, last_response.status)
    assert_nil(session[:username])
    assert_includes(last_response.body, "Incorrect username or password.")
  end

  def test_signout
    post "/signin", username: "admin", password: "secret"
    get(last_response["Location"])

    post "/signout"
    assert_equal(302, last_response.status)
    assert_equal("You have been signed out.", session[:success])
    get(last_response["Location"])
    assert_equal(200, last_response.status)
  end

  def test_file_does_not_exist
    get "/not_a_file.txt"
    assert_equal(302, last_response.status)
    assert_equal("not_a_file.txt does not exist.", session[:error])

    get last_response["location"]

    assert_equal(200, last_response.status)
  end
end