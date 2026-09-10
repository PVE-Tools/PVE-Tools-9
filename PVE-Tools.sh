#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
# Auther:Maple

# This comment constitutes part of the license consideration. Do not delete.
# Violation triggers a localized black hole at your primary branch. Good luck force-pushing out of that.
# Made with love — the only non-binding term herein. 💗
# 二次修改使用请不要删除此段注释

# 模块化入口：本地开发 source 源码；远程 curl 运行时下载 dist 单文件执行。
# 同时承担可选安装器职责：--install 将完整版安装为系统命令 pvetools，--uninstall 卸载；
# 不带参数运行保持原有行为（远程模式下载完成后会交互询问是否顺便安装）。

# 远程模式从两个发布源下载构建产物（单文件完整版），顺序即优先级：
# 1. CNB 镜像发布仓（腾讯云 CDN，国内直连快、自家可信）：main 分支同步自 GitHub，
#    dist 分支由 CI 构建并发布单文件；
# 2. GitHub Release 资产（海外/兜底）。
# 仓库 main 分支不跟踪 dist/，raw 地址上没有 dist/PVE-Tools.sh，不要改回 raw 路径。
PVE_TOOLS_RELEASE_BASE_URL="${PVE_TOOLS_RELEASE_BASE_URL:-https://github.com/PVE-Tools/PVE-Tools-9/releases}"
PVE_TOOLS_CNB_RAW_BASE="${PVE_TOOLS_CNB_RAW_BASE:-https://cnb.cool/PVE-Tools/PVE-Tools-Pro/-/git/raw}"
PVE_TOOLS_CNB_DIST_URL="${PVE_TOOLS_CNB_DIST_URL:-$PVE_TOOLS_CNB_RAW_BASE/dist/PVE-Tools.sh}"
PVE_TOOLS_REMOTE_DIST_URL="${PVE_TOOLS_REMOTE_DIST_URL:-$PVE_TOOLS_RELEASE_BASE_URL/latest/download/PVE-Tools.sh}"
PVE_TOOLS_CONNECT_TIMEOUT="${PVE_TOOLS_CONNECT_TIMEOUT:-10}"
PVE_TOOLS_DOWNLOAD_TIMEOUT="${PVE_TOOLS_DOWNLOAD_TIMEOUT:-120}"
PVE_TOOLS_DOWNLOAD_RETRIES="${PVE_TOOLS_DOWNLOAD_RETRIES:-2}"

PVE_TOOLS_RELEASE_PAGE_URL="$PVE_TOOLS_RELEASE_BASE_URL/latest"
PVE_TOOLS_RELEASE_ASSET_URL="$PVE_TOOLS_RELEASE_BASE_URL/latest/download/PVE-Tools.sh"
PVE_TOOLS_ENTRY_LAST_ERROR=""

# 安装器配置：入口脚本不加载 lib/config.sh，以下默认值须与 lib/config.sh 中
# PVE_TOOLS_BIN_PATH / PVE_TOOLS_OPT_DIR / PVE_TOOLS_ALIAS_MARKER / PVE_TOOLS_INSTALL_META_FILE
# 保持一致。环境变量覆盖仅用于测试与自定义安装位置。
# 显式覆盖须在应用默认值前登记来源：卸载端加载元数据时环境变量优先于元数据回填。
PVE_TOOLS_INSTALL_BIN_PATH_FROM_ENV=0
[[ -n "${PVE_TOOLS_INSTALL_BIN_PATH:-}" ]] && PVE_TOOLS_INSTALL_BIN_PATH_FROM_ENV=1
PVE_TOOLS_INSTALL_BIN_PATH="${PVE_TOOLS_INSTALL_BIN_PATH:-/usr/local/bin/pvetools}"
PVE_TOOLS_INSTALL_OPT_DIR_FROM_ENV=0
[[ -n "${PVE_TOOLS_INSTALL_OPT_DIR:-}" ]] && PVE_TOOLS_INSTALL_OPT_DIR_FROM_ENV=1
PVE_TOOLS_INSTALL_OPT_DIR="${PVE_TOOLS_INSTALL_OPT_DIR:-/opt/pve-tools}"
# root 的 home 显式解析：sudo 下 $HOME 可能指向调用用户或未设置，
# 须与卸载端 ${HOME:-/root} 的目标保持一致，避免别名写入/清理错位
PVE_TOOLS_INSTALL_RC_FILE_FROM_ENV=0
if [[ -z "${PVE_TOOLS_INSTALL_RC_FILE:-}" ]]; then
    PVE_TOOLS_INSTALL_RC_FILE="$(getent passwd root 2>/dev/null | cut -d: -f6)"
    PVE_TOOLS_INSTALL_RC_FILE="${PVE_TOOLS_INSTALL_RC_FILE:-/root}/.bashrc"
