#!/usr/bin/env bash
# Fails when CLAUDE.md exceeds the line cap.
# A long router is a router whose rules get lost in the noise.
set -euo pipefail
CAP=150
n=$(wc -l < CLAUDE.md)
if [ "$n" -gt "$CAP" ]; then
  echo "FAIL router-size: CLAUDE.md is $n lines, cap is $CAP."
  echo "      Move content into a routed file. The router holds routes, not rules."
  exit 1
fi
echo "ok router-size: $n/$CAP lines"
