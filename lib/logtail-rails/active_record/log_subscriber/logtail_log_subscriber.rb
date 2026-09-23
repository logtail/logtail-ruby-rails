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
        # @private
        class LogtailLogSubscriber < ::ActiveRecord::LogSubscriber
          if ::ActiveRecord::LogSubscriber < ::ActiveSupport::LogSubscriber
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
          else
            # Rails 8.2+ feeds this subscriber from Rails.event: the event is a hash and the
            # payload carries the duration.
            self.namespace = "active_record"

            def sql(event)
              return true if silence?

              r = super(event)

              if @message
                payload = event[:payload]

                sql_event = Events::SQLQuery.new(
                  sql: payload[:sql],
                  duration_ms: payload[:duration_ms],
                  message: @message,
                )

                logger.debug sql_event

                @message = nil
              end

              r
            end
          end

          private
          def debug(message)
            @message = message
          end

          def silence?
            ActiveRecord.silence?
          end
        end
      end
    end
  end
end
