require "spec_helper"

# With json 3, ActiveSupport 8.0 and older can't encode anything through `to_json` called directly:
# ActiveSupport::JSON.encode passes `quirks_mode:` to JSON.generate, which json 3 rejects. Calls made
# by JSON.generate itself pass a JSON::State and keep working. The stub raises where json 3 does.
RSpec.describe "JSON encoding when to_json raises like json 3 under ActiveSupport 8.0" do
  let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
  let(:io) { StringIO.new }
  let(:logger) do
    logger = Logtail::Logger.new(io)
    logger.level = ::Logger::INFO
    logger
  end

  around(:each) do |example|
    class JsonEncodingController < ActionController::Base
      layout nil

      def index
        render template: "template"
      end

      def error
        raise "Boom!"
      end

      def method_for_action(action_name)
        action_name
      end
    end

    ::RailsApp.routes.draw do
      get '/json_encoding' => 'json_encoding#index'
      get '/json_encoding_error' => 'json_encoding#error'
    end

    # Raise exceptions instead of rendering them. Since Rails 7.2 the spec app's false means :all.
    env_config = ::Rails.application.env_config
    show_exceptions = env_config["action_dispatch.show_exceptions"]
    env_config["action_dispatch.show_exceptions"] = :none if ::Rails::VERSION::MAJOR > 7 || ::Rails::VERSION::MAJOR == 7 && ::Rails::VERSION::MINOR >= 1

    begin
      with_rails_logger(logger) do
        Timecop.freeze(time) { example.run }
      end
    ensure
      env_config["action_dispatch.show_exceptions"] = show_exceptions
    end

    Object.send(:remove_const, :JsonEncodingController)
  end

  before(:each) do
    allow(::ActiveSupport::JSON).to receive(:encode).and_raise(ArgumentError, "unknown keyword: :quirks_mode")
  end

  it "should log a request" do
    response = dispatch_rails_request("/json_encoding?page=2")

    expect(response.status).to eq(200)

    request = logged_event("http_request_received")
    expect(request).to include("headers_json")
    expect(JSON.parse(request["headers_json"])).to include("X_Request_Id" => "unique-request-id-1234")

    controller_call = logged_event("controller_called")
    expect(controller_call).to include("controller" => "JsonEncodingController", "action" => "index")
    expect(JSON.parse(controller_call["params_json"])).to eq("page" => "2")

    expect(logged_event("template_rendered")).to include("name" => "spec/support/rails/templates/template.html")

    response_sent = logged_event("http_response_sent")
    expect(response_sent).to include("status" => 200)
    expect(JSON.parse(response_sent["headers_json"])).to be_a(Hash)
  end

  it "should log an exception and let it through" do
    expect { dispatch_rails_request("/json_encoding_error") }.to raise_error(RuntimeError, "Boom!")

    error = logged_event("error")
    expect(error).to include("name" => "RuntimeError", "message" => "Boom!")
    expect(JSON.parse(error["backtrace_json"])).to be_an(Array)
  end

  # The first logged event with this name. The Rack middlewares nest theirs under "event".
  def logged_event(name)
    lines = io.string.split("\n").map { |line| JSON.parse(line) }
    lines.map { |line| line[name] || (line["event"] || {})[name] }.compact.first
  end
end
