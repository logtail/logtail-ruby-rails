module Logtail
  module Integrations
    module ActionController
      class LogSubscriber < Integrator
        # The log subscriber that replaces the default `ActionController::LogSubscriber`.
        # The intent of this subscriber is to, as transparently as possible, properly
        # track events that are being logged here. This LogSubscriber will never change
        # default behavior / log messages.
        #
        # @private
        class LogtailLogSubscriber < ::ActionController::LogSubscriber
          if ::ActionController::LogSubscriber < ::ActiveSupport::LogSubscriber
            def start_processing(event)
              return true if silence?

              info do
                payload = event.payload
                params = payload[:params].except(*INTERNAL_PARAMS)
                format = extract_format(payload)
                format = format.to_s.upcase if format.is_a?(Symbol)

                Events::ControllerCall.new(
                  controller: payload[:controller],
                  action: payload[:action],
                  format: format,
                  params: params
                )
              end
            end
          else
            # Rails 8.2+ feeds this subscriber from Rails.event: the event is a hash whose
            # payload already comes without the internal params and with the format upcased.
            self.namespace = "action_controller"

            def request_started(event)
              return true if silence?

              info do
                payload = event[:payload]

                Events::ControllerCall.new(
                  controller: payload[:controller],
                  action: payload[:action],
                  format: payload[:format],
                  params: payload[:params]
                )
              end
            end
          end

          private
          def extract_format(payload)
            if payload.key?(:format)
              payload[:format] # rails > 4.X
            elsif payload.key?(:formats)
              payload[:formats].first # rails 3.X
            end
          end

          def silence?
            ActionController.silence?
          end
        end
      end
    end
  end
end
