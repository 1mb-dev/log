# Deploying markgo to a VPS

> Step-by-step guide for deploying this repo (or your fork) as a markgo blog.

This guide is grounded in the live reference deployment at `log.1mb.dev`. Every command below was used (or generalised from) the actual M1 deploy on 2026-05-15.

## Assumptions

- A Linux VPS reachable over `ssh` with root or sudo. The reference deploy runs Debian 13 (trixie).
- A domain you control with DNS edit access.
- Go 1.26+ and `make` on your **local** machine. The server only needs the resulting binary.
- Caddy v2 on the VPS. Nginx works too if you adapt the vhost — substitute the relevant block from markgo's `docs/deployment.md`.

If you forked this repo, replace `log.1mb.dev` with your domain and `1mb-dev/log` with your repo path before following along.

---

## 1. Prerequisites

On the VPS:

```sh
sudo apt update && sudo apt install -y caddy
```

Confirm: `caddy version` (2.x), `systemctl --version` (any modern systemd works; the unit's hardening directives all land on systemd ≥ 247).

The reference deploy uses Caddy 2.x from Debian's `apt` repos and runs on Debian 13 with 464 MiB total RAM. Markgo adds ~13-15 MiB resident; if your VPS is similarly tight, see "Troubleshooting" for `CACHE_MAX_SIZE` tuning.

## 2. DNS

Point your domain at the VPS:

- A record: `your.domain.example` → VPS public IPv4
- AAAA record: `your.domain.example` → VPS public IPv6 (if available)

Verify propagation before continuing:

```sh
dig +short your.domain.example
```

The reference deploy uses `log.1mb.dev` (one A record to a single DigitalOcean droplet). Caddy needs ports 80 and 443 reachable from the public internet for the Let's Encrypt HTTP-01 challenge — open them in your firewall before the first deploy.

## 3. Build the markgo binary

```sh
make fetch-markgo MARKGO_REF=v3.7.0 GOOS=linux GOARCH=amd64
```

This produces `build/markgo` — a static Linux binary with no runtime dependencies.

If you have a local checkout of `1mb-dev/markgo` at a sibling path (`../markgo`), `make fetch-markgo` builds whatever ref is currently checked out there. Otherwise it shallow-clones the requested ref into `build/markgo-src` and builds from that. Set `MARKGO_SRC=` (empty) to force a clean clone even when a sibling exists.

## 4. Configure and deploy

Create a real `.env` from the template, fill in production values, and tighten its permissions:

```sh
cp .env.example .env
$EDITOR .env
chmod 600 .env
```

Required edits:

- `BASE_URL=https://your.domain.example` — drives canonical links, RSS, OG cards.
- `BLOG_TITLE`, `BLOG_TAGLINE`, `BLOG_DESCRIPTION`, `BLOG_AUTHOR`, `BLOG_AUTHOR_EMAIL` — feed into HTML/feed metadata. Empty values leak placeholder text into rendered pages.
- `ADMIN_USERNAME` and `ADMIN_PASSWORD` — gate `/compose` (publishing) and `/admin/ama` (moderation). Without them, neither AMA submissions nor compose are wired up at all. Generate the password with `openssl rand -base64 32` and stash it in a password manager.
- `CORS_ALLOWED_ORIGINS=https://your.domain.example` — wildcards are a footgun in production.

Leave these as-is unless you have a reason:

- `STATIC_PATH=` (empty) — markgo's static handler is **exclusive**, not overlay. Setting `STATIC_PATH=./static` makes markgo serve from `./static` and bypass its embedded defaults entirely; missing files 404. Leave empty until you've populated `./static/` with overrides.
- `EMAIL_HOST=` (empty) — disables the contact form. AMA doesn't use SMTP; submissions land in markgo's moderation queue on disk.

Now deploy:

```sh
make deploy DOMAIN=your.domain.example
```

What `make deploy` does:

1. Builds the markgo binary if missing (via `make build`).
2. Renders the systemd unit by substituting `User=`, `Group=`, paths, and `SyslogIdentifier=` from `deploy/log.service.example`.
3. `ssh`'s to the VPS as root and idempotently creates the service user (`loguser` by default) and the deploy tree (`/opt/$(DOMAIN)/{articles,static,uploads,logs}`).
4. rsyncs the binary, `.env`, and rendered unit to a staging path on the VPS.
5. rsyncs `articles/` (additive — does **not** delete remote files, so markgo's `/compose` output stays put) and `static/` (mirrored with `--delete`).
6. Installs the binary (mode 0755), `.env` (mode 0600), and systemd unit. `chown`s the tree to the service user. Reloads systemd, enables and restarts the service, then waits for `is-active`.
7. Runs `scripts/verify-deploy.sh DOMAIN` to confirm health.

Tunable variables (matching the reference deploy's defaults — override for your fork):

| Variable | Default | Notes |
|---|---|---|
| `DOMAIN` | (required) | Public hostname. Drives every path. |
| `SSH_TARGET` | `root@$(DOMAIN)` | Override if you don't ssh as root (`sudo` substitution left as exercise). |
| `DEPLOY_USER` | `loguser` | Forkers on a clean VPS often prefer `markgo`. |
| `DEPLOY_PATH` | `/opt/$(DOMAIN)` | Install prefix. |
| `SERVICE_NAME` | `log` | Systemd unit basename (`log.service`). |

Re-running `make deploy` is safe and idempotent: rsync only ships what changed, `useradd` no-ops if the user exists, `systemctl restart` is the same operation either way.

## 5. Caddy

Markgo binds to localhost on `PORT` (default `3001`); Caddy fronts it for TLS, HTTP/2, and compression. The reference vhost is at `deploy/Caddyfile.example`:

```
log.1mb.dev {
    reverse_proxy 127.0.0.1:3001
    header { … HSTS, X-Content-Type-Options, etc. … }
    encode gzip zstd
}
```

Two install paths depending on what's already on the VPS:

**(a) Fresh Caddy install — no existing sites.** Drop the vhost block into `/etc/caddy/Caddyfile` (replacing `log.1mb.dev` with your domain). Then:

```sh
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

**(b) Existing Caddyfile with other sites.** Use the `import` pattern so each site lives in its own file. One-time setup (skip if your Caddyfile already imports a `conf.d/` directory):

```sh
sudo mkdir -p /etc/caddy/conf.d
# Back up current Caddyfile before editing
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak
# Append the import directive (idempotent)
sudo grep -q "^import conf.d/" /etc/caddy/Caddyfile || \
  printf '\n# Per-site configs\nimport conf.d/*.caddy\n' | sudo tee -a /etc/caddy/Caddyfile
```

Then drop the vhost in:

```sh
sudo cp deploy/Caddyfile.example /etc/caddy/conf.d/your.domain.example.caddy
# Edit the file: replace log.1mb.dev with your domain.
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Caddy auto-provisions TLS via Let's Encrypt on the first request (ACME HTTP-01 challenge on port 80). Expect 10-30 seconds of latency on the very first hit while the cert is issued.

The shipped vhost includes an access-log block writing to `/var/log/caddy/`. If that directory doesn't exist, Caddy's reload will fail — create it (`sudo mkdir -p /var/log/caddy && sudo chown caddy:caddy /var/log/caddy`) or remove the `log { … }` block before reloading.

## 6. Verification

Run the smoke-test script:

```sh
scripts/verify-deploy.sh your.domain.example
```

It checks `/health`, `/feed.xml`, `/sitemap.xml`, `/robots.txt`, `/manifest.json`, and the HSTS header. Note: it uses `GET` requests with `curl -f`, not `HEAD`. Markgo registers routes via gin's `.GET()` only, so HEAD requests fall through to 404 — many uptime monitors will need their probe method set to GET until that's fixed upstream.

Browser checks worth doing once:

- Homepage renders. View source: confirm `<title>`, OG meta, and JSON-LD `Article` schema on article pages (if any are published).
- DevTools → Application → Service Workers: `sw.js` registers. On mobile, the PWA install prompt should appear.
- `/feed.xml` is valid RSS (empty if you have no published articles yet).
- `/robots.txt` reflects `SEO_ROBOTS_DISALLOWED`.

AMA flow (requires `ADMIN_USERNAME`/`ADMIN_PASSWORD` set in `.env`):

- Open the homepage. Tap the FAB on desktop or the bottom-nav `?` button on mobile.
- Submit a test question. The form solves a math captcha in JS and includes a honeypot field; submission lands in `articles/` as a draft markdown file with `type: ama`.
- Log in at `/login` with your `ADMIN_*` credentials.
- Visit `/admin/ama`. The pending question appears in the moderation list.
- Answer or delete. Answering appends `\n\n---\n\n<answer>` to the article and flips `draft: false`; the published Q&A then appears on the home feed.

## 7. Forking checklist

If you forked this repo to deploy your own blog:

- [ ] Replace `articles/_example.md` with your own writing.
- [ ] Edit `.env`: `BASE_URL`, `BLOG_*`, `ABOUT_*`, `ADMIN_*`, `CORS_ALLOWED_ORIGINS`.
- [ ] Decide on `STATIC_PATH`: leave empty to use markgo's embedded defaults (recommended for first deploy), or populate `./static/` with a full mirror of markgo's `web/static/` tree before setting `STATIC_PATH=./static`.
- [ ] Edit `deploy/log.service.example` if you want to ship `User=` other than `markgo` directly (or just override `DEPLOY_USER` on the `make deploy` command line).
- [ ] Edit `deploy/Caddyfile.example` with your domain.
- [ ] Add `static/og-default.png` (1200×630 PNG) for default social cards.
- [ ] Update `README.md` and `CHANGELOG.md` to reflect your fork.
- [ ] Decide if you want `/var/log/caddy/` access logs (referenced by the vhost) — create the directory or drop the `log { … }` block.

---

## Troubleshooting

**Service won't start.** `sudo journalctl -u log -n 50 --no-pager`. Common causes: missing `.env` (the unit's `EnvironmentFile=-` uses `-` prefix so a missing file isn't fatal, but markgo errors loudly without `BASE_URL`), port already in use (`ss -lnt | grep 3001`), wrong `User=`/`WorkingDirectory=` in the unit.

**TLS not provisioning.** Caddy needs ports 80 and 443 reachable from the public internet. Check firewall (`sudo ufw status` or your cloud firewall console). Watch `journalctl -u caddy -f` while curling your domain to see the ACME flow.

**Static assets all 404.** You set `STATIC_PATH=./static` but `./static/` is empty or doesn't contain markgo's embedded asset tree. Markgo's static handler is exclusive: if the directory exists, embedded defaults are bypassed *entirely*. Either populate `./static/` with a full mirror of markgo's `web/static/`, or set `STATIC_PATH=` (empty) and let embedded defaults serve.

**Uptime monitor reports the site as down.** Many monitors probe with HEAD by default. Markgo currently returns 404 for HEAD on every registered route — switch the probe method to GET. (Tracked as an upstream fix in `1mb-dev/markgo`.)

**AMA submission rejected.** Confirm `ADMIN_USERNAME` and `ADMIN_PASSWORD` are set — without them, the route isn't registered. Check rate limits in `.env` (`RATE_LIMIT_CONTACT_*`, shared with contact form: 5 requests per hour by default). If submissions silently 200 with no question landing in `/admin/ama`, you likely tripped the honeypot — your client filled the hidden `website` field.

**Tight RAM (< 512 MiB total).** Markgo's default `CACHE_MAX_SIZE=1000` allocates per-article cache slots. Drop it to 100-200 in `.env` if `free -h` shows pressure after running for a day. Markgo's resident size on the reference deploy is ~13-15 MiB; the rest of your RAM headroom is for cache and the kernel.

**`.env` overwritten by `make deploy`.** `make deploy` is local-authoritative — it pushes your local `.env` to the VPS every run. Never edit `.env` on the VPS directly; edit locally and re-deploy. If you rotate a secret, update local `.env` first.
