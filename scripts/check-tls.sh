#!/usr/bin/env bash
# check-tls.sh -- verify the TLS handshake and leaf certificate for a domain.
#
# Split out from verify-deploy.sh because the same check answers two different
# questions, and only one of them is about deploying:
#
#   deploy-time   verify-deploy.sh calls this after /health settles, so a deploy
#                 that breaks TLS fails loudly instead of passing on HTTP probes.
#   ongoing       run it from cron. A vhost can disappear from the proxy without
#                 anything here changing -- editing a *different* site's Caddy
#                 config is enough (Caddy v2 does not auto-load conf.d/ the way
#                 nginx loads sites-enabled/). That is exactly what happened on
#                 2026-07-05: ~2.5h of failed handshakes, found by a user report.
#                 Nothing between deploys was watching.
#
# Usage: scripts/check-tls.sh [domain]
#   domain defaults to log.1mb.dev
#
# Env:
#   TLS_MIN_DAYS  fail when the leaf cert expires within N days (default 14)
#   TLS_TIMEOUT   per-connection timeout in seconds (default 10)
#
# Exit 0 only when the handshake completes, the chain verifies, the cert covers
# the requested name, and it is not expiring inside TLS_MIN_DAYS. Every failure
# names what was actually observed -- a red exit should be worth reading.
set -euo pipefail

DOMAIN="${1:-log.1mb.dev}"
TLS_MIN_DAYS="${TLS_MIN_DAYS:-14}"
TLS_TIMEOUT="${TLS_TIMEOUT:-10}"

fail() { echo "FAIL: $*"; exit 1; }

# GNU timeout is `timeout` on Linux and `gtimeout` (coreutils) on macOS, and is
# absent from a stock Mac. Fall back to running bare rather than refusing to
# check at all -- openssl is only reached after curl has proven the host answers.
run_capped() {
    local secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"
    else "$@"
    fi
}

# 1. Handshake + chain verification. curl is the portable way to get a bounded
#    timeout here, and its exit code distinguishes the failure modes that matter:
#    a dropped vhost (35) reads nothing like an expired cert (60) or dead DNS (6).
# `|| rc=$?` rather than `if ! curl ...` -- inside an `if !` branch $? holds the
# negation's status, not curl's, which silently flattens every case below to *).
rc=0
curl_err=$(curl -sS -o /dev/null --max-time "$TLS_TIMEOUT" "https://$DOMAIN/" 2>&1) || rc=$?
if [ "$rc" -ne 0 ]; then
    case "$rc" in
        6)     fail "DNS for $DOMAIN did not resolve (curl 6)" ;;
        7)     fail "connection to $DOMAIN:443 refused (curl 7)" ;;
        28)    fail "connection to $DOMAIN:443 timed out after ${TLS_TIMEOUT}s (curl 28)" ;;
        35)    fail "TLS handshake with $DOMAIN failed (curl 35) -- vhost missing from the proxy, or no cert for this name. ${curl_err}" ;;
        51|60) fail "certificate for $DOMAIN did not verify (curl $rc). ${curl_err}" ;;
        *)     fail "could not reach https://$DOMAIN/ (curl $rc). ${curl_err}" ;;
    esac
fi
echo "  ok  tls handshake"

# 2. Pull the leaf cert for the checks curl does not make: which names it covers,
#    and how long it has left.
cert=$(run_capped "$TLS_TIMEOUT" openssl s_client -connect "$DOMAIN:443" \
        -servername "$DOMAIN" </dev/null 2>/dev/null \
        | openssl x509 2>/dev/null) \
    || fail "could not read the certificate presented by $DOMAIN"
[ -n "$cert" ] || fail "could not read the certificate presented by $DOMAIN"

# 3. Name coverage. Mostly belt-and-braces: curl already rejects a cert that does
#    not cover the name, so this rarely fires on its own. It earns its keep by
#    printing the served names, which is what tells a vhost mixup (a multi-SAN
#    cert legitimately covering both sites) apart from a correct config.
names=$(printf '%s\n' "$cert" | openssl x509 -noout -ext subjectAltName 2>/dev/null \
        | tr -d ' ' | tr ',' '\n' | sed -n 's/^DNS://p')
matched=0
while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$name" = "$DOMAIN" ]; then matched=1; break; fi
    # Wildcards cover exactly one label: *.example.com matches a.example.com.
    case "$name" in
        \*.*) [ "${DOMAIN#*.}" = "${name#\*.}" ] && [ "${DOMAIN%%.*}" != "$DOMAIN" ] && { matched=1; break; } ;;
    esac
done <<< "$names"
[ "$matched" = "1" ] || fail "certificate for $DOMAIN covers [$(echo "$names" | tr '\n' ' ' | sed 's/ $//')] -- not $DOMAIN"
echo "  ok  tls cert covers $DOMAIN"

# 4. Expiry. Let's Encrypt renews at 30 days left, so 14 means renewal has had
#    two weeks to work and has not. That is a real problem, not a countdown.
expires=$(printf '%s\n' "$cert" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
if ! printf '%s\n' "$cert" | openssl x509 -noout -checkend $(( TLS_MIN_DAYS * 86400 )) >/dev/null 2>&1; then
    fail "certificate for $DOMAIN expires within ${TLS_MIN_DAYS}d (notAfter: ${expires:-unknown}) -- renewal is not working"
fi
echo "  ok  tls cert valid past ${TLS_MIN_DAYS}d (notAfter: ${expires:-unknown})"
