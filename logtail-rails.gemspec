lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "logtail-rails/version"

Gem::Specification.new do |spec|
  spec.name = "logtail-rails"
  spec.version = Logtail::Integrations::Rails::VERSION
  spec.authors = ["Better Stack"]
  spec.email = ["hello@betterstack.com"]

  spec.summary = %q{Better Stack Rails integration}
  spec.homepage = "https://github.com/logtail/logtail-ruby-rails"
  spec.license = "ISC"

  spec.required_ruby_version = '>= 2.5.0'

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/logtail/logtail-ruby-rails"
  spec.metadata["changelog_uri"] = "https://github.com/logtail/logtail-ruby-rails/blob/main/README.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "logtail", "~> 0.1", ">= 0.1.14"
  spec.add_runtime_dependency "logtail-rack", "~> 0.1"

  spec.add_runtime_dependency 'activerecord', '>= 5.0.0'
  spec.add_runtime_dependency 'railties', '>= 5.0.0'
  spec.add_runtime_dependency 'actionpack', '>= 5.0.0'

  spec.add_development_dependency "bundler", ">= 0.0"

  spec.add_development_dependency "rake", ">= 0.8"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_development_dependency "benchmark", ">= 0"
  spec.add_development_dependency "bundler-audit", ">= 0"
  spec.add_development_dependency "rails_stdout_logging", ">= 0"
  spec.add_development_dependency "rspec-its", ">= 0"
  spec.add_development_dependency "timecop", ">= 0"
  spec.add_development_dependency "webmock", "~> 2.3"

  rails_version = 0
  if ENV.key?('RAILS_VERSION')
    rails_version = ENV['RAILS_VERSION'].to_f
  elsif ENV.key?('BUNDLE_GEMFILE')
    matches = File.basename(ENV['BUNDLE_GEMFILE'], '.gemfile').match(/-([0-9.]+)\z/)
    rails_version = matches[1].to_f if matches
  end

  if RUBY_PLATFORM == "java"
    spec.add_development_dependency('activerecord-jdbcsqlite3-adapter', '>= 0')
  elsif rails_version >= 3 && rails_version < 6
    spec.add_development_dependency('sqlite3', '1.3.13')
  else
    spec.add_development_dependency('sqlite3', '~> 1.5.0')
  end
end
