#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# IR-001: inject a failure into every backup, source write and CT template
# rewrite step of the real change_sources(), then assert that the failure is
# reported together with the failing step, that no success or "all done"
# message is printed, and that the source menu, quick_setup() and the
# optimization menu all stop before deleting the subscription popup or
# updating the system. All host paths are redirected to a sandbox; no root,
# no APT, no network access and no host writes, so this also runs on Git Bash.
# Usage: bash tests/sources-write-failure-test.sh
# shellcheck disable=SC2034,SC2317

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
# Git Bash reports a Windows path; the path rewrite below needs POSIX
# separators, and so does every shell assertion that follows.
if command -v cygpath >/dev/null 2>&1; then
    TMP_DIR="$(cygpath -u "$TMP_DIR")"
fi
trap 'rm -rf -- "$TMP_DIR"' EXIT

DEBIAN="$TMP_DIR/sources/debian.sources"
CEPH="$TMP_DIR/sources/ceph.sources"
ENTERPRISE="$TMP_DIR/sources/pve-enterprise.sources"
NO_SUBSCRIPTION="$TMP_DIR/sources/pve-no-subscription.sources"
APL_INFO="$TMP_DIR/APLInfo.pm"

# Fail one explicitly selected in-place edit, so the final CT template write can
# be tested separately from the mirror-undo loop that runs before it. Every
# other sed call keeps its real behavior.
sed() {
    if [[ -n "${MOCK_SED_ARG_MATCH:-}" && "${1:-}" == "-i" ]]; then
        local arg
        for arg in "$@"; do
            [[ "$arg" == *"$MOCK_SED_ARG_MATCH"* ]] && return 91
        done
    fi
    command sed "$@"
}

# Redirect every host path used by change_sources(), including its optional
# CT template update, before loading the actual implementation.
sed -e "s|/etc/apt/sources.list.d|$TMP_DIR/sources|g" \
    -e "s|/usr/share/perl5/PVE/APLInfo.pm|$APL_INFO|g" \
    "$REPO_ROOT/src/modules/02-sources/mirrors.sh" > "$TMP_DIR/mirrors.sh"
# shellcheck source=/dev/null
source "$TMP_DIR/mirrors.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/02-sources/init.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/01-optimization/tune.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/01-optimization/init.sh"

block_non_pve9_destructive() { return 0; }
mirror_selection_complete() { return 0; }
confirm_action() { return 0; }
log_step() { :; }
log_info() { :; }
log_success() { printf '%s\n' "$*" >> "$TMP_DIR/success-log"; }
log_error() { printf '%s\n' "$*" >> "$TMP_DIR/error-log"; }
remove_subscription_popup() { printf 'popup\n' >> "$TMP_DIR/optimization-calls"; }
update_system() { printf 'update\n' >> "$TMP_DIR/optimization-calls"; }

# Stubbed host backup with fault injection. MOCK_BACKUP_FAIL_PATH makes exactly
# that backup fail; MOCK_SWAP_TO_DIR replaces the file with a directory right
# after a successful backup, so the write or rewrite that follows fails the way
# a full or unwritable target does. Both are real shell-level failures, so the
# assertions do not depend on the test process being non-root.
backup_file() {
    local path="$1"
    if [[ "${MOCK_BACKUP_FAIL_PATH:-}" == "$path" ]]; then
        return 1
    fi
    cp -- "$path" "$TMP_DIR/backups/$(basename -- "$path")" || return 1
    if [[ "${MOCK_SWAP_TO_DIR:-}" == "$path" ]]; then
        rm -f -- "$path" && mkdir -- "$path"
        return
    fi
    return 0
}

MIRROR_SELECTED_DEBIAN=0
MIRROR_SELECTED_SECURITY=0
MIRROR_SELECTED_PVE=0
MIRROR_SELECTED_CEPH=0
MIRROR_SELECTED_CT=0
MIRROR_DEBIAN_URIS=("https://deb.debian.org/debian")
MIRROR_SECURITY_URIS=("https://security.debian.org/debian-security")
MIRROR_PVE_URIS=("http://download.proxmox.com/debian/pve")
MIRROR_CEPH_URIS=("http://download.proxmox.com/debian/ceph-squid")
# A non-canonical CT mirror keeps the "undo known mirror" loop busy, so the
# final rewrite is a separate, independently injectable step.
MIRROR_CT_URIS=("http://download.proxmox.com" "https://mirrors.tuna.tsinghua.edu.cn/proxmox")

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