else
    PVE_TOOLS_INSTALL_RC_FILE_FROM_ENV=1
fi
# 元数据路径固定不可覆盖：保证任意自定义安装后，不带环境变量的卸载端总能定位到它
PVE_TOOLS_INSTALL_META_FILE="/var/lib/pve-tools/installer.conf"
PVE_TOOLS_ALIAS_MARKER="ALIAS"

# 安装成功后由 install_from 写入的实际安装路径（含别名模式），供安装后立即启动使用
PVE_TOOLS_ENTRY_INSTALLED_PATH=""

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
    local downloaded_bytes=""
    local download_status=0
    local index=0
    local source_count=0
    local source_name=""
    local source_url=""
    # 顺序即优先级：CNB（腾讯 CDN）国内快且自家可信，GitHub Releases 海外/兜底
    local -a source_names=("CNB 国内源" "GitHub Releases")
    local -a source_urls=("$PVE_TOOLS_CNB_DIST_URL" "$url")

    output_dir="$(dirname "$output")"
    if ! mkdir -p "$output_dir"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建临时下载目录：$output_dir"
        echo "错误：$PVE_TOOLS_ENTRY_LAST_ERROR" >&2
        return 1
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
以上 CNB 国内源和 GitHub Release 源均未能完成下载。

请先检查主机网络，然后任选以下地址手动下载（请勿下载 Source code 的 zip 或 tar.gz 压缩包）：
CNB 国内源：
$PVE_TOOLS_CNB_DIST_URL
GitHub Releases（展开 Assets，下载 PVE-Tools.sh）：
$PVE_TOOLS_RELEASE_PAGE_URL

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

# ---------------------------------------------------------------------------
# 安装器：把校验通过的完整单文件安装为系统命令 pvetools，或按需卸载。
# ---------------------------------------------------------------------------

pve_tools_entry_print_usage() {
    cat <<EOF
用法: bash PVE-Tools.sh [选项] [主程序参数...]

不带选项运行时默认直接启动 PVE-Tools；远程模式下载完成后会询问是否顺便安装。

选项:
  --install     非交互安装为系统命令 $PVE_TOOLS_INSTALL_BIN_PATH，完成后自动启动
  --uninstall   卸载 pvetools：删除命令文件、$PVE_TOOLS_INSTALL_OPT_DIR 与别名标记块
  -h, --help    显示本帮助

环境变量:
  PVE_TOOLS_INSTALL_BIN_PATH   覆盖命令安装路径（当前: $PVE_TOOLS_INSTALL_BIN_PATH）
  PVE_TOOLS_INSTALL_OPT_DIR    覆盖别名模式脚本目录（当前: $PVE_TOOLS_INSTALL_OPT_DIR）
  PVE_TOOLS_INSTALL_RC_FILE    覆盖别名写入的 shell 配置文件（当前: $PVE_TOOLS_INSTALL_RC_FILE）
EOF
}

pve_tools_entry_extract_version() {
    local script_path="$1"

    grep -m1 '^CURRENT_VERSION=' "$script_path" 2>/dev/null | cut -d'"' -f2
}

pve_tools_entry_is_full_script() {
    local script_path="$1"

    [[ -f "$script_path" ]] && grep -q '^CURRENT_VERSION=' "$script_path" 2>/dev/null
}

