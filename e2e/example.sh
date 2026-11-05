#!/usr/bin/env bash
# Installs or runs the example project (example-project/, a Rails app) the way its README tells a customer to, with the
# leg's Rails, logtail and logtail-rack versions. The output goes to out/<command>.log as well, and a failure ends with
# one ::error:: line giving the reason.
#   e2e/example.sh install   pins the leg's versions in the example's Gemfile and runs bundle install
#   e2e/example.sh run       starts bin/rails server, requests /send_logs and /raise_error, and stops the server with
#                            Ctrl-C (SIGINT); the logs go to BETTER_STACK_INGESTING_HOST with BETTER_STACK_SOURCE_TOKEN
# Env: RAILS (a release, or main with RAILS_REF the commit), SQLITE3 (a requirement, or empty for the Gemfile's own),
#      LOGTAIL and LOGTAIL_RACK (releases, or empty for whatever Bundler picks), CLIENT (the logtail-rails release; on
#      pushes and pull requests e2e.yml has installed the gem built from the checkout under that version).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/out
LOG=$OUT/$1.log
PORT=3000
mkdir -p "$OUT"
cd "$ROOT/example-project"

# Replaces gem $1's line in the Gemfile, or adds one, with the requirement $2.
pin() {
  sed -i.orig "/^gem \"$1\"/d" Gemfile && rm Gemfile.orig
  echo "gem \"$1\", $2" >> Gemfile
}

case "$1" in
  install)
    cp Gemfile "$OUT/Gemfile.example"
    if [ "$RAILS" = main ]; then pin rails "github: \"rails/rails\", ref: \"$RAILS_REF\""; else pin rails "\"= $RAILS\""; fi
    if [ -n "$SQLITE3" ]; then pin sqlite3 "\"$SQLITE3\""; fi
    # The example's Gemfile only names logtail-rails, logtail and logtail-rack come with it as its dependencies.
    if [ -n "$LOGTAIL" ]; then pin logtail "\"= $LOGTAIL\""; fi
    if [ -n "$LOGTAIL_RACK" ]; then pin logtail-rack "\"= $LOGTAIL_RACK\""; fi
    pin logtail-rails "\"= $CLIENT\""
    { diff -u "$OUT/Gemfile.example" Gemfile || true; } | tee "$LOG"
    bundle install 2>&1 | tee -a "$LOG" || {
      echo "::error::bundle install failed for Rails $RAILS${RAILS_REF:+ $RAILS_REF} on Ruby $(ruby -e 'print RUBY_VERSION'): $(grep -m 1 -iE 'could not|error|incompatible|requires' "$LOG" || tail -n 1 "$LOG")"
      exit 1
    } ;;
  run)
    bin/rails server -p "$PORT" > "$LOG" 2>&1 &
    SERVER=$!
    # Up when it accepts connections. Polling a page instead would log requests of its own.
    for _ in $(seq 120); do
      if (: > "/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then break; fi
      kill -0 "$SERVER" 2>/dev/null || { cat "$LOG"; echo "::error::bin/rails server exited before it listened: $(tail -n 1 "$LOG")"; exit 1; }
      sleep 1
    done
    FAILED=""
    SEND_LOGS=$(curl -sS -m 30 -o "$OUT/send_logs.html" -w '%{http_code}' "http://127.0.0.1:$PORT/send_logs") || SEND_LOGS=000
    [ "$SEND_LOGS" = 200 ] || FAILED="GET /send_logs answered HTTP $SEND_LOGS, not 200"
    # The action raises, Rails answers with its error page.
    RAISE_ERROR=$(curl -sS -m 30 -o "$OUT/raise_error.html" -w '%{http_code}' "http://127.0.0.1:$PORT/raise_error") || RAISE_ERROR=000
    [ "$RAISE_ERROR" = 500 ] || FAILED="${FAILED:+$FAILED, }GET /raise_error answered HTTP $RAISE_ERROR, not 500"
    # Ctrl-C, as a customer stops it. Puma stops gracefully and the HTTP log device sends what is still buffered
    # when the process exits.
    kill -INT "$SERVER"
    STATUS=0
    wait "$SERVER" || STATUS=$?
    cat "$LOG"
    [ "$STATUS" = 0 ] || FAILED="${FAILED:+$FAILED, }bin/rails server exited with $STATUS after Ctrl-C"
    # The gem warns on stderr about a blank source token and about batches Better Stack rejected.
    if grep -q '^Logtail: ' "$LOG"; then FAILED="${FAILED:+$FAILED, }$(grep -m 1 '^Logtail: ' "$LOG")"; fi
    if [ -n "$FAILED" ]; then echo "::error::The example project failed: $FAILED"; exit 1; fi ;;
  *) echo "::error::unknown command $1"; exit 1 ;;
esac
