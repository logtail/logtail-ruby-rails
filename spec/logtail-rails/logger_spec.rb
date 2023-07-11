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
      logger.tagged("tag1", "tag2").info("test")

      expect(io.string).to include(',"tags":["tag1","tag2"],')
    end

    it "should support formatted data" do
      logger.info("test", nested: { bool: true, text: "abc" }, code: 1234)

      expect(io.string).to include(',"nested":{"bool":true,"text":"abc"},"code":1234,')
    end
  end
end
