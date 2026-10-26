# Build version

The workflow follows upstream `main` on scheduled builds. A manual workflow
run can select a different upstream ref; patches target the current upstream layout.

The `build-version` patch writes the checked-out upstream commit's committer date
in `Asia/Shanghai` and its seven-character hash to `VERSION`, for example
`2026-07-04 23:42:03 (1ae7574)`. The upstream Dockerfile embeds this value in both
the frontend and backend, including the `/api/status` version displayed by the UI.
The date describes the source commit, not when the image was built. A runtime
`VERSION` environment variable overrides the embedded backend version.

# Active custom patches

- `balance-script`: sandboxed JavaScript channel balance scripts, state persistence and result messages.
- `self-use-default-price`: use model ratio 0.5 for unconfigured models in self-use mode.
- `billing-header-filter`: remove Claude Code billing-header markers from forwarded requests.
- `oauth-step-up`: offer linked OAuth for sensitive browser actions even with a password,
  Passkey or 2FA enrolled; prefer it in the dialog. Login second-factor policy,
  provider/account binding checks and single-use operation proofs stay in place.
  For built-in OIDC and custom providers with the `openid` scope, step-up requests
  include `prompt=login` and `max_age=0` to request fresh authentication from the
  identity provider (including Pocket ID). Ordinary login is unchanged.
- `build-version`: embed the checked-out source commit date and hash.
- `secondary-domain`: treat every host other than `ServerAddress` as a restricted
  entry point. A secondary domain answers `/api/status` as if the primary address,
  OIDC, Passkey and third-party sign-in had never been configured, rejects those
  endpoints with `403 PRIMARY_ORIGIN_REQUIRED`, and keeps payment redirects and
  Midjourney image URLs on the address the browser is using. See "Secondary
  domain" below.

Protocol conversion and model configuration use the upstream implementation.
The legacy `classic-build` script remains on disk but is not used by this workflow.

# Secondary domain

`ServerAddress` is the primary address: the one address that is fully featured.
Any other host the instance answers on is a secondary entry point. Visitors of a
secondary domain must not learn that the primary one exists, so there:

- `/api/status` returns an empty `server_address`, disabled `oidc_*`/`passkey_*`
  and no third-party provider ids. The SPA builds its links from
  `window.location.origin` when these values are empty, so it needs no change and
  shows only password sign-in.
- `/api/oauth/state`, `/api/oauth/{provider}`, the WeChat and Telegram OAuth
  routes and the Passkey login routes answer `403 PRIMARY_ORIGIN_REQUIRED`.
  Hiding a button is not enough: the routes themselves must refuse the request.
- `GET /api/verify/methods` drops linked-provider step-up verification, so
  sensitive actions fall back to the password.
- Payment return URLs, Stripe success/cancel URLs and Midjourney image URLs use
  the address of the request, so a buyer on the secondary domain stays there.

Deployment notes:

- `SERVER_ADDRESS` must name the primary domain (e.g. `https://panel.example.com`).
  Leave it empty only for a single-address deployment; an empty value keeps every
  request primary. The patch drops the upstream `http://localhost:3000`
  compile-time default so a fresh install cannot be mistaken for a secondary one.
- Both origins must be listed for session cookies:
  `SESSION_COOKIE_SECURE=true` and
  `SESSION_COOKIE_TRUSTED_URL=https://panel.example.com,https://shop.example.net`.
  Cookies carry no `Domain` attribute, so each domain keeps its own session.
- Epay (易支付) needs no fixed callback in its dashboard: `notify_url` and
  `return_url` are sent per order. `notify_url` stays on the primary address (or
  `CustomCallbackAddress`) because it is a server-to-server call the browser never
  sees; `return_url` follows the buyer's domain.
- The identity provider still needs `https://panel.example.com/oauth/oidc`
  registered. The secondary domain never starts an OIDC flow, so it needs none.
