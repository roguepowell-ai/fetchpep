#!/usr/bin/env bash
# Fails when a commit authored by Claude touches an authority: george-only file.
# The hook refuses the write. This catches anything that got in another way.
set -euo pipefail
BASE="${1:-origin/main}"
fail=0
for f in $(git diff --name-only "$BASE"...HEAD 2>/dev/null || true); do
  [ -f "$f" ] || continue
  if sed -n '1,12p' "$f" 2>/dev/null | grep -q '^authority:\s*george-only'; then
    who=$(git log -1 --format='%an %ae' -- "$f")
    case "$who" in
      *[Cc]laude*|*noreply@anthropic.com*)
        echo "FAIL authority: $f is george-only but was changed by: $who"
        fail=1 ;;
    esac
  fi
done
[ "$fail" -eq 0 ] && echo "ok authority: no george-only files changed by Claude"
exit "$fail"
