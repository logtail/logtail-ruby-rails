module Logtail
  module Frameworks
    # Module for Rails specific code, such as the Railtie and any methods that assist
    # with Rails setup.
    module Rails
      # Installs Logtail into your Rails app automatically.
      class Railtie < ::Rails::Railtie
        railtie_name 'logtail-rails'

        config.logtail = Config.instance

        config.before_initialize do
          Logtail::Config.instance.logger = Proc.new { ::Rails.logger }
        end

        # Must be loaded after initializers so that we respect any Logtail configuration set
        initializer(:logtail, before: :build_middleware_stack, after: :load_config_initializers) do
          Integrations::Rails.integrate!

          # Install the Rack middlewares so that we capture structured data instead of
          # raw text logs.
          Integrations::Rails.middlewares.collect do |middleware_class|
            config.app_middleware.use middleware_class
          end
        end

        # Warns about problems with the logger create_default_logger created, unless the integration is turned off.
        # Registered here, so that it runs after the app's own after_initialize blocks, which may still broadcast to it.
        initializer(:logtail_logger_check, after: :load_config_initializers) do |app|
          app.config.after_initialize do
            next unless Integrations::Rails.enabled?

            if Logtail::Logger.blank_source_token
              Kernel.warn("Logtail: the source token passed to Logtail::Logger.create_default_logger is blank, logging to STDOUT instead of sending logs to Better Stack.")
              next
            end
            next unless Logtail::Logger.better_stack_logger_created

            # A `config.logger = ...` line after config/application.rb, like the one generated in
            # config/environments/production.rb, replaces the Better Stack logger without any error
            loggers = ::Rails.logger.respond_to?(:broadcasts) ? ::Rails.logger.broadcasts : [::Rails.logger]
            next if loggers.any? { |logger| logger.is_a?(Logtail::Logger) }

            # Before Rails 7.1, broadcasting extends the logger with an anonymous module, which hides the target
            extended_modules = ::Rails.logger.singleton_class.included_modules - ::Rails.logger.class.included_modules
            next if extended_modules.any? { |mod| mod.name.nil? }

            Kernel.warn("Logtail: Rails.logger isn't the Better Stack logger created by Logtail::Logger.create_default_logger, and doesn't broadcast to it, so your logs don't reach Better Stack. Most likely config.logger is set again later, e.g. in config/environments/production.rb.")
          end
        end
      end
    end
  end
end
