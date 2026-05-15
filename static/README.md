# Static asset overrides

Drop CSS overrides, favicons, fonts, or OG default images in this directory. Markgo's filesystem `STATIC_PATH` (set in `.env`) takes precedence over its embedded defaults at runtime -- anything here is served at `/static/<path>` and overrides whatever ships in the binary.

Common overrides:

- `css/overrides.css` -- visual customizations on top of markgo's default theme.
- `favicon.ico`, `favicon-16.png`, `favicon-32.png`, `apple-touch-icon.png` -- your icons.
- `og-default.png` (1200×630) -- the default social card for articles without an explicit image. Referenced by `SEO_DEFAULT_IMAGE` in `.env`.
- `manifest.json` -- overrides the dynamically generated PWA manifest if you need custom icons.

When you fork this repo, treat any files you find here as examples -- replace them with your own. The reference deployment at `log.1mb.dev` keeps its overrides minimal and annotated so it stays a useful starting point rather than a finished design.
