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

# Merge the PR branch while preserving current upstream definitions when the
# old PR branch conflicts with newer migrations. Non-conflicting additions,
# especially friends.go/signaling.go and their tests, are retained.
if git merge --no-commit -X ours pr-278/implement-p2p-multiplayer; then
    echo "PR merge completed without conflicts"
else
    echo "Resolving conflicts in favor of current upstream files"
    git diff --name-only --diff-filter=U | while IFS= read -r file; do
        git checkout --ours -- "$file"
        git add -- "$file"
    done
fi

# The P2P implementation needs coordinated changes across the application
# object, model, config, and service routes. The PR branch contains those
# changes; use its versions for these files, while retaining the current
# upstream db.go migration history to avoid duplicate V6 declarations.
for file in config.go main.go model.go player.go services.go; do
    git show pr-278/implement-p2p-multiplayer:"$file" > "$file"
done
perl -i -0pe 's/\nfunc LogInfo\(args \.\.\.any\) \{.*?\n\}\n//s; s/\nfunc LogError\(args \.\.\.any\) \{.*?\n\}\n//s' main.go
if ! grep -q 'type V6Friendship = Friendship' db.go; then
    perl -i -0pe 's/(type V6UserOIDCIdentity = UserOIDCIdentity\n)/$1type V6Friendship = Friendship\n/' db.go
fi

git add -A
git commit --no-edit

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

echo "PR merge completed without unresolved conflict markers"
