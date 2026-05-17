# Changelog

Deploy and configuration changes for this deployment of markgo. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Deployed

- 2026-05-15 — reference deployment live at `log.1mb.dev`. Pinned markgo `v3.7.0-7-gc3a0643` running as `loguser` on a shared Debian 13 VPS, fronted by Caddy with auto-TLS via Let's Encrypt.
- 2026-05-16 — `v3.8.0` shipped. Admin JSON paths (`/admin/drafts`, `/admin/stats`, `/admin/ama`) return `401`; HEAD parity verified against `/`, `/feed.xml`, `/robots.txt`, `/sitemap.xml`.
- 2026-05-16 (later) — `v3.9.0` shipped. `<meta name="application-name">` = `1mb` and `<meta name="markgo-storage-namespace">` = `markgo:log-1mb-dev` verified live; client storage namespaced per blog with auto-migration of v3.8 keys.
- 2026-05-17 — `v3.10.1` shipped. Banner support, server-absolute banner paths, and color-preset dark-mode AA contrast available.
- 2026-05-17 (later) — banner essays imported. Added Caddy `handle /static/img/banners/*` block to overlay the banners path from the deploy tree; embedded `/static/*` continues to serve from markgo. Filed [`1mb-dev/markgo#59`](https://github.com/1mb-dev/markgo/issues/59) for `STATIC_PATH` overlay mode upstream; remove the Caddy block when it lands.
- 2026-05-17 (M3) — `v3.10.2` shipped with `STATIC_PATH` overlay (filesystem-first, embedded fallback). Caddy banner-overlay handle dropped; markgo overlay now serves source-controlled assets natively. CSP header active (`frame-ancestors 'none'`, `form-action 'self'`, `base-uri 'self'`), duplicate `Referrer-Policy` and `X-Content-Type-Options` removed from Caddy (markgo authoritative). Brand layer live: `1.` favicon set, `1.log` OG default, Space Mono self-hosted, dark-default theme with muted-blue accent overriding embedded `themes/minimal.css`.
- 2026-05-17 (M3-polish-1) — `v3.11.0` shipped. Operator-voiced AMA copy via 5 env vars (markgo#63 closed). Theme renamed to `/static/css/themes/1mb.css` with `BLOG_STYLE=1mb` (markgo#64 closed in v3.10.3 relaxed `BLOG_STYLE` validation). Live verified: AMA overlay renders `Ask anything` heading and the rest of the 1mb-voiced copy; Lighthouse holds 100/100/100/100.

### Added

- Repository scaffold: LICENSE, LICENSE-CONTENT.md, .editorconfig, directory layout, Makefile, deploy templates, .env.example, deployment guide stub.
- `scripts/verify-deploy.sh` — smoke-test runner (health, feed, sitemap, robots, manifest, HSTS). Uses GET (not HEAD) so it doesn't hide markgo's HEAD-routing quirk.
- `make deploy` — idempotent push of binary + content + .env, systemd unit install with templated `User`/paths/`SyslogIdentifier`, restart, then verify.
- `make verify` — standalone smoke-test against `DOMAIN`.
- Demo-corpus stance excludes meta-artifacts: `banner-sources/` removed; HTML mockups live in author repo.
- M3 brand layer: `static/img/favicon{.svg,-32x32.png}`, `static/img/apple-touch-icon.png`, `static/og-default.png`, `static/css/themes/minimal.css` (1mb tokens overriding markgo's embedded), `static/css/fonts.css` (Space Mono replacing Inter + Fira Code), `static/fonts/space-mono/` woff2 (latin subset, 400 + 700).
- Caddy CSP + `frame-ancestors 'none'`, `form-action 'self'`, `base-uri 'self'` in `deploy/Caddyfile.example`.
- Operator-voiced AMA copy via 5 env vars (`AMA_PAGE_HEADING`, `AMA_PAGE_INTRO`, `AMA_FORM_PLACEHOLDER`, `AMA_SUBMIT_LABEL`, `AMA_THANKYOU_COPY`). Heading reads `Ask anything`; intro carries selectivity stance.
- Theme file renamed `themes/minimal.css` → `themes/1mb.css` with `BLOG_STYLE=1mb`. v3.10.3 relaxed the `BLOG_STYLE` allowlist so the theme can stand on its own name; forkers see the override at a glance instead of riding on `minimal`.
- `.gitignore`: any `.env.*` (except `.env.example`) — covers backup `.env.pre-*` files made before live edits.
- `scripts/read-logs.sh` — operator-side log reader. SSH to the VPS, stream the Caddy systemd unit's journal, `jq`-filter by `LOG_VHOST` (Caddy aggregates all vhosts onto one stderr stream), pipe to `goaccess --log-format=CADDY`, render one-shot HTML locally. Server-side hygiene only — no service runs on the VPS, no beacon ships from the site. Config via `.env.local` (`LOG_HOST=user@host`, `LOG_VHOST=domain`).
- `docs/deployment.md` — Reading access logs section. Covers VPS-side operator-user provisioning (login shell, `systemd-journal` group membership, `.ssh/authorized_keys`, sshd `AllowUsers` widening when hardened) and operator-side `.env.local` config.

### Fixed

- `.env.example`: default `STATIC_PATH=` (empty) instead of `./static`. Markgo's static handler is exclusive, not overlay — setting `STATIC_PATH=./static` without populating the directory 404s every asset.

### Fixed upstream (markgo v3.8.0)

- [`1mb-dev/markgo#42`](https://github.com/1mb-dev/markgo/issues/42) — admin JSON endpoints no longer bypass `SoftSessionAuth`. Verified against this deploy.
- [`1mb-dev/markgo#43`](https://github.com/1mb-dev/markgo/issues/43) — `HEAD` requests now mirror GET status codes. Verified against this deploy.

### Fixed upstream (markgo v3.9.0)

- [`1mb-dev/markgo#48`](https://github.com/1mb-dev/markgo/issues/48) — engine-name personalization. Install banner, contact/test email subjects, and client storage (`localStorage` + `IndexedDB`) now use `Blog.Title` / per-blog namespace instead of hardcoded `markgo`. Verified against this deploy.

### Fixed upstream (markgo v3.10.0 + v3.10.1 + v3.10.2)

- [`1mb-dev/markgo#51`](https://github.com/1mb-dev/markgo/issues/51) — per-article banner image (frontmatter `banner` + `banner_alt`, essay-only renderer, OG/Twitter card override). Shipped in v3.10.0.
- [`1mb-dev/markgo#54`](https://github.com/1mb-dev/markgo/issues/54) — banner field accepts server-absolute paths (`/static/img/banners/<slug>.png`) in addition to absolute URLs and slug-relative uploads. Lets editorial banners ship as source-controlled assets without coupling frontmatter to `BASE_URL`. Shipped in v3.10.1.
- [`1mb-dev/markgo#56`](https://github.com/1mb-dev/markgo/issues/56) — color preset dark-mode AA contrast (ocean/forest/sunset) + live preview on swatch hover/focus. Shipped in v3.10.1.
- [`1mb-dev/markgo#59`](https://github.com/1mb-dev/markgo/issues/59) — `STATIC_PATH` overlay mode (filesystem-first, embedded fallback). Source-controlled assets no longer require mirroring markgo's full `web/static/` tree. Shipped in v3.10.2.

### Fixed upstream (markgo v3.10.3)

- [`1mb-dev/markgo#64`](https://github.com/1mb-dev/markgo/issues/64) — `BLOG_STYLE` validation relaxed; accepts any non-empty value. Unblocks custom theme names via `STATIC_PATH` overlay without source-modifying markgo.
- Periodic cleanup pass closing 11 v3.7.0→v3.10.2 review findings: `/admin/drafts` JSON no longer leaks `AskerEmail` (security); `/health` reports real degradation instead of always-200; Open Graph `article:tag` emits one `<meta>` per tag; `writeFileAtomically` cleans stranded `.backup` files; banner images resolve across every rendering path (`og:image`, Schema.org); graceful shutdown drains session and rate-limiter cleanups on SIGTERM.

### Filed upstream (open)

- [`1mb-dev/markgo#69`](https://github.com/1mb-dev/markgo/issues/69) — generic top-level pages mechanism (`/pages/:slug` or top-level `/:slug` with `type: page` frontmatter). Pages excluded from `/writing` + RSS + JSON feed + sitemap + tag/category indexes. [Scope addendum](https://github.com/1mb-dev/markgo/issues/69#issuecomment-4470725606): same exclusion predicate covers dedicated-handler slugs (today `about` is the only one), so `articles/about.md` can ship without duplicating at `/writing/about`. Blocks Wave 2 of M3-polish-2 (about page + "Run your own?" page).
- [`1mb-dev/markgo#70`](https://github.com/1mb-dev/markgo/issues/70) — brand-logo customization hook. Header logo is currently inline SVG in `web/templates/base.html`; STATIC_PATH overlay can't reach template-embedded assets. Proposal: inline `static/img/brand-logo.svg` when present, fall back to embedded default. Forkers writing custom logos use CSS-var fills (`var(--color-primary)`) to inherit theme color. Blocks Wave 3 of M3-polish-2.

### Fixed upstream (markgo v3.11.0)

- [`1mb-dev/markgo#63`](https://github.com/1mb-dev/markgo/issues/63) — AMA submission copy is operator-configurable via 5 env vars (`AMA_PAGE_HEADING`, `AMA_PAGE_INTRO`, `AMA_FORM_PLACEHOLDER`, `AMA_SUBMIT_LABEL`, `AMA_THANKYOU_COPY`). Plaintext only, HTML-escaped on render. Defaults preserve pre-v3.11.0 English verbatim.
- Compose form banner control: the v3.10.0 `banner` / `banner_alt` frontmatter fields are now editable from `/compose`. Upload-based banners flow through `/compose/upload/<slug>`; absolute URLs / server-absolute paths stay read-only on edit.
- `SHUTDOWN_TIMEOUT` env var (was hardcoded 30s). Configurable for Caddy rolling-restart tuning.
- Graceful shutdown ordering: cleanup of session store, rate limiters, and templates now runs even when the HTTP server's `Shutdown(ctx)` errors (prevents the `os.Exit(1)` path from skipping cleanups when `SHUTDOWN_TIMEOUT` is hit).
- Orphan `banner_alt` no longer written without a corresponding `banner` key on compose save.

### Known issues (upstream, tracked)

- [`1mb-dev/markgo#44`](https://github.com/1mb-dev/markgo/issues/44) — AMA submission filename uses `thought-` prefix instead of `ama-`. Cosmetic; moderation and rendering unaffected. Fix shipped in v3.8.0; pending live re-verification on next AMA submission.

### Notes

- markgo target version: `v3.12.0` (brand-logo customization hook completing the v3.10.2 STATIC_PATH overlay story; markgo#70 closed in this release).
- Reference deployment binds markgo to `127.0.0.1:3001` (configured via `PORT` in `.env`) to coexist with other services on the same host.
- AMA spam protection is **math captcha + honeypot + `RATE_LIMIT_CONTACT_*`** (not CSRF, contrary to early documentation).
- RAM is tight on small VPSes (the reference deploy has 464 MiB total; markgo resident ~13-15 MiB). Drop `CACHE_MAX_SIZE` in `.env` if pressure surfaces.
- Markgo has no `FEATURES_*` config envelope — feature availability is gated per-feature (e.g., AMA + `/compose` require `ADMIN_*` + compose service; contact form requires `EMAIL_HOST`; SEO sub-features are individual `SEO_*` booleans).
