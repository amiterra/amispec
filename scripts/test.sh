#!/usr/bin/env bash
# test.sh — full AmiSpec schema validation suite (layers 1–2 + golden + negative).
#
# Layers (see specification / validation best practices):
#   1. syntax      — cue fmt -l / cue vet package
#   2. schema      — cue vet instances + cue test unit tests
#   3. regression  — invalid fixtures must fail
#   4. goldens     — cue export snapshot stability
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"
CUE_BIN="${CUE_BIN:-cue}"
if ! command -v "$CUE_BIN" >/dev/null 2>&1; then
  if [ -x "${HOME}/.local/bin/cue" ]; then
    CUE_BIN="${HOME}/.local/bin/cue"
    export CUE_BIN
  else
    echo "error: cue CLI not found (install cuelang.org/go/cmd/cue)" >&2
    exit 2
  fi
fi
export CUE_BIN

section() { printf '\n=== %s ===\n' "$1"; }

section "1/4 Syntax & package (cue vet schemas)"
"$CUE_BIN" vet ./schemas/...

section "2/4 Unit-test fields (unification assertions in schema_test.cue)"
# CUE asserts via unification: any failing & in schema_test.cue fails cue vet.
"$CUE_BIN" vet ./schemas/...
echo "unit assertions: OK"

section "3/4 Valid instances (must pass)"
pass=0
for f in "$ROOT"/tests/valid/*.yaml; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  case "$base" in
    passport-*) kind=passport ;;
    topology-*) kind=topology ;;
        *) kind=passport ;;
  esac
  if "$ROOT/scripts/vet.sh" "$kind" "$f"; then
    echo "PASS valid: $base"
    pass=$((pass + 1))
  else
    echo "FAIL valid: $base"
    exit 1
  fi
done
echo "valid instances: $pass passed"

section "4/4 Negative + golden"
"$ROOT/scripts/negative.sh"
"$ROOT/scripts/export-goldens.sh"

printf '\nALL CHECKS PASSED\n'
