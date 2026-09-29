# We require all of ActiveRecord because the #logger method in ::ActiveRecord::LogSubscriber
# uses ActiveRecord::Base. We can't require active_record/base directly because ActiveRecord
# does not require files properly and we receive unintialized constant errors.
require "active_record"
require "active_record/log_subscriber"

module Logtail
  module Integrations
    module ActiveRecord
      class LogSubscriber < Integrator
        # The log subscriber that replaces the default `ActiveRecord::LogSubscriber`.
        # The intent of this subscriber is to, as transparently as possible, properly
        # track events that are being logged here. This LogSubscriber will never change
        # default behavior / log messages.
        #
        # Until Rails 8.1 it extends the default subscriber. Rails 8.2 turned that one into a
        # subscriber of Rails.event, which receives the SQL events in debug mode only, so there
        # this subscriber listens to the notifications on its own.
        #
        # @private
        class LogtailLogSubscriber < (::ActiveRecord::LogSubscriber < ::ActiveSupport::LogSubscriber ? ::ActiveRecord::LogSubscriber : ::ActiveSupport::LogSubscriber)
          if superclass == ::ActiveRecord::LogSubscriber
            def sql(event)
              return true if silence?

              r = super(event)

              if @message
                payload = event.payload

                sql_event = Events::SQLQuery.new(
                  sql: payload[:sql],
                  duration_ms: event.duration,
                  message: @message,
                )

                logger.debug sql_event

                @message = nil
              end

              r
            end

            private
            def debug(message)
              @message = message
            end
          else
            require "active_record/structured_event_subscriber"

            # Rails 8.2 split ActiveRecord::LogSubscriber#sql in two: a subscriber that turns the
            # notification into an event for Rails.event, rendering and filtering the binds, and
            # a log subscriber that formats the event. Both are used here as they are, without
            # Rails.event between them.
            class Translation < ::ActiveRecord::StructuredEventSubscriber
              attr_reader :payload

              def emit_debug_event(name, payload = nil, caller_depth: 1, **kwargs)
                @payload = payload || kwargs
              end
            end

            class Formatting < ::ActiveRecord::LogSubscriber
              attr_reader :message

              private
              def debug(message)
                @message = message
              end
            end

            def sql(event)
              return true if silence?

              translation = Translation.new
              translation.sql(event)
              # Schema and explain queries are not reported
              return unless translation.payload

              formatting = Formatting.new
              formatting.sql({ name: "active_record.sql", payload: translation.payload })

              logger.debug Events::SQLQuery.new(
                sql: event.payload[:sql],
                duration_ms: event.duration,
                message: formatting.message,
              )
            end
            subscribe_log_level :sql, :debug

            def logger
              ::ActiveRecord::Base.logger
            end
          end

          private
          def silence?
            ActiveRecord.silence?
          end
        end
      end
    end
  end
end
