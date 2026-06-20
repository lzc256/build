#!/bin/bash
DESCRIPTION="Merge PR #278 (Friends system, P2P Multiplayer)"

cd "$1"

# Ensure git identity is set for merge commit
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Add PR #278 fork as a remote
git remote add pr-278 https://github.com/catfromplan9/drasl.git 2>/dev/null || true
git fetch pr-278 implement-p2p-multiplayer

# Merge the PR branch
git merge --no-edit pr-278/implement-p2p-multiplayer
