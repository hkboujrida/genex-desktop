#!/usr/bin/env bash
# Type-check the fork and run the tests that cover its patches (see fork/PATCHES.md).
# The full upstream suite is `npm run check`; this is the quick gate before installing.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
cd "$REPO"
if node -v 2>/dev/null | grep -q '^v24\.'; then NODE=(); else NODE=(mise exec node@24 --); fi
[ -d node_modules ] || "${NODE[@]}" npm ci --ignore-scripts --no-audit --no-fund

echo "== typecheck"
"${NODE[@]}" npm run --silent typecheck
echo "== patch tests"
"${NODE[@]}" node scripts/test.mjs \
  tests/conformance/engine-opencode.test.ts \
  tests/conformance/engine-delegated.test.ts
