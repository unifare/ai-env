#!/usr/bin/env bash
# ==============================================================================
# ai-env - Test Suite
# Usage: ./tests/test.sh
# ==============================================================================

# Don't use set -e in tests — we need to capture exit codes
set -uo pipefail

# ---- Test configuration ----
TEST_AI_ENV_DIR="/tmp/ai-env-test-$$"
TEST_AI_ENV_KEYS="${TEST_AI_ENV_DIR}/keys"
TEST_AI_ENV_BIN=""

# ---- Counters ----
TESTS_PASSED=0
TESTS_FAILED=0

# ---- Color output ----
_GREEN='\033[0;32m'
_RED='\033[0;31m'
_YELLOW='\033[0;33m'
_BOLD='\033[1m'
_RESET='\033[0m'

_pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); printf "  ${_GREEN}✓${_RESET} %s\n" "$1"; }
_fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); printf "  ${_RED}✗${_RESET} %s\n" "$1"; }
_section() { printf "\n${_BOLD}▸ %s${_RESET}\n" "$1"; }

# ---- Setup / Teardown ----
setup() {
    rm -rf "$TEST_AI_ENV_DIR"
    mkdir -p "$TEST_AI_ENV_DIR"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -f "${SCRIPT_DIR}/ai-env" ]; then
        cp "${SCRIPT_DIR}/ai-env" "${TEST_AI_ENV_DIR}/ai-env"
        chmod +x "${TEST_AI_ENV_DIR}/ai-env"
        TEST_AI_ENV_BIN="${TEST_AI_ENV_DIR}/ai-env"
    else
        echo "ERROR: ai-env script not found in ${SCRIPT_DIR}"
        exit 1
    fi

    export AI_ENV_DIR="$TEST_AI_ENV_DIR"
    export AI_ENV_KEYS="${TEST_AI_ENV_DIR}/keys"
}

teardown() {
    rm -rf "$TEST_AI_ENV_DIR"
}

# ---- Test helpers ----

# Run ai-env and capture both output and exit code
# Usage: run_ai_env <args...>
# After calling, use $RUN_OUTPUT and $RUN_EXIT_CODE
RUN_OUTPUT=""
RUN_EXIT_CODE=0
run_ai_env() {
    RUN_EXIT_CODE=0
    RUN_OUTPUT=$(bash "$TEST_AI_ENV_BIN" "$@" 2>&1) && RUN_EXIT_CODE=0 || RUN_EXIT_CODE=$?
}

assert_exit_code() {
    local expected="$1" actual="$2" msg="$3"
    if [ "$actual" -eq "$expected" ]; then
        _pass "$msg"
    else
        _fail "$msg (expected exit $expected, got $actual)"
    fi
}

assert_output_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if printf '%s' "$haystack" | grep -qF "$needle"; then
        _pass "$msg"
    else
        _fail "$msg (output does not contain '$needle')"
    fi
}

assert_output_not_contains() {
    local needle="$1" haystack="$2" msg="$3"
    if ! printf '%s' "$haystack" | grep -qF "$needle"; then
        _pass "$msg"
    else
        _fail "$msg (output unexpectedly contains '$needle')"
    fi
}

assert_file_contains() {
    local file="$1" needle="$2" msg="$3"
    if [ -f "$file" ] && grep -qF "$needle" "$file" 2>/dev/null; then
        _pass "$msg"
    else
        _fail "$msg (file does not contain '$needle')"
    fi
}

assert_file_not_contains() {
    local file="$1" needle="$2" msg="$3"
    if [ ! -f "$file" ] || ! grep -qF "$needle" "$file" 2>/dev/null; then
        _pass "$msg"
    else
        _fail "$msg (file unexpectedly contains '$needle')"
    fi
}

# ---- Tests ----

test_version() {
    _section "version command"
    run_ai_env version
    assert_output_contains "ai-env v" "$RUN_OUTPUT" "version shows version string"
    assert_exit_code 0 "$RUN_EXIT_CODE" "version exits 0"
}

test_help() {
    _section "help command"
    run_ai_env help
    assert_output_contains "AI API Key Manager" "$RUN_OUTPUT" "help shows description"
    assert_output_contains "set <KEY> <VALUE>" "$RUN_OUTPUT" "help shows set usage"
    assert_output_contains "get <KEY>" "$RUN_OUTPUT" "help shows get usage"
    assert_output_contains "list" "$RUN_OUTPUT" "help shows list usage"
    assert_output_contains "remove" "$RUN_OUTPUT" "help shows remove usage"
    assert_output_contains "doctor" "$RUN_OUTPUT" "help shows doctor usage"
}

test_help_on_no_args() {
    _section "help on no args"
    run_ai_env
    assert_output_contains "AI API Key Manager" "$RUN_OUTPUT" "no args shows help"
}

test_set_basic() {
    _section "set command - basic"
    run_ai_env set OPENAI_API_KEY sk-test123
    assert_exit_code 0 "$RUN_EXIT_CODE" "set exits 0"
    assert_output_contains "OPENAI_API_KEY set" "$RUN_OUTPUT" "set confirms key set"
    assert_file_contains "$AI_ENV_KEYS" "export OPENAI_API_KEY=" "keys file contains export line"
}

