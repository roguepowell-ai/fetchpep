#!/usr/bin/env bash
# Refuses a push when any contract check fails.
#
# This is NOT a replacement for a server-side gate — a human can bypass it with
# --no-verify, and it does not exist in a fresh clone until core.hooksPath is set.
# It earns its place for a different reason: it fails in SECONDS, locally, before
# the push leaves the machine. CI takes a minute and needs a round trip. For an
# agent working in a loop, the difference between 3 seconds and 90 is the
# difference between a tight loop and a slow one.
#
# Enable once per clone:
#   git config core.hooksPath .githooks
set -uo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || true
if [ -z "$root" ]; then
  echo "pre-push: not inside a git work tree — refusing rather than guessing." >&2
  exit 1
fi
cd "$root" || exit 1

checks=(
  router-size router-links router-orphans
  frontmatter banned-terms secrets versions naming
)

echo "── contract checks ──"
fail=0
for c in "${checks[@]}"; do
  f="checks/$c.check.sh"
  [ -f "$f" ] || { echo "   SKIP $c (missing)"; continue; }
  if ! out=$(bash "$f" 2>&1); then
    echo "$out" | sed 's/^/   /'
    fail=1
  else
    echo "$out" | sed 's/^/   /'
  fi
done

if [ "$fail" -ne 0 ]; then
  cat <<'MSG'

Push refused: a contract check failed.

Fix the cause, not the check — unless the check is wrong, in which case fix the
check and prove both directions before pushing it.

To push anyway:  git push --no-verify
Doing that is a decision. If you find yourself doing it twice, the check is wrong
or the rule is, and one of them needs changing rather than skipping.
MSG
  exit 1
fi

echo "── all green ──"
exit 0
