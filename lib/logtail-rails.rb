require "logtail-rails/overrides"

require "logtail"

require "rails/railtie"
require "active_record"
require "rack"

require "logtail-rails/active_support_log_subscriber"
require "logtail-rails/event_log_subscriber"
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

require "logtail-rails/log_entry"
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
        filter_parameters_in_urls(::Rails.application.config.filter_parameters)
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
        EventLogSubscriber.enabled = value
      end

      # All enabled middlewares. The order is relevant. Middlewares that set
      # context are added first so that context is included in subsequent log lines.
      def self.middlewares
        @middlewares ||= [Logtail::Integrations::Rack::HTTPContext, SessionContext, Logtail::Integrations::Rack::UserContext,
          Logtail::Integrations::Rack::HTTPEvents, Logtail::Integrations::Rails::ErrorEvent].select(&:enabled?)
      end

      # Filters the app's filter_parameters from the query strings and the Referer and Location
      # URLs that Rack::HTTPEvents logs, unless the app customised its query_string_filters.
      # Procs are left out: they rewrite values, while query string filters match names.
      def self.filter_parameters_in_urls(filter_parameters)
        http_events = Logtail::Integrations::Rack::HTTPEvents
        return if http_events.query_string_filters != http_events::DEFAULT_QUERY_STRING_FILTERS

        http_events.query_string_filters = filter_parameters.reject { |filter| filter.is_a?(Proc) }
      end
    end
  end
end
