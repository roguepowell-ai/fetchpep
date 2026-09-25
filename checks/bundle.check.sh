#!/usr/bin/env bash
# D-097. Fails when services/nakama/build/index.js is not what src/ compiles to.
#
# Nakama loads one JavaScript file, the VM has no build step, and there is no image registry
# of ours — so infra/dev/vm_nakama.tf reads the built file with `file()` and delivers it in
# instance metadata. That makes the committed bundle the thing that actually runs. Without
# this check, editing `src/` and forgetting to rebuild ships the *old* module, and editing
# `build/index.js` by hand ships something no source describes. Neither leaves a trace.
#
# It rebuilds into a temporary directory and compares. It never writes to the working tree,
# so running it can neither fix nor dirty the thing it is checking.
#
# CI only. It needs the npm registry, and the pre-push hook is meant to fail in seconds.
set -euo pipefail

SERVICE=services/nakama
BUNDLE="$SERVICE/build/index.js"

[ -f "$BUNDLE" ] || { echo "FAIL bundle: $BUNDLE is missing. Run 'npm run build' in $SERVICE."; exit 1; }

command -v npm >/dev/null 2>&1 || { echo "FAIL bundle: npm is not on PATH."; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# `npm ci`, not `npm install`: it installs exactly what package-lock.json says and fails if
# the lock file disagrees with package.json. A check that quietly resolved a different
# TypeScript would be checking the wrong compiler (ops/VERSIONS.ops.md rule 2).
( cd "$SERVICE" && npm ci --silent --no-audit --no-fund ) >/dev/null

# --outFile on the command line, so the committed bundle is never the target.
( cd "$SERVICE" && ./node_modules/.bin/tsc -p tsconfig.json --outFile "$tmp/index.js" )

if ! cmp -s "$BUNDLE" "$tmp/index.js"; then
  echo "FAIL bundle: $BUNDLE is not what $SERVICE/src compiles to (D-097)."
  echo "      committed: $(sha256sum < "$BUNDLE" | cut -c1-16)   rebuilt: $(sha256sum < "$tmp/index.js" | cut -c1-16)"
  echo "      First difference:"
  diff <(cat "$BUNDLE") <(cat "$tmp/index.js") | head -8 | sed 's/^/      /'
  echo "      Fix it by rebuilding, never by editing the bundle:"
  echo "        cd $SERVICE && npm ci && npm run build"
  exit 1
fi

echo "ok bundle: $BUNDLE matches $SERVICE/src ($(wc -c < "$BUNDLE") bytes)"
