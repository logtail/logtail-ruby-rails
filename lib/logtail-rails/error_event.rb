begin
  # Rails 3.2 requires you to require all of Rails before requiring
  # the exception wrapper.
  require "action_dispatch/middleware/exception_wrapper"
rescue Exception
end

require "logtail/events/error"
require "logtail-rack/middleware"
require "logtail/util"

module Logtail
  module Integrations
    module Rails
      # A Rack middleware that is responsible for capturing exception and error events
      # {Logtail::Events::Error}.
      class ErrorEvent < Logtail::Integrations::Rack::Middleware
        # We determine this when the app loads to avoid the overhead on a per request basis.
        EXCEPTION_WRAPPER_TAKES_CLEANER = defined?(::ActionDispatch::ExceptionWrapper) &&
          !::ActionDispatch::ExceptionWrapper.instance_methods.include?(:env)
        # config.action_dispatch.log_rescued_responses (Rails 7.0+) and
        # config.action_dispatch.debug_exception_log_level (Rails 7.1+), as ActionDispatch::DebugExceptions
        # reads them. This gem silences its logging and logs the exception here instead.
        LOG_RESCUED_RESPONSES_KEY = "action_dispatch.log_rescued_responses".freeze
        DEBUG_EXCEPTION_LOG_LEVEL_KEY = "action_dispatch.debug_exception_log_level".freeze

        def call(env)
          begin
            status, headers, body = @app.call(env)
          rescue Exception => exception
            log_exception(env, exception)

            raise exception
          end
        end

        private

        # Never raises, so that the exception of the app is the one that propagates.
        def log_exception(env, exception)
          return if !log_exception?(env, exception)

          Config.instance.logger.add(env[DEBUG_EXCEPTION_LOG_LEVEL_KEY] || ::Logger::FATAL) do
            backtrace = extract_backtrace(env, exception)
            Events::Error.new(
              name: exception.class.name,
              error_message: exception.message,
              backtrace: backtrace
            )
          end
        rescue StandardError => e
          Config.instance.debug { "#{self.class.name} could not log #{exception.class}: #{e.inspect}" }
        end

        # Like DebugExceptions, skip rescued responses such as ActiveRecord::RecordNotFound when
        # log_rescued_responses is false. Older Rails versions don't set it and log every exception.
        def log_exception?(env, exception)
          return true if !env.key?(LOG_RESCUED_RESPONSES_KEY) || env[LOG_RESCUED_RESPONSES_KEY]

          !::ActionDispatch::ExceptionWrapper.rescue_responses.key?(exception.class.name)
        end

        # Rails provides a backtrace cleaner, so we use it here.
        def extract_backtrace(env, exception)
          if defined?(::ActionDispatch::ExceptionWrapper)
            wrapper = if EXCEPTION_WRAPPER_TAKES_CLEANER
                        request = Util::Request.new(env)
                        backtrace_cleaner = request.get_header("action_dispatch.backtrace_cleaner")
                        ::ActionDispatch::ExceptionWrapper.new(backtrace_cleaner, exception)
                      else
                        ::ActionDispatch::ExceptionWrapper.new(env, exception)
                      end

            trace = wrapper.application_trace
            trace = wrapper.framework_trace if trace.empty?
            trace
          else
            exception.backtrace
          end
        end
      end
    end
  end
end
