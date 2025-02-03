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

    # Logtail::Logger also works as ActiveSupport::BroadcastLogger
    def kind_of?(clazz)
      return true if defined?(::ActiveSupport::BroadcastLogger) && clazz == ::ActiveSupport::BroadcastLogger

      super(clazz)
    end
    alias is_a? kind_of?

    def broadcasts
      [self] + @extra_loggers
    end

    def broadcast_to(*io_devices_and_loggers)
      io_devices_and_loggers.each do |io_device_or_logger|
        extra_logger = is_a_logger?(io_device_or_logger) ? io_device_or_logger : self.class.new(io_device_or_logger)

        @extra_loggers << extra_logger
      end
    end

    def stop_broadcasting_to(io_device_or_logger)
      if is_a_logger?(io_device_or_logger)
        @extra_loggers.delete(io_device_or_logger)

        return
      end

      @extra_loggers = @extra_loggers.reject { |logger| ::ActiveSupport::Logger.logger_outputs_to?(logger, io_device_or_logger) }
    end

    def self.create_logger(*io_devices_and_loggers)
      logger = Logtail::Logger.new(*io_devices_and_loggers)

      tagged_logging_supported = Rails::VERSION::MAJOR >= 7 || Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR >= 1
      logger = ::ActiveSupport::TaggedLogging.new(logger) if tagged_logging_supported

      logger
    end

    def self.create_default_logger(source_token, options = {})
      if ENV['LOGTAIL_SKIP_LOGS'].blank? && !Rails.env.test?
        io_device = Logtail::LogDevices::HTTP.new(source_token, options)
      else
        io_device = STDOUT
      end

      logger = self.create_logger(io_device)

      if defined?(Sidekiq)
        require "logtail-rails/sidekiq"

        Sidekiq.configure_server do |config|
          logger = self.create_logger(io_device, config.logger) if config.logger.class == Sidekiq::Logger
          config.logger = logger
        end
      end

      logger
    end
  end
end
