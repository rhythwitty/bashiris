#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  tests/shell/test_iris.sh — Automated tests for iris CLI & shared library
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IRIS_BIN="$REPO_ROOT/iris"
COMMON_LIB="$REPO_ROOT/scripts/lib/common.sh"

PASSED=0
FAILED=0

pass() {
    echo "  ✅  $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  ❌  $1" >&2
    FAILED=$((FAILED + 1))
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$message"
    else
        fail "$message (expected '$expected', got '$actual')"
    fi
}

echo ""
echo "Running shell tests..."
echo ""

# ── 1. Dispatcher --help ──────────────────────────────────────────────────────
output="$("$IRIS_BIN" --help 2>&1 || true)"
if echo "$output" | grep -q "USAGE"; then
    pass "iris --help outputs USAGE section"
else
    fail "iris --help did not output USAGE"
fi

# ── 2. Dispatcher --version ───────────────────────────────────────────────────
if "$IRIS_BIN" --version 2>&1 | grep -qE '^iris v[0-9]+\.[0-9]+\.[0-9]+'; then
    pass "iris --version reports valid semver version"
else
    fail "iris --version failed to report semver version"
fi

# ── 3. Unknown command handling ───────────────────────────────────────────────
if "$IRIS_BIN" unknown_command_12345 &> /dev/null; then
    fail "iris unknown_command should exit with non-zero"
else
    pass "iris unknown_command exits with non-zero exit code"
fi

# ── 4. Shared common library tests ────────────────────────────────────────────
# shellcheck source=scripts/lib/common.sh
source "$COMMON_LIB"

# Library dir resolution
lib_dir="$(resolve_iris_lib_dir)"
if [[ -n "$lib_dir" ]]; then
    pass "resolve_iris_lib_dir returned '$lib_dir'"
else
    fail "resolve_iris_lib_dir returned empty string"
fi

# Flag parsing test
parsed_val="$(parse_flag_value "--port" "8080")"
assert_eq "8080" "$parsed_val" "parse_flag_value with valid value"

# Minimal bash requirement test (we know current bash is at least 3)
if require_min_bash 3 &> /dev/null; then
    pass "require_min_bash 3 succeeded"
else
    fail "require_min_bash 3 failed"
fi

# Summary
echo ""
if [[ "$FAILED" -eq 0 ]]; then
    echo "All $PASSED shell tests passed!"
    echo ""
    exit 0
else
    echo "Shell tests failed: $PASSED passed, $FAILED failed." >&2
    echo ""
    exit 1
fi
