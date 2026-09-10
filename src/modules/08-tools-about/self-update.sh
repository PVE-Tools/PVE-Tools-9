#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

check_update() {
    log_info "正在检查更新..."

    # 显示进度提示
    echo -ne "[....] 正在检查更新...\033[0K\r"

    local update_urls prefer_cnb version_url update_url script_url version_fb_url update_fb_url

    update_urls="$(pve_tools_choose_update_urls)"
    IFS='|' read -r prefer_cnb version_url update_url script_url version_fb_url update_fb_url _ <<< "$update_urls"
    if [[ "$prefer_cnb" -eq 1 ]]; then
        log_info "当前地区为： ${USER_COUNTRY_CODE:-unknown}，使用 CNB 国内源检查更新..."
    else
        log_info "使用 GitHub 源检查更新"
    fi

    remote_content=$(pve_tools_download_url "$version_url" 10)

    if [ -z "$remote_content" ]; then
        log_warn "首选源连接失败，尝试备用源..."
        remote_content=$(pve_tools_download_url "$version_fb_url" 10)
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

    detailed_changelog=$(pve_tools_download_url "$update_url" 10)

    if [ -z "$detailed_changelog" ]; then
        log_warn "首选源更新日志获取失败，尝试备用源..."
        detailed_changelog=$(pve_tools_download_url "$update_fb_url" 10)
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
    # 用 $0 定位实际入口脚本（dist 单文件 / launcher），而非被 source 的模块文件
    local current_script="$0"
    local resolved_script backup_dir backup_path tmp_script update_urls prefer_cnb version_url update_url script_url version_fb_url update_fb_url script_fb_url
    local remote_content remote_version detailed_changelog downloaded_version

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
    IFS='|' read -r prefer_cnb version_url update_url script_url version_fb_url update_fb_url script_fb_url <<< "$update_urls"
    remote_content="$(pve_tools_download_url "$version_url" 15)"
    if [[ -z "$remote_content" ]]; then
        log_warn "首选源版本文件获取失败，尝试备用源。"
        remote_content="$(pve_tools_download_url "$version_fb_url" 15)"
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
        log_warn "首选源更新日志获取失败，尝试备用源。"
        detailed_changelog="$(pve_tools_download_url "$update_fb_url" 15)"
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
        log_warn "首选脚本下载失败，尝试备用源: $script_fb_url"
        if ! pve_tools_download_url "$script_fb_url" 30 > "$tmp_script"; then
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

    # VERSION 文件跟随 main 分支，Release 资产可能尚未同步发版，两者不一致时提示但不阻断
    downloaded_version="$(grep -m1 '^CURRENT_VERSION=' "$tmp_script" | cut -d'"' -f2)"
    if [[ -n "$downloaded_version" && "$downloaded_version" != "$remote_version" ]]; then
        log_warn "下载脚本版本为 ${downloaded_version}，与远程 VERSION (${remote_version}) 不一致，可能 Release 尚未同步发布。"
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
# 读取安装器元数据（实际安装路径）。逐行白名单解析，不使用动态求值与 source 加载（dist 安全扫描约束）。
pve_tools_load_installer_meta() {
    local key="" value=""

    [[ -r "$PVE_TOOLS_INSTALL_META_FILE" ]] || return 0
    while IFS='=' read -r key value; do
        case "$key" in
            PVE_TOOLS_BIN_PATH) [[ -n "$value" ]] && PVE_TOOLS_BIN_PATH="$value" ;;
            PVE_TOOLS_OPT_DIR)  [[ -n "$value" ]] && PVE_TOOLS_OPT_DIR="$value" ;;
            PVE_TOOLS_RC_FILE)  [[ -n "$value" ]] && PVE_TOOLS_RC_FILE="$value" ;;
        esac
    done < <(grep -E '^(PVE_TOOLS_BIN_PATH|PVE_TOOLS_OPT_DIR|PVE_TOOLS_RC_FILE)=' "$PVE_TOOLS_INSTALL_META_FILE")
}

