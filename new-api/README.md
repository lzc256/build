# Balance Script Documentation

This document describes the custom balance script feature for new-api channels.

## Overview

Balance scripts allow you to fetch channel balance using custom Python code. This is useful for providers that don't have built-in balance API support, or for implementing custom authentication/login flows.

**Important**: Scripts MUST call `balance.set()` to return the balance. `print()` is disabled.

## API Reference

### `newapi.environ` (dict, read-only)

Channel input parameters:

| Key | Description |
|-----|-------------|
| `CHANNEL_BASE_URL` | Channel's base URL |
| `CHANNEL_KEY` | API key (for multi-key channels: first key only) |
| `CHANNEL_TYPE` | Channel type integer |
| `CHANNEL_ID` | Channel ID |
| `CHANNEL_IS_MULTI_KEY` | `"1"` if multi-key channel, `"0"` otherwise |

### `newapi.state` — State Persistence

For saving login tokens, session data, etc. across balance checks.

| Method | Description |
|--------|-------------|
| `state.get()` | Returns previous state as JSON-parsed object, or `{}` on first run |
| `state.getRaw()` | Returns previous state as raw string, or `""` on first run |
| `state.save(obj)` | Save state (any JSON-serializable object) |
| `state.saveRaw(s)` | Save state as raw string |

State size limit: 65536 bytes.

### `newapi.balance` — Result Output (Required)

| Method | Description |
|--------|-------------|
| `balance.set(value)` | Set channel balance (float). **Must be called exactly once.** |

### `newapi.debug` — Debug Output

| Method | Description |
|--------|-------------|
| `debug.log(*args, **kwargs)` | Write to stderr (visible in error messages) |

## Available Python Modules

Only Python standard library is available:

- `urllib`, `urllib.request`, `urllib.parse`, `urllib.error` — HTTP requests
- `json` — JSON parsing
- `math`, `datetime`, `re` — Utilities
- `base64`, `hashlib`, `hmac` — Encoding/crypto
- `time`, `ssl`, `socket`, `http` — Low-level networking
- `collections`, `itertools`, `functools` — Data structures
- `string`, `random`, `secrets`, `uuid` — String/ID generation
- `decimal` — Precise decimals

`os`, `sys`, `subprocess`, `print()`, and other modules/functions with filesystem/system access are **not available**.

## Example Scripts

### Basic Balance Fetch

```python
import urllib.request, json
from newapi import environ, balance

url = environ["CHANNEL_BASE_URL"] + "/v1/user/balance"
req = urllib.request.Request(url, headers={
    "Authorization": "Bearer " + environ["CHANNEL_KEY"]
})
with urllib.request.urlopen(req, timeout=15) as resp:
    data = json.loads(resp.read())

balance.set(data["balance"])
```

### With State Persistence (Login Token)

```python
import urllib.request, json
from newapi import environ, state, balance

# Load previous state (returns {} on first run)
s = state.get()
token = s.get("token")

# If no token, login first
if not token:
    login_url = environ["CHANNEL_BASE_URL"] + "/v1/login"
    login_req = urllib.request.Request(
        login_url,
        data=json.dumps({"username": "user", "password": "pass"}).encode(),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(login_req, timeout=15) as resp:
        login_data = json.loads(resp.read())
        token = login_data["token"]
        s["token"] = token
        state.save(s)

# Fetch balance with token
url = environ["CHANNEL_BASE_URL"] + "/v1/user/balance"
req = urllib.request.Request(url, headers={
    "Authorization": "Bearer " + token
})
with urllib.request.urlopen(req, timeout=15) as resp:
    data = json.loads(resp.read())

balance.set(data["balance"])

# Update state if token refreshed
if "new_token" in data:
    s["token"] = data["new_token"]
    state.save(s)
```

### Debugging

```python
import urllib.request, json
from newapi import environ, balance, debug

debug.log("Fetching balance for channel:", environ["CHANNEL_ID"])

url = environ["CHANNEL_BASE_URL"] + "/v1/user/balance"
req = urllib.request.Request(url, headers={
    "Authorization": "Bearer " + environ["CHANNEL_KEY"]
})
with urllib.request.urlopen(req, timeout=15) as resp:
    data = json.loads(resp.read())

debug.log("Balance response:", data)
balance.set(data["balance"])
```

## Security

Scripts run with the following restrictions:

1. **RestrictedPython**: Blocks dangerous attributes (`__subclasses__`, `__globals__`, etc.)
2. **Import whitelist**: Only allowed modules can be imported
3. **seccomp**: System call filtering
   - Allowed: read, write, network I/O, read-only file open
   - Blocked: execve, fork, clone, write operations, file modification
4. **prlimit**: Resource limits
   - 30 second timeout
   - 128MB memory
   - 25s CPU time
   - 64 max processes
5. **print() disabled**: Use `newapi.debug.log()` for debug output

## Error Handling

Script errors are returned as:

```json
{"error": "error message"}
```

Common errors:

- `module 'xxx' is not allowed` — Tried to import a blocked module
- `balance script timed out` — Exceeded 30s timeout
- `balance script state exceeds 65536 bytes` — State too large
- `balance.set() was never called` — Script didn't set balance
- `print() is disabled in balance scripts` — Used `print()` instead of `debug.log()`
