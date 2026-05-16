# Static asset overrides

Drop CSS overrides, favicons, fonts, or OG default images here, but read the trap first.

**Markgo's `STATIC_PATH` is exclusive, not overlay.** When `STATIC_PATH` is set in `.env` and the directory exists, markgo serves `/static/*` from there *only* — its embedded defaults are bypassed entirely. There is no per-file fallback. If you set `STATIC_PATH=./static` and put only `favicon.ico` here, every other asset (`css/style.css`, `js/app.js`, `img/icon-192x192.png`, etc.) 404s.

Safe patterns:

- **Embedded defaults only:** leave `STATIC_PATH=` empty in `.env`. Markgo serves its built-in CSS/icons/manifest. No overrides possible, but nothing breaks.
- **Full overlay:** mirror markgo's `web/static/` tree into this directory, then replace the specific files you want to change. Re-sync on markgo version bumps.

Common files to override once you've mirrored:

- `css/overrides.css` -- visual customizations on top of markgo's default theme.
- `favicon.ico`, `favicon-16.png`, `favicon-32.png`, `apple-touch-icon.png` -- your icons.
- `og-default.png` (1200×630) -- the default social card for articles without an explicit image. Referenced by `SEO_DEFAULT_IMAGE` in `.env`.
- `manifest.json` -- overrides the dynamically generated PWA manifest if you need custom icons.

When you fork this repo, treat any files you find here as examples -- replace them with your own. The reference deployment at `log.1mb.dev` ships `STATIC_PATH=` (empty) until the maintainer adds a full override set.
