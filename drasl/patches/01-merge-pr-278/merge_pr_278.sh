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

# Keep current upstream versions of coordinated files. Add the small state and
# configuration surface required by the new friends/signaling files below.
if ! grep -q 'FriendsETagStore' main.go; then
    perl -i -0pe 's/(HeartbeatSaltMap\s+map\[ServerKey\]heartbeatSaltEntry\n)/$1\tPresenceStore *PresenceStore\n\tFriendsETagStore *FriendsETagStore\n\tFriendshipLocks *friendshipLocks\n\tSignalingHub *SignalingHub\n\tTURN *embeddedTURN\n/' main.go
fi
if ! grep -q 'FriendsETagStore: NewFriendsETagStore' main.go; then
    perl -i -0pe 's/(HeartbeatLruList:\s+heartbeatLruList,\n)/$1\t\tPresenceStore: NewPresenceStore(),\n\t\tFriendsETagStore: NewFriendsETagStore(),\n\t\tFriendshipLocks: newFriendshipLocks(),\n\t\tSignalingHub: NewSignalingHub(),\n/' main.go
fi
# Always normalize the non-persisted client token field. A simple global grep
# is insufficient because Pmid also appears in JWT claims.
perl -i -ne 'print unless /Pmid string `gorm/' model.go
perl -i -0pe 's/(type Client struct \{\n)/$1\tPmid string `gorm:"-"`\n/' model.go
if ! grep -q 'FriendsEnabled' model.go; then
    perl -i -0pe 's/(Clients\s+\[\]Client `gorm:"constraint:OnDelete:CASCADE"`\n)/$1\tFriendsEnabled bool\n\tAcceptInvitesEnabled bool\n/' model.go
fi
if ! grep -q 'type Friendship struct' model.go; then
    cat >> model.go <<'EOF'

type Friendship struct {
    ID uint `gorm:"primaryKey"`
    RequesterUUID string `gorm:"uniqueIndex:friendship_pair_idx;not null"`
    RecipientUUID string `gorm:"uniqueIndex:friendship_pair_idx;not null;index"`
    Status string `gorm:"not null;default:pending"`
    CreatedAt time.Time
    UpdatedAt time.Time
}
EOF
fi

if ! grep -q 'type signalingConfig struct' config.go; then
    perl -i -0pe 's/(type Config struct \{)/type TURNServerConfig struct {\n\tUrls []string\n\tUsername string\n\tPassword string\n\tSecret string\n}\n\ntype signalingConfig struct {\n\tEnable bool\n\tTURNListenAddress string\n\tTURNPublicIP string\n\tTURNAuthSecret string\n}\n\n$1/' config.go
    perl -i -0pe 's/(type Config struct \{\n)/$1\tP2P signalingConfig\n/' config.go
fi
if ! grep -q 'ExternalTURNServers' config.go; then
    perl -i -0pe 's/(type Config struct \{\n)/$1\tExternalTURNServers []TURNServerConfig\n/' config.go
fi
# Current upstream already defines these aliases. Remove every copy brought
# by either side of the merge, then append one canonical set.
perl -i -ne 'print unless /^\s*type V6(User|Player|Client|UserOIDCIdentity) = /' db.go
cat >> db.go <<'EOF'

type V6User = User
type V6Player = Player
type V6Client = Client
type V6UserOIDCIdentity = UserOIDCIdentity
EOF

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
