Rails.application.configure do
  if ENV['LOGTAIL_SKIP_LOGS'].blank? && !Rails.env.test?
    http_device = Logtail::LogDevices::HTTP.new('<SOURCE_TOKEN>')
    config.logger = Logtail::Logger.new(http_device)
  else
    config.logger = Logtail::Logger.new(STDOUT)
  end
end
