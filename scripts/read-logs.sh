#!/usr/bin/env bash
# read-logs.sh -- on-demand access-log report via journalctl + goaccess.
#
# Server-side hygiene, not analytics. No reader-side beacon ships from
# log.1mb.dev (handoff F8). This pulls Caddy's access log over ssh and
# renders a one-shot HTML report on the operator's machine. Throw-away
# output -- no dashboard runs on the VPS.
#
# Usage:
#   scripts/read-logs.sh                     last hour (default)
#   scripts/read-logs.sh "24 hours ago"      last day
#   scripts/read-logs.sh "2026-05-15"        since a date
#
# Config (read from .env.local if present, then shell env):
#   LOG_HOST=user@host.example  ssh target (required, no default -- never root)
#   LOG_UNIT=caddy              systemd unit (default: caddy)
#   LOG_VHOST=log.1mb.dev       filter to this vhost only (optional)
#
# LOG_VHOST is important when Caddy hosts multiple sites: the systemd
# journal carries the whole unit's stderr, so unfiltered output mixes
# every vhost's access log. When set, the JSON stream is piped through
# `jq` to keep only entries where `.request.host == $LOG_VHOST`.
#
# The ssh user must be a non-root system account with read access to the
# unit's journal -- typically by membership in the `systemd-journal` group
# on the VPS (`sudo usermod -aG systemd-journal <user>` once, then relogin).
# See docs/deployment.md for the one-time setup.
#
# Requires goaccess on $PATH (`brew install goaccess` on macOS). The remote
# query is read-only -- `journalctl -u <unit>` with no side effects.
#
# Log format: targets Caddy v2's default JSON access log via
# `--log-format=CADDY`. If a forker's Caddy emits a different shape and
# this produces an empty / unparseable report, two fallback paths:
#   1. Reconfigure Caddy to emit Common Log Format (set `format console`
#      or use `transform`), switch to `--log-format=COMBINED` below.
#   2. Preprocess the JSON stream through jq into a goaccess-friendly
#      shape, then pipe to goaccess with a custom `--log-format` string.
# Caddy's log shape isn't a stable contract across versions; document
# the workaround inline if you have to switch.

set -euo pipefail

# Source .env.local for operator-only config (LOG_HOST, etc.). Gitignored
# via the existing .env.* pattern -- keep maintainer-machine settings here,
# not in .env (which gets rsync'd to the VPS by `make deploy`).
if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env.local
  set +a
fi

SINCE="${1:-1 hour ago}"
HOST="${LOG_HOST:-}"
UNIT="${LOG_UNIT:-caddy}"
VHOST="${LOG_VHOST:-}"
OUT="/tmp/log-1mb-dev-stats-$(date +%Y%m%d-%H%M%S).html"

if [ -z "$HOST" ]; then
  cat >&2 <<EOF
LOG_HOST is not set. Configure in .env.local:

  LOG_HOST=loguser@log.1mb.dev

The user must be non-root and in the systemd-journal group on the VPS.
See docs/deployment.md (Reading access logs) for the one-time setup.
EOF
  exit 1
fi

command -v goaccess >/dev/null 2>&1 || {
  echo "goaccess not on \$PATH"
  echo "install: brew install goaccess"
  exit 1
}
command -v ssh >/dev/null 2>&1 || {
  echo "ssh not on \$PATH"
  exit 1
}

if [ -n "$VHOST" ]; then
  command -v jq >/dev/null 2>&1 || {
    echo "LOG_VHOST set but jq not on \$PATH (needed for vhost filtering)"
    echo "install: brew install jq"
    exit 1
  }
fi

label="$HOST"
[ -n "$VHOST" ] && label="$VHOST"
echo "reading $UNIT logs from $HOST since '$SINCE'${VHOST:+ (vhost: $VHOST)}"

# shellcheck disable=SC2029  # SINCE/UNIT are operator-controlled; client-side expansion is intentional
stream() {
  ssh "$HOST" "journalctl -u $UNIT --since '$SINCE' --no-pager -o cat"
}

if [ -n "$VHOST" ]; then
  # -R reads raw lines; `fromjson? // empty` drops non-JSON noise (caddy
  # mixes startup/info text into the same stderr stream as access-log JSON).
  stream | jq -Rcr --arg h "$VHOST" 'fromjson? // empty | select(.request.host == $h)'
else
  stream
fi | goaccess - \
      --log-format=CADDY \
      --html-report-title="$label -- since $SINCE" \
      -o "$OUT"

echo "report: $OUT"

if command -v open >/dev/null 2>&1; then
  open "$OUT"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$OUT"
fi
