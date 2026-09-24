#!/usr/bin/env bash
# Fails when a contract file exists that nothing routes to.
# This is the check that matters. A contract file nothing references is not merely
# unread — after a compaction it is unreachable.
set -euo pipefail
fail=0
routers=$(ls CLAUDE.md .claude/rules/*.md 2>/dev/null || echo CLAUDE.md)
for f in $(find rules state spec ops .claude/rules -type f \( -name '*.md' -o -name '*.sh' \) 2>/dev/null | sort); do
  base=$(basename "$f")
  if ! grep -qF "$base" $routers 2>/dev/null; then
    echo "FAIL router-orphans: $f is routed to by nothing."
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "ok router-orphans: no unreachable contract files"
exit "$fail"
