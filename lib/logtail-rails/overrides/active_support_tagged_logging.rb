# This is an override instead of an integration because without this Logtail would not
# work properly if ActiveSupport::TaggedLogging is used.

begin
  require "active_support/tagged_logging"

  module Logtail
    module Overrides
      # @private
      module ActiveSupportTaggedLogging
        # @private
        module FormatterMethods
          def self.included(mod)
            mod.module_eval do
              alias_method :_logtail_original_push_tags, :push_tags
              alias_method :_logtail_original_pop_tags, :pop_tags

              def call(severity, timestamp, progname, msg)
                if is_a?(Logtail::Logger::Formatter)
                  # Don't convert the message into a string
                  super(severity, timestamp, progname, msg)
                else
                  super(severity, timestamp, progname, "#{tags_text}#{msg}")
                end
              end
            end
          end
        end

        # @private
        module LoggerMethods
          def self.included(klass)
            klass.class_eval do
              def add(severity, message = nil, progname = nil, &block)
                if message.nil?
                  if block_given?
                    message = block.call
                  else
                    message = progname
                    progname = nil #No instance variable for this like Logger
                  end
                end
                if @logger.is_a?(Logtail::Logger)
                  @logger.add(severity, message, progname)
                else
                  @logger.add(severity, "#{tags_text}#{message}", progname)
                end
              end
            end
          end
        end

        if defined?(::ActiveSupport::TaggedLogging::Formatter)
          if !::ActiveSupport::TaggedLogging::Formatter.include?(FormatterMethods)
            ::ActiveSupport::TaggedLogging::Formatter.send(:include, FormatterMethods)
          end
        else
          if !::ActiveSupport::TaggedLogging.include?(LoggerMethods)
            ::ActiveSupport::TaggedLogging.send(:include, LoggerMethods)
          end
        end
      end
    end
  end

rescue Exception
end
