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

        def call(env)
          begin
            status, headers, body = @app.call(env)
          rescue Exception => exception
            Config.instance.logger.fatal do
              backtrace = extract_backtrace(env, exception)
              Events::Error.new(
                name: exception.class.name,
                error_message: exception.message,
                backtrace: backtrace
              )
            end

            raise exception
          end
        end

        private

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
