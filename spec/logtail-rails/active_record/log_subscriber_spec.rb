require "spec_helper"

RSpec.describe Logtail::Integrations::ActiveRecord::LogSubscriber do
  let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
  let(:io) { StringIO.new }
  let(:logger) do
    logger = Logtail::Logger.new(io)
    logger.level = ::Logger::INFO
    logger
  end

  describe "#insert!" do
    around(:each) do |example|
      with_rails_logger(logger) do
        Timecop.freeze(time) { example.run }
      end
    end

    it "should not log if the level is not sufficient" do
      ActiveRecord::Base.connection.execute("select * from users")
      expect(io.string).to eq("")
    end

    context "with an info level" do
      around(:each) do |example|
        old_level = logger.level
        logger.level = ::Logger::DEBUG
        example.run
        logger.level = old_level
      end

      it "should log the sql query" do
        ActiveRecord::Base.connection.execute("select * from users")
        # Rails 4.X adds random spaces :/
        string = io.string.gsub("   ORDER BY", " ORDER BY")
        string = string.gsub("  ORDER BY", " ORDER BY")
        expect(string).to include("select * from users")
        expect(string).to include("duration_ms")
        expect(string).to include("\"level\":\"debug\"")
        expect(string).to include("\"sql_query_executed\":")
      end

      it "should log the bind values" do
        User.where(first_name: "Petr").to_a
        expect(io.string).to include('[[\"first_name\", \"Petr\"]]')
      end

      if Rails.respond_to?(:event)
        # What config.log_level = :info does when the app boots. Rails 8.2 reports the SQL events
        # to Rails.event in debug mode only, whatever the level of the logger is.
        context "with the debug mode of Rails.event turned off" do
          around(:each) do |example|
            debug_mode = Rails.event.debug_mode?
            Rails.event.debug_mode = false
            example.run
            Rails.event.debug_mode = debug_mode
          end

          it "should log the sql query" do
            ActiveRecord::Base.connection.execute("select * from users")
            expect(io.string).to include("select * from users")
            expect(io.string).to include("duration_ms")
            expect(io.string).to include("\"level\":\"debug\"")
            expect(io.string).to include("\"sql_query_executed\":")
          end

          it "should log the bind values" do
            User.where(first_name: "Petr").to_a
            expect(io.string).to include('[[\"first_name\", \"Petr\"]]')
          end
        end
      end
    end
  end
end
