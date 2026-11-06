#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# Exercise real menu input, source dispatch and menu exit status without any
# source edits. Only terminal rendering and the source action are stubbed.
# Usage: bash tests/menu-action-status-test.sh
# shellcheck disable=SC2034,SC2317

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/menu.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/02-sources/init.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT
PRIMARY="" YELLOW="" NC="" UI_DIVIDER=""

clear() { :; }
show_menu_header() { :; }
show_menu_option() { :; }
show_menu_footer() { :; }
pause_function() { :; }
log_error() { printf 'ERROR: %s\n' "$*"; }
log_warn() { printf 'WARN: %s\n' "$*"; }
change_sources() {
    printf 'called\n' >> "$TMP_DIR/calls"
    if [[ "$MOCK_ACTION_FAILS" == "cancel" || "$MOCK_ACTION_FAILS" == "cancel_once" ]]; then
        [[ "$MOCK_ACTION_FAILS" == "cancel_once" ]] && MOCK_ACTION_FAILS=0
        return 2
    fi
    if [[ "$MOCK_ACTION_FAILS" != "0" ]]; then
        if [[ "$MOCK_ACTION_FAILS" == "once" ]]; then
            MOCK_ACTION_FAILS=0
        elif [[ "$MOCK_ACTION_FAILS" == "then_cancel" ]]; then
            MOCK_ACTION_FAILS=cancel
        fi
        log_error '关闭企业源失败，部分软件源可能已改写'
        return 1
    fi
    return 0
}

# Feed real numeric input (or EOF) through menu_sources_updates and assert its
# return status, user-facing messages, action count and menu cleanup.
run_menu_case() {
    local name="$1" input="$2" expected_status="$3" expected_calls="$4"
    local expect_invalid="$5" expect_failure="$6" status=0
    : > "$TMP_DIR/calls"
    menu_sources_updates < <(printf '%s' "$input") > "$TMP_DIR/output" || status=$?
    if [[ "$status" != "$expected_status" ]]; then
        cat "$TMP_DIR/output" >&2
        echo "FAIL: $name exit=$status, expected=$expected_status" >&2
        exit 1
    fi
    [[ "$(wc -l < "$TMP_DIR/calls" | tr -d ' ')" == "$expected_calls" ]]
    if [[ "$expect_invalid" == "1" ]]; then
        grep -q '无效选择: 9' "$TMP_DIR/output"
    elif grep -q '无效选择\|范围内的编号' "$TMP_DIR/output"; then
        echo "FAIL: $name misreported a valid action as invalid input" >&2
        exit 1
    fi
    if [[ "$expect_failure" == "1" ]]; then
        grep -q '操作执行失败' "$TMP_DIR/output"
    elif grep -q '操作执行失败' "$TMP_DIR/output"; then
        echo "FAIL: $name reported an action failure unexpectedly" >&2
        exit 1
    fi
    [[ "$MENU_DEPTH" == "0" && "$MENU_SKIP_PAUSE" == "1" ]]
    echo "PASS: $name"
}

MOCK_ACTION_FAILS=1
run_menu_case 'failed action is not invalid input and survives menu exit' $'1\n0\n' 2 1 0 1
run_menu_case 'failed action survives EOF' $'1\n' 2 1 0 1
run_menu_case 'invalid input does not erase an earlier action failure' $'1\n9\n0\n' 2 1 1 1
run_menu_case 'invalid input remains distinct from action failure' $'9\n0\n' 0 0 1 0
MOCK_ACTION_FAILS=once
run_menu_case 'later success does not erase an earlier action failure' $'1\n1\n0\n' 2 2 0 1
MOCK_ACTION_FAILS=0
run_menu_case 'successful action returns success' $'1\n0\n' 0 1 0 0
run_menu_case 'return without action remains successful' $'0\n' 0 0 0 0
MOCK_ACTION_FAILS=cancel
run_menu_case 'cancelled action is not a failure' $'1\n0\n' 0 1 0 0
run_menu_case 'cancelled action followed by EOF is not a failure' $'1\n' 0 1 0 0
MOCK_ACTION_FAILS=cancel_once
run_menu_case 'successful action after cancellation remains successful' $'1\n1\n0\n' 0 2 0 0
MOCK_ACTION_FAILS=then_cancel
run_menu_case 'cancellation does not erase an earlier action failure' $'1\n1\n0\n' 2 2 0 1