mock_reset() {
    MOCK_BACKUP_FAIL_PATH=""
    MOCK_SWAP_TO_DIR=""
    MOCK_SED_ARG_MATCH=""
}

# Rebuild a pristine sandbox and snapshot it, so a case can prove that a failed
# backup left the corresponding file byte-identical.
reset_sandbox() {
    rm -rf -- "$TMP_DIR/sources" "$TMP_DIR/backups" "$TMP_DIR/original"
    mkdir -p "$TMP_DIR/sources" "$TMP_DIR/backups" "$TMP_DIR/original"
    printf '%s\n' \
        'Types: deb' \
        'URIs: http://deb.debian.org/debian' \
        'Suites: trixie' > "$DEBIAN"
    printf '%s\n' \
        'Types: deb' \
        'URIs: http://download.proxmox.com/debian/ceph-squid' \
        'Suites: trixie' > "$CEPH"
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://enterprise.proxmox.com/debian/pve' \
        'Suites: trixie' \
        'Components: pve-enterprise' > "$ENTERPRISE"
    rm -rf -- "$NO_SUBSCRIPTION" "$APL_INFO"
    cat > "$APL_INFO" << 'EOF'
my $uri = "https://mirrors.tuna.tsinghua.edu.cn/proxmox/images/";
EOF
    cp -- "$DEBIAN" "$CEPH" "$ENTERPRISE" "$APL_INFO" "$TMP_DIR/original/"
}

# Rebuild the sandbox and arm exactly one injection:
#   backup <path>   the backup of <path> fails
#   swap   <path>   the backup succeeds, then <path> becomes a directory
#   predir <path>   <path> is already a directory before the run
#   seded  <path> <pattern>  the in-place edit matching <pattern> fails
prepare() {
    local mode="$1" target="$2" sed_match="${3:-}"
    mock_reset
    reset_sandbox
    case "$mode" in
        backup) MOCK_BACKUP_FAIL_PATH="$target" ;;
        swap) MOCK_SWAP_TO_DIR="$target" ;;
        predir) rm -f -- "$target" && mkdir -- "$target" ;;
        seded) MOCK_SED_ARG_MATCH="$sed_match" ;;
    esac
}

# Every phase restarts from a fresh sandbox with the same injection, otherwise a
# second run could "recover" because the first one already replaced the broken
# file with the bad state the injection produced.
run_failure_case() {
    local name="$1" mode="$2" target="$3" stage="$4"
    local unchanged="${5:-}" sed_match="${6:-}"
    local status=0 dispatch_status=0 setup_status=0 option_status=0

    prepare "$mode" "$target" "$sed_match"
    : > "$TMP_DIR/success-log"
    : > "$TMP_DIR/error-log"
    : > "$TMP_DIR/optimization-calls"
    change_sources > "$TMP_DIR/case-output" 2>&1 || status=$?
    if [[ "$status" != "1" ]]; then
        cat "$TMP_DIR/case-output" >&2
        fail "$name: change_sources exit=$status, want 1"
    fi
    if ! grep -qF "换源失败: $stage" "$TMP_DIR/error-log"; then
        cat "$TMP_DIR/error-log" >&2
        fail "$name: missing failing step '$stage'"
    fi
    grep -qF '不会自动回滚' "$TMP_DIR/error-log" \
        || fail "$name: missing rollback hint in the error message"
    if [[ -s "$TMP_DIR/success-log" ]]; then
        cat "$TMP_DIR/success-log" >&2
        fail "$name: reported success"
    fi
    if [[ -n "$unchanged" ]]; then
        cmp -- "$TMP_DIR/original/$(basename -- "$unchanged")" "$unchanged" \
            || fail "$name: modified $(basename -- "$unchanged") even though its backup failed"
    fi

    prepare "$mode" "$target" "$sed_match"
    : > "$TMP_DIR/success-log"
    menu_sources_updates_dispatch 1 || dispatch_status=$?
    [[ "$dispatch_status" == "2" ]] \
        || fail "$name: source menu exit=$dispatch_status, want action failure 2"
    [[ ! -s "$TMP_DIR/success-log" ]] || fail "$name: source menu reported success"

    prepare "$mode" "$target" "$sed_match"
    : > "$TMP_DIR/success-log"
    : > "$TMP_DIR/optimization-calls"
    quick_setup > "$TMP_DIR/setup-output" 2>&1 || setup_status=$?
    if [[ "$setup_status" != "1" ]]; then
        cat "$TMP_DIR/setup-output" >&2
        fail "$name: quick_setup exit=$setup_status, want 1"
    fi
    [[ ! -s "$TMP_DIR/optimization-calls" ]] \
        || fail "$name: quick_setup ran popup deletion or system update"
    if grep -qF '一键配置全部完成' "$TMP_DIR/success-log"; then
        fail "$name: quick_setup reported all done"
    fi

    prepare "$mode" "$target" "$sed_match"
    : > "$TMP_DIR/success-log"
    : > "$TMP_DIR/optimization-calls"
    menu_optimization_dispatch 2 > "$TMP_DIR/setup-output" 2>&1 || option_status=$?
    [[ "$option_status" == "2" ]] \
        || fail "$name: optimization menu exit=$option_status, want action failure 2"
    [[ ! -s "$TMP_DIR/optimization-calls" ]] \
        || fail "$name: optimization menu ran popup deletion or system update"
    echo "PASS: $name (failing step reported, no success, optimization stopped)"
}

