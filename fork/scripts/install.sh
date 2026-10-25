#!/usr/bin/env bash
# Build this fork and install it over the local Genex (Linux x64).
#
# The fork changes only the app code (app.asar's dist/). Everything else — Electron, its libraries,
# node_modules — comes from the official release of the same version (fork/BASE), downloaded once
# and checked against the release's SHA256SUMS. A release build of an unpatched tree reproduces the
# official dist/ byte for byte (apart from a timestamp), so the result differs only by the patches.
#
# Usage: fork/scripts/install.sh [--restart] [--no-build]
#   --restart   stop a running Genex, install, start it again (otherwise a running Genex is refused)
#   --no-build  reuse the existing dist/ (after a build you already ran)
# Env: GENEX_DIR (default ~/.local/lib/genex), GENEX_FORK_CACHE (default ~/.cache/genex-fork)
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
DEST=${GENEX_DIR:-$HOME/.local/lib/genex}
CACHE=${GENEX_FORK_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/genex-fork}
RELEASES=https://github.com/genex-games/genex-desktop/releases/download
RESTART=0
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=1 ;;
    --no-build) BUILD=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Node 24 is what the repo builds with (package.json engines); mise provides it when the system node differs.
if node -v 2>/dev/null | grep -q '^v24\.'; then NODE=(); else NODE=(mise exec node@24 --); fi
run() { "${NODE[@]}" "$@"; }

TAG=$(cat "$REPO/fork/BASE")
VER=${TAG#v}
PKG_VER=$(run node -p "require('$REPO/package.json').version")
[ "$PKG_VER" = "$VER" ] || { echo "package.json is $PKG_VER but fork/BASE is $TAG: fix BASE after a sync" >&2; exit 1; }

cd "$REPO"
[ -d node_modules/@electron/asar ] || run npm ci --ignore-scripts --no-audit --no-fund
if [ "$BUILD" = 1 ]; then
  echo "== build ($TAG + fork patches)"
  run node scripts/build.mjs --release
fi
[ -f dist/main/app.mjs ] || { echo "no dist/: run without --no-build" >&2; exit 1; }

# The official release this fork sits on, verified.
ZIP=Genex-linux-x64-$VER.zip
STOCK=$CACHE/stock-$VER
if [ ! -d "$STOCK/Genex-linux-x64" ]; then
  echo "== download official $ZIP"
  mkdir -p "$CACHE"
  curl -fL --retry 3 -o "$CACHE/$ZIP" "$RELEASES/$TAG/$ZIP"
  curl -fL --retry 3 -o "$CACHE/SHA256SUMS-$VER" "$RELEASES/$TAG/SHA256SUMS"
  (cd "$CACHE" && grep " $ZIP\$" "SHA256SUMS-$VER" | sha256sum -c -)
  rm -rf "$STOCK" && mkdir -p "$STOCK"
  unzip -q "$CACHE/$ZIP" -d "$STOCK"
fi

ASAR=(run node "$REPO/node_modules/@electron/asar/bin/asar.js")
[ -f "$REPO/node_modules/@electron/asar/bin/asar.js" ] || ASAR=(run npx --yes @electron/asar)

STAGE=$CACHE/stage
rm -rf "$STAGE" && mkdir -p "$STAGE"
echo "== assemble"
cp -a "$STOCK/Genex-linux-x64" "$STAGE/genex"
"${ASAR[@]}" extract "$STOCK/Genex-linux-x64/resources/app.asar" "$STAGE/app"
rm -rf "$STAGE/app/dist"
(cd "$REPO" && find dist -type f ! -name '*.map' -print0 | cpio -0pdm --quiet "$STAGE/app")
COMMIT=$(git -C "$REPO" rev-parse --short HEAD)
DIRTY=$(git -C "$REPO" status --porcelain -- src | grep -q . && echo true || echo false)
printf '{"base":"%s","commit":"%s","dirty":%s,"built":"%s"}\n' "$TAG" "$COMMIT" "$DIRTY" "$(date -Is)" > "$STAGE/app/dist/FORK.json"
rm -rf "$STAGE/genex/resources/app.asar" "$STAGE/genex/resources/app.asar.unpacked"
"${ASAR[@]}" pack "$STAGE/app" "$STAGE/genex/resources/app.asar" \
  --unpack-dir "{dist/resources,**/sandbox-runtime,**/node-pty}"
# asar extract drops file modes: give back the executable bits the official build ships
# (the sandbox's apply-seccomp, node-pty's spawn-helper, …), or Genex starts with no sandbox.
(cd "$STOCK/Genex-linux-x64/resources/app.asar.unpacked" && find . -type f -perm -u+x -print0) |
  while IFS= read -r -d '' f; do
    [ -f "$STAGE/genex/resources/app.asar.unpacked/$f" ] && chmod +x "$STAGE/genex/resources/app.asar.unpacked/$f"
  done
rm -rf "$STAGE/app"

running() { pgrep -f "^$DEST/genex" >/dev/null; }
if running; then
  [ "$RESTART" = 1 ] || { echo "Genex is running: quit it, or pass --restart" >&2; exit 1; }
  echo "== stop Genex"
  pkill -f "^$DEST/genex" || true
  for _ in $(seq 40); do running || break; sleep 0.25; done
fi

BACKUP=$DEST.bak-$(date +%Y%m%d-%H%M%S)
[ -d "$DEST" ] && mv "$DEST" "$BACKUP"
mv "$STAGE/genex" "$DEST"
echo "== installed $TAG + fork $COMMIT at $DEST (previous copy: ${BACKUP})"

if [ "$RESTART" = 1 ]; then
  setsid "$DEST/genex" >/dev/null 2>&1 < /dev/null &
  echo "== started Genex"
fi
