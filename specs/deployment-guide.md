# Bastion: Deployment Guide

**Status**: v1 | **Part of**: [Bastion Design Spec](README.md)

This guide covers two production deployment paths:

1. **[Fly.io](#flyio)** — recommended for most new apps; managed infrastructure, global distribution, built-in secrets
2. **[Bare VPS](#bare-vps)** — Ubuntu/Debian server with systemd + nginx; full control, lowest cost

Both paths use the same single-binary release built by `forge bastion.release --embed-assets`.

---

## Prerequisites

- `forge` installed (`march toolchain` includes it)
- A Bastion app with a `forge.toml`
- `SECRET_KEY_BASE` set (at least 64 random bytes): `forge bastion.gen.secret`
- Postgres database accessible from your deployment target

---

## Building a Release

```bash
MARCH_ENV=prod forge bastion.release --embed-assets
```

What this does:

1. Compiles the app in release mode (optimised, no debug info)
2. Compiles all `@island` modules to WASM
3. Embeds all `priv/static/` assets directly into the binary
4. Produces: `_build/release/<app_name>/bin/<app_name>`

The `--embed-assets` flag produces a **single self-contained binary** — no `priv/` directory needed at runtime. This is the recommended default for container and VPS deployments.

> **Without `--embed-assets`**: the release directory contains `bin/<app>` + `priv/static/`. Use this if you serve static assets from a CDN and want to update them independently of the binary.

---

## Runtime Configuration

Release binaries read configuration from environment variables at startup. Create `config/runtime.march`:

```march
mod MyApp.Config.Runtime do
  fn load() do
    {
      port:            Env.get("PORT", "4000") |> String.to_int(),
      secret_key_base: Env.fetch!("SECRET_KEY_BASE"),
      db: {
        hostname:  Env.fetch!("DB_HOST"),
        port:      Env.get("DB_PORT", "5432") |> String.to_int(),
        database:  Env.fetch!("DB_NAME"),
        username:  Env.fetch!("DB_USER"),
        password:  Env.fetch!("DB_PASS"),
        pool_size: Env.get("DB_POOL_SIZE", "10") |> String.to_int(),
        ssl:       Env.get("MARCH_ENV", "prod") == "prod",
      },
      log_level:  Env.get("LOG_LEVEL", "info"),
      log_format: if Env.get("MARCH_ENV", "prod") == "prod" do "json" else "human" end,
    }
  end
end
```

---

## Fly.io

### 1. Install flyctl and log in

```bash
brew install flyctl
fly auth login
```

### 2. Generate `fly.toml`

```bash
fly launch --no-deploy
```

Edit the generated `fly.toml`:

```toml
app = "my-app"
primary_region = "iad"

[build]

[http_service]
  internal_port = 4000
  force_https   = true
  auto_stop_machines  = true
  auto_start_machines = true
  min_machines_running = 1

  [http_service.concurrency]
    type       = "connections"
    hard_limit = 1000
    soft_limit = 800

[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
  cpus = 1

[checks]
  [checks.health]
    grace_period = "10s"
    interval     = "15s"
    method       = "GET"
    path         = "/health"
    port         = 4000
    timeout      = "5s"
    type         = "http"
```

### 3. Dockerfile

Forge generates one with `forge bastion.release --dockerfile`, but here is the canonical version:

```dockerfile
# syntax=docker/dockerfile:1.4
FROM ubuntu:22.04 AS runner

RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the single release binary (built on CI or locally)
COPY _build/release/my_app/bin/my_app ./my_app

# Non-root user
RUN useradd --system --no-create-home appuser
USER appuser

ENV PORT=4000
EXPOSE 4000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:4000/health || exit 1

CMD ["./my_app", "start"]
```

> **Multi-stage build**: If you want to build inside Docker (e.g., on CI without the March toolchain installed natively):
>
> ```dockerfile
> FROM march:latest AS builder
> WORKDIR /app
> COPY . .
> RUN MARCH_ENV=prod forge bastion.release --embed-assets
>
> FROM ubuntu:22.04 AS runner
> # ... (same as above)
> COPY --from=builder /app/_build/release/my_app/bin/my_app ./my_app
> ```

### 4. Provision a Postgres database

```bash
fly postgres create --name my-app-db --region iad
fly postgres attach my-app-db --app my-app
# Fly sets DATABASE_URL automatically; adapt to your DB_* env vars
```

### 5. Set secrets

```bash
fly secrets set \
  SECRET_KEY_BASE=$(forge bastion.gen.secret) \
  DB_HOST=my-app-db.internal \
  DB_NAME=my_app \
  DB_USER=postgres \
  DB_PASS=<generated-by-fly-postgres>
```

All secrets are available as environment variables at runtime. Never commit secrets to `fly.toml`.

### 6. Database migrations as a release hook

Fly supports **release commands** — a short-lived process that runs before the new deployment goes live. Add to `fly.toml`:

```toml
[deploy]
  release_command = "./my_app migrate"
```

This tells Fly to run `./my_app migrate` in a temporary machine with the new image before routing traffic to it. If the command exits non-zero, the deployment is aborted and the old version keeps serving traffic.

Wire the `migrate` subcommand in your app's entry point:

```march
-- lib/app.march (or wherever your main/1 is)
fn main(args) do
  match args do
  Cons("migrate", _) -> do
    let _ = MyApp.Repo.start()
    let result = Depot.Migrate.run(MyApp.Repo)
    match result do
    Ok(n)  -> println("Ran " ++ int_to_string(n) ++ " migration(s)")
    Err(e) -> do println("Migration failed: " ++ e) ; exit(1) end
    end
  end
  Cons("start", _) -> MyApp.start()
  _                -> MyApp.start()
  end
end
```

### 7. Deploy

```bash
# First deploy (builds locally, pushes image):
fly deploy

# Subsequent deploys:
MARCH_ENV=prod forge bastion.release --embed-assets
fly deploy --local-only   # push pre-built binary
```

### Fly secrets management

Update a secret without redeploying:

```bash
fly secrets set SOME_KEY=new-value
```

Fly automatically restarts machines when secrets change. Use `fly secrets list` to audit (values are never shown).

---

## Bare VPS

Tested on Ubuntu 22.04 LTS. Steps are the same for Debian 12.

### 1. Provision the server

Minimum: 1 vCPU, 512 MB RAM for small apps. Recommended: 2 vCPU, 1 GB RAM.

```bash
# On your local machine — copy the binary
MARCH_ENV=prod forge bastion.release --embed-assets
scp _build/release/my_app/bin/my_app user@yourserver:/opt/my_app/bin/my_app
ssh user@yourserver "chmod +x /opt/my_app/bin/my_app"
```

### 2. Environment file

```bash
# /etc/my_app/env  (mode 600, owned by appuser)
PORT=4000
SECRET_KEY_BASE=<64+-char random string>
DB_HOST=localhost
DB_NAME=my_app_prod
DB_USER=my_app
DB_PASS=<postgres password>
DB_POOL_SIZE=10
LOG_LEVEL=info
MARCH_ENV=prod
```

```bash
sudo install -d -o root -g root -m 755 /etc/my_app
sudo install -o root -g appuser -m 640 /dev/stdin /etc/my_app/env <<EOF
# paste env vars here
EOF
```

### 3. systemd service

```ini
# /etc/systemd/system/my_app.service
[Unit]
Description=My App (Bastion)
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=exec
User=appuser
Group=appuser
WorkingDirectory=/opt/my_app
EnvironmentFile=/etc/my_app/env
ExecStartPre=/opt/my_app/bin/my_app migrate
ExecStart=/opt/my_app/bin/my_app start
ExecStop=/bin/kill -s TERM $MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

# Hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/var/log/my_app

[Install]
WantedBy=multi-user.target
```

Key: `ExecStartPre` runs migrations before the server starts. On failure (`my_app migrate` exits non-zero), systemd aborts the start and the old process (if any) keeps running.

```bash
sudo systemctl daemon-reload
sudo systemctl enable my_app
sudo systemctl start my_app
sudo journalctl -u my_app -f   # follow logs
```

### 4. Database migrations (release hook)

Migrations run automatically via `ExecStartPre` above. For manual runs:

```bash
sudo -u appuser /opt/my_app/bin/my_app migrate
```

For rollback:

```bash
sudo -u appuser /opt/my_app/bin/my_app rollback
```

Wire these in `main/1` alongside `start` (see the Fly.io section above).

### 5. Nginx reverse proxy

```nginx
# /etc/nginx/sites-available/my_app
upstream app {
    server 127.0.0.1:4000;
    keepalive 64;
}

server {
    listen 80;
    server_name myapp.com www.myapp.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name myapp.com www.myapp.com;

    ssl_certificate     /etc/letsencrypt/live/myapp.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myapp.com/privkey.pem;

    # WebSocket support (Channels / islands)
    location /socket/ {
        proxy_pass http://app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }

    location / {
        proxy_pass http://app;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
    }
}
```

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d myapp.com -d www.myapp.com
sudo nginx -t && sudo systemctl reload nginx
```

### 6. Zero-downtime deploys on VPS

Bastion handles graceful shutdown: on SIGTERM, it stops accepting new connections and waits up to 30 seconds for in-flight requests to complete. Use this for rolling deploys:

```bash
# deploy.sh — run this from CI or locally
set -euo pipefail

BINARY=_build/release/my_app/bin/my_app
REMOTE=user@yourserver
DEST=/opt/my_app/bin/my_app

# Build
MARCH_ENV=prod forge bastion.release --embed-assets

# Copy new binary alongside current one
scp $BINARY $REMOTE:${DEST}.new
ssh $REMOTE "chmod +x ${DEST}.new"

# Run migrations first
ssh $REMOTE "sudo -u appuser ${DEST}.new migrate"

# Atomically swap and restart
ssh $REMOTE "sudo mv ${DEST}.new ${DEST} && sudo systemctl restart my_app"
```

The `mv` is atomic on the same filesystem. The old binary keeps running through its SIGTERM until all requests drain, then the new binary starts.

---

## Health Checks

Both Fly.io and nginx/load-balancers poll `GET /health`. Wire it in your router:

```march
import Bastion.Health

-- In your pipeline:
conn |> Health.plug()

-- With custom checks:
conn |> Health.plug_with_checks([
  ("depot", fn -> Depot.ping(MyApp.Repo.pool()) end),
  ("vault", fn -> Ok(()) end),
])
```

Response on healthy:

```json
{"status":"ok","checks":{"depot":"ok","vault":"ok"}}
```

Response on degraded (returns HTTP 503):

```json
{"status":"degraded","checks":{"depot":"error","vault":"ok"}}
```

---

## Structured Logs

In production (`MARCH_ENV=prod`), Bastion emits JSON log lines:

```json
{"time":"2026-04-16T14:23:01.123Z","level":"info","msg":"GET /users 200","req_id":"a1b2c3","duration_ms":12}
```

Pipe to your log aggregator of choice (Fly log shipping, Datadog, Loki, CloudWatch).

Set `LOG_LEVEL=debug` for verbose output during a deployment to verify correctness, then switch back to `info`.

---

## Environment Variables Reference

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `PORT` | No | `4000` | HTTP listen port |
| `SECRET_KEY_BASE` | **Yes** | — | ≥64 chars; generate with `forge bastion.gen.secret` |
| `DB_HOST` | If using Depot | — | Postgres host |
| `DB_PORT` | No | `5432` | Postgres port |
| `DB_NAME` | If using Depot | — | Database name |
| `DB_USER` | If using Depot | — | Postgres user |
| `DB_PASS` | If using Depot | — | Postgres password |
| `DB_POOL_SIZE` | No | `10` | Connection pool size |
| `MARCH_ENV` | No | `prod` | `dev` \| `test` \| `prod` |
| `LOG_LEVEL` | No | `info` | `debug` \| `info` \| `warn` \| `error` |

---

## Multi-Node (TODO)

Single-node deployment is fully supported today. For horizontal scaling:

- **Stateless request handling**: works immediately — standard load balancer distribution, no sticky sessions needed
- **Vault**: currently in-memory per-node. A distributed Vault backend (replicated across nodes) is on the roadmap; in the meantime, use Redis for shared state (rate limiting, sessions, caching) via a future `Bastion.Vault.Redis` adapter
- **PubSub / Channels**: currently in-process per-node. Cross-node broadcasting (needed for multi-node channel fan-out) requires a distributed PubSub backend — also on the roadmap
- **WebSocket affinity**: until distributed PubSub lands, configure your load balancer for WebSocket sticky sessions (`cookie` or `ip_hash` in nginx)

See `specs/open-questions.md` §7 for the distributed Vault design discussion.
