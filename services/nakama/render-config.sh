#!/bin/sh
# Renders nakama.yml into nakama.runtime.yml, replacing the four @@TOKEN@@ placeholders.
# Run on the VM at boot by the startup script, and by hand for a local run.
#
# Values come in as environment variables, never as arguments: an argument is visible in
# `ps` to every process on the host (R-SEC-06).
#
#   NAKAMA_DB_PASSWORD                     NAKAMA_SESSION_ENCRYPTION_KEY
#   NAKAMA_SERVER_KEY                      NAKAMA_SESSION_REFRESH_ENCRYPTION_KEY
#   NAKAMA_HTTP_KEY                        NAKAMA_CONSOLE_SIGNING_KEY
#   NAKAMA_CONSOLE_PASSWORD
#
# Every value must match ^[A-Za-z0-9_-]+$ and the script refuses to render otherwise. Two
# reasons: the substitution below is `sed`, so a value containing the delimiter would
# corrupt the file silently; and the database address is a URL, where a raw `@` or `:` in
# the password changes which host is being connected to. Secret Manager values are created
# by `openssl rand -base64 33 | tr '+/' '-_'`, which stays inside that set — see
# infra/dev/secrets.tf.
set -eu

here=$(dirname "$0")
src="$here/nakama.yml"
out="${1:-$here/nakama.runtime.yml}"

require() {
  name=$1
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    echo "render-config: $name is not set" >&2
    exit 1
  fi
  # No shell glob, no sed delimiter, nothing that changes a URL's meaning.
  case $value in
    *[!A-Za-z0-9_-]*)
      echo "render-config: $name contains a character outside [A-Za-z0-9_-]. Rotate it to a value that does not; see the header." >&2
      exit 1
      ;;
  esac
}

require NAKAMA_DB_PASSWORD
require NAKAMA_SERVER_KEY
require NAKAMA_HTTP_KEY
require NAKAMA_CONSOLE_PASSWORD
require NAKAMA_SESSION_ENCRYPTION_KEY
require NAKAMA_SESSION_REFRESH_ENCRYPTION_KEY
require NAKAMA_CONSOLE_SIGNING_KEY

umask 077
sed \
  -e "s|@@DB_PASSWORD@@|$NAKAMA_DB_PASSWORD|g" \
  -e "s|@@SERVER_KEY@@|$NAKAMA_SERVER_KEY|g" \
  -e "s|@@HTTP_KEY@@|$NAKAMA_HTTP_KEY|g" \
  -e "s|@@CONSOLE_PASSWORD@@|$NAKAMA_CONSOLE_PASSWORD|g" \
  -e "s|@@SESSION_ENCRYPTION_KEY@@|$NAKAMA_SESSION_ENCRYPTION_KEY|g" \
  -e "s|@@SESSION_REFRESH_ENCRYPTION_KEY@@|$NAKAMA_SESSION_REFRESH_ENCRYPTION_KEY|g" \
  -e "s|@@CONSOLE_SIGNING_KEY@@|$NAKAMA_CONSOLE_SIGNING_KEY|g" \
  "$src" > "$out"

# Nothing may be left unrendered: an unreplaced placeholder would start the server with a
# literal password. The four names are matched exactly rather than by pattern, because the
# comments in nakama.yml talk about @@TOKEN@@ and a pattern would match those too.
if grep -qE '@@(DB_PASSWORD|SERVER_KEY|HTTP_KEY|CONSOLE_PASSWORD|SESSION_ENCRYPTION_KEY|SESSION_REFRESH_ENCRYPTION_KEY|CONSOLE_SIGNING_KEY)@@' "$out"; then
  echo "render-config: $out still has an unreplaced placeholder" >&2
  grep -nE '@@(DB_PASSWORD|SERVER_KEY|HTTP_KEY|CONSOLE_PASSWORD|SESSION_ENCRYPTION_KEY|SESSION_REFRESH_ENCRYPTION_KEY|CONSOLE_SIGNING_KEY)@@' "$out" >&2
  rm -f "$out"
  exit 1
fi

chmod 600 "$out"
echo "render-config: wrote $out"
