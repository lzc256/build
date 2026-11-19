# privacy-masking

Server-side, always-on prompt masking for new-api, powered by magpie's rule
engine. No setting, no database change. The admin dashboard stores metadata only.

## What it does

- On every JSON relay request under `/v1/` or `/v1beta/`, the body is passed
  through `redact.MaskJSON` from magpie before new-api parses and forwards it.
- The response writer is wrapped with magpie's `redact.Writer`, so placeholders
  in both normal and streamed responses are restored to their original values.
- WebSocket/realtime requests are skipped (the HTTP writer is not used there).
- Masking is global and always on. There is no option to disable it at runtime.

## How it works

`001-privacy-masking.sh` is a patch script (not a `.patch` file) because the
magpie engine is fetched at build time instead of being copied into this repo:

- `MAGPIE_REPO` (default `https://github.com/yetone/magpie.git`)
- `MAGPIE_REF` (default `main`; branch, tag or commit)
- `MAGPIE_DIR` (default `<build>/.upstream-repos/magpie-src`, a local cache)

The script clones/fetches magpie, copies only the production files of
`internal/redact` and `internal/lazyre` into the target tree, rewrites the
internal import path, writes our small glue package under `privacy/`, and adds
one middleware hook to `router/relay-router.go`.

Magpie is MIT licensed. Its LICENSE is copied to
`internal/privacy/redact/LICENSE` in the build tree, and `privacy/NOTICE`
records the exact commit used.

## Why a shell patch

Go's `internal` package rule prevents importing
`github.com/yetone/magpie/internal/redact` from another module. Fetching at
build time keeps this repository free of magpie source while still following
upstream updates automatically.

## Upstream changes touched

- `router/relay-router.go`: one import line and one
  `router.Use(privacy.Middleware())` line.
- `router/api-router.go`: one import line and one
  `privacy.RegisterAdminRoutes(adminRoute)` line.
- Dashboard registration in `web/default/src/features/dashboard/` and two i18n
  keys (`en.json`, `zh.json`).

All new logic lives in newly created files, so new-api upgrades rarely conflict.

## Dashboard

`002-privacy-insights.sh` adds a magpie-style "Privacy Masking" tab to the
default admin dashboard. It uses magpie's `Options.Seen` callback and stores
only:

- time, request id, route, model and user id
- `Kind`, `By`, `Action`
- placeholder, `Head` and `Len`

No original value is ever written to disk.

Storage is a JSONL file, not a database:

- default: `data/privacy-masking.jsonl`
- override: `PRIVACY_INSIGHTS_PATH`
- path is relative to the new-api process working directory (Docker: `/app`)
- retention: 30 days, max 100000 lines
- cleanup runs hourly on startup

Admin API endpoints:

- `GET /api/privacy/masking/summary?days=7`
- `GET /api/privacy/masking/events?days=7&limit=100`
- `DELETE /api/privacy/masking/events`

## Limitations

- Channels using new-api pass-through mode forward the raw body and bypass all
  new-api processing, including masking.
- The optional local-model detector in magpie is intentionally not enabled;
  detection is rule-based only.
- If a model rewrites a placeholder instead of echoing it verbatim, that value
  cannot be restored and the placeholder is returned as-is.
