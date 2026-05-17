# Static asset overrides

Drop CSS overrides, favicons, fonts, or OG default images here. Markgo's `STATIC_PATH` is **overlay mode** (since v3.10.2): files in this tree are served first, embedded defaults fall back for anything you didn't replace. No mirror needed.

Set `STATIC_PATH=./static` in `.env` once this directory has at least one override.

## What ships with the reference deployment

The `1.` favicon and header brand-logo, `1.log` OG card, `1mb` theme CSS, and Space Mono woff2 in this directory are the maintainer's brand chrome — example overrides at the exact paths markgo's HTML references. Replace with your own when forking.

```
static/
├── css/
│   ├── fonts.css                       Self-hosted @font-face declarations.
│   └── themes/1mb.css                  Theme tokens (colors, fonts). Activated
│                                       via BLOG_STYLE=1mb. markgo v3.10.3+
│                                       accepts any non-empty BLOG_STYLE.
├── fonts/space-mono/                   woff2 fonts referenced from fonts.css.
├── img/
│   ├── favicon.svg                     SVG favicon for modern browsers.
│   ├── favicon-32x32.png               PNG favicon (markgo's emitted path).
│   ├── apple-touch-icon.png            180×180 iOS home-screen icon.
│   ├── brand-logo.svg                  Header brand-logo (markgo v3.12.0+).
│   │                                   Inlined; uses var(--color-*) for theme.
│   └── banners/                        Per-article hero PNGs (markgo banner: frontmatter).
└── og-default.png                      1200×630 default social card.
                                        Referenced by SEO_DEFAULT_IMAGE in .env.
```

## Forking checklist

- Drop your own `favicon.svg` / `favicon-32x32.png` / `apple-touch-icon.png` into `img/`.
- Drop a `brand-logo.svg` into `img/` to swap the header logo (markgo v3.12.0+ inlines it; use `var(--color-primary)` / `var(--color-bg-primary)` / `var(--color-text-primary)` for fills if you want theme-reactive colors). Skip the file to keep markgo's default.
- Replace `og-default.png` (1200×630) with your social card.
- Edit `themes/1mb.css` to recolor / re-font, or rename to `themes/yourname.css` and set `BLOG_STYLE=yourname` in `.env`. Delete the file (and leave `BLOG_STYLE=minimal`) to fall back to markgo's stock minimal theme.
- Replace or remove the Space Mono woff2 + `fonts.css` if you prefer markgo's default Inter + Fira Code.
- Manifest (`/manifest.json`) is generated dynamically by markgo from `BLOG_*` env values — no static file needed.
