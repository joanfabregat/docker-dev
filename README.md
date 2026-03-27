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
   - `traefik.enable=true` — required since Traefik is configured with `exposedByDefault=false`
   - `traefik.http.routers.<name>.rule` — the `Host()` match for your subdomain
   - `traefik.http.routers.<name>.tls=true` — enables TLS (the wildcard certificate is applied automatically)
   - `traefik.http.services.<name>.loadbalancer.server.port` — the port your container listens on
2. Create an external Docker network in your project's `docker-compose.yml` and attach it to your service:
   ```yaml
   networks:
     myproject-network:
       external: true
   ```
3. Add that network to `docker-compose.yml` in this repo:
   ```yaml
   # under services.traefik.networks:
   - myproject-network

   # under networks:
   myproject-network:
     external: true
   ```
4. Create the network and restart:
   ```bash
   docker network create myproject-network
   docker compose restart
   ```

## Adding a Kubernetes project

When a project runs on Docker Desktop's built-in Kubernetes, add the Kubernetes Ingress provider to Traefik and create an Ingress resource with `ingressClass: traefik-dev`. See [issue #2](https://github.com/joanfabregat/docker-dev/issues/2) for details.

## Files

```
docker-compose.yml        # Traefik v3 container
config/dynamic.yaml       # TLS certificate configuration
config/certs/             # Wildcard certificate for *.dev.ffwip.com
```
