#!/usr/bin/env bash
# Fails when a contract file has missing or invalid frontmatter.
# authority: is what the write guard and CI both read.
set -euo pipefail
fail=0
valid='george-only|claude-proposes|claude-writes'
for f in $(find rules state spec ops hooks checks .claude/rules -name '*.md' 2>/dev/null | sort); do
  [ "$f" = "CLAUDE.md" ] && continue
  if ! head -1 "$f" | grep -q '^---$'; then
    echo "FAIL frontmatter: $f has no frontmatter block."
    fail=1; continue
  fi
  a=$(sed -n '1,12p' "$f" | grep -oE "^authority:\s*($valid)\s*$" || true)
  if [ -z "$a" ]; then
    echo "FAIL frontmatter: $f has no valid authority: ($valid)."
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "ok frontmatter: every contract file declares authority"
exit "$fail"
