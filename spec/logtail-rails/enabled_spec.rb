require "spec_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe Logtail::Frameworks::Rails::Railtie do
  describe "config.logtail.enabled" do
    # Booting an app patches Rails classes for the whole process, so each case boots its own app in a new
    # Ruby process. Its config/application.rb creates the logger as in the setup docs.
    def boot_app(rails_env, environment_file)
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "config", "environments"))
        File.write(File.join(root, "config", "environments", "#{rails_env}.rb"), environment_file)
        File.write(File.join(root, "boot.rb"), <<-RUBY)
          require "logger" # Rails < 7.1 doesn't require it before ActiveSupport needs it
          require "rails"
          require "action_controller/railtie"
          require "logtail-rails"

          class EnabledSpecApp < Rails::Application
            config.root = #{root.inspect}
            config.eager_load = false
            config.secret_key_base = "1e05af2b349457936a41427e63450937"
            config.logger = Logtail::Logger.create_default_logger("source-token", ingesting_host: "127.0.0.1", ingesting_port: 9, ingesting_scheme: "http")
          end
          EnabledSpecApp.initialize!

          Rails.logger.info("Structured log line", key: "value")

          log_file = File.join(#{root.inspect}, "log", "#{rails_env}.log")
          File.write(File.join(#{root.inspect}, "result.json"), JSON.generate(
            "middlewares" => Rails.application.middleware.map(&:inspect).grep(/Logtail/),
            "debug_exceptions_patched" => ActionDispatch::DebugExceptions.include?(Logtail::Integrations::ActionDispatch::DebugExceptions::InstanceMethods),
            "event_log_subscriber_enabled" => Logtail::Integrations::Rails::EventLogSubscriber.enabled,
            "logtail_logger" => Rails.logger.is_a?(Logtail::Logger),
            "log_file" => (File.read(log_file) if File.exist?(log_file))
          ))
        RUBY

        _stdout, stderr, status = Open3.capture3({ "RAILS_ENV" => rails_env }, RbConfig.ruby, "-rbundler/setup", File.join(root, "boot.rb"))
        raise "The app failed to boot:\n#{stderr}" unless status.success?

        JSON.parse(File.read(File.join(root, "result.json")))
      end
    end

    it "turns the integration off and logs to log/<env>.log when set to false in an environment file" do
      result = boot_app("development", "Rails.application.configure { config.logtail.enabled = false }\n")

      expect(result["middlewares"]).to eq([])
      expect(result["debug_exceptions_patched"]).to eq(false)
      expect(result["event_log_subscriber_enabled"]).to eq(false)
      expect(result["logtail_logger"]).to eq(true)
      expect(result["log_file"]).to include("Structured log line")
    end

    it "replaces the STDOUT logger create_default_logger returns in the test environment" do
      result = boot_app("test", "Rails.application.configure { config.logtail.enabled = false }\n")

      expect(result["middlewares"]).to eq([])
      expect(result["log_file"]).to include("Structured log line")
    end

    it "keeps the integration on by default" do
      result = boot_app("test", "")

      expect(result["middlewares"]).to include("Logtail::Integrations::Rack::HTTPEvents")
      expect(result["debug_exceptions_patched"]).to eq(true)
      expect(result["event_log_subscriber_enabled"]).to eq(true)
      expect(result["log_file"]).to be_nil
    end
  end
end
