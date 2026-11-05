#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# Issue #112: run the real change_sources() against sandbox paths, then ask
# APT to parse only those sources. Requires Linux, GNU sed and apt-get;
# no root, network access, package installation or host configuration writes.
# Usage: bash tests/sources-enterprise-test.sh
# shellcheck disable=SC2034,SC2317

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v apt-get >/dev/null || { echo "apt-get is required" >&2; exit 1; }
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/sources" "$TMP_DIR/lists/partial" "$TMP_DIR/backups"
: > "$TMP_DIR/sources/debian.sources"
: > "$TMP_DIR/sources/ceph.sources"

# Redirect every system path used by change_sources(), including its optional
# CT template update, before loading the actual implementation.
sed -e "s|/etc/apt/sources.list.d|$TMP_DIR/sources|g" \
    -e "s|/usr/share/perl5/PVE/APLInfo.pm|$TMP_DIR/APLInfo.pm|g" \
    "$REPO_ROOT/src/modules/02-sources/mirrors.sh" > "$TMP_DIR/mirrors.sh"
# shellcheck source=/dev/null
source "$TMP_DIR/mirrors.sh"

block_non_pve9_destructive() { return 0; }
mirror_selection_complete() { return 0; }
confirm_action() { return 0; }
log_step() { :; }
log_info() { :; }
log_success() { :; }
backup_file() { cp -- "$1" "$TMP_DIR/backups/$(basename "$1")"; }

MIRROR_SELECTED_DEBIAN=0
MIRROR_SELECTED_SECURITY=0
MIRROR_SELECTED_PVE=0
MIRROR_SELECTED_CEPH=0
MIRROR_SELECTED_CT=0
MIRROR_DEBIAN_URIS=("https://deb.debian.org/debian")
MIRROR_SECURITY_URIS=("https://security.debian.org/debian-security")
MIRROR_PVE_URIS=("http://download.proxmox.com/debian/pve")
MIRROR_CEPH_URIS=("http://download.proxmox.com/debian/ceph-squid")
MIRROR_CT_URIS=("http://download.proxmox.com")

SOURCE="$TMP_DIR/sources/pve-enterprise.sources"

assert_apt_sources() {
    # --print-uris parses and plans downloads without fetching any repository.
    apt-get -o Dir::Etc::sourcelist=/dev/null \
        -o Dir::Etc::sourceparts="$TMP_DIR/sources" \
        -o Dir::State::lists="$TMP_DIR/lists" \
        --print-uris update > "$TMP_DIR/uris" 2> "$TMP_DIR/apt-error" || {
        cat "$TMP_DIR/apt-error" >&2
        echo "FAIL: change_sources left an invalid enterprise source" >&2
        exit 1
    }
    if grep -q 'enterprise.proxmox.com' "$TMP_DIR/uris"; then
        echo "FAIL: enterprise repository is still enabled" >&2
        exit 1
    fi
    grep -q 'download.proxmox.com/debian/pve' "$TMP_DIR/uris"
    grep -q 'download.proxmox.com/debian/ceph-squid' "$TMP_DIR/uris"
    grep -q 'deb.debian.org/debian' "$TMP_DIR/uris"
}

run_case() {
    local name="$1"
    cat > "$SOURCE"
    cp -- "$SOURCE" "$TMP_DIR/original"
    change_sources
    cmp -- "$TMP_DIR/original" "$TMP_DIR/backups/pve-enterprise.sources"
    assert_apt_sources
    if grep -qEv '^[[:space:]]*(#|$)' "$SOURCE"; then
        echo "FAIL: active deb822 fields remain ($name)" >&2
        exit 1
    fi
    cp -- "$SOURCE" "$TMP_DIR/disabled"
    change_sources
    cmp -- "$SOURCE" "$TMP_DIR/disabled"
    assert_apt_sources
    echo "PASS: $name (backup, disabled, APT parser, idempotence)"
}

base_source() {
    printf '%s\n' \
        'Types: deb' \
        'URIs: https://enterprise.proxmox.com/debian/pve' \
        'Suites: trixie' \
        'Components: pve-enterprise' \
        'Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg'
}

{ base_source; printf 'Enabled: true\n'; } | run_case 'Enabled: true'
{ base_source; printf 'Enabled: false\n'; } | run_case 'Enabled: false'
base_source | run_case 'Enabled absent'
{ base_source | sed 's/^/#/'; printf 'Enabled: true\n'; } | run_case 'legacy malformed stanza'
{
    printf '# Existing comment\n\n'
    base_source
    printf 'Enabled: true\nArchitectures: amd64\nX-Custom: keep\n continuation\n\n'
    base_source | sed 's/^/  /'
    printf '  Enabled: yes\n  # Indented comment\n'
} | run_case 'multiple stanzas, extra fields, indentation and continuation'
printf '# Already commented\n\n  # Indented comment\n' | run_case 'comments only'
printf '' | run_case 'empty file'

rm -f -- "$SOURCE"
change_sources
[[ ! -e "$SOURCE" ]]
assert_apt_sources
echo 'PASS: absent enterprise source stays absent'
