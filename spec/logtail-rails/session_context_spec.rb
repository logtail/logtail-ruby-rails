require "spec_helper"

RSpec.describe Logtail::Integrations::Rails::SessionContext do
  let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
  let(:io) { StringIO.new }
  let(:logger) do
    logger = Logtail::Logger.new(io)
    logger.level = ::Logger::INFO
    logger
  end
end
