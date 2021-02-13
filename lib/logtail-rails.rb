require "logtail-rails/overrides"

require "logtail"
require "rails"
require "logtail-rails/active_support_log_subscriber"
require "logtail-rails/config"
require "logtail-rails/railtie"

require "logtail-rack/http_context"
require "logtail-rack/http_events"
require "logtail-rack/user_context"
require "logtail-rails/session_context"
require "logtail-rails/rack_logger"
require "logtail-rails/error_event"

require "logtail-rails/action_controller"
require "logtail-rails/action_dispatch"
require "logtail-rails/action_view"
require "logtail-rails/active_record"

require "logtail-rails/logger"

module Logtail
  module Integrations
    # Module for holding *all* Rails integrations. This module does *not*
    # extend {Integration} because it's dependent on {Rack::HTTPEvents}. This
    # module simply disables the default HTTP request logging.
    module Rails
      def self.enabled?
        Logtail::Integrations::Rack::HTTPEvents.enabled?
      end

      def self.integrate!
        return false if !enabled?

        ActionController.integrate!
        ActionDispatch.integrate!
        ActionView.integrate!
        ActiveRecord.integrate!
        RackLogger.integrate!
      end

      def self.enabled=(value)
        Logtail::Integrations::Rails::ErrorEvent.enabled = value
        Logtail::Integrations::Rack::HTTPContext.enabled = value
        Logtail::Integrations::Rack::HTTPEvents.enabled = value
        Logtail::Integrations::Rack::UserContext.enabled = value
        SessionContext.enabled = value

        ActionController.enabled = value
        ActionView.enabled = value
        ActiveRecord.enabled = value
      end

      # All enabled middlewares. The order is relevant. Middlewares that set
      # context are added first so that context is included in subsequent log lines.
      def self.middlewares
        @middlewares ||= [Logtail::Integrations::Rack::HTTPContext, SessionContext, Logtail::Integrations::Rack::UserContext,
          Logtail::Integrations::Rack::HTTPEvents, Logtail::Integrations::Rails::ErrorEvent].select(&:enabled?)
      end
    end
  end
end

