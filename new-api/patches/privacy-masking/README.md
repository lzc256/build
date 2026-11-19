# privacy-masking

Server-side prompt masking for new-api, powered by magpie's rule engine. The
builtin request plugin `request-mask` is only JS glue: it calls a Go host
function that runs magpie. No database change. The admin dashboard stores
metadata only.

## What it does

- Add the builtin `request-mask` request plugin (global or per group). Its
  `ingress` hook calls `utils.magpieMaskPatch`; the Go host runs magpie and
  returns only the changed leaf operations. `egress` is intentionally read-only
  because that stage rejects effects.
- Fields containing media placeholders such as `[media:0]` are skipped in those
  operations, which avoids `invalid_effect` on requests with attachments.
- Secrets and personal data become stable magpie placeholders before the body
  is forwarded upstream.
- `privacy.Middleware()` wraps the response writer with magpie's `redact.Writer`,
  so placeholders in normal and streamed responses are restored.
- WebSocket/realtime requests are skipped by the response wrapper.
- The plugin config exposes `secrets` and `personal`; no database or option
  table changes are needed.

## How it works

New static files live in `.patch` files; only dynamic work and edits to existing
upstream files stay as shell patches:

- `../privacy-masking-engine/001-fetch-magpie.sh` fetches magpie at build time.
- `001-privacy-core.patch`, `002-request-mask-plugin.patch` and
  `003-privacy-dashboard.patch` add the new Go, plugin and dashboard files.
- `../privacy-masking-hooks/001-wire-hooks.sh` edits existing router, jsplugin,
  plugin-test and frontend files.

The engine patch uses:

- `MAGPIE_REPO` (default `https://github.com/yetone/magpie.git`)
- `MAGPIE_REF` (default `main`; branch, tag or commit)
- `MAGPIE_DIR` (default `<build>/.upstream-repos/magpie-src`, a local cache)

The engine script copies only the production files of `internal/redact` and
`internal/lazyre` and rewrites the internal import path. The patch files add
the response wrapper, insight store, admin API, dashboard and builtin plugin.
The hooks script wires them into new-api.

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
- `pkg/jsplugin/utils.go`: import plus `utils.magpieMaskJSON` and
  `utils.magpieMaskPatch`.
- `plugins/builtin_plugins_test.go`: add `request-mask` to the expected list.
- Admin-only sidebar entry at `/dashboard/privacy`, i18n keys and a lazy
  component mount. There is intentionally no dashboard tab.

All new logic lives in newly created files, so new-api upgrades rarely conflict.

## Dashboard

The hooks patch adds a magpie-style "Privacy Masking" page under the admin
sidebar at `/dashboard/privacy`. It uses magpie's `Options.Seen` callback and
stores only:

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

- `GET /api/user/privacy/masking/summary?days=7`
- `GET /api/user/privacy/masking/events?days=7&limit=100`
- `DELETE /api/user/privacy/masking/events`

## request-mask plugin

`002-request-mask-plugin.patch` adds a builtin request plugin named
`request-mask`. In the admin UI it appears as **Request mask (Magpie)** /
**请求脱敏（Magpie）**. Add an instance globally or per group to enable masking.
Its config has two booleans:

- `secrets`: API keys, tokens, private keys and passwords (default true)
- `personal`: emails, phone numbers, ID and bank card numbers (default true)

The JS hook serializes the body and calls `utils.magpieMaskPatch`, which runs
the Go magpie engine, records insight metadata and returns only changed leaf
operations. Response restoration is handled by `privacy.Middleware()` at the
HTTP writer layer.
## Limitations

- Channels using new-api pass-through mode forward the raw body and bypass all
  new-api processing, including masking.
- The optional local-model detector in magpie is intentionally not enabled;
  detection is rule-based only.
- If a model rewrites a placeholder instead of echoing it verbatim, that value
  cannot be restored and the placeholder is returned as-is.
