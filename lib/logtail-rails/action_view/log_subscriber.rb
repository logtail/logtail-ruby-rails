module Logtail
  module Integrations
    module ActionView
      # Responsible for uninstalling the default `ActionView::LogSubscriber` and installing
      # the LogtailLogSubscriber.
      #
      # @private
      class LogSubscriber < Integrator
        def initialize
          require "action_view/log_subscriber"
          require "logtail-rails/action_view/log_subscriber/logtail_log_subscriber"
        rescue LoadError => e
          raise RequirementNotMetError.new(e.message)
        end

        def integrate!
          return true if Logtail::Integrations::Rails::ActiveSupportLogSubscriber.subscribed?(:action_view, LogtailLogSubscriber)

          Logtail::Integrations::Rails::ActiveSupportLogSubscriber.unsubscribe!(:action_view, ::ActionView::LogSubscriber)
          LogtailLogSubscriber.attach_to(:action_view)
        end
      end
    end
  end
end
