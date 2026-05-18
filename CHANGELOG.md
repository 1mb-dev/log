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
- 2026-05-17 (M3-polish-2 Wave 3) — `v3.12.0` shipped. Header brand-logo overridable via `static/img/brand-logo.svg` (markgo#70 closed). Reference deploy ships a `1.` glyph mirroring the favicon, theme-reactive via `--color-bg-primary` / `--color-text-primary`. CSP unchanged; Lighthouse holds 100/100/100/100. Wave 2 still gated on markgo#69 (top-level pages + dedicated-handler-slug exclusion).
- 2026-05-17 (M3-polish-2 Wave 2) — `v3.13.0` shipped. `articles/about.md` lives at `/about` (corpus voice, two stanzas, LinkedIn-seed soul cross-linking the engine page); `articles/run-your-own.md` lives at `/p/run-your-own` as the first `type: page` article on this deploy (markgo#69 closed — `DedicatedRouteArticle` predicate excludes both from `/writing` + feeds + sitemap + taxonomy, 301-redirects `/writing/<dedicated-slug>` → canonical URL). README "When to use this" cross-links to the engine page. A11y fix in `1mb.css` adds underline to inline links inside `.article-content p` (WCAG 2.1 SC 1.4.1 — page-template body text uses `--color-text-secondary`, contrast against theme-primary link was 1.25:1, under the 3:1 floor). Lighthouse holds 100/100/100/100 across `/`, `/about`, `/p/run-your-own`. Filed markgo#75 (env-driven /about reach section unifying AMA + contact — current about-page AMA copy is template-baked English, voice mismatch with the configured AMA overlay).
- 2026-05-18 (v3.15.1 follow-up to Wave 4) — `v3.15.1` shipped. Closes the three open watches from Wave 4: `markgo#78` (env-driven `/about` reach section heading + email card copy via new `ABOUT_REACH_HEADING` / `ABOUT_EMAIL_HEADING` / `ABOUT_EMAIL_INTRO`; defaults preserve pre-v3.15.0 literals byte-for-byte), `markgo#79` (`/compose/new-page` authoring affordance + exported `article.ValidateSlug` strict slug gate + edit-mode plumbing for `type:page`), `markgo#80` (drop `BLOG_AUTHOR_EMAIL` placeholder default — empty hides the email card on `/about` and omits the email field in JSON-LD; no-op for log since production sets `hi@1mb.dev`). Operator-side: production was running `v3.14.0-5-gece206f` (pre-tag precursor of v3.15.0 built from the local markgo working tree); this redeploy lands a clean `v3.15.1` and surfaces the three new env vars overridden in 1mb voice (`Reach` / `Mail` / `Drop a note. Private reply when there's signal.`) — parallels the `Ask anything` / `Send a question. Public answer when there's weight to add.` AMA card. Lighthouse holds 100/100/100/100 across `/`, `/about`, `/p`, `/p/run-your-own`.
- 2026-05-18 (M3-polish-2 Wave 4) — `v3.14.0` shipped. markgo#75 closed: `/about` reach section consolidates AMA + mailto into one card with two affordance columns; AMA half now reads from existing `AMA_PAGE_HEADING` / `AMA_PAGE_INTRO` / `AMA_SUBMIT_LABEL` env vars, matching the overlay + `/ama` voice. New `/p` index route at `https://log.1mb.dev/p` lists all `type: page` articles with a footer link between `/categories` and `/about`. Sitemap completeness: `/about`, `/p`, `/p/run-your-own` now indexed (closes the latent v3.13.0 gap). CanonicalURLFor sweep across feeds, compose, taxonomy, post handler, and SEO emissions — verified `not-a-brand` page canonical, RSS link, JSON Feed URL, and sitemap loc all agree. CSP unchanged; Lighthouse 100/100/100/100 across `/`, `/about`, `/p`, `/p/run-your-own`. Filed markgo#78 (env-driven copy for the new about-reach section heading + email card — AMA half is operator-voiced, mailto half + wrapper heading still default English) and markgo#79 (`type: page` authoring affordance in compose — the v3.13.0+ deferred follow-up that v3.14.0 didn't ship; pages currently must be authored by direct markdown drop).

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
- `static/img/brand-logo.svg` — `1.` glyph header logo. Mirrors the favicon's two-color treatment but inherits theme tokens (`--color-bg-primary` background, `--color-text-primary` text), so it tracks the active theme. Inlined by markgo v3.12.0+ at request time via the brand-logo overlay hook (≤32 KiB cap, well-formed XML, `class="brand-logo"` injected if absent).
- `articles/about.md` — about page in corpus voice. Mirrors `homepage-copy.md` cadence (identity stanzas + resonance close) with one extra beat cross-linking the engine page at `/p/run-your-own`. Loaded by markgo's dedicated `/about` handler as the bio body; `DedicatedRouteArticle` predicate (v3.13.0+) keeps it off `/writing` + feeds + sitemap + taxonomy.
- `articles/run-your-own.md` — engine-storefront for on-site readers at `/p/run-your-own` (first `type: page` article on this deploy). Corpus voice; identity → stack inventory → posture/why → ownership-cost beat → invitation → deploy-guide pointer. README "When to use this" cross-links to it for the corpus-side framing of the fork question.
- `static/css/themes/1mb.css` — underline rule for inline links inside `.article-content p` (WCAG 2.1 SC 1.4.1; theme-primary link on text-secondary surrounding had 1.25:1 contrast, under the 3:1 floor). Forkable; rephrase or remove in your own theme as needed.

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

- [`1mb-dev/markgo#78`](https://github.com/1mb-dev/markgo/issues/78) — env-driven copy for the new `/about` reach section heading + email card. v3.14.0 (#75) routed the AMA half through `AMA_PAGE_*` env vars but left the section wrapper `<h2>Reach out</h2>`, email card `<h3>Email</h3>`, and email card text `Or drop a line directly.` as default English. Inside the same DOM section, half speaks operator voice and half speaks markgo voice. Proposal: add `ABOUT_REACH_HEADING` / `ABOUT_EMAIL_HEADING` / `ABOUT_EMAIL_INTRO` to the `ABOUT_*` env-var family, same shape as `ABOUT_TAGLINE`. Surfaced from log.1mb.dev M3-polish-2 Wave 4.
- [`1mb-dev/markgo#79`](https://github.com/1mb-dev/markgo/issues/79) — `type: page` authoring affordance in compose form. v3.13.0 introduced the page content type and v3.14.0 polished the routing + index + sitemap, but compose's type dropdown still lists only thought / article / link / ama. Operators currently author pages by direct markdown drop. Proposal: add `page` to the dropdown with explicit-slug requirement, type:page frontmatter emission, edit-existing-page support via `/compose/edit/<slug>`, and no banner control (pages aren't banner-bearing). The v3.13.0 release notes flagged this as a v3.14.0+ deferral; v3.14.0 didn't ship it. Surfaced from log.1mb.dev M3-polish-2 Wave 4.

### Fixed upstream (markgo v3.11.0)

- [`1mb-dev/markgo#63`](https://github.com/1mb-dev/markgo/issues/63) — AMA submission copy is operator-configurable via 5 env vars (`AMA_PAGE_HEADING`, `AMA_PAGE_INTRO`, `AMA_FORM_PLACEHOLDER`, `AMA_SUBMIT_LABEL`, `AMA_THANKYOU_COPY`). Plaintext only, HTML-escaped on render. Defaults preserve pre-v3.11.0 English verbatim.
- Compose form banner control: the v3.10.0 `banner` / `banner_alt` frontmatter fields are now editable from `/compose`. Upload-based banners flow through `/compose/upload/<slug>`; absolute URLs / server-absolute paths stay read-only on edit.
- `SHUTDOWN_TIMEOUT` env var (was hardcoded 30s). Configurable for Caddy rolling-restart tuning.
- Graceful shutdown ordering: cleanup of session store, rate limiters, and templates now runs even when the HTTP server's `Shutdown(ctx)` errors (prevents the `os.Exit(1)` path from skipping cleanups when `SHUTDOWN_TIMEOUT` is hit).
- Orphan `banner_alt` no longer written without a corresponding `banner` key on compose save.

### Fixed upstream (markgo v3.12.0)

- [`1mb-dev/markgo#70`](https://github.com/1mb-dev/markgo/issues/70) — operator brand-logo override. Drop SVG at `<STATIC_PATH>/img/brand-logo.svg`; markgo validates well-formed XML + `<svg>` root + ≤32 KiB, injects `class="brand-logo"` when absent, silent fallback on missing, warned fallback on validation failure. Shipped in v3.12.0 (PR #71). Verified against this deploy — header now renders the `1.` glyph; CSP unchanged; Lighthouse holds 100/100/100/100.

### Fixed upstream (markgo v3.13.0)

- [`1mb-dev/markgo#69`](https://github.com/1mb-dev/markgo/issues/69) — generic top-level pages mechanism. v3.13.0 ships `/p/<slug>` for `type: page` articles (required frontmatter, never inferred) and a `DedicatedRouteArticle` predicate that excludes both `type: page` and the existing `about`-slugged article from `/writing` + RSS + JSON feed + sitemap + tag/category indexes. `/writing/<dedicated-slug>` 301-redirects to the canonical URL (GET + HEAD) to preserve inbound link equity. Schema.org `@type: WebPage` for pages (vs `Article`). Shipped in v3.13.0 (PR #73). Verified against this deploy — `/writing/about` → 301 `/about`, `/writing/run-your-own` → 301 `/p/run-your-own`, neither article in `/feed.xml` or `/sitemap.xml`, Lighthouse 100/100/100/100 across `/`, `/about`, `/p/run-your-own`.

### Fixed upstream (markgo v3.14.0)

- [`1mb-dev/markgo#75`](https://github.com/1mb-dev/markgo/issues/75) — `/about` reach consolidation. v3.14.0 collapses the prior two `.about-ama` + `.about-contact` sections into a single `.about-reach` card with two affordance columns. AMA card heading / intro / submit-button labels now read from the existing `AMA_PAGE_HEADING` / `AMA_PAGE_INTRO` / `AMA_SUBMIT_LABEL` env vars — operator voice across `/ama`, the overlay, and the `/about` reach card now matches. Shipped in v3.14.0 (PR #76). Verified against this deploy — reach card renders `Ask anything` heading, `Send a question. Public answer when there's weight to add.` intro, `Send` button label. Email half of the reach card still default English; tracked separately in #78.
- v3.14.0 dedicated-route polish: `/p` index route added (alphabetic page listing, footer link between `/categories` and `/about`); sitemap now includes `/about`, `/p`, and `/p/<slug>` entries (closes a latent v3.13.0 gap); all hardcoded `/writing/<slug>` URL emissions sweep through `CanonicalURLFor` across feeds, compose, taxonomy, post handler, and SEO helper (uniform canonical URLs across page canonical meta, RSS `<link>`, JSON Feed `url`, and sitemap `<loc>`). Removed dead `seo.Helper.GenerateSitemap` (feed-service implementation is the live one). Shipped in v3.14.0 (PR #76).

### Known issues (upstream, tracked)

- [`1mb-dev/markgo#44`](https://github.com/1mb-dev/markgo/issues/44) — AMA submission filename uses `thought-` prefix instead of `ama-`. Cosmetic; moderation and rendering unaffected. Fix shipped in v3.8.0; pending live re-verification on next AMA submission.

### Notes

- markgo target version: `v3.14.0` (dedicated-route polish — `/about` reach section consolidates AMA + mailto and reads from v3.11.0 `AMA_PAGE_*` env vars, new `/p` index lists all pages with a footer link, sitemap now includes `/about` + `/p` + `/p/<slug>`, all `/writing/<slug>` emissions route through `CanonicalURLFor`; markgo#75 closed).
- Reference deployment binds markgo to `127.0.0.1:3001` (configured via `PORT` in `.env`) to coexist with other services on the same host.
- AMA spam protection is **math captcha + honeypot + `RATE_LIMIT_CONTACT_*`** (not CSRF, contrary to early documentation).
- RAM is tight on small VPSes (the reference deploy has 464 MiB total; markgo resident ~13-15 MiB). Drop `CACHE_MAX_SIZE` in `.env` if pressure surfaces.
- Markgo has no `FEATURES_*` config envelope — feature availability is gated per-feature (e.g., AMA + `/compose` require `ADMIN_*` + compose service; contact form requires `EMAIL_HOST`; SEO sub-features are individual `SEO_*` booleans).
