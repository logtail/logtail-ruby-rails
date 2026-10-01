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

        # `config.logtail.enabled = false` turns the integration off. The environment files are loaded
        # by now, and Rails hasn't set up Rails.logger from config.logger yet.
        initializer(:logtail_enabled, after: :load_environment_config, before: :initialize_logger) do |app|
          next if app.config.logtail.enabled?

          # Before the :logtail initializer below picks the middlewares
          Integrations::Rails.enabled = false

          # The setup docs create the logger in config/application.rb, i.e. in every environment. Log to the
          # default log file instead, with a Logtail::Logger so that `logger.info("message", key: value)` works.
          if app.config.logger.is_a?(Logtail::Logger)
            log_file = app.paths["log"].first
            FileUtils.mkdir_p(File.dirname(log_file))
            app.config.logger = Logtail::Logger.create_logger(log_file)
          end
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
      end
    end
  end
end
