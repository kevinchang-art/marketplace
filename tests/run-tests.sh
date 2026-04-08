#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$ROOT_DIR/scripts/validate-plugin.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
TOTAL=0

run_test() {
  local test_name="$1"
  local expected="$2"
  local plugin_dir="$3"
  local repo_name="$4"
  TOTAL=$((TOTAL + 1))

  local result
  if bash "$VALIDATE" "$plugin_dir" "$repo_name" > /dev/null 2>&1; then
    result="pass"
  else
    result="fail"
  fi

  if [[ "$result" == "$expected" ]]; then
    echo "  ✓ $test_name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $test_name (expected $expected, got $result)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== validate-plugin.sh tests ==="
echo ""

echo "--- Structure validation ---"
run_test "valid skill plugin passes" "pass" "$FIXTURES/valid-skill" "plugin-test-skill"
run_test "valid hook plugin passes" "pass" "$FIXTURES/valid-hook" "plugin-test-hook"
run_test "missing required fields fails" "fail" "$FIXTURES/invalid-missing-fields" "plugin-bad-plugin"
run_test "invalid naming/version/type fails" "fail" "$FIXTURES/invalid-naming" "plugin-wrong-name"

echo ""
echo "--- Content & cross validation ---"
run_test "type mismatch (skill with hooks) fails" "fail" "$FIXTURES/invalid-type-mismatch" "plugin-type-mismatch"
run_test "wrong repo name fails" "fail" "$FIXTURES/valid-skill" "plugin-wrong-repo-name"

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if (( FAIL > 0 )); then
  exit 1
fi
