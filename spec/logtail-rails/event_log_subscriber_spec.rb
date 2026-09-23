require "spec_helper"

RSpec.describe Logtail::Integrations::Rails::EventLogSubscriber do
  let(:io) { StringIO.new }
  let(:logger) { Logtail::Logger.new(io) }
  let(:subscriber) { described_class.new(logger) }

  around(:each) do |example|
    with_rails_logger(logger) { example.run }
  end

  it "logs events reported by the application" do
    subscriber.emit({ name: "user.created", payload: { id: 1 }, tags: {}, context: {}, source_location: {} })

    expect(io.string).to include('"message":"[user.created] id=1"')
    expect(io.string).to include('"event_name":"user.created"')
  end

  it "does not log events the Rails framework already logs" do
    skip("Rails 8.2 routes the framework's own events through Rails.event") unless defined?(::ActiveSupport::EventReporter::LogSubscriber)

    subscriber.emit({ name: "active_record.sql", payload: { sql: "select 1" }, tags: {}, context: {}, source_location: {} })

    expect(io.string).to eq("")
  end
end
