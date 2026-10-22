#!/usr/bin/env bash
# export-goldens.sh — render valid fixtures with cue export and diff against goldens.
#
# Usage:
#   scripts/export-goldens.sh          # check (CI)
#   scripts/export-goldens.sh --update # rewrite goldens
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CUE_BIN="${CUE_BIN:-cue}"
if ! command -v "$CUE_BIN" >/dev/null 2>&1; then
  if [ -x "${HOME}/.local/bin/cue" ]; then
    CUE_BIN="${HOME}/.local/bin/cue"
  else
    echo "error: cue CLI not found" >&2
    exit 2
  fi
fi

UPDATE=0
if [ "${1:-}" = "--update" ]; then
  UPDATE=1
fi

VALID="$ROOT/tests/valid"
GOLDENS="$ROOT/tests/goldens"
mkdir -p "$GOLDENS"

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

fail=0
for f in "$VALID"/*.yaml; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .yaml)"
  kind="$(kind_for "$f")"
  golden="$GOLDENS/${base}.json"

  case "$kind" in
    passport)
      DEF='#ComponentPassport'
      SCHEMA=./schemas/component_passport.cue
      EXTRA=""
      ;;
    topology)
      DEF='#TopologyBlueprint'
      SCHEMA=./schemas/topology_spec.cue
      EXTRA=./schemas/component_passport.cue
      ;;
    layout)
      DEF='#CanvasLayout'
      SCHEMA=./schemas/topology_spec.cue
      EXTRA=./schemas/component_passport.cue
      ;;
  esac

  set +e
  if [ -n "$EXTRA" ]; then
    rendered="$("$CUE_BIN" export --out json -d "$DEF" "$SCHEMA" "$EXTRA" "$f" 2>&1)"
  else
    rendered="$("$CUE_BIN" export --out json -d "$DEF" "$SCHEMA" "$f" 2>&1)"
  fi
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    echo "FAIL: could not export $f"
    echo "$rendered"
    fail=$((fail + 1))
    continue
  fi

  if [ "$UPDATE" -eq 1 ]; then
    printf '%s\n' "$rendered" >"$golden"
    echo "UPDATED $(basename "$golden")"
  else
    if [ ! -f "$golden" ]; then
      echo "FAIL: missing golden $(basename "$golden") (run: scripts/export-goldens.sh --update)"
      fail=$((fail + 1))
    elif ! diff -u "$golden" <(printf '%s\n' "$rendered") >/dev/null; then
      echo "FAIL: golden drift for $(basename "$golden")"
      diff -u "$golden" <(printf '%s\n' "$rendered") || true
      fail=$((fail + 1))
    else
      echo "PASS golden: $(basename "$golden")"
    fi
  fi
done

if [ "$UPDATE" -eq 0 ]; then
  echo "---"
  echo "golden tests: $fail failed"
  [ "$fail" -eq 0 ]
fi
