# log

Reference deployment of [markgo](https://github.com/1mb-dev/markgo) at [log.1mb.dev](https://log.1mb.dev). A working example of how to fork markgo onto a VPS and serve a blog with TLS, AMA, and PWA support.

The published content under `articles/` is the maintainer's writing. The deploy harness -- `Makefile`, Caddy + systemd templates, `.env.example`, deployment guide -- is the part you copy when forking.

## Quick deploy

Prerequisites: a Linux VPS you can `ssh` to, a domain with DNS edit access, Go 1.26+ and `make` locally, Caddy v2 on the VPS.

```sh
# Fork on GitHub, then clone your fork
git clone https://github.com/yourname/your-blog.git && cd your-blog

# Build the markgo binary for your server
make fetch-markgo MARKGO_REF=v3.8.0 GOOS=linux GOARCH=amd64

# Customise
cp .env.example .env                  # edit BASE_URL, BLOG_*, ADMIN_*, CORS
rm articles/_example.md               # replace with your own writing
$EDITOR static/                       # swap or remove the overrides
```

Then follow [`docs/deployment.md`](docs/deployment.md) for the rest -- DNS, systemd, Caddy. Once `.env` is populated, `make deploy DOMAIN=your.domain.example` pushes binary + content + `.env`, installs the systemd unit with templated user/paths, restarts the service, and runs `scripts/verify-deploy.sh` to confirm health.

## What you get

A markgo deployment with:

- **Articles**, **Thoughts**, **Links** as content types, with type inferred from frontmatter or filename when omitted.
- **AMA** (Ask Me Anything): readers submit questions with math captcha + honeypot; you moderate at `/admin/ama`; published Q&As flow into the home feed.
- **Compose form** at `/compose` for publishing from any device once authenticated.
- **PWA**: installable, offline reading, service worker, dynamic manifest.
- **SEO**: RSS, sitemap, JSON-LD `Article` schema, OG cards.
- No analytics. No comments. No engagement features beyond AMA.

Everything is configured via `.env`. The full feature surface lives in [markgo's docs](https://github.com/1mb-dev/markgo/tree/main/docs).

## Repository layout

```
log/
├── articles/                  Blog content (markdown + frontmatter). Replace with yours.
├── static/                    Visual overrides on top of markgo's defaults. Treat as examples.
├── deploy/
│   ├── Caddyfile.example      Caddy vhost (reverse proxy + TLS via Let's Encrypt)
│   └── log.service.example    Hardened systemd unit
├── docs/deployment.md         Step-by-step deploy guide
├── Makefile                   fetch-markgo, build, deploy DOMAIN=...
├── .env.example               Production configuration template
├── LICENSE                    MIT (repo structure)
└── LICENSE-CONTENT.md         Content-licensing note (articles/ are © the author)
```

## Configuration

`.env.example` is grounded against markgo v3.8.0; every knob is annotated. Copy to `.env`, edit, then secure on the deploy target with `chmod 600 .env`.

A few choices baked into the reference deployment, none of them required:

- Markgo binds to `127.0.0.1:3001` rather than the default `3000`, to coexist with other services on the host.
- Caddy fronts the binary for TLS and access logging; systemd supervises it with hardening flags.

## Reverse proxy and service

[`deploy/Caddyfile.example`](deploy/Caddyfile.example) -- paste the block into your existing Caddyfile or drop the file into `/etc/caddy/conf.d/`. Caddy provisions TLS via Let's Encrypt on first request to the domain.

[`deploy/log.service.example`](deploy/log.service.example) -- systemd unit modeled on markgo's own production unit. Hardened with `NoNewPrivileges`, `ProtectSystem=strict`, and `ReadWritePaths` scoped to `articles/`, `uploads/`, and `logs/`. Edit user and paths for your setup before installing.

## Customising

- **Content type inference** -- see [markgo's design.md](https://github.com/1mb-dev/markgo/blob/main/docs/design.md).
- **Visual overrides** go in `static/`. The reference deployment keeps overrides minimal and annotated; see [`static/README.md`](static/README.md). Adjust to taste rather than treating these as a finished design.
- **Theme, navigation, and behavioural changes** belong upstream in markgo, not as patches in this repo.

## License

Repository structure (templates, deploy configs, `Makefile`, documentation) is MIT licensed -- see [`LICENSE`](LICENSE).

Content under `articles/` is the author's, all rights reserved -- see [`LICENSE-CONTENT.md`](LICENSE-CONTENT.md). Forkers replace it with their own writing.

## Status

Live at [log.1mb.dev](https://log.1mb.dev) running pinned markgo `v3.8.0`. The deploy harness (`make deploy`, `scripts/verify-deploy.sh`, [`docs/deployment.md`](docs/deployment.md)) is what forkers copy; the corpus under `articles/` is the maintainer's.
