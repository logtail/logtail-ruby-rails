require "singleton"
require "spec_helper"

RSpec.describe Logtail::Config, :rails_23 => true do
  let(:config) { Logtail::Config.send(:new) }

  describe ".logrageify!" do
    it "should logrageify!" do
      expect(Logtail::Integrations::ActionController.silence?).to eq(false)
      expect(Logtail::Integrations::ActionView.silence?).to eq(false)
      expect(Logtail::Integrations::ActiveRecord.silence?).to eq(false)
      expect(Logtail::Integrations::Rack::HTTPEvents.collapse_into_single_event?).to eq(false)

      config.logrageify!

      expect(Logtail::Integrations::ActionController.silence?).to eq(true)
      expect(Logtail::Integrations::ActionView.silence?).to eq(true)
      expect(Logtail::Integrations::ActiveRecord.silence?).to eq(true)
      expect(Logtail::Integrations::Rack::HTTPEvents.collapse_into_single_event?).to eq(true)

      # Reset
      Logtail::Integrations::ActionController.silence = false
      Logtail::Integrations::ActionView.silence = false
      Logtail::Integrations::ActiveRecord.silence = false
      Logtail::Integrations::Rack::HTTPEvents.collapse_into_single_event = false
    end
  end
end
