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
PVE_TOOLS_CONNECT_TIMEOUT="${PVE_TOOLS_CONNECT_TIMEOUT:-10}"
PVE_TOOLS_DOWNLOAD_TIMEOUT="${PVE_TOOLS_DOWNLOAD_TIMEOUT:-120}"
PVE_TOOLS_DOWNLOAD_RETRIES="${PVE_TOOLS_DOWNLOAD_RETRIES:-2}"

PVE_TOOLS_RELEASE_PAGE_URL="https://github.com/PVE-Tools/PVE-Tools-9/releases/tag/v10.2.0"
PVE_TOOLS_RELEASE_ASSET_URL="https://github.com/PVE-Tools/PVE-Tools-9/releases/download/v10.2.0/PVE-Tools.sh"
PVE_TOOLS_ENTRY_LAST_ERROR=""

pve_tools_entry_normalize_positive_integer() {
    local variable_name="$1"
    local default_value="$2"
    local value="${!variable_name:-}"

    if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "警告：$variable_name 必须是正整数，已使用默认值 $default_value。" >&2
        printf -v "$variable_name" '%s' "$default_value"
    fi
}

pve_tools_entry_curl_error() {
    local status="$1"
    local http_code="${2:-}"

    case "$status" in
        5|6)  PVE_TOOLS_ENTRY_LAST_ERROR="DNS 解析失败（curl $status）" ;;
        7)    PVE_TOOLS_ENTRY_LAST_ERROR="无法连接下载服务器（curl $status）" ;;
        18)   PVE_TOOLS_ENTRY_LAST_ERROR="下载内容不完整（curl $status）" ;;
        22)
            if [[ "$http_code" =~ ^[1-9][0-9][0-9]$ ]]; then
                PVE_TOOLS_ENTRY_LAST_ERROR="服务器返回 HTTP $http_code（curl $status）"
            else
                PVE_TOOLS_ENTRY_LAST_ERROR="服务器返回 HTTP 错误（curl $status）"
            fi
            ;;
        23)   PVE_TOOLS_ENTRY_LAST_ERROR="无法写入临时文件（curl $status）" ;;
        28)   PVE_TOOLS_ENTRY_LAST_ERROR="连接或下载超时（curl $status）" ;;
        35|51|60) PVE_TOOLS_ENTRY_LAST_ERROR="TLS 证书或握手失败（curl $status）" ;;
        47)   PVE_TOOLS_ENTRY_LAST_ERROR="服务器重定向次数过多（curl $status）" ;;
        56)   PVE_TOOLS_ENTRY_LAST_ERROR="接收下载数据失败（curl $status）" ;;
        124)  PVE_TOOLS_ENTRY_LAST_ERROR="下载超过 ${PVE_TOOLS_DOWNLOAD_TIMEOUT} 秒（curl $status）" ;;
        *)    PVE_TOOLS_ENTRY_LAST_ERROR="curl 下载失败（错误码 $status）" ;;
    esac
}

pve_tools_entry_wget_error() {
    local status="$1"

    case "$status" in
        3)   PVE_TOOLS_ENTRY_LAST_ERROR="无法写入临时文件（wget $status）" ;;
        4)   PVE_TOOLS_ENTRY_LAST_ERROR="网络连接失败（wget $status）" ;;
        5)   PVE_TOOLS_ENTRY_LAST_ERROR="TLS 证书或握手失败（wget $status）" ;;
        6)   PVE_TOOLS_ENTRY_LAST_ERROR="服务器认证失败（wget $status）" ;;
        7)   PVE_TOOLS_ENTRY_LAST_ERROR="服务器协议错误（wget $status）" ;;
        8)   PVE_TOOLS_ENTRY_LAST_ERROR="服务器返回错误状态（wget $status）" ;;
        124) PVE_TOOLS_ENTRY_LAST_ERROR="下载超过 ${PVE_TOOLS_DOWNLOAD_TIMEOUT} 秒（wget $status）" ;;
        *)   PVE_TOOLS_ENTRY_LAST_ERROR="wget 下载失败（错误码 $status）" ;;
    esac
}

