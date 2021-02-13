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
