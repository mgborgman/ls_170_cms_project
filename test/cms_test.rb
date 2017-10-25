ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup 
    @root = File.expand_path("../..", __FILE__)
  end

  def test_index
    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.txt")
    assert_includes(last_response.body, "changes.txt")
    assert_includes(last_response.body, "history.txt")
  end

  def test_history
    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, File.read("../data/history.txt"))
  end

  def test_markdown
    get "/about.md"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<h1>Ruby is...</h1>")
  end

  def test_file_does_not_exist
    get "/not_a_file.txt"
    assert_equal(302, last_response.status)

    get last_response["location"]

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "does not exist")
  end
end