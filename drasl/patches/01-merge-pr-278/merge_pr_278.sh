#!/bin/bash
DESCRIPTION="Merge PR #278 (Friends system, P2P Multiplayer)"

set -x  # Debug output

cd "$1"

# Ensure git identity is set for merge commit
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Add PR #278 fork as a remote
git remote add pr-278 https://github.com/catfromplan9/drasl.git 2>/dev/null || true

# Fetch the specific branch with full history (shallow clone can cause merge issues)
git fetch pr-278 implement-p2p-multiplayer --unshallow 2>/dev/null || git fetch pr-278 implement-p2p-multiplayer

# Show what we fetched
git branch -a | grep pr-278

# Merge the PR branch. Prefer the PR side only where the current upstream
# has conflicting edits: the patch's purpose is to carry the Friends/P2P
# implementation, while non-conflicting upstream changes are retained.
git merge --no-edit -X theirs pr-278/implement-p2p-multiplayer

# Do not let unresolved markers reach the build or produce a misleading cache
# success marker.
if git diff --name-only --diff-filter=U | grep -q .; then
    echo "PR merge left unmerged paths"
    exit 1
fi
if grep -R -n -E '^(<<<<<<<|=======|>>>>>>>)' --exclude-dir=.git .; then
    echo "PR merge left unresolved conflict markers"
    exit 1
fi

echo "PR merge completed without unresolved conflicts"
