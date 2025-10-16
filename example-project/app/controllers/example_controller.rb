class ExampleController < ApplicationController
    # Index action
    def index
        send_logs_path = '/send_logs'
    end

    # The following action send example logs
    def send_logs
        # Sending logs using the Rails.logger

        # Send debug logs messages using the debug() method
        Rails.logger.debug("Hey! I am debuging!")

        # Send informative messages about interesting events using the info() method
        Rails.logger.info("You know what's interesting? Logtail !")

        # Send messages about worrying events using the warn() method
        Rails.logger.warn("Something might not be quite right...")

        # Send error messages using the error() method
        Rails.logger.error("Oops! Something went wrong.")

        # Send messages about fatal events thet caused the app to crash using the fatal() method
        Rails.logger.fatal("Application crashed! Needs to be fixed ASAP!")


        # You can optionally add tags when logging
        Rails.logger.tagged("tag1", "tag2").info("log message with tags")


        # You can also provide additional information when logging
        Rails.logger.warn("log structured data",
            name: {
                first: "John",
                last: "Smith"
            },
            id: 123456
        )

        # Since Rails 8.1, you can also use the Rails.event to send events with structured data to Better Stack.
        Rails.event.notify("My first event", user_id: 123, email: "user@example.com")
        
        # You can add context to all events
        Rails.event.set_context(request_id: "abc123", shop_id: 456)
        # And tags specific events
        Rails.event.tagged("api") do
            Rails.event.notify("My tagged event with additional context", user_id: 123, email: "user@example.com")
        end
    end
end
