# Deploying markgo to a VPS

> Step-by-step guide for deploying this repo (or your fork) as a markgo blog.

This guide assumes you have:

- A Linux VPS you can reach over `ssh` with sudo (the reference deploy uses Debian 12).
- A domain you control with DNS edit access.
- Go 1.26+ and `make` on your local machine. The server only needs the resulting binary.
- Caddy v2 on the VPS (Nginx works too; substitute the relevant block from markgo's `docs/deployment.md`).

If you forked this repo, replace every `log.1mb.dev` reference with your domain and `1mb-dev/log` with your repo path before following along.

> Status: this guide is a scaffold. M1 fills in the parts marked `TODO(M1)` from real deploy experience.

---

## 1. Prerequisites

<!-- TODO(M1): list exact package versions used in the reference deployment. -->

Install on the VPS:

```sh
sudo apt update && sudo apt install -y caddy
```

Confirm versions: `caddy version`, `systemctl --version`.

## 2. DNS

<!-- TODO(M1): exact records used for log.1mb.dev once deployed. -->

Point your domain at the VPS:

- A record: `your.domain.example` -> VPS public IPv4
- AAAA record: `your.domain.example` -> VPS public IPv6 (if available)

Verify propagation with `dig +short your.domain.example` before continuing.

## 3. Build the markgo binary

```sh
make fetch-markgo MARKGO_REF=v3.7.0 GOOS=linux GOARCH=amd64
```

This produces `build/markgo` -- a static Linux binary with no runtime dependencies.

If you have a local checkout of `1mb-dev/markgo` at a sibling path (`../markgo`), `make fetch-markgo` builds whatever ref is currently checked out there. Otherwise it shallow-clones the requested ref into `build/markgo-src` and builds from that.

## 4. Provision the server

<!-- TODO(M1): full sequence with exact commands and verification. -->

Create the service user and deploy directory:

```sh
sudo useradd --system --no-create-home --shell /bin/false markgo
sudo mkdir -p /opt/log.1mb.dev/{articles,static,uploads,logs}
sudo chown -R markgo:markgo /opt/log.1mb.dev
```

Copy the binary, articles, static overrides, and `.env`:

```sh
scp build/markgo your.vps:/tmp/
rsync -a articles/ static/ .env your.vps:/tmp/log-bundle/
ssh your.vps 'sudo mv /tmp/markgo /opt/log.1mb.dev/ \
  && sudo rsync -a /tmp/log-bundle/ /opt/log.1mb.dev/ \
  && sudo chown -R markgo:markgo /opt/log.1mb.dev \
  && sudo chmod 600 /opt/log.1mb.dev/.env'
```

Install the systemd unit:

```sh
sudo cp deploy/log.service.example /etc/systemd/system/log.service
# Edit the unit if your user/paths differ.
sudo systemctl daemon-reload
sudo systemctl enable --now log.service
```

Confirm it: `sudo systemctl status log` and `curl -fsS http://127.0.0.1:3001/health`.

## 5. Caddy

<!-- TODO(M1): paste the actual vhost block that ships in production. -->

Add the block from `deploy/Caddyfile.example` to your Caddyfile, then reload:

```sh
sudo cp deploy/Caddyfile.example /etc/caddy/conf.d/log.1mb.dev.caddy
# Edit: replace log.1mb.dev with your domain.
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Caddy auto-provisions TLS via Let's Encrypt on first request to the domain.

## 6. Verification

<!-- TODO(M1): expand with the full M1 acceptance checklist from todos/handoff.md. -->

Once everything is up:

```sh
curl -fsSI https://your.domain.example | grep -i 'strict-transport-security'
```

Expected: HTTP 200 with the HSTS header.

Browser and feed checks:

- Homepage renders with markgo's feed view.
- `/feed.xml` returns RSS (empty if you have no published articles yet).
- `/sitemap.xml` renders.
- `/robots.txt` reflects `SEO_ROBOTS_DISALLOWED`.
- Article pages contain JSON-LD `Article` schema (view source).
- Mobile: the PWA install prompt appears and the Service Worker registers.

AMA flow (requires `ADMIN_USERNAME`/`ADMIN_PASSWORD` set in `.env`):

- Open the homepage, tap the FAB / question-mark button.
- Submit a test question (math captcha + honeypot).
- Log in at `/login`, visit `/admin/ama`. The pending question should appear.
- Answer or delete it; published answers should appear on the home feed with a "Q" badge.

## 7. Forking checklist

If you forked this repo to deploy your own blog:

- [ ] Replace `articles/_example.md` with your own writing.
- [ ] Edit `.env`: `BASE_URL`, `BLOG_*`, `ABOUT_*`, `ADMIN_*`, `CORS_ALLOWED_ORIGINS`.
- [ ] Replace `static/` overrides with your design (or remove them and rely on markgo's defaults).
- [ ] Edit `deploy/log.service.example` if your service user or paths differ.
- [ ] Edit `deploy/Caddyfile.example` with your domain.
- [ ] Add `static/og-default.png` (1200x630 PNG) for default social cards.
- [ ] Update README.md and CHANGELOG.md to reflect your fork.

---

## Troubleshooting

<!-- TODO(M1): collect failure modes hit during deploy. -->

- **Service won't start.** `sudo journalctl -u log -n 50 --no-pager`. Common causes: missing `.env`, port already in use, wrong user/path in the unit.
- **TLS not provisioning.** Caddy needs ports 80 and 443 reachable from the public internet; check firewall rules.
- **AMA submission rejected.** Confirm `ADMIN_USERNAME`/`ADMIN_PASSWORD` are set and rate limits haven't been tripped.
