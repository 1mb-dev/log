#!/usr/bin/env bash
# verify-deploy.sh -- smoke-test a markgo deployment.
#
# Usage: scripts/verify-deploy.sh [domain]
#   domain defaults to log.1mb.dev
#
# Exits non-zero on the first failure -- curl's -f makes any 4xx/5xx
# response fatal on the first probed endpoint.
set -euo pipefail

DOMAIN="${1:-log.1mb.dev}"
BASE="https://$DOMAIN"

check() {
  local path="$1" label="$2"
  curl -fsS -o /dev/null "$BASE$path" || { echo "FAIL: $label ($path)"; exit 1; }
  echo "  ok  $label"
}

echo "verifying $BASE"

# Health endpoint -- markgo's own readiness probe
check /health "health"

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

echo "ok: $DOMAIN"
