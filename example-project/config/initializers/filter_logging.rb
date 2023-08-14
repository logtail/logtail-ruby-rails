# Be sure to restart your server when you modify this file.

# Configure parameters to be filtered from the log file. Use this to limit dissemination of
# sensitive information. See the ActiveSupport::ParameterFilter documentation for supported
# notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
]

# Configure HTTP headers to be filtered from the log. Use this to limit dissemination of sensitive information.
Logtail::Integrations::Rack::HTTPEvents.http_header_filters = [
  :authorization, :proxy_authorization, :cookie
]