pve_tools_entry_download_with_curl() {
    local url="$1"
    local output="$2"
    local status=0
    local http_code=""
    local retry_count=$((PVE_TOOLS_DOWNLOAD_RETRIES - 1))
    local -a curl_args=(
        --fail
        --location
        --show-error
        --connect-timeout "$PVE_TOOLS_CONNECT_TIMEOUT"
        --max-time "$PVE_TOOLS_DOWNLOAD_TIMEOUT"
        --speed-limit 1
        --speed-time 20
        --retry "$retry_count"
        --retry-delay 1
        --retry-connrefused
        --output "$output"
        --write-out '%{http_code}'
    )

    if [[ -t 2 ]]; then
        curl_args+=(--progress-bar)
    else
        curl_args+=(--silent)
    fi

    if command -v timeout >/dev/null 2>&1; then
        if http_code="$(timeout --kill-after=5s "$PVE_TOOLS_DOWNLOAD_TIMEOUT" curl "${curl_args[@]}" "$url")"; then
            return 0
        else
            status=$?
        fi
    elif http_code="$(curl "${curl_args[@]}" "$url")"; then
        return 0
    else
        status=$?
    fi

    pve_tools_entry_curl_error "$status" "$http_code"
    return "$status"
}

pve_tools_entry_download_with_wget() {
    local url="$1"
    local output="$2"
    local status=0
    local -a wget_args=(
        --connect-timeout="$PVE_TOOLS_CONNECT_TIMEOUT"
        --read-timeout=20
        --dns-timeout="$PVE_TOOLS_CONNECT_TIMEOUT"
        --tries="$PVE_TOOLS_DOWNLOAD_RETRIES"
        --waitretry=1
        -O "$output"
    )

    if [[ -t 2 ]]; then
        wget_args+=(--show-progress --progress=bar:force:noscroll)
    else
        wget_args+=(--no-verbose)
    fi

    if command -v timeout >/dev/null 2>&1; then
        if timeout --kill-after=5s "$PVE_TOOLS_DOWNLOAD_TIMEOUT" wget "${wget_args[@]}" "$url"; then
            return 0
        else
            status=$?
        fi
    elif wget "${wget_args[@]}" "$url"; then
        return 0
    else
        status=$?
    fi

    pve_tools_entry_wget_error "$status"
    return "$status"
}

pve_tools_entry_validate_script() {
    local script_path="$1"

    if [[ ! -s "$script_path" ]]; then
        PVE_TOOLS_ENTRY_LAST_ERROR="下载文件为空"
        return 1
    fi
    if ! bash -n "$script_path" >/dev/null 2>&1; then
        PVE_TOOLS_ENTRY_LAST_ERROR="下载内容不是有效的 Bash 脚本，可能是代理错误页"
        return 1
    fi
    if ! grep -q '^CURRENT_VERSION=' "$script_path"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="下载内容不是 PVE-Tools 主程序完整版"
        return 1
    fi

    return 0
}

