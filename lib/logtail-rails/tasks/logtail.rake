namespace :logtail do
  desc 'Install a default config/initializers/logtail.rb file'

  PLACEHOLDER = '<SOURCE_TOKEN>'.freeze
  def content(source_token = nil)
    <<~RUBY
      Rails.application.configure do
        if ENV['LOGTAIL_SKIP_LOGS'].blank? && !Rails.env.test?
          http_device = Logtail::LogDevices::HTTP.new('#{source_token || PLACEHOLDER}')
          config.logger = Logtail::Logger.new(http_device)
        else
          config.logger = Logtail::Logger.new(STDOUT)
        end
      end
    RUBY
  end

  task install: :environment do
    quiet = ENV['quiet']
    force = ENV['force']
    source_token = ENV['source_token']
    source_token = nil if source_token == ''

    config_file = 'config/initializers/logtail.rb'

    if File.exist?(config_file) && !force
      puts <<~EOF
        #{config_file} file already exists.
        Overwrite the config with:
          rake logtail:install force=true source_token=<SOURCE_TOKEN>
      EOF
      next
    end

    File.open(config_file, 'w') { |out| out.puts(content(source_token)) }

    return if quiet

    info = <<~EOF
      Want to see full setup instructions?
      Check out https://betterstack.com/docs/logs/ruby-and-rails/

      Need help?
      Let us know at hello@logtail.com
      We are happy to help!
    EOF

    if source_token.nil?
      puts <<~EOF
        Installed a configuration file with a token placeholder to #{config_file}.

      EOF

      puts <<~EOF
        You will need a Logtail source token to send logs to Logtail!
        Get your source token at https://logtail.com/ -> Sources

        Set up Logtail logger with:
          rake logtail:install force=true source_token=<SOURCE_TOKEN>

      EOF

      puts info
    else
      puts <<~EOF
        Installed a configuration file to #{config_file}
        using a source token ending with '#{source_token[-4..-1]}'.

      EOF

      puts info
    end
  end
end
