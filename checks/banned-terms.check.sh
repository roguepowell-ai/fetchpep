#!/usr/bin/env bash
# Fails when a banned term appears outside the files that define it.
# Backstop only — hooks/guard-write.mjs blocks these before they are written.
#
# Matches WHOLE WORDS (grep -w). Substring matching produced false positives on
# compound identifiers — PowerShell's Get-ChildItem tripped "child" — and a check
# that cries wolf is a check that gets switched off.
#
# A line may be exempted by ending it with:  <!-- allow-term: why -->
# Use it only where naming the term IS the content, such as a decision log entry
# recording that the term was retired. Every exemption is visible in the diff.
set -euo pipefail
fail=0
[ -f checks/banned-terms.txt ] || { echo "ok banned-terms: no list"; exit 0; }
while IFS= read -r term; do
  [ -z "$term" ] && continue
  case "$term" in \#*) continue ;; esac
  hits=$(grep -rniIw --exclude-dir=.git --exclude-dir=node_modules \
           --exclude-dir=Library --exclude-dir=checks --exclude-dir=rules \
           -- "$term" . 2>/dev/null | grep -v 'allow-term' || true)
  if [ -n "$hits" ]; then
    echo "FAIL banned-terms: \"$term\" appears outside the contract files:"
    echo "$hits" | head -10 | sed 's/^/      /'
    fail=1
  fi
done < checks/banned-terms.txt
[ "$fail" -eq 0 ] && echo "ok banned-terms: clean"
exit "$fail"
