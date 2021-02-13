require "logtail-rails/active_record"

module Logtail
  class Config
    # Convenience module for accessing the various `Logtail::Integrations::*` classes
    # through the {Logtail::Config} object. Logtail couples configuration with the class
    # responsible for implementing it. This provides for a tighter design, but also
    # requires the user to understand and access the various classes. This module aims
    # to provide a simple ruby-like configuration interface for internal Logtail classes.
    #
    # For example:
    #
    #     config = Logtail::Config.instance
    #     config.integrations.active_record.silence = true
    module Integrations
      extend self

      # Convenience method for accessing the {Logtail::Integrations::ActiveRecord} class
      # specific configuration.
      #
      # @example
      #   config = Logtail::Config.instance
      #   config.integrations.active_record.silence = true
      def active_record
        Logtail::Integrations::ActiveRecord
      end
    end
  end
end
