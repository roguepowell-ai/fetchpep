#!/usr/bin/env bash
# D-097. Fails when services/nakama/build/index.js is not what src/ compiles to.
#
# Nakama loads one JavaScript file, the VM has no build step, and there is no image registry
# of ours — so infra/dev/vm_nakama.tf reads the built file with `file()` and delivers it in
# instance metadata. That makes the committed bundle the thing that actually runs. Without
# this check, editing `src/` and forgetting to rebuild ships the *old* module, and editing
# `build/index.js` by hand ships something no source describes. Neither leaves a trace.
#
# **It builds in a copy.** The sources go to a temporary directory and `npm ci` and `tsc`
# run there, so the check touches nothing in the working tree — not the bundle it is
# judging, and not `node_modules`, which an in-place `npm ci` would have deleted and
# rebuilt under whoever ran it.
#
# CI only. It needs the npm registry, and the pre-push hook is meant to fail in seconds.
set -euo pipefail

SERVICE=services/nakama
BUNDLE="$SERVICE/build/index.js"

[ -f "$BUNDLE" ] || { echo "FAIL bundle: $BUNDLE is missing. Run 'npm run build' in $SERVICE."; exit 1; }

command -v npm >/dev/null 2>&1 || { echo "FAIL bundle: npm is not on PATH."; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp -R "$SERVICE/src" "$tmp/src"
cp "$SERVICE/tsconfig.json" "$SERVICE/package.json" "$SERVICE/package-lock.json" "$tmp/"

# `npm ci`, not `npm install`: it installs exactly what package-lock.json says and fails if
# the lock file disagrees with package.json. A check that quietly resolved a different
# TypeScript would be checking the wrong compiler (ops/VERSIONS.ops.md rule 2).
#
# `--ignore-scripts`: a check should not run a dependency's install hooks. Output is kept
# and printed only on failure, because an npm error that goes to /dev/null is a check that
# fails with no reason given.
if ! npm ci --prefix "$tmp" --ignore-scripts --no-audit --no-fund >"$tmp/npm.log" 2>&1; then
  echo "FAIL bundle: 'npm ci' failed in $SERVICE. Is package-lock.json in step with package.json?"
  tail -15 "$tmp/npm.log" | sed 's/^/      /'
  exit 1
fi

if ! "$tmp/node_modules/.bin/tsc" -p "$tmp/tsconfig.json" --outFile "$tmp/rebuilt.js" >"$tmp/tsc.log" 2>&1; then
  echo "FAIL bundle: $SERVICE/src does not compile."
  tail -15 "$tmp/tsc.log" | sed 's/^/      /'
  exit 1
fi

if ! cmp -s "$BUNDLE" "$tmp/rebuilt.js"; then
  echo "FAIL bundle: $BUNDLE is not what $SERVICE/src compiles to (D-097)."
  echo "      committed: $(sha256sum < "$BUNDLE" | cut -c1-16)   rebuilt: $(sha256sum < "$tmp/rebuilt.js" | cut -c1-16)"
  echo "      First difference:"
  diff "$BUNDLE" "$tmp/rebuilt.js" | head -8 | sed 's/^/      /'
  echo "      Fix it by rebuilding, never by editing the bundle:"
  echo "        cd $SERVICE && npm ci && npm run build"
  exit 1
fi

echo "ok bundle: $BUNDLE matches $SERVICE/src ($(wc -c < "$BUNDLE") bytes)"
