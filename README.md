# docker-dev

Shared Docker infrastructure for local development. Runs a **Traefik v3** reverse proxy on ports 80/443 that auto-discovers routes from Docker container labels and terminates TLS using a wildcard certificate for `*.dev.ffwip.com`.

## How it works

```
Browser → https://classic.sophos.dev.ffwip.com
       → DNS resolves to 127.0.0.1
       → Traefik (port 443) terminates TLS
       → reads Host header, matches a router rule
       → proxies to the upstream container (e.g. sophos-pomerium:80)
```

Traefik discovers routes automatically from Docker container labels — no shared config file to edit when projects change.

## Projects

| Domain pattern | Upstream | Network |
|---|---|---|
| `*.sophos.dev.ffwip.com` | `sophos-pomerium:80` | `sophos-network` |
| `*.aritas.dev.ffwip.com` | `aritas-si:80` / `aritas-si-encore:9000` / `aritas-si-phpmyadmin:80` | `aritas-network` |
| `dtpdf.dev.ffwip.com` | `dtpdf-web:5173` | `dtpdf-network` |
| `traefik.dev.ffwip.com` | Traefik dashboard | — |

## Prerequisites

- Docker Desktop running
- Project networks must exist (created by each project's `docker compose up`)
- All `*.dev.ffwip.com` domains must resolve to `127.0.0.1`

## Usage

```bash
# Start the proxy
cd ~/Code/docker-dev
docker compose up -d

# Check the dashboard
open https://traefik.dev.ffwip.com
```

Then start any project normally — Traefik picks up its routes from container labels automatically.

## Adding a new Docker project

1. Add Traefik labels to the service in your project's `docker-compose.yml`:
   ```yaml
   labels:
     - traefik.enable=true
     - traefik.http.routers.myproject.rule=Host(`myproject.dev.ffwip.com`)
     - traefik.http.routers.myproject.tls=true
     - traefik.http.services.myproject.loadbalancer.server.port=8080
   ```
2. Add your project's Docker network to `docker-compose.yml` in this repo (under `services.traefik.networks` and `networks`)
3. Restart: `docker compose restart`

## Adding a Kubernetes project

When a project runs on Docker Desktop's built-in Kubernetes, add the Kubernetes Ingress provider to Traefik and create an Ingress resource with `ingressClass: traefik-dev`. See [issue #2](https://github.com/joanfabregat/docker-dev/issues/2) for details.

## Files

```
docker-compose.yml        # Traefik v3 container
config/dynamic.yaml       # TLS certificate configuration
config/certs/             # Wildcard certificate for *.dev.ffwip.com
```
