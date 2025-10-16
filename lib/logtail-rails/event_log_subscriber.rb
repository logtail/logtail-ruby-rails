module Logtail
  module Integrations
    module Rails
      # A subscriber for Rails 8.1's Structured Event Reporting system.
      # This subscriber receives events emitted by Rails.event.notify() and logs
      # them with all their data to Rails.logger, which sends them to Better Stack.
      class EventLogSubscriber
        # Rails logger instance
        attr_reader :logger

        # Log level to use for logging events
        mattr_accessor :log_level, default: :info

        # Allows to disable the subscriber
        mattr_accessor :enabled, default: true

        # Initialize the subscriber with a logger instance
        def initialize(logger)
          @logger = logger
        end

        # Rails 8.1 event emission method - called when events are emitted
        def emit(event)
          return unless self.class.enabled

          # Log the event with all its data to Rails.logger
          # Create a structured log entry with the event data
          tags = event[:tags]
          tags_array = tags.is_a?(Hash) ? tags.keys : (tags.is_a?(Array) ? tags : [])

          log_data = {
            event_name: event[:name],
            payload: event[:payload] || {},
            context: event[:context] || {},
            tags: tags_array,
            source_location: event[:source_location] || {}
          }

          message = build_log_message(event)
          logger.info("hello")
          logger.send(self.class.log_level, message, log_data)
        end

        private

        def build_log_message(event)
          payload = event[:payload] || {}
          payload_str = payload.map { |key, value| "#{key}=#{value}" }.join(" ")

          source_location = event[:source_location] || {}
          source_str = "at #{source_location[:filepath]}:#{source_location[:lineno]}" if source_location[:filepath] && source_location[:lineno]

          "[#{event[:name]}] #{payload_str} #{source_str}".strip
        end
      end
    end
  end
end
