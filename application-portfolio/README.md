# Application Portfolio Manager (D + vibe.d)

A lightweight **Application Portfolio Management (APM)** web app built with **D** and **vibe.d**.

## What it covers

- **Inventory Management**
  - Complete application list with ownership, licensing, usage, and cost
- **Assessment & Metrics**
  - Business value, functional quality, technical health, strategic alignment
- **Rationalization**
  - Decision per application: **Invest**, **Tolerate**, **Migrate**, or **Retire**
- **Strategic Alignment**
  - Capability mapping and alignment scoring
- **Transparency**
  - Dashboard summary with key counts, risks, costs, and decision breakdown

## Prerequisites

- D toolchain (`dmd`, `ldc`, or `gdc`)
- `dub`

## Run

```bash
cd application-portfolio
dub run
```

Open: http://127.0.0.1:8080

## Routes

- `GET /` - dashboard + application inventory
- `GET /applications/new` - create form
- `POST /applications` - create application
- `GET /applications/:id` - details page
- `GET /applications/:id/edit` - edit form
- `POST /applications/:id` - update application
- `POST /applications/:id/delete` - delete application

## Notes

- Data is stored in memory for quick prototyping.
- Seed data is included to show realistic APM use cases immediately.
