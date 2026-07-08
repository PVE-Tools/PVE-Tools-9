#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

check_update() {
    log_info "正在检查更新..."

    # 显示进度提示
    echo -ne "[....] 正在检查更新...\033[0K\r"

    local update_urls prefer_mirror preferred_version_url preferred_update_url preferred_script_url
    local mirror_version_url="${GITHUB_MIRROR_PREFIX}${VERSION_FILE_URL}"
    local mirror_update_url="${GITHUB_MIRROR_PREFIX}${UPDATE_FILE_URL}"

    update_urls="$(pve_tools_choose_update_urls)"
    IFS='|' read -r prefer_mirror preferred_version_url preferred_update_url preferred_script_url <<< "$update_urls"
    if [[ "$prefer_mirror" -eq 1 ]]; then
        log_info "当前地区为： ${USER_COUNTRY_CODE:-unknown}，使用镜像源检查更新..."
    else
        log_info "使用 GitHub 源检查更新"
    fi

    remote_content=$(pve_tools_download_url "$preferred_version_url" 10)

    if [ -z "$remote_content" ]; then
        if [[ $prefer_mirror -eq 1 ]]; then
            log_warn "镜像源连接失败，尝试使用 GitHub 源..."
            remote_content=$(pve_tools_download_url "$VERSION_FILE_URL" 10)
        else
            log_warn "GitHub 连接失败，尝试使用镜像源..."
            remote_content=$(pve_tools_download_url "$mirror_version_url" 10)
        fi
    fi
    
    # 清除进度显示
    echo -ne "\033[0K\r"
    
    # 如果下载失败
    if [ -z "$remote_content" ]; then
        log_warn "网络连接失败，跳过版本检查"
        echo "提示：您可以手动访问以下地址检查更新："
        echo "https://github.com/PVE-Tools/PVE-Tools-9"
        echo "按回车键继续..."
        read -r
        return
    fi
    
    # 提取版本号和更新日志
    remote_version=$(echo "$remote_content" | head -1 | tr -d '[:space:]')
    version_changelog=$(echo "$remote_content" | tail -n +2)
    
    if [ -z "$remote_version" ]; then
        log_warn "获取的版本信息格式不正确"
        return
    fi

    detailed_changelog=$(pve_tools_download_url "$preferred_update_url" 10)

    if [ -z "$detailed_changelog" ]; then
        if [[ $prefer_mirror -eq 1 ]]; then
            log_warn "镜像源更新日志获取失败，尝试使用 GitHub 源..."
            detailed_changelog=$(pve_tools_download_url "$UPDATE_FILE_URL" 10)
        else
            log_warn "GitHub 更新日志获取失败，尝试使用镜像源..."
            detailed_changelog=$(pve_tools_download_url "$mirror_update_url" 10)
        fi
    fi
    
    # 比较版本
    if pve_tools_version_gt "$remote_version" "$CURRENT_VERSION"; then
        echo -e "${UI_HEADER}"
        echo -e "${YELLOW}🚀 发现新版本！推荐更新以获取最新功能和修复喵${NC}"
        echo -e "----------------------------------------------"
        echo -e "当前版本: ${WHITE}$CURRENT_VERSION${NC}"
        echo -e "最新版本: ${GREEN}$remote_version${NC}"
        echo -e "${BLUE}更新日志：${NC}"
        
        # 如果获取到了详细的更新日志
        if [ -n "$detailed_changelog" ]; then
            # 使用 sed 提取第一行作为标题，其余行缩进显示
            local first_line=$(echo "$detailed_changelog" | head -n 1)
            local rest_lines=$(echo "$detailed_changelog" | tail -n +2)
            
            echo -e "  ${CYAN}★ $first_line${NC}"
            if [ -n "$rest_lines" ]; then
                echo "$rest_lines" | sed 's/^/    /'
            fi
        else
            # 格式化显示版本文件中的更新内容
            if [ -n "$version_changelog" ] && [ "$version_changelog" != "$remote_version" ]; then
                echo "$version_changelog" | sed 's/^/    /'
            else
                echo -e "    ${YELLOW}- 请访问项目页面获取详细更新内容${NC}"
            fi
        fi
        
        echo -e "----------------------------------------------"
        echo -e "${CYAN}官方文档与最新脚本：${NC}"
        echo -e "🔗 https://pve.u3u.icu (推荐)"
        echo -e "🔗 https://github.com/PVE-Tools/PVE-Tools-9"
        echo -e "${UI_FOOTER}"
        echo -e "按 ${GREEN}回车键${NC} 进入主菜单..."
        read -r
    else
        log_success "当前已是最新版本 ($CURRENT_VERSION) 放心用吧"
    fi
}
pve_tools_local_update() {
    local current_script="${BASH_SOURCE[0]}"
    local resolved_script backup_dir backup_path tmp_script update_urls prefer_mirror version_url update_url script_url
    local remote_content remote_version detailed_changelog fallback_script_url

    if [[ -z "$current_script" || ! -f "$current_script" ]]; then
        display_error "无法定位当前脚本文件" "请使用本地文件方式运行脚本后再执行更新。"
        return 1
    fi

    resolved_script="$(readlink -f "$current_script" 2>/dev/null || realpath "$current_script" 2>/dev/null || echo "$current_script")"
    if [[ ! -w "$resolved_script" ]]; then
        display_error "当前脚本不可写: $resolved_script" "请使用 root 或确认脚本文件权限后重试。"
        return 1
    fi

    update_urls="$(pve_tools_choose_update_urls)"
    IFS='|' read -r prefer_mirror version_url update_url script_url <<< "$update_urls"
    remote_content="$(pve_tools_download_url "$version_url" 15)"
    if [[ -z "$remote_content" ]]; then
        if [[ "$prefer_mirror" -eq 1 ]]; then
            log_warn "镜像源版本文件获取失败，尝试 GitHub 源。"
            remote_content="$(pve_tools_download_url "$VERSION_FILE_URL" 15)"
        else
            log_warn "GitHub 版本文件获取失败，尝试镜像源。"
            remote_content="$(pve_tools_download_url "${GITHUB_MIRROR_PREFIX}${VERSION_FILE_URL}" 15)"
        fi
    fi

    if [[ -z "$remote_content" ]]; then
        display_error "无法获取远程版本信息" "网络不通或 GitHub/镜像源不可用，已保持本地脚本不变。"
        return 1
    fi

    remote_version="$(echo "$remote_content" | head -1 | tr -d '[:space:]')"
    if [[ -z "$remote_version" ]]; then
        display_error "远程版本文件格式异常" "已保持本地脚本不变。"
        return 1
    fi

    detailed_changelog="$(pve_tools_download_url "$update_url" 15)"
    if [[ -z "$detailed_changelog" ]]; then
        if [[ "$prefer_mirror" -eq 1 ]]; then
            detailed_changelog="$(pve_tools_download_url "$UPDATE_FILE_URL" 15)"
        else
            detailed_changelog="$(pve_tools_download_url "${GITHUB_MIRROR_PREFIX}${UPDATE_FILE_URL}" 15)"
        fi
    fi

    clear
    show_menu_header "本地脚本快捷更新"
    echo -e "${CYAN}当前脚本:${NC} $resolved_script"
    echo -e "${CYAN}当前版本:${NC} $CURRENT_VERSION"
    echo -e "${CYAN}远程版本:${NC} $remote_version"
    echo -e "${CYAN}下载来源:${NC} $script_url"
    echo "$UI_DIVIDER"
    if pve_tools_version_gt "$remote_version" "$CURRENT_VERSION"; then
        echo -e "${GREEN}发现可更新版本。${NC}"
    elif [[ "$remote_version" == "$CURRENT_VERSION" ]]; then
        echo -e "${YELLOW}远程版本与当前版本一致，也可以选择强制覆盖本地脚本。${NC}"
    else
        echo -e "${YELLOW}远程版本看起来不高于当前版本，默认不建议覆盖。${NC}"
    fi
    echo "$UI_DIVIDER"
    if [[ -n "$detailed_changelog" ]]; then
        echo -e "${CYAN}更新日志预览:${NC}"
        echo "$detailed_changelog" | head -n 30 | sed 's/^/  /'
        echo "$UI_DIVIDER"
    fi

    read -p "是否下载并替换本地脚本？(yes/no) [no]: " confirm
    confirm="${confirm:-no}"
    if [[ "$confirm" != "yes" && "$confirm" != "YES" ]]; then
        log_info "已取消脚本更新。"
        return 0
    fi

    backup_dir="/var/backups/pve-tools"
    mkdir -p "$backup_dir" || {
        display_error "无法创建备份目录: $backup_dir" "已保持本地脚本不变。"
        return 1
    }
    backup_path="${backup_dir}/PVE-Tools.sh.bak"
    tmp_script="$(mktemp /tmp/pve-tools-update.XXXXXX)" || {
        display_error "无法创建临时文件" "已保持本地脚本不变。"
        return 1
    }

    if ! cp -a "$resolved_script" "$backup_path"; then
        rm -f "$tmp_script"
        display_error "备份当前脚本失败" "目标备份: $backup_path。已保持本地脚本不变。"
        return 1
    fi
    log_success "当前脚本已备份: $backup_path"

    if ! pve_tools_download_url "$script_url" 30 > "$tmp_script"; then
        fallback_script_url="$PVE_TOOLS_SCRIPT_URL"
        [[ "$script_url" == "$PVE_TOOLS_SCRIPT_URL" ]] && fallback_script_url="${GITHUB_MIRROR_PREFIX}${PVE_TOOLS_SCRIPT_URL}"
        log_warn "首选脚本下载失败，尝试备用源: $fallback_script_url"
        if ! pve_tools_download_url "$fallback_script_url" 30 > "$tmp_script"; then
            rm -f "$tmp_script"
            display_error "下载新脚本失败" "已保留原脚本，备份位于 $backup_path。"
            return 1
        fi
    fi

    if ! grep -q '^CURRENT_VERSION=' "$tmp_script" || ! bash -n "$tmp_script"; then
        rm -f "$tmp_script"
        cp -a "$backup_path" "$resolved_script" >/dev/null 2>&1 || true
        display_error "下载的新脚本校验失败，已自动回滚" "请稍后重试或手动检查下载源。"
        return 1
    fi

    if ! cp -a "$tmp_script" "$resolved_script"; then
        cp -a "$backup_path" "$resolved_script" >/dev/null 2>&1 || true
        rm -f "$tmp_script"
        display_error "替换脚本失败，已尝试自动回滚" "备份文件: $backup_path"
        return 1
    fi
    chmod +x "$resolved_script" >/dev/null 2>&1 || true
    rm -f "$tmp_script"

    display_success "本地脚本更新完成" "备份文件: $backup_path；请重新运行脚本以加载新版本。"
}
pve_tools_local_uninstall() {
    local current_script resolved_script clean_cron delete_targets=()
    current_script="${BASH_SOURCE[0]}"
    resolved_script="$(readlink -f "$current_script" 2>/dev/null || realpath "$current_script" 2>/dev/null || echo "$current_script")"

    clear
    show_menu_header "本地脚本快捷卸载"
    echo -e "${RED}将删除 PVE-Tools 本地脚本及脚本产生的日志/备份/导出目录。${NC}"
    echo -e "${YELLOW}不会删除 PVE 自身软件包、VM 磁盘或系统存储配置。${NC}"
    echo "$UI_DIVIDER"

    [[ -f "$resolved_script" ]] && delete_targets+=("$resolved_script")
    [[ -f "/var/log/pve-tools.log" ]] && delete_targets+=("/var/log/pve-tools.log")
    [[ -d "/var/backups/pve-tools" ]] && delete_targets+=("/var/backups/pve-tools/")
    [[ -d "/var/lib/pve-tools" ]] && delete_targets+=("/var/lib/pve-tools/")

    if [[ -f "$VM_BACKUP_CRON_FILE" ]]; then
        read -p "是否同时清理 VM 定时备份任务 ${VM_BACKUP_CRON_FILE}？(yes/no) [no]: " clean_cron
        clean_cron="${clean_cron:-no}"
        if [[ "$clean_cron" == "yes" || "$clean_cron" == "YES" ]]; then
            delete_targets+=("$VM_BACKUP_CRON_FILE")
        fi
    fi

    if (( ${#delete_targets[@]} == 0 )); then
        log_warn "未发现可删除的 PVE-Tools 本地文件。"
        return 0
    fi

    echo -e "${CYAN}将删除以下文件/目录:${NC}"
    printf '  - %s\n' "${delete_targets[@]}"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "卸载 PVE-Tools 本地脚本及关联文件" "会永久删除上方列出的脚本、日志、备份和导出目录。" "误删备份目录会丢失脚本自动备份的历史配置副本；删除 cron 会停止后续定时备份。" "请确认已经导出仍需保留的备份/配置文件，并确认删除清单只包含 PVE-Tools 文件。" "UNINSTALL"; then
        return 0
    fi

    local target
    for target in "${delete_targets[@]}"; do
        if [[ -d "${target%/}" ]]; then
            rm -rf -- "${target%/}"
            echo -e "${GREEN}已删除目录:${NC} ${target%/}"
        elif [[ -e "$target" ]]; then
            rm -f -- "$target"
            echo -e "${GREEN}已删除文件:${NC} $target"
        fi
    done

    if [[ "$clean_cron" == "yes" || "$clean_cron" == "YES" ]]; then
        systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    fi

    echo -e "${GREEN}卸载完成。当前脚本文件如已删除，本次会话结束后请直接退出。${NC}"
}
