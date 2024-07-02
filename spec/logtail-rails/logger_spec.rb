require "spec_helper"

RSpec.describe Logtail::Logger, :rails_23 => true do
  describe "#silence" do
    let(:io) { StringIO.new }
    let(:logger) { Logtail::Logger.create_logger(io) }

    it "should silence the logs" do
      logger.silence do
        logger.info("test")
      end

      expect(io.string).to eq("")
    end

    it "should support tags by default" do
      skip("TaggedLogging is supported in Rails 6.1 and higher") if Rails::VERSION::STRING < "6.1"

      logger.tagged("tag1", "tag2").info("test")

      expect(io.string).to include(',"tags":["tag1","tag2"],')
    end

    it "should support formatted data" do
      logger.info("test", nested: { bool: true, text: "abc" }, code: 1234)

      expect(io.string).to include(',"nested":{"bool":true,"text":"abc"},"code":1234,')
    end

    it "should filter sensitive parameters by default" do
      skip("ParameterFilter is supported in Rails 6.0 and higher") if Rails::VERSION::STRING < "6.0"

      Rails.application.config.filter_parameters = [:secret]

      logger.info("test", secret: "top_secret_token")
      logger.info("test", public_info: "public_info")
      logger.info("test", north_pole: { secret: "Santa" })

      expect(io.string).to include(',"secret":"[FILTERED]",')
      expect(io.string).to include(',"public_info":"public_info",')
      expect(io.string).to include(',"north_pole":{"secret":"[FILTERED]"},')
    end

    it "should be considered a broadcast logger in Rails 7.1" do
      expect(logger.is_a?(::Logger)).to eq(true)
      expect(logger).to be_kind_of(::Logger)

      expect(logger.is_a?(::Logtail::Logger)).to eq(true)
      expect(logger).to be_kind_of(::Logtail::Logger)

      if Rails::VERSION::STRING >= "7.1"
        expect(logger.is_a?(::ActiveSupport::BroadcastLogger)).to eq(true)
        expect(logger).to be_kind_of(::ActiveSupport::BroadcastLogger)
      end

      expect(logger.is_a?(::Rails::Application)).to eq(false)
      expect(logger).to_not be_kind_of(::Rails::Application)
    end

    it "should be able to start and stop broadcast" do
      expect(::ActiveSupport::Logger.logger_outputs_to?(logger, STDOUT)).to eq(false)
      expect(logger.broadcasts.length).to eq(1)

      logger.broadcast_to(STDOUT)

      # Logger.logger_outputs_to? didn't work correctly for broadcasting loggers before, skip the assert
      # see https://github.com/rails/rails/pull/49417/files#r1340736648
      expect(::ActiveSupport::Logger.logger_outputs_to?(logger, STDOUT)).to eq(true) if Rails::VERSION::STRING >= "7.1"
      expect(logger.broadcasts.length).to eq(2)

      logger.stop_broadcasting_to(STDOUT)

      expect(::ActiveSupport::Logger.logger_outputs_to?(logger, STDOUT)).to eq(false)
      expect(logger.broadcasts.length).to eq(1)
    end
  end

  describe ".create_default_logger" do
    let(:log_double) { instance_double("Sidekiq::Logger") }

    before do
      allow(Logtail::Logger).to receive(:create_logger).and_return(log_double)
    end

    it "should return the newly created logger" do
      res = Logtail::Logger.create_default_logger("foo")

      expect(res).to eq(log_double)
    end

    it "should not load Sidekiq if it hasn't been required" do
      Logtail::Logger.create_default_logger("foo")

      expect(defined?(Sidekiq)).to be nil
    end

    it "should configure the Sidekiq server to use a logtail logger when required" do
      require 'sidekiq/testing'
      require 'sidekiq/cli'

      Logtail::Logger.create_default_logger("foo")

      expect(Sidekiq.logger).to eq(log_double)
    end
  end
end
