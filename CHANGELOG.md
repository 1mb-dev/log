# Changelog

Deploy and configuration changes for this deployment of markgo. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Deployed

- 2026-05-15 — reference deployment live at `log.1mb.dev`. Pinned markgo `v3.7.0-7-gc3a0643` running as `loguser` on a shared Debian 13 VPS, fronted by Caddy with auto-TLS via Let's Encrypt.

### Added

- Repository scaffold: LICENSE, LICENSE-CONTENT.md, .editorconfig, directory layout, Makefile, deploy templates, .env.example, deployment guide stub.
- `scripts/verify-deploy.sh` — smoke-test runner (health, feed, sitemap, robots, manifest, HSTS). Uses GET (not HEAD) so it doesn't hide markgo's HEAD-routing quirk.
- `make deploy` — idempotent push of binary + content + .env, systemd unit install with templated `User`/paths/`SyslogIdentifier`, restart, then verify.
- `make verify` — standalone smoke-test against `DOMAIN`.

### Fixed

- `.env.example`: default `STATIC_PATH=` (empty) instead of `./static`. Markgo's static handler is exclusive, not overlay — setting `STATIC_PATH=./static` without populating the directory 404s every asset. Trap for forkers.

### Notes

- markgo target version: `v3.7.0` (first release with the AMA content type).
- Reference deployment binds markgo to `127.0.0.1:3001` (configured via `PORT` in `.env`) to coexist with other services on the same host.
- AMA spam protection is **math captcha + honeypot + `RATE_LIMIT_CONTACT_*`** (not CSRF, contrary to early documentation).
- Markgo's gin routes are registered as `.GET()` only; `HEAD` requests fall through to `NoRoute` → 404. Set uptime monitors to GET probes. Upstream fix planned.
- RAM is tight on small VPSes (the reference deploy has 464 MiB total; markgo resident ~13-15 MiB). Drop `CACHE_MAX_SIZE` in `.env` if pressure surfaces.
- Markgo has no `FEATURES_*` config envelope — feature availability is gated per-feature (e.g., AMA + `/compose` require `ADMIN_*` + compose service; contact form requires `EMAIL_HOST`; SEO sub-features are individual `SEO_*` booleans).
