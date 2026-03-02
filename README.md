# docker-dev-env

Shared Docker infrastructure for local development. Runs an nginx SNI proxy on ports 80/443 that routes `*.dev.ffwip.com` traffic to the correct project's Pomerium based on the TLS hostname.

This allows multiple projects to run simultaneously without port conflicts — each project keeps its own Pomerium with its own auth config, certs, and routes.

## How it works

```
Browser → https://classic.sophos.dev.ffwip.com
       → DNS resolves to 127.0.0.1
       → nginx SNI proxy (port 443) reads TLS hostname
       → proxies raw TCP to sophos-pomerium:443
       → Pomerium terminates TLS & routes to the app container
```

nginx never decrypts TLS — it's a pure TCP pass-through using SNI inspection.

## Projects

| Domain pattern | Pomerium container | Network |
|---|---|---|
| `*.sophos.dev.ffwip.com` | `sophos-pomerium` | `sophos-network` |
| `*.aritas.dev.ffwip.com` | `aritas-si-pomerium` | `aritas-network` |

## Prerequisites

- Docker Desktop running
- Project networks must exist (created by each project's `docker compose up`)
- Each project's Pomerium must **not** bind to host ports 80/443

## Usage

```bash
# Start the SNI proxy
cd ~/Code/docker-dev
docker compose up -d

# Verify
docker logs sni-proxy
```

Then start any project normally — its Pomerium runs without host port bindings, and the SNI proxy routes traffic to it.

## Adding a new project

1. Edit `config/nginx.conf` — add a new map entry:
   ```nginx
   ~\.myproject\.dev\.ffwip\.com$    myproject-pomerium:443;
   ```
2. Edit `docker-compose.yml` — add the project's Docker network under `networks`
3. Reload: `docker compose restart`

## Files

```
docker-compose.yml      # SNI proxy container (nginx:alpine)
config/nginx.conf       # Stream-level SNI routing config
```
