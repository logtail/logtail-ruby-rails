# Prints the running Ruby and what the example's bundle resolved, as name=value lines for e2e.yml's version check.
# Run with bundle exec from example-project/.
rails = Gem.loaded_specs.fetch("rails")
client = Gem.loaded_specs.fetch("logtail-rails")
{
  "ruby" => RUBY_VERSION,
  "ruby_description" => RUBY_DESCRIPTION,
  # ruby-head reports the next version with patch level -1
  "ruby_dev" => RUBY_PATCHLEVEL == -1,
  "rails" => rails.version,
  # The commit of a Rails from GitHub, empty for a release
  "rails_ref" => Bundler.locked_gems.specs.find { |spec| spec.name == "rails" }.source.options["revision"],
  "logtail" => Gem.loaded_specs.fetch("logtail").version,
  "logtail_rack" => Gem.loaded_specs.fetch("logtail-rack").version,
  "sqlite3" => Gem.loaded_specs.fetch("sqlite3").version,
  "client" => client.version,
  "client_dir" => client.full_gem_path,
  # The .gem file RubyGems installed it from, kept in its cache
  "client_gem" => client.cache_file,
}.each { |name, value| puts "#{name}=#{value}" }
