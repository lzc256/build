# privacy-masking

Server-side prompt masking for new-api, powered by magpie's rule engine and an
optional AstrLink Guard local PII model. The builtin request plugin
`request-mask` is only JS glue: it calls a Go host function that runs magpie.
No database change. The admin dashboard stores metadata only.

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
- Optionally enable AstrLink Guard v1 (int8 ONNX, about 37 MB) to catch full
  names, addresses and passwords that the rules miss. Its model files are
  downloaded at runtime, not stored in this repository or the image.
- The plugin config exposes `secrets`, `personal`, `names`, `model` and
  `names_by_model`; no database or option table changes are needed.

## How it works

New static files live in `.patch` files; only dynamic work and edits to existing
upstream files stay as shell patches:

- `../privacy-masking-engine/001-fetch-magpie.sh` fetches magpie at build time.
- `001-privacy-core.patch`, `002-request-mask-plugin.patch` and
  `003-privacy-dashboard.patch` add the Go core, plugin and dashboard.
- `004-privacy-model.patch` adds `privacy/model.go` and the admin model routes;
  `005-privacy-model-ui.patch` adds the settings card.
- `../privacy-masking-hooks/001-wire-hooks.sh` edits existing router, jsplugin,
  plugin-test and frontend files.

The engine patch uses:

- `MAGPIE_REPO` (default `https://github.com/yetone/magpie.git`)
- `MAGPIE_REF` (default `main`; branch, tag or commit)
- `MAGPIE_DIR` (default `<build>/.upstream-repos/magpie-src`, a local cache)

The engine script copies only the production files of `internal/redact`,
`internal/lazyre` and `internal/pii/guard`, and rewrites the internal import
paths. The patch files add the response wrapper, insight store, admin API,
dashboard, model manager and builtin plugin. The hooks script wires them into
new-api.

Magpie is MIT licensed. Its LICENSE is copied to
`internal/privacy/redact/LICENSE` in the build tree, and `privacy/NOTICE`
records the exact commit used. AstrLink Guard model files are Apache-2.0 and
are downloaded at runtime from `QuantumNous/astrlink-guard`; they are not part
of the repository or image.

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
- writes are asynchronous: requests enqueue events, one writer appends batches
- `PRIVACY_INSIGHTS_FLUSH_FREQUENCY` sets events per batch (default `100`)
- partial batches flush every second, so low traffic still lands promptly
- queue holds 4096 events; when full, new events are dropped and counted
- the summary API/UI exposes the dropped count

Admin API endpoints:

- `GET /api/user/privacy/masking/summary?days=7`
- `GET /api/user/privacy/masking/events?days=7&limit=100`
- `DELETE /api/user/privacy/masking/events`

## AstrLink Guard model

The optional local model is a pure-Go int8 ONNX classifier, so no native
`pf-serve` binary is needed. It is process-global, not per plugin instance:

- config file: `data/privacy-model.json`
  (override: `PRIVACY_MODEL_CONFIG_PATH`)
- default model root: `data/privacy-models`
  (override per install from the plugin settings card)
- download endpoint: `HF_ENDPOINT` (default `https://huggingface.co`)
  can point at a mirror such as `https://hf-mirror.com`
- actual directory: `<root>/astrlink-guard/<revision-prefix>`
- pinned files: `model_int8.onnx`, `model_int8.onnx_data`, `tokenizer.json`
- size: about 37 MB total, verified with SHA-256
- idle unload: 10 minutes by default; `0` keeps it loaded
- the first masked request after download loads the model lazily
- if loading fails, masking continues with rules and configured names

Admin API endpoints:

- `GET /api/user/privacy/model/status`
- `POST /api/user/privacy/model/download`
- `POST /api/user/privacy/model/cancel`
- `POST /api/user/privacy/model/config`
- `POST /api/user/privacy/model/unload`

The dashboard only shows metadata. The settings card lives in the `request-mask`
plugin editor, not in the sidebar.

## request-mask plugin

`002-request-mask-plugin.patch` adds a builtin request plugin named
`request-mask`. In the admin UI it appears as **Request mask (Magpie)** /
**请求脱敏（Magpie）**. Add an instance globally or per group to enable masking.
Its config has:

- `secrets`: API keys, tokens, private keys and passwords (default true)
- `personal`: emails, phone numbers, ID and bank card numbers (default true)
- `names`: one name per line; always masked, with or without the model
- `model`: `off` or `astrlink` (default `off`)
- `names_by_model`: let AstrLink Guard find full names, with rules adding
  nicknames (default true; shown when `model` is `astrlink`)

The JS hook serializes the body and calls `utils.magpieMaskPatch`, which runs
the Go magpie engine, records insight metadata and returns only changed leaf
operations. Response restoration is handled by `privacy.Middleware()` at the
HTTP writer layer.

## Limitations

- Channels using new-api pass-through mode forward the raw body and bypass all
  new-api processing, including masking.
- If a model rewrites a placeholder instead of echoing it verbatim, that value
  cannot be restored and the placeholder is returned as-is.
