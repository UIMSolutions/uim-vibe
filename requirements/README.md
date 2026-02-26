# Wiki App (D + vibe.d)

This project is a lightweight wiki web application built with **D** and **vibe.d**.

## Features

- List all wiki pages
- Create new pages with automatic slug generation
- View individual pages
- Edit page title and content
- Delete pages
- In-memory storage for quick development

## Prerequisites

- D toolchain (`dmd`, `ldc`, or `gdc`)
- `dub`

## Run

```bash
cd requirements
dub run
```

Open: http://127.0.0.1:8080

## Routes

- `GET /` - wiki home and page list
- `GET /new` - create form
- `POST /pages` - create page
- `GET /pages/:slug` - view page
- `GET /pages/:slug/edit` - edit form
- `POST /pages/:slug` - update page
- `POST /pages/:slug/delete` - delete page

## Notes

- Data is stored in memory and resets when the server restarts.