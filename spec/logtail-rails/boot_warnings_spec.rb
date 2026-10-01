require "spec_helper"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe Logtail::Frameworks::Rails::Railtie do
  describe "boot warnings" do
    let(:blank_token_warning) { "Logtail: the source token passed to Logtail::Logger.create_default_logger is blank" }
    let(:logger_warning) { "Logtail: Rails.logger isn't the Better Stack logger" }

    def ingesting_options
      'ingesting_host: "127.0.0.1", ingesting_port: 9, ingesting_scheme: "http"'
    end

    # Booting an app patches Rails classes for the whole process, so each case boots its own production app in a
    # new Ruby process. Its config/application.rb creates the logger as in the setup docs.
    def boot_app(source_token, environment_file = "", after_boot = "")
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "config", "environments"))
        File.write(File.join(root, "config", "environments", "production.rb"), environment_file)
        File.write(File.join(root, "boot.rb"), <<-RUBY)
          require "logger" # Rails < 7.1 doesn't require it before ActiveSupport needs it
          require "rails"
          require "action_controller/railtie"
          require "logtail-rails"

          class BootWarningsSpecApp < Rails::Application
            config.root = #{root.inspect}
            config.eager_load = false
            config.secret_key_base = "1e05af2b349457936a41427e63450937"
            config.logger = Logtail::Logger.create_default_logger(#{source_token.inspect}, #{ingesting_options})
          end
          BootWarningsSpecApp.initialize!
          #{after_boot}
        RUBY

        Open3.capture3({ "RAILS_ENV" => "production" }, RbConfig.ruby, "-rbundler/setup", File.join(root, "boot.rb"))
      end
    end

    it "boots with a missing source token, logs to STDOUT and warns once" do
      stdout, stderr, status = boot_app(nil, "", 'Rails.logger.info("Logged after boot")')

      expect(status).to be_success, stderr
      expect(stderr.scan(blank_token_warning).length).to eq(1)
      expect(stderr.scan(/^Logtail: /).length).to eq(1)
      expect(stdout).to include("Logged after boot")
    end

    it "logs to STDOUT and warns when the source token is an empty string" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      logger = nil

      expect { logger = Logtail::Logger.create_default_logger("") }.to output(a_string_including(blank_token_warning)).to_stderr
      expect(::ActiveSupport::Logger.logger_outputs_to?(logger, STDOUT)).to eq(true)
    end

    it "warns once when config.logger is set again after config/application.rb" do
      _stdout, stderr, status = boot_app("source-token", <<-RUBY)
        Rails.application.configure do
          config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
        end
      RUBY

      expect(status).to be_success, stderr
      expect(stderr.scan(logger_warning).length).to eq(1)
      expect(stderr.scan(/^Logtail: /).length).to eq(1)
    end

    it "doesn't warn when Rails.logger broadcasts to the Better Stack logger" do
      # ActiveSupport::BroadcastLogger replaced ActiveSupport::Logger.broadcast in Rails 7.1
      environment_file = if ::ActiveSupport::Logger.respond_to?(:broadcast)
        <<-RUBY
          Rails.application.configure do
            config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
            config.logger.extend(ActiveSupport::Logger.broadcast(Logtail::Logger.create_default_logger("source-token", #{ingesting_options})))
          end
        RUBY
      else
        <<-RUBY
          Rails.application.configure do
            config.logger = ActiveSupport::BroadcastLogger.new(ActiveSupport::Logger.new(STDOUT), Logtail::Logger.create_default_logger("source-token", #{ingesting_options}))
          end
        RUBY
      end

      _stdout, stderr, status = boot_app("source-token", environment_file)

      expect(status).to be_success, stderr
      expect(stderr).not_to match(/^Logtail: /)
    end

    it "doesn't warn with the documented setup" do
      _stdout, stderr, status = boot_app("source-token")

      expect(status).to be_success, stderr
      expect(stderr).not_to match(/^Logtail: /)
    end
  end
end
