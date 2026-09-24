#!/usr/bin/env bash
# Fails when ops/VERSIONS.ops.md disagrees with what is actually pinned in the repo.
#
# The point is not to police tidiness. Code written against the wrong version of a
# package or an API compiles, passes review, and fails in production — and the version
# is the one thing an agent cannot infer from the code in front of it.
set -euo pipefail
fail=0
M=ops/VERSIONS.ops.md
[ -f "$M" ] || { echo "FAIL versions: $M is missing"; exit 1; }

note() { echo "      $1"; }

# --- 1. Unity editor version, if a project exists --------------------------------
pv=$(find . -name ProjectVersion.txt -path '*/ProjectSettings/*' 2>/dev/null | head -1)
if [ -n "$pv" ]; then
  actual=$(grep -oE 'm_EditorVersion: .*' "$pv" | awk '{print $2}' | tr -d '\r')
  if ! grep -qF "$actual" "$M"; then
    echo "FAIL versions: Unity Editor is $actual but $M does not record it."
    fail=1
  fi
fi

# --- 2. No floating ranges in any lockfile-bearing manifest ----------------------
while IFS= read -r f; do
  bad=$(grep -nE '"(\^|~|\*|latest)' "$f" 2>/dev/null || true)
  if [ -n "$bad" ]; then
    echo "FAIL versions: $f contains a floating range. Pin it exactly."
    echo "$bad" | head -5 | sed 's/^/      /'
    fail=1
  fi
done < <(find . -name package.json -not -path './node_modules/*' \
              -o -name manifest.json -path '*/Packages/*' 2>/dev/null)

# --- 3. Never :latest in a container reference -----------------------------------
latest=$(grep -rn --include='*.tf' --include='*.yml' --include='*.yaml' \
           --include='Dockerfile*' --exclude-dir=.git -- ':latest' . 2>/dev/null || true)
if [ -n "$latest" ]; then
  echo "FAIL versions: ':latest' is used. An unpinned image is an unreproducible build."
  echo "$latest" | head -5 | sed 's/^/      /'
  fail=1
fi

# --- 4. TBD entries are a warning until that thing exists, then an error ---------
tbd=$(grep -c '`TBD`' "$M" || true)
if [ "$tbd" -gt 0 ]; then
  note "note versions: $tbd entries still TBD in $M — fill each one when that thing is installed"
fi

[ "$fail" -eq 0 ] && echo "ok versions: manifest agrees with what is pinned"
exit "$fail"
