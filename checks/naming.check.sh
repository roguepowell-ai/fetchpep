#!/usr/bin/env bash
# Fails when a contract file is named outside the convention.
#
# Deliberately narrow. Code naming belongs to a language linter once code exists — C#
# already has strong community conventions and prose about them is dead weight. What a
# linter cannot see is whether a CONTRACT file is findable, and that is what the double
# extension is for: the kind is visible in every listing and every diff.
set -euo pipefail
fail=0

# $1 dir   $2 extended-regex the filename must match   $3 upper|lower stem rule
check_dir() {
  [ -d "$1" ] || return 0
  local f b stem
  for f in "$1"/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    [ "$b" = "README.md" ] && continue
    if ! printf '%s' "$b" | grep -qE "$2"; then
      echo "FAIL naming: $f does not match the convention for $1/  ($2)"
      fail=1; continue
    fi
    stem="${b%%.*}"
    if [ "$3" = upper ] && ! printf '%s' "$stem" | grep -qE '^[A-Z][A-Z0-9-]*$'; then
      echo "FAIL naming: $f — stem should be UPPER-KEBAB, got \"$stem\""
      fail=1
    fi
    if [ "$3" = lower ] && ! printf '%s' "$stem" | grep -qE '^[a-z][a-z0-9-]*$'; then
      echo "FAIL naming: $f — stem should be lower-kebab, got \"$stem\""
      fail=1
    fi
  done
}

check_dir rules          '\.rule\.md$'          upper
check_dir spec           '\.spec\.md$'          upper
check_dir ops            '\.ops\.md$'           upper
check_dir state          '\.state\.md$'         upper
check_dir .claude/rules  '\.md$'                lower
check_dir checks         '\.(check\.sh|txt)$'   lower
check_dir hooks          '\.(mjs|js)$'          lower

[ "$fail" -eq 0 ] && echo "ok naming: contract files follow the convention"
exit "$fail"
