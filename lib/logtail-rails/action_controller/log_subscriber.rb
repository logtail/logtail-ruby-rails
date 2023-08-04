module Logtail
  module Integrations
    module ActionController
      # Responsible for removing the default ActionController::LogSubscriber and installing
      # the LogtailLogSubscriber
      #
      # @private
      class LogSubscriber < Integrator
        def initialize
          require "action_controller"
          require "logtail-rails/action_controller/log_subscriber/logtail_log_subscriber"
        rescue LoadError => e
          raise RequirementNotMetError.new(e.message)
        end

        def integrate!
          return true if Logtail::Integrations::Rails::ActiveSupportLogSubscriber.subscribed?(:action_controller, LogtailLogSubscriber)

          Logtail::Integrations::Rails::ActiveSupportLogSubscriber.unsubscribe!(:action_controller, ::ActionController::LogSubscriber)
          LogtailLogSubscriber.attach_to(:action_controller)
        end
      end
    end
  end
end
