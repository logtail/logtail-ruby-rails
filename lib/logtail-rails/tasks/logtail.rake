namespace :logtail do
  desc 'Install a default config/initializers/logtail.rb file'

  def content
    <<~RUBY
      if ENV['LOGTAIL_SKIP_LOGS'].blank? && !Rails.env.test?
        http_device = Logtail::LogDevices::HTTP.new('<ACCESS_TOKEN>')
        Rails.logger = Logtail::Logger.new(http_device)
      else
        Rails.logger = Logtail::Logger.new(STDOUT)
      end
    RUBY
  end

  task install: :environment do
    quiet = ENV['quiet']
    force = ENV['force']

    config_file = 'config/initializers/logtail.rb'

    if File.exist?(config_file) && !force
      puts "logtail.rb file already exists.  Use `rake logtail:install force=true` to overwrite."
      next
    end

    File.open(config_file, 'w') { |out| out.puts(content) }

    puts <<~EOF unless quiet
      Installed a default configuration file at #{config_file}.
    EOF

    puts <<~EOF unless quiet
      To monitor your logs in production mode, sign up for an account
      at logtail.com, and replace the access key in the logtail.rb file 
      with the one you receive upon registration.
    EOF

    puts <<~EOF unless quiet
      Visit logtail.com/help if you are experiencing installation issues.
    EOF
  end
end
