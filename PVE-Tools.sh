#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
# Auther:Maple

# This comment constitutes part of the license consideration. Do not delete.
# Violation triggers a localized black hole at your primary branch. Good luck force-pushing out of that.
# Made with love — the only non-binding term herein. 💗
# 二次修改使用请不要删除此段注释

# 模块化入口：本地开发 source 源码；远程 curl 运行时下载 dist 单文件执行。

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
        echo "错误：未找到 curl 或 wget，无法下载 PVE-Tools。" >&2
        return 1
    fi

    return 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/lib/config.sh" && -d "$SCRIPT_DIR/src/modules" ]]; then
    # 本地开发模式：直接 source 全部源码
    for lib_file in \
        "$SCRIPT_DIR/lib/config.sh" \
        "$SCRIPT_DIR/lib/core.sh" \
        "$SCRIPT_DIR/lib/network.sh" \
        "$SCRIPT_DIR/lib/runtime.sh"; do
        if [[ ! -f "$lib_file" ]]; then
            echo "错误：缺少基础库 $lib_file" >&2
            exit 1
        fi
        # shellcheck source=/dev/null
        source "$lib_file"
    done

    for module_dir in "$SCRIPT_DIR/src/modules"/*/; do
        [[ -d "$module_dir" ]] || continue
        if [[ -f "${module_dir}init.sh" ]]; then
            # shellcheck source=/dev/null
            source "${module_dir}init.sh"
        fi
        while IFS= read -r -d '' module_file; do
            [[ "$module_file" == "${module_dir}init.sh" ]] && continue
            # shellcheck source=/dev/null
            source "$module_file"
        done < <(find "$module_dir" -name '*.sh' -print0 | sort -z)
    done
else
    # 远程模式：下载 dist 单文件并执行
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    if pve_tools_entry_download_file "$PVE_TOOLS_REMOTE_DIST_URL" "$tmp_dir/PVE-Tools.sh"; then
        bash "$tmp_dir/PVE-Tools.sh" "$@"
        exit $?
    fi

    echo "错误：无法下载 PVE-Tools。请检查网络连接或稍后重试。" >&2
    echo "下载地址: $PVE_TOOLS_REMOTE_DIST_URL" >&2
    exit 1
fi

main "$@"
