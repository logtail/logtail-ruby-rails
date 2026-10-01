require "spec_helper"

RSpec.describe Logtail::Integrations::Rack::HTTPEvents do
  let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
  let(:io) { StringIO.new }
  let(:logger) do
    logger = Logtail::Logger.new(io)
    logger.level = ::Logger::INFO
    logger
  end

  around(:each) do |example|
    class RackHttpController < ActionController::Base
      layout nil

      def index
        Thread.current[:_logtail_context_snapshot] = Logtail::CurrentContext.instance.snapshot
        render json: {}
      end

      def method_for_action(action_name)
        action_name
      end
    end

    ::RailsApp.routes.draw do
      get '/rack_http' => 'rack_http#index'
    end

    with_rails_logger(logger) do
      Timecop.freeze(time) { example.run }
    end

    Object.send(:remove_const, :RackHttpController)
  end

  describe "#process" do
    it "should log the events" do
      allow(Benchmark).to receive(:ms).and_return(1).and_yield

      dispatch_rails_request("/rack_http")

      lines = clean_lines(io.string.split("\n"))
      expect(lines.length).to eq(3)

      expect(lines[0]).to include("Started GET \\\"/rack_http\\\"")
      expect(lines[1]).to include("Processing by RackHttpController#index as HTML")
      expect(lines[2]).to include("Completed 200 OK in 0.0ms")
    end

    context "with the route silenced" do
      around(:each) do |example|
        described_class.silence_request = lambda do |rack_env, rack_request|
          rack_request.path == "/rack_http"
        end

        example.run

        described_class.silence_request = nil
      end

      it "should silence the logs" do
        allow(Benchmark).to receive(:ms).and_return(1).and_yield

        dispatch_rails_request("/rack_http")

        lines = clean_lines(io.string.split("\n"))
        expect(lines.length).to eq(0)
      end
    end

    context "collapsed into a single event" do
      around(:each) do |example|
        described_class.collapse_into_single_event = true

        example.run

        described_class.collapse_into_single_event = nil
      end

      it "should silence the logs" do
        allow(Benchmark).to receive(:ms).and_return(1).and_yield

        dispatch_rails_request("/rack_http")

        lines = clean_lines(io.string.split("\n"))
        expect(lines.length).to eq(2)

        expect(lines[0]).to include("Processing by RackHttpController#index as HTML")
        expect(lines[1]).to include("GET /rack_http completed with 200 OK in 0.0ms")
      end
    end
  end

  describe "query string filters" do
    around(:each) do |example|
      class RackHttpRedirectController < ActionController::Base
        layout nil

        def index
          redirect_to "/next?email=jane%40example.com&step=2"
        end

        def method_for_action(action_name)
          action_name
        end
      end

      ::RailsApp.routes.draw do
        get '/rack_http_redirect' => 'rack_http_redirect#index'
      end

      example.run

      Object.send(:remove_const, :RackHttpRedirectController)
    end

    it "should filter the app's filter_parameters from the query string, the Referer and the Location" do
      dispatch_rails_request("/rack_http_redirect?email=jane%40example.com&page=2&password=hunter2",
        "HTTP_REFERER" => "https://example.com/signup?email=jane%40example.com&ref=ad")

      rows = io.string.split("\n").map { |line| JSON.parse(line) }
      http_request_received = rows.map { |row| row.dig("event", "http_request_received") }.compact.first
      expect(http_request_received["query_string"]).to eq("email=[FILTERED]&page=2&password=[FILTERED]")
      expect(JSON.parse(http_request_received["headers_json"])["Referer"]).to eq("https://example.com/signup?email=[FILTERED]&ref=ad")

      http_response_sent = rows.map { |row| row.dig("event", "http_response_sent") }.compact.first
      _name, location = JSON.parse(http_response_sent["headers_json"]).find { |name, _value| name.casecmp("location").zero? }
      expect(location).to eq("http://example.org/next?email=[FILTERED]&step=2")
    end

    it "should use the app's filter_parameters without Procs, when query_string_filters are rack's default" do
      with_query_string_filters(described_class::DEFAULT_QUERY_STRING_FILTERS) do
        Logtail::Integrations::Rails.filter_parameters_in_urls([:email, /\Apin\z/, ->(_key, value) { value.replace("[FILTERED]") }])

        expect(described_class.query_string_filters).to eq([:email, /\Apin\z/])
      end
    end

    it "should keep query_string_filters that the app customised" do
      with_query_string_filters(described_class::DEFAULT_QUERY_STRING_FILTERS + ["code"]) do
        Logtail::Integrations::Rails.filter_parameters_in_urls([:email])

        expect(described_class.query_string_filters).to eq(described_class::DEFAULT_QUERY_STRING_FILTERS + ["code"])
      end
    end

    def with_query_string_filters(filters)
      previous = described_class.query_string_filters
      described_class.query_string_filters = filters

      yield
    ensure
      described_class.query_string_filters = previous
    end
  end

  # Remove blank lines since Rails does this to space out requests in the logs
  def clean_lines(lines)
    lines.select { |line| !line.start_with?(" @metadat") }
  end
end
