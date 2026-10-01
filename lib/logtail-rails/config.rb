require 'logtail/config'
require 'logtail-rack/config'
require 'logtail-rails/config/action_view'
require 'logtail-rails/config/active_record'
require 'logtail-rails/config/action_controller'

Logtail::Config.instance.define_singleton_method(:logrageify!) do
  integrations.action_controller.silence = true
  integrations.action_view.silence = true
  integrations.active_record.silence = true
  integrations.rack.http_events.collapse_into_single_event = true
end

module Logtail
  class Config
    # Turns the Rails integration on or off, it's on by default. Set it in `config/application.rb`
    # or `config/environments/*.rb`, see {Logtail::Frameworks::Rails::Railtie} for what it turns off.
    #
    # @example Keep the standard Rails logging in development
    #   # config/environments/development.rb
    #   config.logtail.enabled = false
    def enabled=(value)
      @enabled = value
    end

    # Accessor method for {#enabled=}
    def enabled?
      @enabled != false
    end
  end
end
