#!/usr/bin/env bash
# negative.sh — assert that every invalid fixture FAILS validation.
# Modern practice: schema regression suite = valid must pass, invalid must fail.
#
# Two validation layers:
#   1. structural  — cue vet (meta-schema: enums, ranges, patterns)
#   2. semantic    — amispec-validate (cross-references: exposure rules,
#                    provider registry, scope/auth policy)
# A fixture is correctly rejected when EITHER layer rejects it. Semantic
# fixtures (topology-expose-*, topology-lb-*) pass cue vet on purpose: their
# violations live in the Rust validator, the single authority for rules that
# need cross-field resolution (Design Doc 0025 §2.3).
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
       *) echo passport ;;
  esac
}

# Resolve the semantic validator (amispec CLI from amispec-core).
# Prints the command to run on stdout; exits 2 when unavailable.
AMISPEC_CMD=""
resolve_amispec() {
  if [ -n "${AMISPEC_BIN:-}" ]; then
    AMISPEC_CMD="${AMISPEC_BIN}"
    return 0
  fi
  if command -v amispec >/dev/null 2>&1; then
    AMISPEC_CMD="amispec"
    return 0
  fi
  local core_dir="${AMISPEC_CORE_DIR:-$ROOT/../amispec-core}"
  if [ -f "$core_dir/Cargo.toml" ]; then
    (cd "$core_dir" && cargo build -q -p amispec-cli) || {
      echo "error: cannot build amispec-cli in $core_dir" >&2
      return 2
    }
    AMISPEC_CMD="$core_dir/target/debug/amispec"
    return 0
  fi
  echo "error: semantic validator not found (set AMISPEC_BIN or AMISPEC_CORE_DIR)" >&2
  return 2
}
resolve_amispec

if [ ! -d "$INVALID_DIR" ]; then
  echo "error: missing $INVALID_DIR" >&2
  exit 2
fi

for f in "$INVALID_DIR"/*.yaml; do
  [ -e "$f" ] || continue
  kind="$(kind_for "$f")"
  if "$VET" "$kind" "$f" >/dev/null 2>&1; then
    # structurally valid — the semantic layer must reject it
    if "${AMISPEC_CMD}" validate "$f" >/dev/null 2>&1; then
      echo "FAIL (should have been rejected): $f"
      fail=$((fail + 1))
    else
      echo "PASS (rejected by amispec-validate): $(basename "$f")"
      pass=$((pass + 1))
    fi
  else
    echo "PASS (correctly rejected): $(basename "$f")"
    pass=$((pass + 1))
  fi
done

echo "---"
echo "negative tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
