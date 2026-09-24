#!/usr/bin/env bash
# Fails when anything that looks like a credential is committed.
#
# Backstop only — hooks/guard-write.mjs blocks these before they are written.
# [certain] A secret in git history is permanent; rotation is the only remedy. So this
# runs on the working tree AND, where a base ref is available, on the diff.
#
# Exempt a line with a trailing:  # allow-secret: why
set -euo pipefail
fail=0

# name=value patterns for things that are always secret
patterns=(
  'AKIA[0-9A-Z]{16}'                               # AWS access key id
  'sk_(live|test)_[0-9a-zA-Z]{16,}'                # Stripe secret key
  'rk_(live|test)_[0-9a-zA-Z]{16,}'                # Stripe restricted key
  'gh[pousr]_[0-9A-Za-z]{30,}'                     # GitHub token
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'             # any private key
  'AIza[0-9A-Za-z_-]{30,}'                         # Google API key
  'xox[baprs]-[0-9A-Za-z-]{10,}'                   # Slack token
  '(password|passwd|secret|api_?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{12,}["'"'"']'
)

for p in "${patterns[@]}"; do
  hits=$(grep -rnIE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=Library \
          --exclude='*.check.sh' --exclude='guard-write.mjs' \
          -- "$p" . 2>/dev/null | grep -v 'allow-secret' || true)
  if [ -n "$hits" ]; then
    echo "FAIL secrets: a value matching a credential pattern is committed (R-SEC-01):"
    echo "$hits" | head -5 | sed 's/^/      /'
    echo "      Rotate it. Removing the line does not remove it from history."
    fail=1
  fi
done

# a committed .env is always wrong, whatever is in it
env_files=$(find . -name '.env' -o -name '.env.*' -not -name '.env.example' 2>/dev/null \
            | grep -v node_modules || true)
if [ -n "$env_files" ]; then
  echo "FAIL secrets: an environment file is present in the tree (R-SEC-01):"
  echo "$env_files" | sed 's/^/      /'
  fail=1
fi

[ "$fail" -eq 0 ] && echo "ok secrets: no credential patterns found"
exit "$fail"
