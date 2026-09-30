require "logtail-rails/active_record/log_subscriber/logtail_log_subscriber"

module Logtail
  module Integrations
    module ActiveRecord
      # Responsible for uninstalling the default `ActiveRecord::LogSubscriber` and replacing it
      # with the `LogtailLogSubscriber`.
      #
      # @private
      class LogSubscriber < Integrator
        def integrate!
          return true if Logtail::Integrations::Rails::ActiveSupportLogSubscriber.subscribed?(:active_record, LogtailLogSubscriber)

          Logtail::Integrations::Rails::ActiveSupportLogSubscriber.unsubscribe!(:active_record, ::ActiveRecord::LogSubscriber)
          Logtail::Integrations::Rails::ActiveSupportLogSubscriber.subscribe!(:active_record, LogtailLogSubscriber)
        end
      end
    end
  end
end
