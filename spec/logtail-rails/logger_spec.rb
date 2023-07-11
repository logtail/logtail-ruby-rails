require "spec_helper"

RSpec.describe Logtail::Logger, :rails_23 => true do
  describe "#silence" do
    let(:io) { StringIO.new }
    let(:logger) { Logtail::Logger.new(io) }

    it "should silence the logs" do
      logger.silence do
        logger.info("test")
      end

      expect(io.string).to eq("")
    end

    it "should support formatted data" do
      logger.info("test", nested: { bool: true, text: "abc" }, code: 1234)

      expect(io.string).to include(',"nested":{"bool":true,"text":"abc"},"code":1234,')
    end

    it "should filter sensitive parameters by default" do
      skip("ParameterFilter is supported in Rails 6.0 and higher") if Rails::VERSION::STRING <= "6.0"

      Rails.application.config.filter_parameters = [:secret]

      logger.info("test", secret: "top_secret_token")
      logger.info("test", public_info: "public_info")
      logger.info("test", north_pole: { secret: "Santa" })

      expect(io.string).to include(',"secret":"[FILTERED]",')
      expect(io.string).to include(',"public_info":"public_info",')
      expect(io.string).to include(',"north_pole":{"secret":"[FILTERED]"},')
    end
  end
end
