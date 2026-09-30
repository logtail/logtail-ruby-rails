module Logtail
  module Integrations
    module Rails
      # @private
      module ActiveSupportLogSubscriber
        extend self

        def find(component, type)
          if event_reporter_subscriber?(type)
            return ::ActiveSupport.event_reporter.subscribers.map { |entry| entry[:subscriber] }.find do |subscriber|
              subscriber.class == type
            end
          end

          ::ActiveSupport::LogSubscriber.log_subscribers.find do |subscriber|
            subscriber.class == type
          end
        end

        def subscribed?(component, type)
          !find(component, type).nil?
        end

        def subscribe!(component, type)
          if event_reporter_subscriber?(type)
            # Like attach_to below, only deliver the events for the methods the subscriber defines itself
            events = type.public_instance_methods(false).map { |method| "#{component}.#{method}" }
            ::ActiveSupport.event_reporter.subscribe(type.new) { |event| events.include?(event[:name]) }
            return
          end

          type.attach_to(component)
        end

        # I don't know why this has to be so complicated, but it is. This code was taken from
        # lograge :/
        def unsubscribe!(component, type)
          if event_reporter_subscriber?(type)
            ::ActiveSupport.event_reporter.unsubscribe(type)
            return
          end

          if defined?(type.detach_from)
            type.detach_from(component)
            return
          end

          subscriber = find(component, type)

          if !subscriber
            raise "We could not find a log subscriber for #{component.inspect} of type #{type.inspect}"
          end

          events = subscriber.public_methods(false).reject { |method| method.to_s == 'call' }
          events.each do |event|
            ::ActiveSupport::Notifications.notifier.listeners_for("#{event}.#{component}").each do |listener|
              if listener.instance_variable_get('@delegate') == subscriber
                ::ActiveSupport::Notifications.unsubscribe listener
              end
            end
          end
        end

        # Rails 8.2+ feeds the framework log subscribers from Rails.event instead of
        # ActiveSupport::Notifications.
        def event_reporter_subscriber?(type)
          defined?(::ActiveSupport::EventReporter::LogSubscriber) && type < ::ActiveSupport::EventReporter::LogSubscriber
        end
      end
    end
  end
end
