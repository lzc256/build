# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Multi-Project Patch Framework** — a build/CI system for managing patches across multiple projects. It clones target repositories, applies patch scripts, and runs builds via GitHub Actions.

## Common Commands

```bash
# Apply a patch to a target directory
source scripts/common.sh
apply_patch <patch_name> <target_dir>

# Example: apply patch to zeroclaw project
git clone https://github.com/zeroclaw-labs/zeroclaw.git zeroclaw
apply_patch finalize_draft zeroclaw
git diff zeroclaw
```

## Architecture

The framework operates across multiple project directories, each with its own `patches/` subdirectory:

```
.
├── scripts/
│   └── common.sh              # Core apply_patch function
├── zeroclaw/                  # zeroclaw project patches
│   └── patches/
│       ├── zeroclaw_matrix_partial.sh
│       ├── channel_matrix_partial_draft_Thinking.sh
│       └── disable_high_entropy_redaction.sh
├── other-project/             # Placeholder for additional projects
├── .github/workflows/         # CI workflows trigger builds
└── README.md
```

**How it works:**
1. `apply_patch` searches all `{project}/patches/` directories for the named `.sh` file
2. Each patch script is executed with the target directory as argument
3. CI workflows (`.github/workflows/*.yml`) run builds after patches are applied

## Adding a New Project

1. Create project directory and patches subdirectory: `mkdir -p new-project/patches`
2. Add patch scripts (see patch format below)
3. Create corresponding GitHub Actions workflow in `.github/workflows/`

## Patch Script Format

```bash
#!/bin/bash
DESCRIPTION="Description of what this patch does"

# Apply sed/perl replacements to files
sed -i '' 's/old/new/' "$1/src/file.rs"
```

The target directory path is passed as `$1` to the patch script.

## Linked Context

The `zeroclaw-src/` subdirectory contains the full ZeroClaw Rust project with its own AGENTS.md. For questions about ZeroClaw itself (Rust architecture, crates, channels, providers), refer to `zeroclaw-src/AGENTS.md`.