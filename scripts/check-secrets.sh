#!/usr/bin/env bash
# Looks for key-like strings in added lines and prints only where they are
# (commit and file name), never the matching text.
#
#   scripts/check-secrets.sh                  scan the staged diff
#   scripts/check-secrets.sh --log <revs...>  scan commits, e.g. --log main..HEAD
#
# Exit 0 when clean, 1 when something is found.
set -euo pipefail

# Split so this file never matches its own patterns.
p1='AI''za'
p2='private''_key'
p3='-----''BEGIN'
p4='api''_key='

if [ "${1:-}" = "--log" ]; then
  shift
  diff_cmd=(git log -p -U0 --no-color --no-ext-diff --format='commit %H' "$@")
else
  diff_cmd=(git diff --cached -U0 --no-color --no-ext-diff)
fi

hits=$("${diff_cmd[@]}" | awk -v p1="$p1" -v p2="$p2" -v p3="$p3" -v p4="$p4" '
  /^commit [0-9a-f]+$/ { c = substr($2, 1, 7); next }
  /^\+\+\+ / { f = substr($0, 5); sub(/^b\//, "", f); next }
  /^\+/ {
    l = $0; ll = tolower(l)
    # *.example templates hold env variable names (the Firebase API key name) with
    # placeholder values, so pattern p4 is skipped for them only.
    tmpl = (f ~ /\.example$/)
    if (index(l, p1) || index(ll, p2) || index(l, p3) || (!tmpl && index(ll, p4))) {
      print (c != "" ? c " " : "") f
    }
  }
' | sort -u)

if [ -n "$hits" ]; then
  echo "check-secrets: key-like strings found in these places (values hidden):" >&2
  echo "$hits" | sed 's/^/  /' >&2
  exit 1
fi
echo "check-secrets: clean"