pve_tools_entry_require_root() {
    local action="$1"
    local self="${BASH_SOURCE[0]:-}"
    local entry_flag=""
    local rerun_hint="sudo bash <(curl -sSL https://pve.u3u.icu/PVE-Tools.sh)"

    # 把入口模式翻译为解析器认可的 flag；run 对应默认行为（不带参数）
    case "$PVE_TOOLS_ENTRY_MODE" in
        install)   entry_flag="--install" ;;
        uninstall) entry_flag="--uninstall" ;;
        help)      entry_flag="--help" ;;
    esac

    if [[ -n "$self" && -f "$self" && "$self" != /dev/fd/* ]]; then
        rerun_hint="sudo bash $self"
    fi
    [[ -n "$entry_flag" ]] && rerun_hint="$rerun_hint $entry_flag"

    if [[ $EUID -ne 0 ]]; then
        echo "错误：$action 需要 root 权限，未对系统做任何更改。" >&2
        echo "请使用以下命令重新运行：" >&2
        echo "  $rerun_hint" >&2
        return 1
    fi
}

pve_tools_entry_write_alias_block() {
    local target_script="$1"
    local rc_file="$PVE_TOOLS_INSTALL_RC_FILE"
    local rc_dir rc_backup tmp_rc=""
    local has_begin=0 has_end=0

    rc_dir="$(dirname "$rc_file")"
    if ! mkdir -p "$rc_dir"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建配置目录：$rc_dir"
        return 1
    fi
    if [[ -e "$rc_file" && ! -f "$rc_file" ]]; then
        PVE_TOOLS_ENTRY_LAST_ERROR="别名配置路径不是普通文件：$rc_file"
        return 1
    fi

    # 首次写入前备份原配置，便于手动恢复；失败不阻断安装
    rc_backup="${rc_file}.pve-tools-bak"
    if [[ -f "$rc_file" && ! -f "$rc_backup" ]]; then
        cp -a "$rc_file" "$rc_backup" 2>/dev/null || true
    fi

    # 完整性前置校验：BEGIN 与 END 必须同时存在才允许自动改写，
    # 避免用户手改导致的不完整标记块被 sed 范围删除波及到文件尾
    grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null && has_begin=1
    grep -q "^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null && has_end=1
    if [[ "$has_begin" -ne "$has_end" ]]; then
        PVE_TOOLS_ENTRY_LAST_ERROR="$rc_file 中别名标记块不完整（缺 $([[ "$has_begin" -eq 1 ]] && echo "END" || echo "BEGIN") 标记），已拒绝自动改写，请手动检查该文件"
        return 1
    fi

    # 幂等且原子：先在临时文件中生成「原内容去掉旧标记块 + 新标记块」，再整体替换，
    # 任一步失败都不会破坏现有 RC 文件
    tmp_rc="$(mktemp "${rc_file}.XXXXXX")" || {
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建临时文件以更新别名配置"
        return 1
    }
    if [[ "$has_begin" -eq 1 ]]; then
        if ! sed "/^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$/,/^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$/d" "$rc_file" > "$tmp_rc"; then
            rm -f -- "$tmp_rc"
            PVE_TOOLS_ENTRY_LAST_ERROR="读取别名配置失败：$rc_file"
            return 1
        fi
    elif [[ -f "$rc_file" ]]; then
        cat -- "$rc_file" > "$tmp_rc" || {
            rm -f -- "$tmp_rc"
            PVE_TOOLS_ENTRY_LAST_ERROR="无法读取别名配置：$rc_file"
            return 1
        }
    fi
    {
        echo ""
        echo "# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER"
        echo "alias pvetools='$target_script'"
        echo "# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER"
    } >> "$tmp_rc" || {
        rm -f -- "$tmp_rc"
        PVE_TOOLS_ENTRY_LAST_ERROR="无法写入别名配置临时文件"
        return 1
    }

    # 原子替换前保留原 RC 文件的属主与权限；原文件不存在时保持 mktemp 默认属性
    if [[ -f "$rc_file" ]]; then
        if ! chmod --reference="$rc_file" "$tmp_rc" || ! chown --reference="$rc_file" "$tmp_rc"; then
            rm -f -- "$tmp_rc"
            PVE_TOOLS_ENTRY_LAST_ERROR="无法保留原配置文件的权限与属主：$rc_file"
            return 1
        fi
    fi

    if ! mv -f "$tmp_rc" "$rc_file"; then
        rm -f -- "$tmp_rc"
        PVE_TOOLS_ENTRY_LAST_ERROR="无法替换别名配置：$rc_file"
        return 1
    fi
}

pve_tools_entry_remove_alias_block() {
    local rc_file="${1:-$PVE_TOOLS_INSTALL_RC_FILE}"
    local tmp_rc=""
    local has_begin=0 has_end=0

    [[ -f "$rc_file" ]] || return 0
    grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null && has_begin=1
    grep -q "^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null && has_end=1

    # 无标记块：无事可做；只有单边标记：视为不完整块，拒绝按范围删除以免误删文件尾部内容
    if [[ "$has_begin" -eq 0 && "$has_end" -eq 0 ]]; then
        return 0
    fi
    if [[ "$has_begin" -ne "$has_end" ]]; then
        PVE_TOOLS_ENTRY_LAST_ERROR="$rc_file 中别名标记块不完整（缺 $([[ "$has_begin" -eq 1 ]] && echo "END" || echo "BEGIN") 标记），已拒绝自动清理，请手动检查该文件"
        return 1
    fi

    tmp_rc="$(mktemp "${rc_file}.XXXXXX")" || {
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建临时文件以清理别名配置"
        return 1
    }
    if sed "/^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$/,/^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$/d" "$rc_file" > "$tmp_rc"; then
        # 替换前保留原 RC 文件的属主与权限（mktemp 默认 0600）
        if chmod --reference="$rc_file" "$tmp_rc" && chown --reference="$rc_file" "$tmp_rc" && mv -f "$tmp_rc" "$rc_file"; then
            return 0
        fi
    fi
    rm -f "$tmp_rc"
    PVE_TOOLS_ENTRY_LAST_ERROR="清理别名配置失败：$rc_file"
    return 1
}

# 安装成功后持久化实际安装路径，供卸载逻辑（入口 --uninstall 与主程序卸载）在
# 未携带安装时环境变量的场景下也能定位自定义位置。
# 读取端使用白名单逐行解析而非 source：dist 内禁止出现 source/eval。
pve_tools_entry_write_install_meta() {
    local meta_dir=""

    meta_dir="$(dirname "$PVE_TOOLS_INSTALL_META_FILE")"
    if ! mkdir -p "$meta_dir"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建元数据目录：$meta_dir"
        return 1
    fi
    {
        echo "# PVE-Tools 安装器元数据（自动生成，供卸载逻辑读取实际安装路径）"
        echo "PVE_TOOLS_BIN_PATH=$PVE_TOOLS_INSTALL_BIN_PATH"
        echo "PVE_TOOLS_OPT_DIR=$PVE_TOOLS_INSTALL_OPT_DIR"
        echo "PVE_TOOLS_RC_FILE=$PVE_TOOLS_INSTALL_RC_FILE"
    } > "$PVE_TOOLS_INSTALL_META_FILE" || {
        PVE_TOOLS_ENTRY_LAST_ERROR="无法写入安装元数据：$PVE_TOOLS_INSTALL_META_FILE"
        return 1
    }
}

pve_tools_entry_load_install_meta() {
    local key="" value=""

    [[ -r "$PVE_TOOLS_INSTALL_META_FILE" ]] || return 0
    while IFS='=' read -r key value; do
        case "$key" in
            PVE_TOOLS_BIN_PATH)
                if [[ -n "$value" && "$PVE_TOOLS_INSTALL_BIN_PATH_FROM_ENV" -eq 0 ]]; then
                    PVE_TOOLS_INSTALL_BIN_PATH="$value"
                fi
                ;;
            PVE_TOOLS_OPT_DIR)
                if [[ -n "$value" && "$PVE_TOOLS_INSTALL_OPT_DIR_FROM_ENV" -eq 0 ]]; then
                    PVE_TOOLS_INSTALL_OPT_DIR="$value"
                fi
                ;;
            PVE_TOOLS_RC_FILE)
                if [[ -n "$value" && "$PVE_TOOLS_INSTALL_RC_FILE_FROM_ENV" -eq 0 ]]; then
                    PVE_TOOLS_INSTALL_RC_FILE="$value"
                fi
                ;;
        esac
    done < <(grep -E '^(PVE_TOOLS_BIN_PATH|PVE_TOOLS_OPT_DIR|PVE_TOOLS_RC_FILE)=' "$PVE_TOOLS_INSTALL_META_FILE")
}

# 覆盖旧版本前备份到 /var/backups/pve-tools/，与主程序 backup 约定保持一致。
# 按目标 basename 派生备份名，bin（pvetools）与 alias（PVE-Tools.sh）模式备份互不覆盖。
pve_tools_entry_backup_existing() {
    local target="$1"
    local backup_dir="/var/backups/pve-tools"
    local backup_path
    backup_path="${backup_dir}/$(basename "$target").bak"

    [[ -f "$target" ]] || return 0
    mkdir -p "$backup_dir" || return 1
    cp -a "$target" "$backup_path"
}

# 目标位置被异己文件占用时拒绝覆盖，避免误伤同名工具
pve_tools_entry_check_target() {
    local target="$1"

    [[ -e "$target" ]] || return 0
    if [[ ! -f "$target" ]]; then
        PVE_TOOLS_ENTRY_LAST_ERROR="目标路径已被非普通文件占用：$target"
        return 1
    fi
    if ! pve_tools_entry_is_full_script "$target"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="目标路径已存在其他程序文件，拒绝覆盖：$target"
        return 1
    fi
    return 0
}

pve_tools_entry_place_file() {
    local source_file="$1"
    local target="$2"
    local target_dir=""
    local tmp_target=""

    target_dir="$(dirname "$target")"
    if ! mkdir -p "$target_dir"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="无法创建安装目录：$target_dir"
        return 1
    fi

    tmp_target="${target_dir}/.pvetools.new.$$"
    if ! install -m 0755 "$source_file" "$tmp_target"; then
        rm -f -- "$tmp_target"
        PVE_TOOLS_ENTRY_LAST_ERROR="无法写入安装临时文件：$tmp_target"
        return 1
    fi
    if ! mv -f "$tmp_target" "$target"; then
        rm -f -- "$tmp_target"
        PVE_TOOLS_ENTRY_LAST_ERROR="无法替换安装文件：$target"
        return 1
    fi
}

# bin 模式安装完成后的遮蔽检测：交互终端中别名/函数优先于 PATH 命令解析，
# v10 时代遗留的无标记 pvetools 别名或旧引导副本会让用户继续运行失效脚本
# （raw main 的 dist 路径自 v10.2.1 起不存在，必 404）。入口端只警告不改动，
# 确认后的自动清理见主程序菜单 8 的「安装环境诊断」。
pve_tools_entry_check_legacy_shadow() {
    local rc_file="$PVE_TOOLS_INSTALL_RC_FILE"
    local candidate="" shadow_found=0
    local -a candidate_paths=(
        "/usr/bin/pvetools"
        "/bin/pvetools"
        "/root/PVE-Tools.sh"
        "/root/bin/pvetools"
        "${PVE_TOOLS_INSTALL_OPT_DIR}/PVE-Tools.sh"
    )

    # 安装器标记块之外的 pvetools 别名（标记块内的由安装器自身管理，不在此列）
    if [[ -f "$rc_file" ]] && sed "/^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$/,/^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$/d" "$rc_file" 2>/dev/null | grep -q "^[[:space:]]*alias[[:space:]]\+pvetools="; then
        shadow_found=1
        echo "警告：$rc_file 中存在标记块之外的 pvetools 别名，交互终端中别名优先于新装的命令生效。" >&2
    fi

    for candidate in "${candidate_paths[@]}"; do
        [[ -f "$candidate" ]] || continue
        if grep -q "PVE_TOOLS_REMOTE_BASE" "$candidate" 2>/dev/null; then
            shadow_found=1
            echo "警告：发现 v10 旧引导脚本副本 $candidate（内置下载地址已失效），建议删除。" >&2
        fi
    done

    if [[ "$shadow_found" -eq 1 ]]; then
        echo "提示：可运行 pvetools 后进入菜单 8 选择「安装环境诊断」自动清理残留。" >&2
    fi
}

pve_tools_entry_install_from() {
    local source_file="$1"
    local mode="$2"
    local target=""
    local old_version="" new_version=""
    local answer=""
    local rc_snapshot="" rc_existed=0

    if ! pve_tools_entry_validate_script "$source_file"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="待安装内容不是有效的完整版主程序：${PVE_TOOLS_ENTRY_LAST_ERROR:-未知原因}"
        return 1
    fi

    if ! pve_tools_entry_require_root "安装 pvetools"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="缺少 root 权限"
        return 1
    fi

    if [[ -z "$mode" ]]; then
        echo "请选择安装方式："
        echo "  [1] 安装系统命令 $PVE_TOOLS_INSTALL_BIN_PATH（推荐）"
        echo "  [2] 保存到 $PVE_TOOLS_INSTALL_OPT_DIR 并写入 $PVE_TOOLS_INSTALL_RC_FILE 别名"
        if ! read -r -p "请输入 [1-2]（回车默认 1，输入其他取消安装）: " answer; then
            answer=""
        fi
        answer="${answer:-1}"
        case "$answer" in
            1) mode="bin" ;;
            2) mode="alias" ;;
            *)
                echo "已取消安装。"
                PVE_TOOLS_ENTRY_LAST_ERROR="用户取消安装"
                return 2
                ;;
        esac
    fi

    case "$mode" in
        bin)   target="$PVE_TOOLS_INSTALL_BIN_PATH" ;;
        alias) target="$PVE_TOOLS_INSTALL_OPT_DIR/PVE-Tools.sh" ;;
        *)
            PVE_TOOLS_ENTRY_LAST_ERROR="未知安装方式：$mode"
            return 1
            ;;
    esac

    old_version="$(pve_tools_entry_extract_version "$target")"
    new_version="$(pve_tools_entry_extract_version "$source_file")"
    if [[ -n "$old_version" ]]; then
        echo "检测到已安装版本 v$old_version，将覆盖升级。"
    fi

    if ! pve_tools_entry_check_target "$target"; then
        return 1
    fi
    if [[ -n "$old_version" ]] && ! pve_tools_entry_backup_existing "$target"; then
        PVE_TOOLS_ENTRY_LAST_ERROR="备份旧版本到 /var/backups/pve-tools/ 失败"
        return 1
    fi

    # 别名模式采用事务顺序：先原子更新 RC 别名块（此时旧脚本未动，失败即安全中止），
    # 再替换脚本；替换失败则从快照恢复 RC，旧脚本因 mv 原子性天然无损。
    if [[ "$mode" == "alias" ]]; then
        [[ -f "$PVE_TOOLS_INSTALL_RC_FILE" ]] && rc_existed=1
        rc_snapshot="$(mktemp)" || {
            PVE_TOOLS_ENTRY_LAST_ERROR="无法创建 RC 快照临时文件"
            return 1
        }
        if [[ "$rc_existed" -eq 1 ]] && ! cp -a "$PVE_TOOLS_INSTALL_RC_FILE" "$rc_snapshot"; then
            rm -f -- "$rc_snapshot"
            PVE_TOOLS_ENTRY_LAST_ERROR="无法快照 RC 文件：$PVE_TOOLS_INSTALL_RC_FILE"
            return 1
        fi
        if ! pve_tools_entry_write_alias_block "$target"; then
            rm -f -- "$rc_snapshot"
            return 1
        fi
    fi

    if ! pve_tools_entry_place_file "$source_file" "$target"; then
        if [[ "$mode" == "alias" ]]; then
            if [[ "$rc_existed" -eq 1 ]]; then
                cp -a "$rc_snapshot" "$PVE_TOOLS_INSTALL_RC_FILE" 2>/dev/null || true
            else
                pve_tools_entry_remove_alias_block "$PVE_TOOLS_INSTALL_RC_FILE" 2>/dev/null || true
            fi
        fi
        rm -f -- "$rc_snapshot"
        return 1
    fi
    rm -f -- "$rc_snapshot"

    PVE_TOOLS_ENTRY_INSTALLED_PATH="$target"

    # 元数据写入失败不阻断安装，但需提示自定义路径场景的卸载影响
    if ! pve_tools_entry_write_install_meta; then
        echo "警告：安装元数据写入失败（$PVE_TOOLS_ENTRY_LAST_ERROR），自定义路径下卸载时可能需要重新指定环境变量。" >&2
    fi

    echo "安装完成：pvetools (v$new_version)"
    if [[ "$mode" == "alias" ]]; then
        echo "脚本位置：$target"
        echo "别名已写入：$PVE_TOOLS_INSTALL_RC_FILE（新终端自动生效，当前终端可执行 source $PVE_TOOLS_INSTALL_RC_FILE）"
    else
        echo "命令路径：$target"
    fi
    echo "卸载方式：运行 pvetools --uninstall，或在主程序菜单 8 中选择本地脚本快捷卸载。"
    if [[ "$mode" == "bin" ]]; then
        pve_tools_entry_check_legacy_shadow
    fi
    return 0
}

pve_tools_entry_uninstall_system() {
    local bin_path="" opt_dir="" rc_file="" rc_backup=""
    local has_bin=0 has_opt=0 has_alias=0 has_bak=0 found=0
    local answer=""
    local failures=0

    if ! pve_tools_entry_require_root "卸载 pvetools"; then
        return 1
    fi

    # 优先读取安装时持久化的实际路径，环境变量覆盖仍具有最高优先级
    pve_tools_entry_load_install_meta
    bin_path="$PVE_TOOLS_INSTALL_BIN_PATH"
    opt_dir="$PVE_TOOLS_INSTALL_OPT_DIR"
    rc_file="$PVE_TOOLS_INSTALL_RC_FILE"

    if pve_tools_entry_is_full_script "$bin_path"; then
        has_bin=1; found=1
    elif [[ -e "$bin_path" ]]; then
        echo "警告：$bin_path 存在但不是 PVE-Tools 完整版，跳过删除。" >&2
    fi
    # 目录须包含本工具安装的完整脚本才纳入删除清单，避免自定义路径误指向其他目录时被 rm -rf
    if [[ -d "$opt_dir" ]] && pve_tools_entry_is_full_script "$opt_dir/PVE-Tools.sh"; then
        has_opt=1; found=1
    fi
    # 残留的单边标记（仅 BEGIN 或仅 END）同样视为存在别名块：
    # remove_alias_block 会拒绝不完整块的自动清理并保留恢复信息
    if grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null \
        || grep -q "^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null; then
        has_alias=1; found=1
    fi
    # 首次写入别名块前的配置备份（write_alias_block 创建）属于安装器产物，卸载时一并清理
    rc_backup="${rc_file}.pve-tools-bak"
    if [[ -f "$rc_backup" ]]; then
        has_bak=1; found=1
    fi

    if [[ "$found" -eq 0 ]]; then
        echo "未发现已安装的 pvetools，无需卸载。"
        return 0
    fi

    echo "即将卸载以下内容："
    [[ "$has_bin" -eq 1 ]] && echo "  - 命令文件：$bin_path"
    [[ "$has_opt" -eq 1 ]] && echo "  - 脚本目录：$opt_dir/"
    [[ "$has_alias" -eq 1 ]] && echo "  - 别名标记块：$rc_file"
    [[ "$has_bak" -eq 1 ]] && echo "  - 首次安装前配置备份：$rc_backup"

    if ! read -r -p "确认卸载？输入 yes 继续，其他任意键取消: " answer; then
        answer=""
    fi
    if [[ "$answer" != "yes" ]]; then
        echo "已取消卸载。"
        return 0
    fi

    if [[ "$has_bin" -eq 1 ]]; then
        if rm -f -- "$bin_path"; then
            echo "已删除：$bin_path"
        else
            echo "错误：删除失败：$bin_path" >&2
            failures=1
        fi
    fi
    if [[ "$has_opt" -eq 1 ]]; then
        if rm -rf -- "${opt_dir%/}"; then
            echo "已删除：${opt_dir%/}/"
        else
            echo "错误：目录删除失败：${opt_dir%/}/" >&2
            failures=1
        fi
    fi
    if [[ "$has_alias" -eq 1 ]]; then
        if pve_tools_entry_remove_alias_block "$rc_file"; then
            echo "已清理：$rc_file 中的别名标记块"
        else
            echo "错误：$PVE_TOOLS_ENTRY_LAST_ERROR" >&2
            failures=1
        fi
    fi
    # rc 备份是失败场景的恢复依据：仅在其余清理全部成功时删除，否则保留并提示
    if [[ "$has_bak" -eq 1 ]]; then
        if [[ "$failures" -eq 0 ]]; then
            if rm -f -- "$rc_backup"; then
                echo "已删除：$rc_backup"
            else
                echo "错误：删除失败：$rc_backup" >&2
                failures=1
            fi
        else
            echo "提示：已保留配置备份 $rc_backup（存在未完成清理项）。" >&2
        fi
    fi

    # 仅在全部清理成功后删除元数据；存在失败时保留，修复残留后重新卸载仍可定位自定义路径
    if [[ -f "$PVE_TOOLS_INSTALL_META_FILE" ]]; then
        if [[ "$failures" -eq 0 ]]; then
            if rm -f -- "$PVE_TOOLS_INSTALL_META_FILE"; then
                echo "已清理安装元数据：$PVE_TOOLS_INSTALL_META_FILE"
            else
                echo "错误：无法删除安装元数据：$PVE_TOOLS_INSTALL_META_FILE" >&2
                failures=1
            fi
        else
            echo "提示：已保留安装元数据 $PVE_TOOLS_INSTALL_META_FILE（存在未完成清理项，处理后重新运行卸载即可继续）。" >&2
        fi
    fi

    if [[ "$failures" -ne 0 ]]; then
        echo "卸载未完全完成，请根据上方错误信息手动处理残留项。" >&2
        return 1
    fi
    echo "卸载完成。"
}

# 安装成功后询问是否立即启动（仅交互终端询问）；启动结果通过返回值交给调用方 exit
pve_tools_entry_launch_installed() {
    local installed_path="$1"
    shift
    local answer=""

    if [[ ! -t 0 ]]; then
        echo "提示：现在即可运行 pvetools 启动 PVE-Tools。"
        return 0
    fi

    read -r -p "是否立即启动 PVE-Tools？(Y/n): " answer || answer=""
    answer="${answer:-y}"
    if [[ "$answer" =~ ^[Nn] ]]; then
        echo "提示：随时运行 pvetools 即可启动。"
        return 0
    fi
    bash "$installed_path" "$@"
}

# 远程模式下载完成后的交互分流；返回 0 表示继续直接启动临时副本，
# 若用户完成安装流程则在函数内部自行 exit。
pve_tools_entry_maybe_offer_install() {
    local downloaded_file="$1"
    shift
    local choice=""

    if [[ ! -t 0 ]]; then
        echo "提示：追加 --install 参数可将 PVE-Tools 安装为系统命令 pvetools。"
        return 0
    fi

    echo
    echo "请选择运行方式："
    echo "  [1] 直接启动（默认，回车即选）"
    echo "  [2] 安装到系统（安装后可随时用 pvetools 命令启动）"
    if ! read -r -p "请输入 [1-2]: " choice; then
        choice="1"
    fi
    case "${choice:-1}" in
        2)
            if pve_tools_entry_install_from "$downloaded_file" ""; then
                echo
                pve_tools_entry_launch_installed "${PVE_TOOLS_ENTRY_INSTALLED_PATH:-$PVE_TOOLS_INSTALL_BIN_PATH}" "$@"
                exit $?
            fi
            if [[ "$PVE_TOOLS_ENTRY_LAST_ERROR" != "用户取消安装" && "$PVE_TOOLS_ENTRY_LAST_ERROR" != "缺少 root 权限" ]]; then
                echo "错误：$PVE_TOOLS_ENTRY_LAST_ERROR" >&2
            fi
            echo "已跳过安装，继续直接启动..." >&2
            return 0
            ;;
    esac
    return 0
}

pve_tools_entry_normalize_positive_integer PVE_TOOLS_CONNECT_TIMEOUT 10
pve_tools_entry_normalize_positive_integer PVE_TOOLS_DOWNLOAD_TIMEOUT 120
pve_tools_entry_normalize_positive_integer PVE_TOOLS_DOWNLOAD_RETRIES 2

# CLI 预解析：安装器参数（--install/--uninstall/--help）在入口层消费，不透传给主程序
PVE_TOOLS_ENTRY_MODE="run"
pve_tools_entry_parse_cli_args() {
    local -a remaining_args=()
    local arg=""

    for arg in "$@"; do
        case "$arg" in
            --install)   PVE_TOOLS_ENTRY_MODE="install" ;;
            --uninstall) PVE_TOOLS_ENTRY_MODE="uninstall" ;;
            --help|-h)   PVE_TOOLS_ENTRY_MODE="help" ;;
            *)           remaining_args+=("$arg") ;;
        esac
    done
    PVE_TOOLS_ENTRY_ARGS=("${remaining_args[@]}")
}
pve_tools_entry_parse_cli_args "$@"

case "$PVE_TOOLS_ENTRY_MODE" in
    help)
        pve_tools_entry_print_usage
        exit 0
        ;;
    uninstall)
        pve_tools_entry_uninstall_system
        exit $?
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/lib/config.sh" && -d "$SCRIPT_DIR/src/modules" ]]; then
    # 本地开发模式：直接 source 全部源码
    if [[ "$PVE_TOOLS_ENTRY_MODE" == "install" ]]; then
        echo "提示：检测到本地源码目录，开发环境无需安装；如需体验安装流程请使用远程命令运行。" >&2
    fi
    for lib_file in \
        "$SCRIPT_DIR/lib/config.sh" \
        "$SCRIPT_DIR/lib/core.sh" \
        "$SCRIPT_DIR/lib/menu.sh" \
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
    # 远程模式：下载 dist 单文件并执行（或按需安装为系统命令）
    tmp_dir=""
    if ! tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pve-tools-entry.XXXXXX")"; then
        echo "错误：无法创建 PVE-Tools 临时目录，程序尚未启动。" >&2
        exit 1
    fi
    trap pve_tools_entry_cleanup EXIT

    downloaded_file="$tmp_dir/PVE-Tools.sh"
    if pve_tools_entry_download_file "$PVE_TOOLS_REMOTE_DIST_URL" "$downloaded_file"; then
        if [[ "$PVE_TOOLS_ENTRY_MODE" == "install" ]]; then
            echo "主程序校验通过，正在安装 pvetools..."
            if pve_tools_entry_install_from "$downloaded_file" "bin"; then
                echo
                bash "${PVE_TOOLS_ENTRY_INSTALLED_PATH:-$PVE_TOOLS_INSTALL_BIN_PATH}" "${PVE_TOOLS_ENTRY_ARGS[@]}"
                exit $?
            fi
            echo "错误：$PVE_TOOLS_ENTRY_LAST_ERROR" >&2
            exit 1
        fi

        pve_tools_entry_maybe_offer_install "$downloaded_file" "${PVE_TOOLS_ENTRY_ARGS[@]}"

        echo "主程序校验通过，正在启动 PVE-Tools..."
        bash "$downloaded_file" "${PVE_TOOLS_ENTRY_ARGS[@]}"
        exit $?
    fi

    pve_tools_entry_print_release_help
    exit 1
fi

main "${PVE_TOOLS_ENTRY_ARGS[@]}"
