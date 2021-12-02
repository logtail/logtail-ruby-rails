namespace :logtail do
  desc 'Install a default config/initializers/logtail.rb file'

  PLACEHOLDER = '<SOURCE_TOKEN>'.freeze
  def content(source_token = nil)
    <<~RUBY
      if ENV['LOGTAIL_SKIP_LOGS'].blank? && !Rails.env.test?
        http_device = Logtail::LogDevices::HTTP.new('#{source_token || PLACEHOLDER}')
        Rails.logger = Logtail::Logger.new(http_device)
      else
        Rails.logger = Logtail::Logger.new(STDOUT)
      end
    RUBY
  end

  task install: :environment do
    quiet = ENV['quiet']
    force = ENV['force']
    source_token = ENV['source_token']

    config_file = 'config/initializers/logtail.rb'

    if File.exist?(config_file) && !force
      puts "logtail.rb file already exists. Use `rake logtail:install force=true` to overwrite."
      next
    end

    File.open(config_file, 'w') { |out| out.puts(content(source_token)) }

    return if quiet

    if source_token.nil? || source_token == ''
      puts <<~EOF
        Installed a default configuration file at #{config_file}.
      EOF

      puts <<~EOF
        To monitor your logs in production mode, sign up for an account
        at logtail.com, and replace the source token in the logtail.rb file
        with the one you receive upon registration.
      EOF

      puts <<~EOF
        Visit logtail.com/help if you are experiencing installation issues.
      EOF
    else
      puts <<~EOF
        Installed a configuration file at #{config_file} with a source token 
        ending with '#{source_token[-4..-1]}'.
      EOF

      puts <<~EOF
        Visit logtail.com/help if you are experiencing installation issues.
      EOF
    end
  end
end
