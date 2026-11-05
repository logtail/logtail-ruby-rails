require "spec_helper"
require "open3"
require "rbconfig"

# A Rails app loads Rails before Bundler.require loads this gem, but a script, a Rake task or a test helper may
# require the gem first, so it has to load everything of Rails it relies on itself.
RSpec.describe "require \"logtail-rails\"" do
  it "loads in a new Ruby process before anything else of Rails" do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-rbundler/setup", "-e", 'require "logtail-rails"; puts Logtail::Integrations::Rails.name')

    expect(status).to be_success, stderr
    expect(stdout).to eq("Logtail::Integrations::Rails\n")
  end
end
