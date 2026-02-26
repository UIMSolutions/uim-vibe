# Service Portfolio Manager (D + vibe.d)

A lightweight Service Portfolio Management application built with D and vibe.d.

## Covered Service Portfolio Capabilities

- Service lifecycle tracking:
  - Service Pipeline (in design/development)
  - Service Catalog (active and customer-facing)
  - Retired Services (phased out)
- Strategic view:
  - Alignment score per service and overall dashboard metrics
- Value optimization:
  - Cost, annual value estimate, risk score, and redundancy indicators
- Lifecycle management:
  - Create, assess, transition, and retire services
- Service Design Package (SDP):
  - SDP owner, summary, and last review metadata

## Data Model Highlights

Each service includes:

- identity and ownership
- lifecycle stage
- strategic alignment score (1-5)
- value score (1-5)
- risk score (1-5)
- annual cost and annual value estimate
- customer visibility and service domain
- SDP details

## Run Locally

1. Go to project folder:

   cd service-portfolio

2. Build or run:

   dub run

3. Open:

   http://127.0.0.1:8080

## Podman

Build image:

podman build -t service-portfolio:latest -f Containerfile .

Run container:

podman run --rm -p 8080:8080 service-portfolio:latest

## Kubernetes

Apply manifests:

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

Port-forward for local access:

kubectl port-forward svc/service-portfolio 8080:8080

Then open:

http://127.0.0.1:8080

## Routes

- GET / : dashboard and portfolio table
- GET /services/new : create service form
- POST /services : create service
- GET /services/:id : view details
- GET /services/:id/edit : edit service
- POST /services/:id : update service
- POST /services/:id/delete : delete service
- GET /healthz : health endpoint for probes

## Notes

- Data is in-memory for prototype speed.
- Seed data is included for pipeline, catalog, and retired examples.