- Remaining, intentional leaks to review by content: `TaskPublicAddress`
  (pin it, or task artifact URLs fall back to `ServerAddress`), the
  administrator-authored `Notice`, `About`, `HomePageContent`, `DocsLink` and the
  console `ApiInfo` list. Do not put primary-domain links there.
- Administrators signed in on the secondary domain still see the full settings
  page, including `ServerAddress` and the OIDC configuration, because
  `/api/option/` is an authenticated admin endpoint.

# Balance Script Documentation

This document describes the custom balance script feature for new-api channels.

## Overview

Balance scripts fetch a channel balance by running a short JavaScript program on
an embedded engine (goja). Nothing is spawned: the script runs in-process, so
there is no interpreter binary, no pip package and no wrapper process.

**Important**: Scripts MUST call `newapi.balance.set()` to return the balance.
`print()`, `require()` and file/process/socket access do not exist.

### Dependency handling

The patch deliberately does not touch `go.mod`/`go.sum`. Pinning dependency
versions there means every upstream bump of the same lines conflicts, which
breaks the build for commits the patch would otherwise survive. Instead the
image resolves the runtime dependency itself:

```dockerfile
RUN go get github.com/dop251/goja@v0.0.0-20261024144015-2a9269b6b6de
```

Local builds therefore need the same step once after applying the patch.

## API Reference

### `newapi.environ` (object, read-only)

Channel input parameters:

| Key | Description |
|-----|-------------|
| `CHANNEL_BASE_URL` | Channel's base URL |
| `CHANNEL_KEY` | API key (for multi-key channels: all keys joined with `,`) |
| `CHANNEL_TYPE` | Channel type integer, as string |
| `CHANNEL_ID` | Channel ID, as string |
| `CHANNEL_IS_MULTI_KEY` | `"1"` if multi-key channel, `"0"` otherwise |

### `newapi.fetch(options)` — The Only Way Out

```js
const r = newapi.fetch({
  url: "https://example.com/v1/user/balance",  // required
  method: "GET",                                // optional, default GET
  headers: { Authorization: "Bearer " + key },   // optional
  body: "{\"a\":1}",                           // optional
});
// r -> { status: 200, headers: { ... }, body: "..." }
```

`options` may also be a plain URL string. `fetch` throws on failure, so wrap it
in `try`/`catch` when a provider has several endpoints.

| Limit | Value |
|-------|-------|
| Schemes | `http`, `https` only |
| Per-request timeout | 10s |
| Response body | 1 MiB (larger responses throw) |
| Calls per run | 16 |
| Redirects | 3 |
| Private / loopback / link-local targets | rejected |

### `newapi.state` — State Persistence

For saving login tokens, session data, etc. across balance checks.

| Method | Description |
|--------|-------------|
| `state.get()` | Previous state as parsed JSON, or `{}` on first run |
| `state.getRaw()` | Previous state as a raw string, or `""` on first run |
| `state.save(obj)` | Save state (any JSON-serializable value) |
| `state.saveRaw(s)` | Save a raw string |

State size limit: 65536 bytes. State is only written when the script saves it.

### `newapi.balance` — Result Output (Required)

| Method | Description |
|--------|-------------|
| `balance.set(value)` | Set channel balance (number). **Must be called at least once.** |

### `newapi.debug` — Result Message

| Method | Description |
|--------|-------------|
| `debug.log(...args)` | Collects a message line; arguments are joined with spaces |

Multiple calls produce multiple lines in the channel's result message. Total
message text is capped at 72 KiB; further lines are dropped.

## JavaScript Environment

Standard ECMAScript is available and nothing else: `JSON`, `Math`, `Date`,
`String`/`Array`/`Object` methods, regular expressions, `try`/`catch`,
`class`, closures, `let`/`const`, template strings. There is no `require()`,
no `process`, no timers and no `print()`.

## Example Scripts

### Basic Balance Fetch

```js
const url = newapi.environ.CHANNEL_BASE_URL + "/v1/user/balance";
const resp = newapi.fetch({
  url: url,
  headers: { Authorization: "Bearer " + newapi.environ.CHANNEL_KEY },
});
const data = JSON.parse(resp.body);

newapi.balance.set(data.balance);
```

