# DNS Resolver (D + vibe.d)

A DNS resolver demo web app built with D and vibe.d.

## Features and Use Cases Covered

- URL/host input and resolution to IP address
- Resolver cache with TTL for faster repeated lookups
- Recursive lookup trace visualization:
  - root server step
  - TLD server step
  - authoritative server step
- Resolver provider mode:
  - ISP/system recursive resolver
  - Google Public DNS (8.8.8.8 via DNS-over-HTTPS)
  - Cloudflare (1.1.1.1 via DNS-over-HTTPS)
- Stub resolver explanation and behavior (client sends request to recursive resolver)
- Cache table, cache hit indicator, and manual cache clear action
- Health endpoint for container and Kubernetes probes

## Run Locally

```bash
cd dns-resolver
dub run
```

Open: http://127.0.0.1:8080

## Podman

```bash
cd dns-resolver
podman build -t dns-resolver:latest -f Containerfile .
podman run --rm -p 8080:8080 dns-resolver:latest
```

## Kubernetes

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl port-forward svc/dns-resolver 8080:8080
```

Open: http://127.0.0.1:8080

## Routes

- `GET /` : web UI and optional resolve result
- `POST /resolve` : resolve target and render result
- `GET /healthz` : health probe endpoint
- `POST /cache/clear` : clear cache

## Notes

- DNS provider behavior for Google/Cloudflare uses DNS-over-HTTPS APIs.
- ISP mode uses the system resolver (`getent`) as a practical recursive resolver.
- Cache is in-memory and resets on restart.
