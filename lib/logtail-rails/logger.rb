module Logtail
  # The Logtail Logger behaves exactly like the standard Ruby `::Logger`, except that it supports a
  # transparent API for logging structured data and events.
  #
  # @example Basic logging
  #   logger.info "Payment rejected for customer #{customer_id}"
  #
  # @example Logging an event
  #   logger.info "Payment rejected", payment_rejected: {customer_id: customer_id, amount: 100}
  class Logger < ::Logger
    include ::ActiveSupport::LoggerThreadSafeLevel if defined?(::ActiveSupport::LoggerThreadSafeLevel)

    if defined?(::ActiveSupport::LoggerSilence)
      include ::ActiveSupport::LoggerSilence
    elsif defined?(::LoggerSilence)
      include ::LoggerSilence
    end

    def self.create_logger(*io_devices_and_loggers)
      logger = Logtail::Logger.new(*io_devices_and_loggers)

      logger = ::ActiveSupport::TaggedLogging.new(logger) if defined?(::ActiveSupport::TaggedLogging)

      logger
    end

    def self.create_default_logger(source_token)
      if ENV['LOGTAIL_SKIP_LOGS'].blank? && !Rails.env.test?
        io_device = Logtail::LogDevices::HTTP.new(source_token)
      else
        io_device = STDOUT
      end

      self.create_logger(io_device)
    end
  end
end
