# privacy-masking

Server-side prompt masking for new-api, powered by magpie's rule engine. The
builtin request plugin `request-mask` is only JS glue: it calls a Go host
function that runs magpie. No database change. The admin dashboard stores
metadata only.

## What it does

- Add the builtin `request-mask` request plugin (global or per group) to mask
  JSON relay requests. Its `ingress`/`egress` hooks call magpie's `MaskJSON`
  through `utils.magpieMaskJSON`.
- Secrets and personal data become stable magpie placeholders before the body
  is forwarded upstream.
- `privacy.Middleware()` wraps the response writer with magpie's `redact.Writer`,
  so placeholders in normal and streamed responses are restored.
- WebSocket/realtime requests are skipped by the response wrapper.
- The plugin config exposes `secrets` and `personal`; no database or option
  table changes are needed.

## How it works

`001-privacy-masking.sh` fetches magpie at build time because its rule engine
lives under an `internal` package:

- `MAGPIE_REPO` (default `https://github.com/yetone/magpie.git`)
- `MAGPIE_REF` (default `main`; branch, tag or commit)
- `MAGPIE_DIR` (default `<build>/.upstream-repos/magpie-src`, a local cache)

`001` copies only the production files of `internal/redact` and
`internal/lazyre`, rewrites the internal import path, and writes the response
wrapper under `privacy/`. `002` adds the insight store, admin API and dashboard.
`003` adds the builtin `request-mask` plugin and exposes `utils.magpieMaskJSON`
to its JS hooks.

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
- `pkg/jsplugin/utils.go`: one import and one `utils.magpieMaskJSON` entry.
- `plugins/builtin_plugins_test.go`: add `request-mask` to the expected list.
- Dashboard registration in `web/src/features/dashboard/` (or
  `web/default/src/features/dashboard/` on older trees) and i18n keys.

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

## request-mask plugin

`003-request-mask-plugin.sh` adds a builtin request plugin named
`request-mask`. In the admin UI it appears as **Request mask (Magpie)** /
**请求脱敏（Magpie）**. Configure an instance globally or per group to enable
masking. Its config has two booleans:

- `secrets`: API keys, tokens, private keys and passwords (default true)
- `personal`: emails, phone numbers, ID and bank card numbers (default true)

The JS hook only serializes the body and calls `utils.magpieMaskJSON`, which
runs the Go magpie engine and records insight metadata. Response restoration is
handled by `privacy.Middleware()` at the HTTP writer layer, so the plugin does
not need a reply hook to replace text.
## Limitations

- Channels using new-api pass-through mode forward the raw body and bypass all
  new-api processing, including masking.
- The optional local-model detector in magpie is intentionally not enabled;
  detection is rule-based only.
- If a model rewrites a placeholder instead of echoing it verbatim, that value
  cannot be restored and the placeholder is returned as-is.
