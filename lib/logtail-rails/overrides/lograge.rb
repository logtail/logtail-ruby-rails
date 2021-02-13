# Logtail and lograge are not compatible installed together. Using lograge
# with the Logtail.com *service* is perfectly fine, but not with the Logtail *gem*.
#
# Logtail does ship with a {Logtail::Config#logrageify!} option that configures
# Logtail to behave similarly to Lograge (silencing various logs). Check out
# the aforementioned method or the README for info.
begin
  require "lograge"

  module Lograge
    module_function

    def setup(app)
      return true
    end
  end
rescue Exception
end