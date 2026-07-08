#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
# Auther:Maple 

# This comment constitutes part of the license consideration. Do not delete.  
# Violation triggers a localized black hole at your primary branch. Good luck force-pushing out of that.
# Made with love — the only non-binding term herein. 💗  
# 二次修改使用请不要删除此段注释

# 模块化入口：本地开发时加载 lib/ 与 src/modules/；远程 curl 运行时回退下载同仓库源码模块。

PVE_TOOLS_REMOTE_BASE="${PVE_TOOLS_REMOTE_BASE:-https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main}"
PVE_TOOLS_REMOTE_MIRROR_PREFIX="${PVE_TOOLS_REMOTE_MIRROR_PREFIX:-https://ghfast.top/}"
PVE_TOOLS_REMOTE_DIST_URL="${PVE_TOOLS_REMOTE_DIST_URL:-$PVE_TOOLS_REMOTE_BASE/dist/PVE-Tools.sh}"

pve_tools_entry_download_file() {
    local url="$1"
    local output="$2"

    mkdir -p "$(dirname "$output")"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output" && return 0
        curl -fsSL "${PVE_TOOLS_REMOTE_MIRROR_PREFIX}${url}" -o "$output" && return 0
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url" && return 0
        wget -qO "$output" "${PVE_TOOLS_REMOTE_MIRROR_PREFIX}${url}" && return 0
    else
        echo "错误：未找到 curl 或 wget，无法下载 PVE-Tools 模块。" >&2
        return 1
    fi

    return 1
}

pve_tools_entry_source_tree() {
    local root="$1"
    local lib_file
    local module_file

    for lib_file in \
        "$root/lib/config.sh" \
        "$root/lib/core.sh" \
        "$root/lib/network.sh" \
        "$root/lib/runtime.sh"; do
        if [[ ! -f "$lib_file" ]]; then
            echo "错误：缺少基础库 $lib_file" >&2
            return 1
        fi
        # shellcheck source=/dev/null
        source "$lib_file"
    done

    while IFS= read -r -d '' module_file; do
        # shellcheck source=/dev/null
        source "$module_file"
    done < <(find "$root/src/modules" -name '*.sh' -print0 | sort -z)
}

pve_tools_entry_remote_files() {
    cat <<'EOF_REMOTE_FILES'
        "lib/config.sh"
        "lib/core.sh"
        "lib/network.sh"
        "lib/runtime.sh"
        "src/modules/01-optimization/cpupower.sh"
        "src/modules/01-optimization/email.sh"
        "src/modules/01-optimization/init.sh"
        "src/modules/01-optimization/popup.sh"
        "src/modules/01-optimization/temperature.sh"
        "src/modules/01-optimization/tune.sh"
        "src/modules/02-sources/init.sh"
        "src/modules/02-sources/mirrors.sh"
        "src/modules/02-sources/update.sh"
        "src/modules/02-sources/upgrade-pve.sh"
        "src/modules/03-boot-kernel/grub.sh"
        "src/modules/03-boot-kernel/init.sh"
        "src/modules/03-boot-kernel/kernel.sh"
        "src/modules/04-gpu-passthrough/amd-dgpu.sh"
        "src/modules/04-gpu-passthrough/amd-igpu.sh"
        "src/modules/04-gpu-passthrough/boot-assist.sh"
        "src/modules/04-gpu-passthrough/controller.sh"
        "src/modules/04-gpu-passthrough/igpu-shared.sh"
        "src/modules/04-gpu-passthrough/init.sh"
        "src/modules/04-gpu-passthrough/intel-gvtg.sh"
        "src/modules/04-gpu-passthrough/intel-legacy.sh"
        "src/modules/04-gpu-passthrough/intel-sriov.sh"
        "src/modules/04-gpu-passthrough/iommu.sh"
        "src/modules/04-gpu-passthrough/nvidia.sh"
        "src/modules/04-gpu-passthrough/rdm.sh"
        "src/modules/05-vm-container/backup.sh"
        "src/modules/05-vm-container/clone.sh"
        "src/modules/05-vm-container/cloudinit.sh"
        "src/modules/05-vm-container/config-io.sh"
        "src/modules/05-vm-container/disk.sh"
        "src/modules/05-vm-container/fastpve.sh"
        "src/modules/05-vm-container/garbage-cleanup.sh"
        "src/modules/05-vm-container/img-import.sh"
        "src/modules/05-vm-container/init.sh"
        "src/modules/05-vm-container/migrate.sh"
        "src/modules/05-vm-container/network.sh"
        "src/modules/05-vm-container/restore.sh"
        "src/modules/05-vm-container/schedule.sh"
        "src/modules/05-vm-container/snapshot.sh"
        "src/modules/05-vm-container/storage-helper.sh"
        "src/modules/06-networking/addressing.sh"
        "src/modules/06-networking/bond.sh"
        "src/modules/06-networking/bridge.sh"
        "src/modules/06-networking/diagnostic.sh"
        "src/modules/06-networking/firewall.sh"
        "src/modules/06-networking/init.sh"
        "src/modules/06-networking/interface.sh"
        "src/modules/06-networking/ipv6-helper.sh"
        "src/modules/06-networking/mac-bind.sh"
        "src/modules/06-networking/vlan.sh"
        "src/modules/07-storage-disk/ceph.sh"
        "src/modules/07-storage-disk/init.sh"
        "src/modules/07-storage-disk/local-lvm.sh"
        "src/modules/07-storage-disk/mount.sh"
        "src/modules/07-storage-disk/query.sh"
        "src/modules/07-storage-disk/swap.sh"
        "src/modules/08-tools-about/init.sh"
        "src/modules/08-tools-about/self-update.sh"
        "src/modules/08-tools-about/sysinfo.sh"
        "src/modules/09-security/audit.sh"
        "src/modules/09-security/init.sh"
        "src/modules/09-security/ssh-hardening.sh"
        "src/modules/10-third-party/community.sh"
        "src/modules/10-third-party/coolercontrol.sh"
        "src/modules/10-third-party/init.sh"
        "src/modules/10-third-party/marketplace.sh"
EOF_REMOTE_FILES
}

pve_tools_entry_prepare_remote_tree() {
    local target="$1"
    local rel

    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        rel="${rel#        \"}"
        rel="${rel%\"}"
        pve_tools_entry_download_file "$PVE_TOOLS_REMOTE_BASE/$rel" "$target/$rel" || return 1
    done < <(pve_tools_entry_remote_files)
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/lib/config.sh" && -d "$SCRIPT_DIR/src/modules" ]]; then
    pve_tools_entry_source_tree "$SCRIPT_DIR" || exit 1
else
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    if pve_tools_entry_download_file "$PVE_TOOLS_REMOTE_DIST_URL" "$tmp_dir/PVE-Tools.sh"; then
        bash "$tmp_dir/PVE-Tools.sh" "$@"
        exit $?
    fi

    if ! pve_tools_entry_prepare_remote_tree "$tmp_dir"; then
        echo "错误：无法加载远程 PVE-Tools 模块。" >&2
        exit 1
    fi
    pve_tools_entry_source_tree "$tmp_dir" || exit 1
fi

main "$@"