### With State Persistence (Login Token)

```js
const s = newapi.state.get(); // {} on the first run
let token = s.token;

if (!token) {
  const login = newapi.fetch({
    url: newapi.environ.CHANNEL_BASE_URL + "/v1/login",
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: "user", password: "pass" }),
  });
  token = JSON.parse(login.body).token;
  s.token = token;
  newapi.state.save(s);
}

const resp = newapi.fetch({
  url: newapi.environ.CHANNEL_BASE_URL + "/v1/user/balance",
  headers: { Authorization: "Bearer " + token },
});
const data = JSON.parse(resp.body);

newapi.balance.set(data.balance);

if (data.new_token) {
  s.token = data.new_token;
  newapi.state.save(s);
}
```

### Picking A Field From A Provider List

```js
const PROVIDER = "trae-global";      // data[].provider
const WINDOW = "Dollar Usage";       // windows[].name
const AMOUNT_KEY = "remaining";      // field used as amount
const LIMIT_KEY = "limit";           // field used as the cap

const resp = newapi.fetch({
  url: newapi.environ.CHANNEL_BASE_URL + "/v1/magpie/quotas",
  headers: { Authorization: "Bearer " + newapi.environ.CHANNEL_KEY },
});

let item = {};
for (const provider of JSON.parse(resp.body).data) {
  if (provider.provider === PROVIDER) { item = provider; break; }
}

let win = {};
for (const window of item.windows || []) {
  if (window.name === WINDOW) { win = window; break; }
}
if (!win.name && (item.windows || []).length) { win = item.windows[0]; }

newapi.debug.log(item.name + " [" + win.name + "]");
newapi.balance.set(win[AMOUNT_KEY] || 0);
```

### Debugging

```js
newapi.debug.log("Channel:", newapi.environ.CHANNEL_ID);
const resp = newapi.fetch(newapi.environ.CHANNEL_BASE_URL + "/v1/user/balance");
newapi.debug.log("Response:", resp.status, resp.body);
newapi.balance.set(JSON.parse(resp.body).balance);
```

## Security and Limits

There is no process sandbox any more; isolation comes from the engine's empty
environment plus caps at every entry point:

1. **No host capability by default**: a fresh goja runtime only knows
   ECMAScript. File system, processes, sockets and `require()` are not exposed.
2. **Single egress path**: `newapi.fetch()` is the only network call, restricted
   to `http`/`https`, and it refuses loopback, private, link-local and multicast
   addresses (it dials the resolved IP itself, so DNS answers cannot change
   between the check and the connection).
3. **Entry-point limits**: 30s wall clock (the VM is interrupted, not killed),
   10s per request, 1 MiB per response, 16 fetches per run, 256 call depth,
   72 KiB of messages, 64 KiB of state, 64 KiB of script source.
4. **Panic isolation**: an exception escaping the engine is returned as a script
   error instead of crashing the process.

Known gap: there is no per-run memory cap. A runaway script can still allocate
through ordinary JS value construction; only the entry-point sizes above bound
it. Script authors are expected to be trusted channel administrators.

## Error Handling

Script errors are returned as `balance script error: ...` with the position of
the failure:

```
balance script error: TypeError: Cannot read property 'foo' of undefined
    at <balance_script>:2:6(5)
```

Common errors:

- `balance script error: ...` — the script threw (message includes line/column)
- `balance script error: newapi.balance.set() was never called` — no result set
- `balance script error: balance script timed out after 30s` — exceeded 30s
- `newapi.fetch(): unsupported scheme "file", only http and https are allowed`
- `newapi.fetch(): address 127.0.0.1 is not allowed` — private target blocked
- `newapi.fetch(): called more than 16 times`
- `newapi.fetch(): response body exceeds 1048576 bytes`
- `balance script error: TypeError: balance script state exceeds 65536 bytes`
- `balance script exceeds 65536 bytes` — the source itself is too large