pve_tools_entry_download_file() {
    local url="$1"
    local output="$2"
    local output_dir=""
    local part_file="${output}.part"
    local mirror_url=""
    local downloaded_bytes=""
    local download_status=0
    local index=0
    local source_count=0
    local source_name=""
    local source_url=""
    local -a source_names=("GitHub 原始源")
    local -a source_urls=("$url")

    output_dir="$(dirname "$output")"
    if ! mkdir -p "$output_dir"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建临时下载目录：$output_dir"
        echo "错误：$PVE_TOOLS_ENTRY_LAST_ERROR" >&2
        return 1
    fi

    if [[ -n "$PVE_TOOLS_REMOTE_MIRROR_PREFIX" && "$url" != "${PVE_TOOLS_REMOTE_MIRROR_PREFIX}"* ]]; then
        mirror_url="${PVE_TOOLS_REMOTE_MIRROR_PREFIX}${url}"
        source_names+=("GitHub 加速源")
        source_urls+=("$mirror_url")
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        PVE_TOOLS_ENTRY_LAST_ERROR="未找到 curl 或 wget"
        echo "错误：未找到 curl 或 wget，无法下载 PVE-Tools。" >&2
        echo "请先执行：apt update && apt install -y curl" >&2
        return 1
    fi

    source_count="${#source_urls[@]}"
    for ((index = 0; index < source_count; index++)); do
        source_name="${source_names[$index]}"
        source_url="${source_urls[$index]}"
        rm -f -- "$part_file"

        echo "[$((index + 1))/$source_count] 正在通过${source_name}下载主程序完整版..."
        echo "下载地址：$source_url"

        if command -v curl >/dev/null 2>&1; then
            if pve_tools_entry_download_with_curl "$source_url" "$part_file"; then
                download_status=0
            else
                download_status=$?
            fi
        elif pve_tools_entry_download_with_wget "$source_url" "$part_file"; then
            download_status=0
        else
            download_status=$?
        fi

        if [[ "$download_status" -eq 0 ]]; then
            echo "下载完成，正在校验脚本完整性..."
            if pve_tools_entry_validate_script "$part_file"; then
                if ! mv -f -- "$part_file" "$output"; then
                    PVE_TOOLS_ENTRY_LAST_ERROR="无法保存已下载的主程序"
                else
                    downloaded_bytes="$(wc -c < "$output")"
                    downloaded_bytes="${downloaded_bytes//[[:space:]]/}"
                    echo "${source_name}下载成功：${downloaded_bytes:-未知} 字节。"
                    return 0
                fi
            fi
        fi

        rm -f -- "$part_file"
        echo "${source_name}下载失败：$PVE_TOOLS_ENTRY_LAST_ERROR" >&2
        if ((index + 1 < source_count)); then
            echo "将自动切换到下一个下载源..." >&2
        fi
    done

    return 1
}

pve_tools_entry_print_release_help() {
    cat >&2 <<EOF

错误：PVE-Tools 主程序单文件完整版下载失败，程序尚未启动。
以上 GitHub 原始源和加速源均未能完成下载。

请在另一台能够访问 GitHub 的设备或网络中打开：
$PVE_TOOLS_RELEASE_PAGE_URL

展开 Assets，下载 PVE-Tools.sh（请勿下载 Source code 的 zip 或 tar.gz 压缩包）。
直接下载地址：$PVE_TOOLS_RELEASE_ASSET_URL

下载后可通过 SCP、WinSCP 或 U 盘传到 PVE 主机，然后执行：
  chmod +x PVE-Tools.sh
  sudo ./PVE-Tools.sh
EOF
}

pve_tools_entry_cleanup() {
    if [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]]; then
        rm -rf -- "$tmp_dir"
    fi
}

pve_tools_entry_normalize_positive_integer PVE_TOOLS_CONNECT_TIMEOUT 10
pve_tools_entry_normalize_positive_integer PVE_TOOLS_DOWNLOAD_TIMEOUT 120
pve_tools_entry_normalize_positive_integer PVE_TOOLS_DOWNLOAD_RETRIES 2

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
    tmp_dir=""
    if ! tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pve-tools-entry.XXXXXX")"; then
        echo "错误：无法创建 PVE-Tools 临时目录，程序尚未启动。" >&2
        exit 1
    fi
    trap pve_tools_entry_cleanup EXIT

    if pve_tools_entry_download_file "$PVE_TOOLS_REMOTE_DIST_URL" "$tmp_dir/PVE-Tools.sh"; then
        echo "主程序校验通过，正在启动 PVE-Tools..."
        bash "$tmp_dir/PVE-Tools.sh" "$@"
        exit $?
    fi

    pve_tools_entry_print_release_help
    exit 1
fi

main "$@"