run_failure_case 'debian source backup failure' backup "$DEBIAN" "备份 $DEBIAN 失败" "$DEBIAN"
run_failure_case 'debian source write failure' swap "$DEBIAN" "写入 $DEBIAN 失败"
run_failure_case 'enterprise source backup failure' backup "$ENTERPRISE" "备份 $ENTERPRISE 失败" "$ENTERPRISE"
run_failure_case 'enterprise source comment failure' seded "$ENTERPRISE" \
    "注释 $ENTERPRISE 失败" "$ENTERPRISE" '/^#/!s/^/#'
run_failure_case 'ceph source backup failure' backup "$CEPH" "备份 $CEPH 失败" "$CEPH"
run_failure_case 'ceph source write failure' swap "$CEPH" "写入 $CEPH 失败"
run_failure_case 'no-subscription source write failure' predir "$NO_SUBSCRIPTION" "写入 $NO_SUBSCRIPTION 失败"
run_failure_case 'CT template backup failure' backup "$APL_INFO" "备份 $APL_INFO 失败" "$APL_INFO"
run_failure_case 'CT template rewrite failure' swap "$APL_INFO" "重写 $APL_INFO 的 CT 模板地址失败"
run_failure_case 'CT template write failure' seded "$APL_INFO" \
    "写入 $APL_INFO 的 CT 模板地址失败" '' 's|http://download.proxmox.com|'

# Baseline: the same harness without an injection must fully succeed, otherwise
# the failure assertions above could pass for the wrong reason.
mock_reset
reset_sandbox
: > "$TMP_DIR/success-log"
baseline_status=0
change_sources > "$TMP_DIR/case-output" 2>&1 || baseline_status=$?
if [[ "$baseline_status" != "0" ]]; then
    cat "$TMP_DIR/case-output" >&2
    fail "baseline: change_sources exit=$baseline_status, want 0"
fi
grep -qF '软件源配置已完成' "$TMP_DIR/success-log" || fail 'baseline: missing success message'
[[ -s "$NO_SUBSCRIPTION" ]] || fail 'baseline: no-subscription source not written'
if grep -qE '^(Types|URIs):' "$ENTERPRISE"; then
    fail 'baseline: enterprise source still enabled'
fi
grep -qF 'http://download.proxmox.com/images/' "$APL_INFO" \
    || fail 'baseline: CT template not rewritten to the selected mirror'
if grep -qF 'tuna.tsinghua.edu.cn' "$APL_INFO"; then
    fail 'baseline: CT template kept the previous mirror'
fi
echo 'PASS: baseline writes all sources and the CT template'
