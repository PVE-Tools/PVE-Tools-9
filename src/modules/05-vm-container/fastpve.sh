#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

fastpve_quick_download_menu() {
    clear
    show_banner
    show_menu_header "PVE 虚拟机快速下载 (FastPVE)"

    echo "  FastPVE 由社区开发者 @kspeeder 维护，提供热门 PVE 虚拟机模板快速拉取能力。"
    echo "  本功能将直接运行 FastPVE 官方脚本，请在执行前确保信任该来源。"
    echo
    echo "  项目地址: $FASTPVE_PROJECT_URL"
    echo "  安装脚本: $FASTPVE_INSTALLER_URL"
    echo
    echo -e "${RED}⚠️  重要提示:${NC} 这是第三方脚本，出现任何问题请前往 FastPVE 项目反馈，别找我喔~"
    echo -e "${YELLOW}    我们只负责帮你下载并执行，后续操作和风险请自行承担。${NC}"
    echo "${UI_DIVIDER}"
    echo "  使用说明："
    echo "    • FastPVE 会拉取独立菜单，按提示选择需要的虚拟机模板"
    echo "    • 需要互联网访问 GitHub（大陆环境自动优先使用镜像源）"
    echo "    • 本脚本仅负责下载并执行 FastPVE，具体操作由 FastPVE 完成"
    echo "${UI_DIVIDER}"

    read -p "是否立即运行 FastPVE 脚本？(y/N): " confirm
    confirm=${confirm:-N}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消执行 FastPVE"
        return 0
    fi

    local fastpve_url="$FASTPVE_INSTALLER_URL"
    local fastpve_mirror_url="${GITHUB_MIRROR_PREFIX}${FASTPVE_INSTALLER_URL}"
    local preferred_url="$fastpve_url"
    local fallback_url="$fastpve_mirror_url"
    local preferred_label="GitHub"
    local fallback_label="加速镜像"

    if detect_network_region; then
        if [[ $USE_MIRROR_FOR_UPDATE -eq 1 ]]; then
            preferred_url="$fastpve_mirror_url"
            fallback_url="$fastpve_url"
            preferred_label="加速镜像"
            fallback_label="GitHub"
            log_info "检测到中国大陆网络环境，优先使用 FastPVE 加速镜像下载"
        else
            if [[ -n "$USER_COUNTRY_CODE" ]]; then
                log_info "检测到当前地区: $USER_COUNTRY_CODE，将通过 GitHub 下载 FastPVE"
            else
                log_info "网络检测成功，将通过 GitHub 下载 FastPVE"
            fi
        fi
    else
        log_warn "无法检测网络地区，默认使用 GitHub 下载 FastPVE"
    fi

    local -a download_cmd
    local downloader_name=""
    if command -v curl &> /dev/null; then
        download_cmd=(curl -fsSL --connect-timeout 10 --max-time 60 -o)
        downloader_name="curl"
    elif command -v wget &> /dev/null; then
        download_cmd=(wget -q -O)
        downloader_name="wget"
    else
        log_error "未检测到 curl 或 wget，无法下载 FastPVE 脚本"
        return 1
    fi

    local tmp_script
    if ! tmp_script=$(mktemp /tmp/fastpve-install.XXXXXX.sh); then
        log_error "无法创建临时文件，FastPVE 启动失败"
        return 1
    fi

    log_info "使用 $preferred_label 下载 FastPVE 安装脚本 (下载器: $downloader_name)..."
    if ! "${download_cmd[@]}" "$tmp_script" "$preferred_url"; then
        log_warn "$preferred_label 下载失败，尝试改用 $fallback_label..."
        : > "$tmp_script"
        if ! "${download_cmd[@]}" "$tmp_script" "$fallback_url"; then
            log_error "FastPVE 安装脚本下载失败，请检查网络或稍后重试"
            rm -f "$tmp_script"
            return 1
        fi
    fi

    chmod +x "$tmp_script"
    echo
    log_step "FastPVE 脚本即将运行，请根据 FastPVE 菜单提示选择虚拟机模板"
    echo "${UI_BORDER}"
    sh "$tmp_script"
    local run_status=$?
    echo "${UI_BORDER}"

    rm -f "$tmp_script"

    if [[ $run_status -eq 0 ]]; then
        log_success "FastPVE 虚拟机快速下载脚本执行完成"
    else
        log_error "FastPVE 脚本执行失败 (退出码: $run_status)"
    fi

    return $run_status
}
