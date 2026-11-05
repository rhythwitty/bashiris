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
if echo "$output" | grep -q "ALIASES"; then
    pass "iris --help outputs ALIASES section"
else
    fail "iris --help did not output ALIASES"
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

# ── 3b. Dispatcher aliases ────────────────────────────────────────────────────
clean_help="$(IRIS_LIB_DIR="$REPO_ROOT/scripts" "$IRIS_BIN" clean --help 2>&1 || true)"
if echo "$clean_help" | grep -q "ChromePower Cleaner"; then
    pass "iris clean dispatches to power-clean"
else
    fail "iris clean failed to dispatch to power-clean"
fi

kill_help="$(IRIS_LIB_DIR="$REPO_ROOT/scripts" "$IRIS_BIN" kill --help 2>&1 || true)"
if echo "$kill_help" | grep -q "kill-port"; then
    pass "iris kill dispatches to kill-port"
else
    fail "iris kill failed to dispatch to kill-port"
fi

download_help="$(IRIS_LIB_DIR="$REPO_ROOT/scripts" "$IRIS_BIN" download --help 2>&1 || true)"
if echo "$download_help" | grep -q "download-yt"; then
    pass "iris download dispatches to download-yt"
else
    fail "iris download failed to dispatch to download-yt"
fi

check_help="$(IRIS_LIB_DIR="$REPO_ROOT/scripts" "$IRIS_BIN" check --help 2>&1 || true)"
if echo "$check_help" | grep -q "check-power"; then
    pass "iris check dispatches to check-power"
else
    fail "iris check failed to dispatch to check-power"
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

# ── 5. ssh command tests ─────────────────────────────────────────────────────
ssh_help="$("$REPO_ROOT/scripts/ssh.sh" --help 2>&1 || true)"
if echo "$ssh_help" | grep -q "setup" && echo "$ssh_help" | grep -q "verify"; then
    pass "ssh --help lists setup and verify subcommands"
else
    fail "ssh --help missing subcommands"
fi

# Ensure --migrate is no longer present in help
if ! echo "$ssh_help" | grep -q -- "--migrate"; then
    pass "ssh --help does not contain removed --migrate option"
else
    fail "ssh --help unexpectedly contains removed --migrate option"
fi

# Test unknown subcommand handling
if "$REPO_ROOT/scripts/ssh.sh" invalid_subcmd &> /dev/null; then
    fail "ssh invalid_subcmd should exit with non-zero"
else
    pass "ssh invalid_subcmd exits with non-zero exit code"
fi

# ── 6. ssh verify test with temporary config ──────────────────────────────────
TEST_TMP_DIR="$(mktemp -d)"
TEST_SSH_CONFIG="$TEST_TMP_DIR/config"
touch "$TEST_SSH_CONFIG"

# Verify on empty config should fail with no hosts found message
verify_output="$(IRIS_SSH_CONFIG="$TEST_SSH_CONFIG" "$REPO_ROOT/scripts/ssh.sh" verify 2>&1 || true)"
if echo "$verify_output" | grep -q "No GitHub SSH hosts found"; then
    pass "ssh verify reports no GitHub hosts found on empty config"
else
    fail "ssh verify did not report missing GitHub hosts"
fi

rm -rf "$TEST_TMP_DIR"

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
