#!/usr/bin/env bash
# vet.sh — structural validation (CUE) of AmiSpec instance documents.
#
# Usage:
#   scripts/vet.sh <passport|topology> <file.yaml>
#
# Instance files are root-form documents (apiVersion/kind/metadata at top level),
# validated against the closed meta-schema definition via cue vet -d.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CUE_BIN="${CUE_BIN:-cue}"
if ! command -v "$CUE_BIN" >/dev/null 2>&1; then
  if [ -x "${HOME}/.local/bin/cue" ]; then
    CUE_BIN="${HOME}/.local/bin/cue"
  else
    echo "error: cue CLI not found (set CUE_BIN or install cuelang.org/go/cmd/cue)" >&2
    exit 2
  fi
fi

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <passport|topology> <file.yaml>" >&2
  exit 2
fi

KIND="$1"
FILE="$2"
[ -f "$FILE" ] || { echo "error: file not found: $FILE" >&2; exit 2; }

case "$KIND" in
  passport)
    DEF="#ComponentPassport"
    SCHEMA=./schemas/component_passport.cue
    ;;
  topology)
    DEF="#TopologyBlueprint"
    SCHEMA=./schemas/topology_spec.cue
    # topology_spec references shared types from component_passport.cue
    EXTRA=./schemas/component_passport.cue
    ;;
  *)
    echo "error: unknown kind '$KIND' (expected passport|topology)" >&2
    exit 2
    ;;
esac

if [ -n "${EXTRA:-}" ]; then
  "$CUE_BIN" vet -d "$DEF" "$SCHEMA" "$EXTRA" "$FILE"
else
  "$CUE_BIN" vet -d "$DEF" "$SCHEMA" "$FILE"
fi
