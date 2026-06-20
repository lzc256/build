# Drasl - Custom Build

Builds [unmojang/drasl](https://github.com/unmojang/drasl) with [PR #278](https://github.com/unmojiang/drasl/pull/278) (Friends system / P2P Multiplayer) merged, plus a Web UI patch for Friends settings.

## Image

- `ghcr.io/lzc256/build:drasl` (latest)
- `ghcr.io/lzc256/build:drasl-<version>` (versioned)

## Patches

- **merge-pr-278**: Merges PR #278 (`catfromplan9/drasl:implement-p2p-multiplayer`) into master
- **add-friends-webui**: Adds `FriendsEnabled` / `AcceptInvitesEnabled` checkboxes to player Web UI (3 patch files, one per Go/template file)
