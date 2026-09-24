#!/usr/bin/env bash
# Fails when CLAUDE.md references a path that does not exist.
# Caught real drift once already: three dead routes after a rename.
set -euo pipefail
fail=0
paths=$(
  { grep -oE '`[A-Za-z0-9_./-]+\.(md|sh|sql|txt|mjs|json)`' CLAUDE.md | tr -d '`'
    grep -oE '^@[A-Za-z0-9_./-]+' CLAUDE.md | sed 's/^@//'
  } | sort -u
)
for p in $paths; do
  case "$p" in
    *'**'*) continue ;;
  esac
  if [ ! -e "$p" ]; then
    echo "FAIL router-links: CLAUDE.md routes to $p — which does not exist."
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "ok router-links: every route resolves"
exit "$fail"
