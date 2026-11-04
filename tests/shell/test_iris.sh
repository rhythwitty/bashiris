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

# ── 5. ssh-setup --help option test ──────────────────────────────────────────
ssh_setup_help="$("$REPO_ROOT/scripts/ssh-setup.sh" --help 2>&1 || true)"
if echo "$ssh_setup_help" | grep -q -- "--migrate"; then
    pass "ssh-setup --help lists --migrate option"
else
    fail "ssh-setup --help missing --migrate option"
fi

# ── 6. ssh-setup migration test ──────────────────────────────────────────────
TEST_TMP_DIR="$(mktemp -d)"
TEST_SSH_CONFIG="$TEST_TMP_DIR/config"

cat << 'EOF' > "$TEST_SSH_CONFIG"
Host 10.9.8.1
  HostName 10.9.8.1
  User mac

Host github_rhythwitty
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519_rhythwitty
  User git
  IdentitiesOnly yes

Host github_already_migrated
  HostName ssh.github.com
  IdentityFile ~/.ssh/id_ed25519_already
  Port 443
  User git
  IdentitiesOnly yes
EOF

# Run migration with auto-confirm
IRIS_SSH_CONFIG="$TEST_SSH_CONFIG" FORCE_YES=true "$REPO_ROOT/scripts/ssh-setup.sh" --migrate > /dev/null 2>&1

# Verify github_rhythwitty was migrated to port 443 & ssh.github.com
if grep -A 5 "Host github_rhythwitty" "$TEST_SSH_CONFIG" | grep -q "HostName ssh.github.com" &&
    grep -A 5 "Host github_rhythwitty" "$TEST_SSH_CONFIG" | grep -q "Port 443"; then
    pass "ssh-setup --migrate updated github_rhythwitty to ssh.github.com and Port 443"
else
    fail "ssh-setup --migrate failed to update github_rhythwitty"
fi

# Verify non-github host was preserved
if grep -A 2 "Host 10.9.8.1" "$TEST_SSH_CONFIG" | grep -q "HostName 10.9.8.1" &&
    ! grep -A 2 "Host 10.9.8.1" "$TEST_SSH_CONFIG" | grep -q "Port 443"; then
    pass "ssh-setup --migrate preserved non-github host unchanged"
else
    fail "ssh-setup --migrate corrupted non-github host"
fi

# Verify already migrated host did not get duplicate Port 443
port_count="$(grep -A 6 "Host github_already_migrated" "$TEST_SSH_CONFIG" | grep -c "Port 443" || true)"
if [[ "$port_count" -eq 1 ]]; then
    pass "ssh-setup --migrate did not duplicate Port 443"
else
    fail "ssh-setup --migrate duplicated Port 443 (found $port_count occurrences)"
fi

# Verify idempotency
migration_output="$(IRIS_SSH_CONFIG="$TEST_SSH_CONFIG" FORCE_YES=true "$REPO_ROOT/scripts/ssh-setup.sh" --migrate 2>&1 || true)"
if echo "$migration_output" | grep -q "already use port 443"; then
    pass "ssh-setup --migrate is idempotent when all hosts are migrated"
else
    fail "ssh-setup --migrate failed idempotency check"
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
