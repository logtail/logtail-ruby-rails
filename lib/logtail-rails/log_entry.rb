module Logtail
  class LogEntry
    alias to_hash_unfiltered to_hash

    def to_hash(options = {})
      hash = to_hash_unfiltered(options)

      parameter_filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      parameter_filter.filter(hash)
    end
  end
end
