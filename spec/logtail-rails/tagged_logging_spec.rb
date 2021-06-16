require "spec_helper"

RSpec.describe ActiveSupport::TaggedLogging, :rails_23 => true do
  describe "#new" do
    let(:io) { StringIO.new }

    it "should instantiate for Logtail::Logger object" do
      ActiveSupport::TaggedLogging.new(Logtail::Logger.new(io))
    end

    if defined?(ActiveSupport::BufferedLogger)
      it "should instantiate for a ActiveSupport::BufferedLogger object" do
        ActiveSupport::TaggedLogging.new(ActiveSupport::BufferedLogger.new(io))
      end
    end
  end

  describe "#info" do
    let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
    let(:io) { StringIO.new }
    let(:logger) { ActiveSupport::TaggedLogging.new(Logtail::Logger.new(io)) }

    it "should accept events as the second argument" do
      logger.info("SQL query", payment_rejected: { customer_id: "abcd1234", amount: 100, reason: "Card expired" })
      expect(io.string).to include("SQL query")
      expect(io.string).to include("\"payment_rejected\":")
    end
  end

  describe "adds tags to the log event" do
    let(:io) { StringIO.new }

    it "should add the tag to the log event" do
      logger = ActiveSupport::TaggedLogging.new(Logtail::Logger.new(io))
      logger.tagged('ABC') { |tagged_logger| tagged_logger.info('tagged log') }
      expect(io.string).to include(',"tags":["ABC"],')
    end

    it "should add multiple tags to the log event" do
      logger = ActiveSupport::TaggedLogging.new(Logtail::Logger.new(io))
      logger.tagged('ABC') { |a| a.tagged('DEF') { |b| b.info('tagged log') } }
      expect(io.string).to include(',"tags":["ABC","DEF"],')
    end
  end
end
