#!/usr/bin/env bash
# verify-deploy.sh -- smoke-test a markgo deployment.
#
# Usage: scripts/verify-deploy.sh [domain]
#   domain defaults to log.1mb.dev
#
# Waits for /health to settle (markgo takes a moment to bind after a restart),
# then probes the discovery endpoints. Every failure reports the HTTP status it
# actually saw, so a slow start and a broken deploy never look alike.
#
# Tunable via env for slower hosts:
#   HEALTH_ATTEMPTS  number of /health tries before giving up (default 5)
#   HEALTH_TIMEOUT   per-request timeout in seconds (default 10)
set -euo pipefail

DOMAIN="${1:-log.1mb.dev}"
BASE="https://$DOMAIN"
HEALTH_ATTEMPTS="${HEALTH_ATTEMPTS:-5}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-10}"

# HTTP status, or 000 when the connection never completed (DNS, refused, timeout).
status_of() {
  local path="$1"
  curl -sS -o /dev/null -w '%{http_code}' --max-time "$HEALTH_TIMEOUT" "$BASE$path" 2>/dev/null || true
}

check() {
  local path="$1" label="$2" code
  code="$(status_of "$path")"
  [ "$code" = "200" ] || { echo "FAIL: $label ($path) -- HTTP $code"; exit 1; }
  echo "  ok  $label"
}

# Restart-settle retry. Only "not up yet" statuses are worth a retry: 000 (nothing
# listening behind the proxy) and the gateway 5xx family. Anything else -- a 404,
# an app-level 500 -- means the process is answering and misconfigured, so fail
# immediately rather than burning the full backoff on a verdict that will not change.
wait_for_health() {
  local attempt=1 code
  while :; do
    code="$(status_of /health)"
    if [ "$code" = "200" ]; then
      if [ "$attempt" -gt 1 ]; then
        echo "  ok  health (settled on attempt $attempt)"
      else
        echo "  ok  health"
      fi
      return 0
    fi

    case "$code" in
      000|502|503|504) ;;
      *) echo "FAIL: health (/health) -- HTTP $code"; exit 1 ;;
    esac

    if [ "$attempt" -ge "$HEALTH_ATTEMPTS" ]; then
      echo "FAIL: health (/health) -- HTTP $code after $HEALTH_ATTEMPTS attempts"
      exit 1
    fi

    echo "  ..  health not ready (HTTP $code), retrying in ${attempt}s"
    sleep "$attempt"
    attempt=$((attempt + 1))
  done
}

echo "verifying $BASE"

# Health endpoint -- markgo's own readiness probe, and the restart gate
wait_for_health

# Discovery endpoints
check /feed.xml "rss feed"
check /sitemap.xml "sitemap"
check /robots.txt "robots"
check /manifest.json "pwa manifest"

# HSTS header presence (without depending on response code semantics)
if ! curl -fsS -D - -o /dev/null "$BASE/" | grep -qi '^strict-transport-security:'; then
  echo "FAIL: HSTS header missing on /"
  exit 1
fi
echo "  ok  hsts header"

# TLS handshake + certificate. The probes above all ride HTTPS, so a broken
# handshake would already have failed them -- this adds the checks they cannot
# make (which names the cert covers, how long it has left) and reports the
# specific failure instead of a bare curl error. Run it standalone from cron to
# catch a vhost dropping out between deploys; see docs/deployment.md.
"$(dirname "$0")/check-tls.sh" "$DOMAIN"

echo "ok: $DOMAIN"
