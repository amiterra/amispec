#!/usr/bin/env bash
# negative.sh — assert that every invalid fixture FAILS structural validation.
# Modern practice: schema regression suite = valid must pass, invalid must fail.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VET="$ROOT/scripts/vet.sh"
INVALID_DIR="$ROOT/tests/invalid"

pass=0
fail=0

kind_for() {
  local base
  base="$(basename "$1")"
  case "$base" in
    passport-*) echo passport ;;
    topology-*) echo topology ;;
    *layout*) echo layout ;;
    *) echo passport ;;
  esac
}

if [ ! -d "$INVALID_DIR" ]; then
  echo "error: missing $INVALID_DIR" >&2
  exit 2
fi

for f in "$INVALID_DIR"/*.yaml; do
  [ -e "$f" ] || continue
  kind="$(kind_for "$f")"
  if "$VET" "$kind" "$f" >/dev/null 2>&1; then
    echo "FAIL (should have been rejected): $f"
    fail=$((fail + 1))
  else
    echo "PASS (correctly rejected): $(basename "$f")"
    pass=$((pass + 1))
  fi
done

echo "---"
echo "negative tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
