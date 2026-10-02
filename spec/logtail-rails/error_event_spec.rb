require "spec_helper"

RSpec.describe Logtail::Integrations::Rails::ErrorEvent do
  let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
  let(:io) { StringIO.new }
  let(:logger) do
    logger = Logtail::Logger.new(io)
    logger.level = ::Logger::INFO
    logger
  end

  around(:each) do |example|
    class RackErrorController < ActionController::Base
      layout nil

      hook_name = respond_to?(:before_action) ? "before_action" : "before_filter"
      send(hook_name) do
        raise "Boom!"
      end

      def index
        Thread.current[:_logtail_context_snapshot] = Logtail::CurrentContext.instance.snapshot
        render json: {}
      end

      def method_for_action(action_name)
        action_name
      end
    end

    ::RailsApp.routes.draw do
      get '/rack_error' => 'rack_error#index'
    end

    with_rails_logger(logger) do
      Timecop.freeze(time) { example.run }
    end

    Object.send(:remove_const, :RackErrorController)
  end

  describe "#process" do
    it "should log the exception" do
      allow(Benchmark).to receive(:ms).and_return(1).and_yield

      suppress(RuntimeError) { dispatch_rails_request("/rack_error") }

      lines = clean_lines(io.string.split("\n"))

      expect(lines.length).to eq(4)

      expect(lines[0]).to include("Started GET \\\"/rack_error\\\"")
      expect(lines[1]).to include("Processing by RackErrorController#index as HTML")
      expect(lines[2]).to include("RuntimeError (Boom!)")
      expect(lines[3]).to include("Completed 500 Internal Server Error in")
    end

    it "should re-raise the exception of the app when the logger fails" do
      error = RuntimeError.new("Boom!")
      allow(logger).to receive(:add).and_raise(IOError, "closed stream")

      expect { described_class.new(->(_env) { raise error }).call(Rack::MockRequest.env_for("/")) }.to raise_error(RuntimeError) { |raised| expect(raised).to be(error) }
    end

    it "should re-raise the exception of the app when building the error event fails" do
      error = RuntimeError.new("Boom!")
      allow(Logtail::Events::Error).to receive(:new).and_raise(ArgumentError, "bad event")

      expect { described_class.new(->(_env) { raise error }).call(Rack::MockRequest.env_for("/")) }.to raise_error(RuntimeError) { |raised| expect(raised).to be(error) }
      expect(io.string).to eq("")
    end
  end

  describe "exception responses" do
    around(:each) do |example|
      class ExceptionResponseController < ActionController::Base
        layout nil

        def runtime_error
          raise "Boom!"
        end

        def record_not_found
          raise ActiveRecord::RecordNotFound, "Couldn't find User"
        end

        def record_not_found_in_template
          render inline: "<% raise ActiveRecord::RecordNotFound, 'Couldn\\'t find User' %>"
        end

        def method_for_action(action_name)
          action_name
        end
      end

      ::RailsApp.routes.draw do
        get '/runtime_error' => 'exception_response#runtime_error'
        get '/record_not_found' => 'exception_response#record_not_found'
        get '/record_not_found_in_template' => 'exception_response#record_not_found_in_template'
      end

      example.run

      Object.send(:remove_const, :ExceptionResponseController)
    end

    it "should log a fatal error and a response with status 500" do
      response = dispatch_rendering_exceptions("/runtime_error")

      expect(response.status).to eq(500)
      expect(error_rows.map { |row| [row["level"], row["message"]] }).to eq([["fatal", "RuntimeError (Boom!)"]])
      expect(response_statuses).to eq([500])
      expect(response_rows.first["message"]).to match(/\ACompleted 500 Internal Server Error in \d+\.\dms\z/)
    end

    it "should log the response with the status from config.action_dispatch.rescue_responses" do
      response = dispatch_rendering_exceptions("/record_not_found")

      expect(response.status).to eq(404)
      expect(response_statuses).to eq([404])
      expect(response_rows.first["message"]).to match(/\ACompleted 404 Not Found in \d+\.\dms\z/)
      expect(error_rows.map { |row| [row["level"], row["message"]] }).to eq([["fatal", "ActiveRecord::RecordNotFound (Couldn't find User)"]])
    end

    it "should log the response with the status of the exception a template error wraps" do
      response = dispatch_rendering_exceptions("/record_not_found_in_template")

      expect(response.status).to eq(404)
      expect(response_statuses).to eq([404])
    end

    it "should not log rescued responses when config.action_dispatch.log_rescued_responses is false" do
      skip("config.action_dispatch.log_rescued_responses is new in Rails 7.0") unless ::Rails.application.env_config.key?("action_dispatch.log_rescued_responses")

      dispatch_rendering_exceptions("/record_not_found", "action_dispatch.log_rescued_responses" => false)
      dispatch_rendering_exceptions("/runtime_error", "action_dispatch.log_rescued_responses" => false)

      expect(error_rows.map { |row| row["message"] }).to eq(["RuntimeError (Boom!)"])
      expect(response_statuses).to eq([404, 500])
    end

    it "should log the error at fatal even when config.action_dispatch.debug_exception_log_level is :error" do
      skip("config.action_dispatch.debug_exception_log_level is new in Rails 7.1") unless ::Rails.application.env_config.key?("action_dispatch.debug_exception_log_level")

      dispatch_rendering_exceptions("/runtime_error", "action_dispatch.debug_exception_log_level" => ::Logger::ERROR)

      expect(error_rows.map { |row| [row["level"], row["message"]] }).to eq([["fatal", "RuntimeError (Boom!)"]])
    end

    # Renders exceptions as error pages like a production app, instead of raising them
    def dispatch_rendering_exceptions(path, env_config = {})
      show_exceptions = ::Rails.gem_version >= Gem::Version.new("7.1") ? :all : true

      with_env_config(env_config.merge("action_dispatch.show_exceptions" => show_exceptions)) do
        dispatch_rails_request(path)
      end
    end

    # Rails copies its config.action_dispatch settings from env_config into every request env
    def with_env_config(settings)
      env_config = ::Rails.application.env_config
      previous = settings.keys.map { |key| [key, env_config.key?(key), env_config[key]] }
      env_config.merge!(settings)

      yield
    ensure
      previous.each do |key, existed, value|
        if existed
          env_config[key] = value
        else
          env_config.delete(key)
        end
      end
    end

    def log_rows
      io.string.split("\n").map { |line| JSON.parse(line) }
    end

    def error_rows
      log_rows.select { |row| row.key?("error") }
    end

    def response_rows
      log_rows.select { |row| row.dig("event", "http_response_sent") }
    end

    def response_statuses
      response_rows.map { |row| row["event"]["http_response_sent"]["status"] }
    end
  end

  # Remove blank lines since Rails does this to space out requests in the logs
  def clean_lines(lines)
    lines.select { |line| !line.start_with?(" @metadat") }
  end
end
