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
make fetch-markgo GOOS=linux GOARCH=amd64
```

This produces `build/markgo` — a static Linux binary with no runtime dependencies. The markgo version is pinned in the Makefile (`MARKGO_REF`); override with `MARKGO_REF=vX.Y.Z` only when you want a different version than the repo ships with.

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

- `STATIC_PATH=` (empty) — markgo's static handler is **overlay mode** (since v3.10.2): setting `STATIC_PATH=./static` serves your override files first, falls back to markgo's embedded defaults for everything else. No mirror needed. Leave empty if you have no overrides; set to `./static` once you drop favicons, OG images, fonts, or theme CSS into `./static/`.
- `EMAIL_HOST=` (empty) — disables the contact form. AMA doesn't use SMTP; submissions land in markgo's moderation queue on disk.

Now deploy:

```sh
make deploy DOMAIN=your.domain.example
```

What `make deploy` does:

1. **Pre-flight confirmation.** Surfaces local `.env` mtime and line count; prompts `y/N` before any build or ssh. Since deploy is local-authoritative (`.env` is rsynced onto the VPS, overwriting whatever's there), this gate exists so you don't push a stale local `.env` after hand-editing prod, or vice versa. Default is N — Enter aborts. Bypass via `make deploy` alone is not supported; if you need a confirmed scripted retry, `yes | make deploy DOMAIN=...`.
2. Builds the markgo binary if missing (via `make build`).
3. Renders the systemd unit by substituting `User=`, `Group=`, paths, and `SyslogIdentifier=` from `deploy/log.service.example`.
4. `ssh`'s to the VPS as root and idempotently creates the service user (`loguser` by default) and the deploy tree (`/opt/$(DOMAIN)/{articles,static,uploads,logs}`).
5. rsyncs the binary, `.env`, and rendered unit to a staging path on the VPS.
6. rsyncs `articles/` (additive — does **not** delete remote files, so markgo's `/compose` output stays put) and `static/` (mirrored with `--delete`).
7. Installs the binary (mode 0755), `.env` (mode 0600), and systemd unit. `chown`s the tree to the service user. Reloads systemd, enables and restarts the service, then waits for `is-active`.
8. Runs `scripts/verify-deploy.sh DOMAIN` to confirm health.

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

markgo auto-trusts loopback for rate-limit keying (v3.22.5+), so this same-host Caddy → `127.0.0.1` topology keys on the real client with no extra config — leave `TRUSTED_PROXIES` unset. Set it only for an off-host proxy (a separate proxy machine, or Cloudflare → Caddy): list the full proxy chain, else the limiter collapses every visitor onto that proxy's IP and the per-client limits go global. markgo logs the keying posture at boot (`trusted_proxies_source=loopback-default|explicit`).

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

The shipped vhost logs access events to stderr, which systemd captures into the journal. Tail with `journalctl -u caddy --grep 'your.domain.example' -f`. Switch to file output (with rotation) if you need long retention — the template includes a commented-out example.

## 6. Verification

Run the smoke-test script:

```sh
scripts/verify-deploy.sh your.domain.example
```

It checks `/health`, `/feed.xml`, `/sitemap.xml`, `/robots.txt`, `/manifest.json`, and the HSTS header. Probes use `GET` with `curl -f` — fatal on any 4xx/5xx response on the first probed endpoint.

Browser checks worth doing once:

- Homepage renders. View source: confirm `<title>`, OG meta, and JSON-LD `Article` schema on article pages (if any are published).
- DevTools → Application → Service Workers: `sw.js` registers. On mobile, the PWA install prompt should appear.
- `/feed.xml` is valid RSS (empty if you have no published articles yet).
- `/robots.txt` reflects `SEO_ROBOTS_DISALLOWED`.

AMA flow (requires `ADMIN_USERNAME`/`ADMIN_PASSWORD` set in `.env`):

- Open the homepage. Tap the FAB on desktop or the bottom-nav `?` button on mobile.
- Submit a test question. The form solves a math captcha in JS and includes a honeypot field; submission lands in `articles/` as a draft markdown file with `type: ama`.
- Visit `/admin/ama`. Markgo renders an inline Sign in form on any admin route — enter your `ADMIN_*` credentials there. The pending question appears in the moderation list.
- Answer or delete. Answering appends `\n\n---\n\n<answer>` to the article and flips `draft: false`; the published Q&A then appears on the home feed.

## External uptime probe

The reference deploy uses UptimeRobot to poll `/health` every 5 minutes and alert on non-200. Configured operator-side (account, monitor, alert channel); not codified in this repo. For your fork: any pull-mode probe service pointed at `/health` works — markgo's endpoint returns `200` only when the binary is up and serving.

## Reading access logs

Caddy writes its access log to systemd's journal via the `log { output stderr; level INFO }` block in the vhost. `scripts/read-logs.sh` pulls that log over ssh and renders a one-shot HTML report on your machine — no dashboard runs on the VPS, no analytics beacon ships from the site. Server-side hygiene, not analytics.

**One-time VPS setup.** The ssh user must be non-root and able to read the caddy unit's journal. Using the app user (`loguser`) is fine — it's already on the box. Service accounts often ship with no login shell, no `.ssh/authorized_keys`, and no journal access, so all three usually need wiring:

```sh
ssh root@your.host
chsh -s /bin/bash loguser
usermod -aG systemd-journal loguser