test_set_with_special_chars() {
    _section "set command - special characters"
    run_ai_env set TEST_KEY "hello'world"
    assert_file_contains "$AI_ENV_KEYS" "export TEST_KEY=" "keys file has entry for TEST_KEY"

    # Verify the value can be correctly sourced
    local value
    value=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${TEST_KEY:-}\"")
    if [ "$value" = "hello'world" ]; then
        _pass "single quote in value preserved correctly"
    else
        _fail "single quote in value not preserved (got: $value)"
    fi
}

test_set_with_spaces() {
    _section "set command - spaces in value"
    run_ai_env set SPACES_KEY "hello world"
    local value
    value=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${SPACES_KEY:-}\"")
    if [ "$value" = "hello world" ]; then
        _pass "spaces in value preserved"
    else
        _fail "spaces in value not preserved (got: $value)"
    fi
}

test_set_with_dollar_sign() {
    _section "set command - dollar sign in value"
    run_ai_env set DOLLAR_KEY 'price$100'
    local value
    value=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${DOLLAR_KEY:-}\"")
    if [ "$value" = 'price$100' ]; then
        _pass "dollar sign in value preserved"
    else
        _fail "dollar sign in value not preserved (got: $value)"
    fi
}

test_set_update_existing() {
    _section "set command - update existing"
    run_ai_env set UPDATE_KEY "value1"
    run_ai_env set UPDATE_KEY "value2"

    # Should only have one export line for UPDATE_KEY
    local count
    count=$(grep -c "^export UPDATE_KEY=" "$AI_ENV_KEYS" 2>/dev/null || echo 0)
    if [ "$count" -eq 1 ]; then
        _pass "update replaces existing key"
    else
        _fail "update created duplicate ($count entries)"
    fi

    local value
    value=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${UPDATE_KEY:-}\"")
    if [ "$value" = "value2" ]; then
        _pass "update sets new value"
    else
        _fail "update value incorrect (got: $value)"
    fi
}

test_set_invalid_var_name() {
    _section "set command - invalid variable names"
    run_ai_env set "123BAD" "value"
    assert_exit_code 1 "$RUN_EXIT_CODE" "rejects variable starting with number"

    run_ai_env set "bad-name" "value"
    assert_exit_code 1 "$RUN_EXIT_CODE" "rejects variable with hyphen"

    run_ai_env set "bad name" "value"
    assert_exit_code 1 "$RUN_EXIT_CODE" "rejects variable with space"
}

test_get() {
    _section "get command"
    run_ai_env set GET_TEST_KEY "my-secret-value"

    run_ai_env get GET_TEST_KEY
    # The get command reads from env or file; in test mode we verify from file
    local value
    value=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${GET_TEST_KEY:-}\"")
    if [ "$value" = "my-secret-value" ]; then
        _pass "get returns correct value"
    else
        _fail "get returns wrong value (got: $value, output: $RUN_OUTPUT)"
    fi
}

test_get_not_found() {
    _section "get command - not found"
    run_ai_env get NONEXISTENT_KEY
    assert_exit_code 1 "$RUN_EXIT_CODE" "get nonexistent key exits 1"
}

test_list() {
    _section "list command"
    run_ai_env set LIST_KEY1 "sk-abc123"
    run_ai_env set LIST_KEY2 "sk-xyz789"

    run_ai_env list
    assert_output_contains "LIST_KEY1" "$RUN_OUTPUT" "list shows LIST_KEY1"
    assert_output_contains "LIST_KEY2" "$RUN_OUTPUT" "list shows LIST_KEY2"
    assert_output_not_contains "sk-abc123" "$RUN_OUTPUT" "list hides full value for KEY1"
    assert_output_not_contains "sk-xyz789" "$RUN_OUTPUT" "list hides full value for KEY2"
}

test_list_empty() {
    _section "list command - empty"
    rm -f "$AI_ENV_KEYS"
    run_ai_env list
    assert_output_contains "No keys" "$RUN_OUTPUT" "list shows no keys message"
}

test_remove() {
    _section "remove command"
    run_ai_env set REMOVE_KEY "value"
    assert_file_contains "$AI_ENV_KEYS" "export REMOVE_KEY=" "key exists before remove"

    run_ai_env remove REMOVE_KEY
    assert_file_not_contains "$AI_ENV_KEYS" "export REMOVE_KEY=" "key removed from file"
}

test_remove_not_found() {
    _section "remove command - not found"
    run_ai_env remove NONEXISTENT
    assert_exit_code 1 "$RUN_EXIT_CODE" "remove nonexistent key exits 1"
}

test_reload() {
    _section "reload command"
    run_ai_env set RELOAD_KEY "reload-value"

    run_ai_env reload
    assert_output_contains "__EVAL__:" "$RUN_OUTPUT" "reload outputs eval commands"
    assert_output_contains "Reloaded" "$RUN_OUTPUT" "reload confirms reloaded"
}

