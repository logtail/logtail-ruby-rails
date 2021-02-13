require "logtail-rails"
require "logtail"
require "logtail/config"

config = Logtail::Config.instance
config.environment = "production"
