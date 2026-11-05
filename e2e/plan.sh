#!/usr/bin/env bash
# Plans the E2E matrix: one job per leg, with the Ruby and the Rails, logtail and logtail-rack versions the leg runs the
# example project (example-project/, a Rails app) with. Prints the matrix as a JSON array, the include list of the test
# job in e2e.yml.
#   floor   the oldest Rails the example runs on (its config.load_defaults) at that line's newest patch, on the oldest
#           Ruby both that Rails release and logtail-rails.gemspec allow, with logtail and logtail-rack at the gemspec's
#           floors
#   rails7  the newest Rails 7 release on Ruby 3.2 with the newest logtail and logtail-rack: the step between the
#           floor and the newest Rails
#   latest  the newest stable Ruby (endoflife.date) with the newest Rails, logtail and logtail-rack releases
#   canary  ruby-head with the current commit of Rails' main branch, and whatever logtail and logtail-rack Bundler picks
# Env: LEG (all, floor, rails7, latest or canary), CLIENT_FROM (checkout or rubygems), and RUBY_VERSION_INPUT and
#      RAILS_VERSION_INPUT: an exact Ruby, and an exact Rails release or a commit of Rails' main branch, that replace the
#      planned ones in every leg.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUBYGEMS=https://rubygems.org/api/v1
# Job names become artifact names (e2e-summary-<job name>), which must not contain any of these.
NOT_IN_NAMES='[:"<>|*?/\\]'

# A registry hiccup at schedule time should not file a Linear issue, so every lookup is retried.
get() { curl -fsS -m 60 --retry 3 --retry-delay 10 "$1"; }
# The newest release of gem $1: rubygems.org's "version" is the highest version that is not a pre-release.
newest() { get "$RUBYGEMS/gems/$1.json" | jq -er .version; }
# The X.Y.Z of gem $1's ">= X.Y.Z" in logtail-rails.gemspec.
gemspec_floor() { sed -n "s/.*add_runtime_dependency \"$1\", .*\">= \([0-9.]*\)\".*/\1/p" "$ROOT/logtail-rails.gemspec"; }
# The X.Y of a ">= X.Y.Z" requirement.
minor_of() { sed -n 's/^>= *\([0-9]*\.[0-9]*\).*/\1/p' <<<"$1"; }
# The higher of two versions.
higher() { printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1; }

RAILS_VERSIONS=$(get "$RUBYGEMS/versions/rails.json")
# The newest release of Rails line $1 (7.0, or 7 for all of Rails 7).
newest_rails_of() {
  jq -er --arg line "$1." '[.[] | select(.prerelease | not) | .number | select(startswith($line))]
    | sort_by(split(".") | map(tonumber)) | last // empty' <<<"$RAILS_VERSIONS"
}

# The client the example installs: the gem built from the checkout, or the newest release on rubygems.org.
if [ "${CLIENT_FROM:-checkout}" = rubygems ]; then
  CLIENT=$(newest logtail-rails)
else
  CLIENT=$(sed -n 's/.*VERSION = "\(.*\)".*/\1/p' "$ROOT/lib/logtail-rails/version.rb")
fi

LEGS=$([ "${LEG:-all}" = all ] && echo "floor rails7 latest canary" || echo "$LEG")
MATRIX='[]'
for leg in $LEGS; do
  rails_ref=""
  case "$leg" in
    floor)
      # The example's config.load_defaults names the oldest Rails it boots on: older releases reject that version.
      rails=$(newest_rails_of "$(sed -n 's/^ *config\.load_defaults \([0-9.]*\).*/\1/p' "$ROOT/example-project/config/application.rb")")
      gem_ruby=$(minor_of "$(sed -n "s/.*required_ruby_version = '\(.*\)'.*/\1/p" "$ROOT/logtail-rails.gemspec")")
      rails_ruby=$(minor_of "$(jq -r --arg rails "$rails" '.[] | select(.number == $rails) | .ruby_version' <<<"$RAILS_VERSIONS")")
      ruby=$(higher "$gem_ruby" "$rails_ruby")
      logtail=$(gemspec_floor logtail)
      logtail_rack=$(gemspec_floor logtail-rack) ;;
    rails7)
      ruby=3.2
      rails=$(newest_rails_of 7)
      logtail=$(newest logtail)
      logtail_rack=$(newest logtail-rack) ;;
    latest)
      ruby=$(get https://endoflife.date/api/ruby.json | jq -er 'max_by(.cycle | split(".") | map(tonumber)) | .latest')
      rails=$(newest rails)
      logtail=$(newest logtail)
      logtail_rack=$(newest logtail-rack) ;;
    canary)
      ruby=head
      rails=main
      rails_ref=$(git ls-remote https://github.com/rails/rails.git refs/heads/main | cut -f 1)
      logtail=""
      logtail_rack="" ;;
    *) echo "unknown leg $leg" >&2; exit 1 ;;
  esac
  ruby=${RUBY_VERSION_INPUT:-$ruby}
  if [[ "${RAILS_VERSION_INPUT:-}" =~ ^[0-9a-f]{7,40}$ ]]; then
    rails=main
    rails_ref=$RAILS_VERSION_INPUT
  elif [ -n "${RAILS_VERSION_INPUT:-}" ]; then
    rails=$RAILS_VERSION_INPUT
    rails_ref=""
  fi
  for value in "$ruby" "$rails" "$CLIENT"; do
    [ -n "$value" ] || { echo "the $leg leg could not be planned: ruby '$ruby', rails '$rails', client '$CLIENT'" >&2; exit 1; }
  done
  [ "$rails" != main ] || [ -n "$rails_ref" ] || { echo "no commit found on Rails' main branch" >&2; exit 1; }
  # Rails 7.0 and 7.1's sqlite3 adapter requires sqlite3 ~> 1.4, while the example's Gemfile asks for 2.x.
  sqlite3=""
  if [ "$rails" != main ] && [ "$(higher "$rails" 7.2)" != "$rails" ]; then sqlite3="~> 1.4"; fi

  MATRIX=$(jq -c --arg leg "$leg" --arg ruby "$ruby" --arg rails "$rails" --arg rails_ref "$rails_ref" --arg sqlite3 "$sqlite3" \
    --arg logtail "$logtail" --arg logtail_rack "$logtail_rack" --arg source "${CLIENT_FROM:-checkout}" --arg client "$CLIENT" '. + [{
      name: "\($leg) (Ruby \($ruby), Rails \(if $rails == "main" then "main " + $rails_ref[0:7] else $rails end), \(
        if $logtail == "" then "newest logtail and logtail-rack" else "logtail \($logtail), logtail-rack \($logtail_rack)" end))",
      leg: $leg, ruby: $ruby, rails: $rails, rails_ref: $rails_ref, sqlite3: $sqlite3,
      logtail: $logtail, logtail_rack: $logtail_rack, source: $source, client: $client,
      # The floor and the Rails 7 leg run on the oldest Ubuntu image GitHub offers, the other legs follow ubuntu-latest.
      runner: (if $leg == "floor" or $leg == "rails7" then "ubuntu-24.04" else "ubuntu-latest" end)
    }]' <<<"$MATRIX")
done
if jq -e --arg not "$NOT_IN_NAMES" 'any(.[]; .name | test($not))' <<<"$MATRIX" >/dev/null; then
  echo "a job name contains one of $NOT_IN_NAMES, which artifact names do not allow: $(jq -c 'map(.name)' <<<"$MATRIX")" >&2
  exit 1
fi
echo "$MATRIX"
