#!/usr/bin/env bash
# Move the fork onto a newer official Genex release: replay the fork's commits on top of the new tag.
#
# Usage: fork/scripts/sync-upstream.sh [vX.Y.Z]   (default: the newest upstream release tag)
# Then: fix any conflicts (git rebase --continue), run fork/scripts/check.sh, fork/scripts/install.sh, and
# git push --force-with-lease origin main. Local tags fork-before-<tag> are never pushed.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
cd "$REPO"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/genex-games/genex-desktop.git
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "commit or stash your changes first" >&2; exit 1; }

OLD=$(cat fork/BASE)
git fetch --quiet upstream --tags
NEW=${1:-$(git tag --list 'v*' --sort=-v:refname | head -1)}
git rev-parse -q --verify "refs/tags/$NEW" >/dev/null || { echo "no tag $NEW upstream" >&2; exit 1; }
if [ "$NEW" = "$OLD" ]; then echo "already on $OLD"; exit 0; fi

BRANCH=$(git branch --show-current)
git tag -f "fork-before-$NEW" HEAD >/dev/null   # the pre-sync fork, to go back to: git reset --hard fork-before-<tag>
echo "== rebase $BRANCH: $OLD -> $NEW ($(git rev-list --count "$OLD"..HEAD) fork commits)"
git rebase --onto "$NEW" "$OLD" "$BRANCH"
echo "$NEW" > fork/BASE
git commit --quiet -m "fork: base $NEW" fork/BASE
echo "== on $NEW. Next: fork/scripts/check.sh, fork/scripts/install.sh --restart, then git push --force-with-lease origin main"