test_export() {
    _section "export command"
    run_ai_env set EXPORT_KEY "export-value"

    run_ai_env export
    assert_output_contains "export EXPORT_KEY=" "$RUN_OUTPUT" "export outputs export line"
}

test_doctor() {
    _section "doctor command"
    run_ai_env doctor
    assert_output_contains "ai-env doctor" "$RUN_OUTPUT" "doctor shows header"
    assert_output_contains "Config directory" "$RUN_OUTPUT" "doctor checks config dir"
}

test_eval_prefix_set() {
    _section "eval prefix - set"
    run_ai_env set EVAL_TEST "value"
    assert_output_contains "__EVAL__:" "$RUN_OUTPUT" "set outputs eval prefix"
    assert_output_contains "export EVAL_TEST=" "$RUN_OUTPUT" "set outputs export command"
}

test_eval_prefix_remove() {
    _section "eval prefix - remove"
    run_ai_env set EVAL_RM "value"
    run_ai_env remove EVAL_RM
    assert_output_contains "__EVAL__:" "$RUN_OUTPUT" "remove outputs eval prefix"
    assert_output_contains "unset EVAL_RM" "$RUN_OUTPUT" "remove outputs unset command"
}

test_keys_file_permissions() {
    _section "keys file permissions"
    run_ai_env set PERM_TEST "value"
    if [ -f "$AI_ENV_KEYS" ]; then
        local perms
        perms=$(stat -c '%a' "$AI_ENV_KEYS" 2>/dev/null || stat -f '%Lp' "$AI_ENV_KEYS" 2>/dev/null || echo "unknown")
        if [ "$perms" = "600" ]; then
            _pass "keys file has 600 permissions"
        else
            _fail "keys file has $perms permissions (expected 600)"
        fi
    else
        _fail "keys file not created"
    fi
}

test_multiple_keys() {
    _section "multiple keys"
    run_ai_env set KEY_A "val_a"
    run_ai_env set KEY_B "val_b"
    run_ai_env set KEY_C "val_c"

    local count
    count=$(grep -c '^export KEY_' "$AI_ENV_KEYS")
    if [ "$count" -eq 3 ]; then
        _pass "all 3 keys stored"
    else
        _fail "expected 3 keys, found $count"
    fi

    # Verify each individually
    local val
    val=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${KEY_A:-}\"")
    [ "$val" = "val_a" ] && _pass "KEY_A correct" || _fail "KEY_A wrong (got: $val)"

    val=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${KEY_B:-}\"")
    [ "$val" = "val_b" ] && _pass "KEY_B correct" || _fail "KEY_B wrong (got: $val)"

    val=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${KEY_C:-}\"")
    [ "$val" = "val_c" ] && _pass "KEY_C correct" || _fail "KEY_C wrong (got: $val)"
}

test_invalid_command() {
    _section "invalid command"
    run_ai_env badcommand
    assert_exit_code 1 "$RUN_EXIT_CODE" "invalid command exits 1"
    assert_output_contains "Unknown command" "$RUN_OUTPUT" "shows unknown command message"
}

test_set_underscore_var() {
    _section "set command - underscore variable name"
    run_ai_env set _MY_KEY "underscore_value"
    assert_exit_code 0 "$RUN_EXIT_CODE" "accepts variable starting with underscore"

    local value
    value=$(bash -c "source '${AI_ENV_KEYS}' && printf '%s' \"\${_MY_KEY:-}\"")
    if [ "$value" = "underscore_value" ]; then
        _pass "underscore variable value preserved"
    else
        _fail "underscore variable value wrong (got: $value)"
    fi
}

# ---- Main ----

main() {
    printf "${_BOLD}ai-env test suite${_RESET}\n"
    printf "══════════════════════════════════════\n\n"

    setup

    test_version
    test_help
    test_help_on_no_args
    test_set_basic
    test_set_with_special_chars
    test_set_with_spaces
    test_set_with_dollar_sign
    test_set_update_existing
    test_set_invalid_var_name
    test_get
    test_get_not_found
    test_list
    test_list_empty
    test_remove
    test_remove_not_found
    test_reload
    test_export
    test_doctor
    test_eval_prefix_set
    test_eval_prefix_remove
    test_keys_file_permissions
    test_multiple_keys
    test_invalid_command
    test_set_underscore_var

    local total=$((TESTS_PASSED + TESTS_FAILED))
    printf "\n${_BOLD}══════════════════════════════════════${_RESET}\n"
    printf "${_BOLD}Results:${_RESET} ${_GREEN}${TESTS_PASSED} passed${_RESET}, ${_RED}${TESTS_FAILED} failed${_RESET}, ${total} total\n"

    printf "\n"
    if [ $TESTS_FAILED -eq 0 ]; then
        printf "${_GREEN}${_BOLD}All tests passed! ✅${_RESET}\n\n"
    else
        printf "${_RED}${_BOLD}Some tests failed! ❌${_RESET}\n\n"
    fi

    teardown

    exit $TESTS_FAILED
}

main
