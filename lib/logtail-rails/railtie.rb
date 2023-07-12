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
      end
    end
  end
end