pve_tools_local_uninstall() {
    local current_script resolved_script clean_cron delete_targets=()
    local deferred_targets=()
    local installed_bin installed_opt_dir alias_rc_file
    local cleanup_failed=0
    local has_begin=0 has_end=0
    # 用 $0 定位实际入口脚本（dist 单文件 / launcher），而非被 source 的模块文件
    current_script="$0"
    resolved_script="$(readlink -f "$current_script" 2>/dev/null || realpath "$current_script" 2>/dev/null || echo "$current_script")"

    clear
    show_menu_header "本地脚本快捷卸载"
    echo -e "${RED}将删除 PVE-Tools 本地脚本及脚本产生的日志/备份/导出目录。${NC}"
    echo -e "${YELLOW}同时会清理安装器写入的系统命令 pvetools、/opt 脚本副本与 shell 别名标记块。${NC}"
    echo -e "${YELLOW}不会删除 PVE 自身软件包、VM 磁盘或系统存储配置。${NC}"
    echo "$UI_DIVIDER"

    # 元数据优先于默认常量：先加载安装器元数据再快照实际安装路径，
    # 否则 delete_targets 会拿到未解析的默认值，自定义位置的产物将无法被清理
    pve_tools_load_installer_meta
    installed_bin="$PVE_TOOLS_BIN_PATH"
    installed_opt_dir="$PVE_TOOLS_OPT_DIR"
    # 元数据缺失时回退到 root 的 .bashrc（显式解析，与安装器默认值保持一致）
    alias_rc_file="$(getent passwd root 2>/dev/null | cut -d: -f6)"
    alias_rc_file="${alias_rc_file:-/root}/.bashrc"
    if [[ -n "${PVE_TOOLS_RC_FILE:-}" ]]; then
        alias_rc_file="$PVE_TOOLS_RC_FILE"
    fi

    # 标记块完整性前置校验（与入口安装器同一守卫语义）：任一标记缺失配对即拒绝自动清理，
    # 防止范围删除波及文件尾部或残留孤儿标记
    grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$alias_rc_file" 2>/dev/null && has_begin=1
    grep -q "^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$" "$alias_rc_file" 2>/dev/null && has_end=1
    if [[ "$has_begin" -ne "$has_end" ]]; then
        echo -e "${YELLOW}警告：${alias_rc_file} 中别名标记块不完整（缺 $([[ "$has_begin" -eq 1 ]] && echo "END" || echo "BEGIN") 标记），已拒绝自动清理，请手动检查该文件。${NC}" >&2
        return 1
    fi

    [[ -f "$resolved_script" ]] && delete_targets+=("$resolved_script")
    # 安装器产物联动清理：系统命令与 /opt 脚本副本目录（若当前正运行的就是它们则不重复收录）
    # 命令文件须为本工具完整版才纳入删除（与下方 opt 目录同一守卫规则），避免误删占用该路径的其他程序
    if [[ -f "$installed_bin" ]] \
        && [[ "$installed_bin" != "$resolved_script" ]] \
        && grep -q '^CURRENT_VERSION=' "$installed_bin" 2>/dev/null; then
        delete_targets+=("$installed_bin")
    fi
    # 目录须包含本工具安装的完整版脚本才纳入递归删除清单（与入口安装器同一守卫规则；
    # pve_tools_entry_is_full_script 仅存在于入口脚本，此处按相同规则就地校验），
    # 避免元数据指向其他目录时被 rm -rf 误删无关文件
    if [[ -d "$installed_opt_dir" ]] \
        && [[ -f "$installed_opt_dir/PVE-Tools.sh" ]] \
        && grep -q '^CURRENT_VERSION=' "$installed_opt_dir/PVE-Tools.sh" 2>/dev/null; then
        delete_targets+=("${installed_opt_dir}/")
    fi
    [[ -f "/var/log/pve-tools.log" ]] && delete_targets+=("/var/log/pve-tools.log")
    # 备份与数据目录是清理失败时的恢复依据，延后到别名块等清理全部成功后再删除
    [[ -d "/var/backups/pve-tools" ]] && deferred_targets+=("/var/backups/pve-tools/")
    [[ -d "/var/lib/pve-tools" ]] && deferred_targets+=("/var/lib/pve-tools/")

    if [[ -f "$VM_BACKUP_CRON_FILE" ]]; then
        read -p "是否同时清理 VM 定时备份任务 ${VM_BACKUP_CRON_FILE}？(yes/no) [no]: " clean_cron
        clean_cron="${clean_cron:-no}"
        if [[ "$clean_cron" == "yes" || "$clean_cron" == "YES" ]]; then
            delete_targets+=("$VM_BACKUP_CRON_FILE")
        fi
    fi

    if (( ${#delete_targets[@]} == 0 && ${#deferred_targets[@]} == 0 )); then
        if [[ "$has_begin" -eq 0 ]]; then
            log_warn "未发现可删除的 PVE-Tools 本地文件。"
            return 0
        fi
    fi

    echo -e "${CYAN}将删除以下文件/目录:${NC}"
    if (( ${#delete_targets[@]} > 0 )); then
        printf '  - %s\n' "${delete_targets[@]}"
    fi
    if (( ${#deferred_targets[@]} > 0 )); then
        printf '  - %s（别名标记块等清理成功后删除）\n' "${deferred_targets[@]}"
    fi
    if grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$alias_rc_file" 2>/dev/null; then
        echo -e "  - 别名标记块：${alias_rc_file}（# PVE-TOOLS BEGIN/END ${PVE_TOOLS_ALIAS_MARKER}）"
    fi
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "卸载 PVE-Tools 本地脚本及关联文件" "会永久删除上方列出的脚本、日志、备份和导出目录。" "误删备份目录会丢失脚本自动备份的历史配置副本；删除 cron 会停止后续定时备份。" "请确认已经导出仍需保留的备份/配置文件，并确认删除清单只包含 PVE-Tools 文件。" "UNINSTALL"; then
        return 0
    fi

    local target
    for target in "${delete_targets[@]}"; do
        if [[ -d "${target%/}" ]]; then
            if rm -rf -- "${target%/}"; then
                echo -e "${GREEN}已删除目录:${NC} ${target%/}"
            else
                echo -e "${RED}错误：目录删除失败:${NC} ${target%/}" >&2
                cleanup_failed=1
            fi
        elif [[ -e "$target" ]]; then
            if rm -f -- "$target"; then
                echo -e "${GREEN}已删除文件:${NC} $target"
            else
                echo -e "${RED}错误：文件删除失败:${NC} $target" >&2
                cleanup_failed=1
            fi
        fi
    done

    if grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$alias_rc_file" 2>/dev/null; then
        # 完整性守卫：BEGIN/END 必须同时存在才按范围删除，防止不完整块误删文件尾部
        # （remove_block 内部不校验 END 标记，守卫必须先于此复用）
        if ! grep -q "^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$" "$alias_rc_file" 2>/dev/null; then
            echo -e "${YELLOW}警告：${alias_rc_file} 中别名标记块不完整（缺 END 标记），已跳过自动清理，请手动检查该文件。${NC}"
            cleanup_failed=1
        elif ! backup_file "$alias_rc_file"; then
            echo -e "${YELLOW}警告：清理前备份 ${alias_rc_file} 失败，已跳过自动清理，请手动检查该文件。${NC}"
            cleanup_failed=1
        elif remove_block "$alias_rc_file" "$PVE_TOOLS_ALIAS_MARKER"; then
            echo -e "${GREEN}已清理别名标记块:${NC} ${alias_rc_file}（清理前已备份至 /var/backups/pve-tools/）"
        else
            echo -e "${YELLOW}警告：清理 ${alias_rc_file} 别名标记块失败，请手动删除 # PVE-TOOLS BEGIN/END ${PVE_TOOLS_ALIAS_MARKER} 之间的内容。${NC}"
            cleanup_failed=1
        fi
    fi

    # 备份与数据目录仅在全部清理成功后删除；失败时保留恢复依据并报告失败
    if [[ "$cleanup_failed" -eq 1 ]]; then
        echo -e "${RED}卸载未完全完成：已保留 /var/backups/pve-tools/ 与 /var/lib/pve-tools/，处理残留后可重新运行卸载。${NC}" >&2
        return 1
    fi
    if (( ${#deferred_targets[@]} > 0 )); then
        for target in "${deferred_targets[@]}"; do
            if [[ -d "${target%/}" ]]; then
                if rm -rf -- "${target%/}"; then
                    echo -e "${GREEN}已删除目录:${NC} ${target%/}"
                else
                    echo -e "${RED}错误：目录删除失败:${NC} ${target%/}" >&2
                    cleanup_failed=1
                fi
            fi
        done
    fi

    if [[ "$clean_cron" == "yes" || "$clean_cron" == "YES" ]]; then
        systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    fi

    if [[ "$cleanup_failed" -eq 1 ]]; then
        echo -e "${RED}卸载未完全完成，请根据上方提示处理残留项。${NC}" >&2
        return 1
    fi
    echo -e "${GREEN}卸载完成。当前脚本文件如已删除，本次会话结束后请直接退出。${NC}"
}