install -d -m 700 -o loguser -g loguser /home/loguser/.ssh
echo 'ssh-ed25519 AAAA... your@key' \
  >> /home/loguser/.ssh/authorized_keys
chown loguser:loguser /home/loguser/.ssh/authorized_keys
chmod 600 /home/loguser/.ssh/authorized_keys
chown loguser:loguser /home/loguser && chmod 755 /home/loguser

# If sshd is hardened with AllowUsers, add the operator user:
#   /etc/ssh/sshd_config.d/*.conf -> AllowUsers ... loguser
#   sshd -t && systemctl reload ssh
```

**Operator config.** Put the ssh target in `.env.local` (gitignored, machine-local — distinct from `.env`, which gets rsync'd to the VPS):

```sh
LOG_HOST=loguser@your.host
LOG_VHOST=your.domain.example   # optional; filters when Caddy hosts multiple sites
```

If Caddy fronts multiple vhosts on the same systemd unit, the journal carries all of them. Set `LOG_VHOST` to keep only entries for one site (requires `jq`: `brew install jq`).

**Usage:**

```sh
scripts/read-logs.sh                     # last hour
scripts/read-logs.sh "24 hours ago"      # last day
scripts/read-logs.sh "2026-05-15"        # since a date
```

Requires `goaccess` on your `$PATH` (`brew install goaccess` on macOS). The script uses `goaccess --log-format=CADDY` against Caddy v2's default JSON access log — see the script header for fallback paths if your Caddy emits a different format.

## Pulling VPS-authored content back

AMA submissions and compose-published articles land in `articles/` on the VPS — not in your local clone. `make deploy` is additive (it pushes local content up, doesn't pull VPS content down), so VPS-only content stays VPS-only until you pull it back.

```sh
make pull-from-vps DOMAIN=your.domain.example
```

Idempotent: rsyncs `articles/` from the VPS into your local clone (additive — won't delete local-only files), then runs `git status --short articles/` so you can review and commit anything new. Run before composing locally or shipping changes; otherwise VPS-side AMAs and compose posts won't make it back to the canonical git history.

---

## 7. Forking checklist

If you forked this repo to deploy your own blog:

- [ ] Replace the contents of `articles/` with your own writing.
- [ ] Edit `.env`: `BASE_URL`, `BLOG_*`, `ABOUT_*`, `ADMIN_*`, `CORS_ALLOWED_ORIGINS`.
- [ ] Decide on `STATIC_PATH`: leave empty if you have no static overrides; set to `./static` once you drop favicons, OG image, fonts, or theme CSS into `./static/`. Overlay mode falls back to markgo's embedded defaults for everything you didn't replace.
- [ ] Edit `deploy/log.service.example` if you want to ship `User=` other than `markgo` directly (or just override `DEPLOY_USER` on the `make deploy` command line).
- [ ] Edit `deploy/Caddyfile.example` with your domain.
- [ ] Add `static/og-default.png` (1200×630 PNG) for default social cards.
- [ ] Update `README.md` and `CHANGELOG.md` to reflect your fork.
- [ ] Decide if you want `/var/log/caddy/` access logs (referenced by the vhost) — create the directory or drop the `log { … }` block.

---

## Troubleshooting

**Service won't start.** `sudo journalctl -u log -n 50 --no-pager`. Common causes: missing `.env` (the unit's `EnvironmentFile=-` uses `-` prefix so a missing file isn't fatal, but markgo errors loudly without `BASE_URL`), port already in use (`ss -lnt | grep 3001`), wrong `User=`/`WorkingDirectory=` in the unit.

**TLS not provisioning.** Caddy needs ports 80 and 443 reachable from the public internet. Check firewall (`sudo ufw status` or your cloud firewall console). Watch `journalctl -u caddy -f` while curling your domain to see the ACME flow.

**Static asset overrides not appearing.** Overlay mode falls back to embedded for any path you didn't replace; if your override doesn't show, confirm the file is present in `./static/` at the exact path markgo's HTML references (`/static/img/favicon.svg` → `./static/img/favicon.svg`). Pre-v3.10.2 the handler was exclusive; if you're on an older binary, either bump or leave `STATIC_PATH=` empty.

**AMA submission rejected.** Confirm `ADMIN_USERNAME` and `ADMIN_PASSWORD` are set — without them, the route isn't registered. Check rate limits in `.env` (`RATE_LIMIT_CONTACT_*`, shared with contact form: 5 requests per hour by default). If submissions silently 200 with no question landing in `/admin/ama`, you likely tripped the honeypot — your client filled the hidden `website` field.

**Tight RAM (< 512 MiB total).** Markgo's default `CACHE_MAX_SIZE=1000` allocates per-article cache slots. Drop it to 100-200 in `.env` if `free -h` shows pressure after running for a day. Markgo's resident size on the reference deploy is ~13-15 MiB; the rest of your RAM headroom is for cache and the kernel.

**`.env` overwritten by `make deploy`.** `make deploy` is local-authoritative — it pushes your local `.env` to the VPS every run. Never edit `.env` on the VPS directly; edit locally and re-deploy. If you rotate a secret, update local `.env` first.
