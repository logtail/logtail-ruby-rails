module Logtail
  module Integrations
    module ActionView
      class LogSubscriber < Integrator

        # The log subscriber that replaces the default `ActionView::LogSubscriber`.
        # The intent of this subscriber is to, as transparently as possible, properly
        # track events that are being logged here.
        #
        # @private
        class LogtailLogSubscriber < ::ActionView::LogSubscriber
          def render_template(event)
            return true if silence?

            info do
              full_name = from_rails_root(event.payload[:identifier])
              message = "  Rendered #{full_name}"
              message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
              message << " (#{event.duration.round(1)}ms)"

              Events::TemplateRender.new(
                name: full_name,
                duration_ms: event.duration,
                message: message
              )
            end
          end
          subscribe_log_level :render_template, :info if defined?(subscribe_log_level)

          def render_partial(event)
            return true if silence?

            info do
              full_name = from_rails_root(event.payload[:identifier])
              message = "  Rendered #{full_name}"
              message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
              message << " (#{event.duration.round(1)}ms)"
              message << " #{cache_message(event.payload)}" if event.payload.key?(:cache_hit)

              Events::TemplateRender.new(
                name: full_name,
                duration_ms: event.duration,
                message: message
              )
            end
          end

          def render_collection(event)
            return true if silence?

            if respond_to?(:render_count, true)
              info do
                identifier = event.payload[:identifier] || "templates"
                full_name = from_rails_root(identifier)
                message = "  Rendered collection of #{full_name}" \
                  " #{render_count(event.payload)} (#{event.duration.round(1)}ms)"

                Events::TemplateRender.new(
                  name: full_name,
                  duration_ms: event.duration,
                  message: message
                )
              end
            else
              # Older versions of rails delegate this method to #render_template
              render_template(event)
            end
          end

          def self.attach_to(*)
            super

            if ::Rails::VERSION::MAJOR > 7 || ::Rails::VERSION::MAJOR == 7 && ::Rails::VERSION::MINOR >= 1
              # Clean extra listeners subscribed in parent's attach_to method
              ::ActiveSupport::Notifications.notifier.listeners_for("render_template.action_view")
                .concat(::ActiveSupport::Notifications.notifier.listeners_for("render_layout.action_view")).flatten
                .filter { |listener| listener.delegate.class == ::ActionView::LogSubscriber::Start }
                .each { |listener| ActiveSupport::Notifications.unsubscribe(listener) }
            end
          end

          private
          def log_rendering_start(*args)
            # Consolidates 2 template rendering events into 1. We don't need 2 events for
            # rendering a template. If you disagree, please feel free to open a PR and we
            # can make this an option.
            # *args is to be future proof for Rails 6.1, which adds another method argument
          end

          def silence?
            ActionView.silence?
          end
        end
      end
    end
  end
end
