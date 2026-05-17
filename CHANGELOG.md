# Changelog

Deploy and configuration changes for this deployment of markgo. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Deployed

- 2026-05-15 — reference deployment live at `log.1mb.dev`. Pinned markgo `v3.7.0-7-gc3a0643` running as `loguser` on a shared Debian 13 VPS, fronted by Caddy with auto-TLS via Let's Encrypt.
- 2026-05-16 — `v3.8.0` shipped. Admin JSON paths (`/admin/drafts`, `/admin/stats`, `/admin/ama`) return `401`; HEAD parity verified against `/`, `/feed.xml`, `/robots.txt`, `/sitemap.xml`.
- 2026-05-16 (later) — `v3.9.0` shipped. `<meta name="application-name">` = `1mb` and `<meta name="markgo-storage-namespace">` = `markgo:log-1mb-dev` verified live; client storage namespaced per blog with auto-migration of v3.8 keys.
- 2026-05-17 — `v3.10.1` shipped. Banner support, server-absolute banner paths, and color-preset dark-mode AA contrast available.
- 2026-05-17 (later) — banner essays imported. Added Caddy `handle /static/img/banners/*` block to overlay the banners path from the deploy tree; embedded `/static/*` continues to serve from markgo. Filed [`1mb-dev/markgo#59`](https://github.com/1mb-dev/markgo/issues/59) for `STATIC_PATH` overlay mode upstream; remove the Caddy block when it lands.

### Added

- Repository scaffold: LICENSE, LICENSE-CONTENT.md, .editorconfig, directory layout, Makefile, deploy templates, .env.example, deployment guide stub.
- `scripts/verify-deploy.sh` — smoke-test runner (health, feed, sitemap, robots, manifest, HSTS). Uses GET (not HEAD) so it doesn't hide markgo's HEAD-routing quirk.
- `make deploy` — idempotent push of binary + content + .env, systemd unit install with templated `User`/paths/`SyslogIdentifier`, restart, then verify.
- `make verify` — standalone smoke-test against `DOMAIN`.
- Demo-corpus stance excludes meta-artifacts: `banner-sources/` removed; HTML mockups live in author repo.

### Fixed

- `.env.example`: default `STATIC_PATH=` (empty) instead of `./static`. Markgo's static handler is exclusive, not overlay — setting `STATIC_PATH=./static` without populating the directory 404s every asset.

### Fixed upstream (markgo v3.8.0)

- [`1mb-dev/markgo#42`](https://github.com/1mb-dev/markgo/issues/42) — admin JSON endpoints no longer bypass `SoftSessionAuth`. Verified against this deploy.
- [`1mb-dev/markgo#43`](https://github.com/1mb-dev/markgo/issues/43) — `HEAD` requests now mirror GET status codes. Verified against this deploy.

### Fixed upstream (markgo v3.9.0)

- [`1mb-dev/markgo#48`](https://github.com/1mb-dev/markgo/issues/48) — engine-name personalization. Install banner, contact/test email subjects, and client storage (`localStorage` + `IndexedDB`) now use `Blog.Title` / per-blog namespace instead of hardcoded `markgo`. Verified against this deploy.

### Fixed upstream (markgo v3.10.0 + v3.10.1)

- [`1mb-dev/markgo#51`](https://github.com/1mb-dev/markgo/issues/51) — per-article banner image (frontmatter `banner` + `banner_alt`, essay-only renderer, OG/Twitter card override). Shipped in v3.10.0.
- [`1mb-dev/markgo#54`](https://github.com/1mb-dev/markgo/issues/54) — banner field accepts server-absolute paths (`/static/img/banners/<slug>.png`) in addition to absolute URLs and slug-relative uploads. Lets editorial banners ship as source-controlled assets without coupling frontmatter to `BASE_URL`. Shipped in v3.10.1.
- [`1mb-dev/markgo#56`](https://github.com/1mb-dev/markgo/issues/56) — color preset dark-mode AA contrast (ocean/forest/sunset) + live preview on swatch hover/focus. Shipped in v3.10.1.

### Known issues (upstream, tracked)

- [`1mb-dev/markgo#44`](https://github.com/1mb-dev/markgo/issues/44) — AMA submission filename uses `thought-` prefix instead of `ama-`. Cosmetic; moderation and rendering unaffected. Fix shipped in v3.8.0; pending live re-verification on next AMA submission.

### Notes

- markgo target version: `v3.10.1` (banner feature + theme contrast over the v3.9.0 personalization baseline).
- Reference deployment binds markgo to `127.0.0.1:3001` (configured via `PORT` in `.env`) to coexist with other services on the same host.
- AMA spam protection is **math captcha + honeypot + `RATE_LIMIT_CONTACT_*`** (not CSRF, contrary to early documentation).
- RAM is tight on small VPSes (the reference deploy has 464 MiB total; markgo resident ~13-15 MiB). Drop `CACHE_MAX_SIZE` in `.env` if pressure surfaces.
- Markgo has no `FEATURES_*` config envelope — feature availability is gated per-feature (e.g., AMA + `/compose` require `ADMIN_*` + compose service; contact form requires `EMAIL_HOST`; SEO sub-features are individual `SEO_*` booleans).
