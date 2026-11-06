#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# Exercise real mirror selection, confirmation, source actions and both menus.
# All host paths are redirected; later optimization steps only record calls.
# Usage: bash tests/sources-cancellation-test.sh
# shellcheck disable=SC2034,SC2317

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

# shellcheck source=/dev/null
source "$REPO_ROOT/lib/config.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/core.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/menu.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/network.sh"
sed -e "s|/etc/apt/sources.list.d|$TMP_DIR/sources|g" \
    -e "s|/usr/share/perl5/PVE/APLInfo.pm|$TMP_DIR/APLInfo.pm|g" \
    "$REPO_ROOT/src/modules/02-sources/mirrors.sh" > "$TMP_DIR/mirrors.sh"
# shellcheck source=/dev/null
source "$TMP_DIR/mirrors.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/02-sources/init.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/01-optimization/tune.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/01-optimization/init.sh"

clear() { :; }
show_menu_header() { :; }
show_menu_option() { :; }
show_menu_footer() { :; }
pause_function() { :; }
block_non_pve9_destructive() { return 0; }
log_step() { :; }
log_info() { printf 'INFO: %s\n' "$*"; }
log_error() { printf 'ERROR: %s\n' "$*"; }
log_warn() { printf 'WARN: %s\n' "$*"; }
log_success() { printf 'success: %s\n' "$*" >> "$TMP_DIR/events"; }
backup_file() { printf 'backup: %s\n' "$*" >> "$TMP_DIR/events"; }
remove_subscription_popup() { printf 'popup\n' >> "$TMP_DIR/events"; }
update_system() { printf 'update\n' >> "$TMP_DIR/events"; }

mkdir -p "$TMP_DIR/sources"
for file in debian ceph pve-enterprise pve-no-subscription; do
    printf '# Original %s\n' "$file" > "$TMP_DIR/sources/$file.sources"
done
cp -R "$TMP_DIR/sources" "$TMP_DIR/original-sources"
printf 'http://download.proxmox.com\n' > "$TMP_DIR/APLInfo.pm"
cp "$TMP_DIR/APLInfo.pm" "$TMP_DIR/original-APLInfo.pm"

# Conditional calls suppress errexit, matching the real menu dispatch context.
# Every cancellation must leave sources, CT configuration and later steps alone.
run_cancel_case() {
    local name="$1" action="$2" input="$3" expected_status="$4"
    local preset="${5:-0}" status=0 source_type
    mirror_reset_selection
    if [[ "$preset" == "1" ]]; then
        for source_type in debian security pve ceph ct; do
            mirror_set_selected "$source_type" 0
        done
    fi
    : > "$TMP_DIR/events"
    "$action" "${6:-}" < <(printf '%s' "$input") > "$TMP_DIR/output" 2>&1 || status=$?
    if [[ "$status" != "$expected_status" ]]; then
        cat "$TMP_DIR/output" >&2
        echo "FAIL: $name exit=$status, expected=$expected_status" >&2
        exit 1
    fi
    diff -r "$TMP_DIR/original-sources" "$TMP_DIR/sources"
    cmp "$TMP_DIR/original-APLInfo.pm" "$TMP_DIR/APLInfo.pm"
    if [[ -s "$TMP_DIR/events" ]] || grep -qE 'ERROR:|WARN:' "$TMP_DIR/output"; then
        cat "$TMP_DIR/events" "$TMP_DIR/output" >&2
        echo "FAIL: $name wrote configuration, continued optimization or reported failure" >&2
        exit 1
    fi
    for source_type in debian security pve ceph ct; do
        [[ "$(mirror_selected_index_by_type "$source_type")" == "$((preset - 1))" ]]
    done
    [[ "$MENU_DEPTH" == "0" ]]
    echo "PASS: $name"
}

run_cancel_case 'mirror skip has a distinct cancellation status' select_mirror $'3\n' 2
run_cancel_case 'mirror EOF cancels safely' select_mirror '' 2
run_cancel_case 'source action preserves mirror cancellation' change_sources $'3\n' 2
run_cancel_case 'source dispatcher distinguishes cancellation' menu_sources_updates_dispatch $'3\n' 3 0 1
run_cancel_case 'source menu handles mirror skip' menu_sources_updates $'1\n3\n0\n' 0
run_cancel_case 'source menu handles skip followed by EOF' menu_sources_updates $'1\n3\n' 0
run_cancel_case 'source menu handles EOF in mirror selection' menu_sources_updates $'1\n' 0
run_cancel_case 'source menu allows retry after skip' menu_sources_updates $'1\n3\n1\n3\n0\n' 0
run_cancel_case 'quick setup stops on mirror skip' quick_setup $'3\n' 2
run_cancel_case 'optimization dispatcher distinguishes cancellation' menu_optimization_dispatch $'3\n' 3 0 2
run_cancel_case 'optimization menu handles mirror skip' menu_optimization $'2\n3\n0\n' 0

run_cancel_case 'source action preserves declined confirmation' change_sources $'no\n' 2 1
run_cancel_case 'source action handles confirmation EOF' change_sources '' 2 1
run_cancel_case 'source dispatcher handles declined confirmation' menu_sources_updates_dispatch $'no\n' 3 1 1
run_cancel_case 'source menu handles declined confirmation' menu_sources_updates $'1\nno\n0\n' 0 1
run_cancel_case 'quick setup stops on declined confirmation' quick_setup $'no\n' 2 1
run_cancel_case 'optimization menu handles declined confirmation' menu_optimization $'2\nno\n0\n' 0 1
