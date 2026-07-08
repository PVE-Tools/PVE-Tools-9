#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

third_party_market_menu() {
    local -a download_cmd

    if command -v curl &> /dev/null; then
        download_cmd=(curl -fsSL --connect-timeout 10 --max-time 60 -o)
    elif command -v wget &> /dev/null; then
        download_cmd=(wget -q --timeout=60 -O)
    else
        log_error "未检测到 curl 或 wget，无法访问第三方软件市场"
        return 1
    fi

    local tmp_index
    if ! tmp_index=$(mktemp /tmp/pve-third-party-index.XXXXXX.json); then
        log_error "无法创建临时文件，第三方软件市场启动失败"
        return 1
    fi

    local api_main_url="$THIRD_PARTY_MODULES_TREE_API_MAIN_URL"
    local api_master_url="$THIRD_PARTY_MODULES_TREE_API_MASTER_URL"
    local index_ok=0

    log_info "正在通过 GitHub API 拉取第三方软件列表..."
    if command -v curl &> /dev/null; then
        if curl -fsSL --connect-timeout 10 --max-time 60 \
            -H "Accept: application/vnd.github+json" \
            -H "User-Agent: pve-tools" \
            -o "$tmp_index" "$api_main_url"; then
            index_ok=1
        else
            log_warn "main 分支列表拉取失败，尝试使用 master 分支..."
            : > "$tmp_index"
            if curl -fsSL --connect-timeout 10 --max-time 60 \
                -H "Accept: application/vnd.github+json" \
                -H "User-Agent: pve-tools" \
                -o "$tmp_index" "$api_master_url"; then
                index_ok=1
            fi
        fi
    else
        if wget -q --timeout=60 \
            --header="Accept: application/vnd.github+json" \
            --user-agent="pve-tools" \
            -O "$tmp_index" "$api_main_url"; then
            index_ok=1
        else
            log_warn "main 分支列表拉取失败，尝试使用 master 分支..."
            : > "$tmp_index"
            if wget -q --timeout=60 \
                --header="Accept: application/vnd.github+json" \
                --user-agent="pve-tools" \
                -O "$tmp_index" "$api_master_url"; then
                index_ok=1
            fi
        fi
    fi

    if [[ $index_ok -ne 1 ]]; then
        log_error "第三方软件列表拉取失败，请稍后重试"
        rm -f "$tmp_index"
        return 1
    fi

    local -a module_files
    while IFS= read -r module_name; do
        [[ -z "$module_name" ]] && continue
        module_files+=("$module_name")
    done < <(grep -oE '"path":[[:space:]]*"Modules/[^"]+\.sh"' "$tmp_index" | sed -E 's#.*"path":[[:space:]]*"Modules/([^"]+)".*#\1#')
    rm -f "$tmp_index"

    if [[ ${#module_files[@]} -eq 0 ]]; then
        log_warn "未在 Modules 目录发现可用的 .sh 第三方脚本"
        return 1
    fi

    local -a valid_files valid_names valid_authors valid_versions valid_githubs
    for module_file in "${module_files[@]}"; do
        local module_url="${THIRD_PARTY_MODULES_RAW_BASE_URL}/${module_file}"
        local module_mirror_url="${GITHUB_MIRROR_PREFIX}${module_url}"
        local module_preferred_url="$module_url"
        local module_fallback_url="$module_mirror_url"

        if [[ $USE_MIRROR_FOR_UPDATE -eq 1 ]]; then
            module_preferred_url="$module_mirror_url"
            module_fallback_url="$module_url"
        fi

        local tmp_module
        if ! tmp_module=$(mktemp /tmp/pve-third-party-meta.XXXXXX.sh); then
            continue
        fi

        if ! "${download_cmd[@]}" "$tmp_module" "$module_preferred_url"; then
            : > "$tmp_module"
            if ! "${download_cmd[@]}" "$tmp_module" "$module_fallback_url"; then
                rm -f "$tmp_module"
                continue
            fi
        fi

        local meta_block
        meta_block=$(sed -n '2,5p' "$tmp_module")
        rm -f "$tmp_module"

        local script_name script_author script_version script_github
        script_name=$(echo "$meta_block" | grep -m1 '^## name:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        script_author=$(echo "$meta_block" | grep -m1 '^## author:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        script_version=$(echo "$meta_block" | grep -m1 '^## version:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        script_github=$(echo "$meta_block" | grep -m1 '^## github:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ -z "$script_name" || -z "$script_author" || -z "$script_version" || -z "$script_github" ]]; then
            continue
        fi

        valid_files+=("$module_file")
        valid_names+=("$script_name")
        valid_authors+=("$script_author")
        valid_versions+=("$script_version")
        valid_githubs+=("$script_github")
    done

    if [[ ${#valid_files[@]} -eq 0 ]]; then
        log_warn "已发现 .sh 文件，但没有符合元信息规范（第2-5行）的脚本"
        return 1
    fi

    while true; do
        clear
        show_menu_header "第三方软件市场 (Modules)"
        echo "  数据源: $THIRD_PARTY_MODULES_RAW_BASE_URL"
        echo "  共发现 ${#valid_files[@]} 个符合规范的脚本"
        echo "${UI_DIVIDER}"
        local idx=1
        while [[ $idx -le ${#valid_files[@]} ]]; do
            local arr_idx=$((idx - 1))
            echo -e "  ${CYAN}${idx}.${NC} ${valid_names[$arr_idx]}"
            echo "      作者: ${valid_authors[$arr_idx]} | 版本: ${valid_versions[$arr_idx]}"
            echo "      脚本: ${valid_files[$arr_idx]}"
            echo "      仓库: ${valid_githubs[$arr_idx]}"
            ((idx++))
        done
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回上级菜单"
        show_menu_footer

        local choice
        read -p "请选择要运行的脚本 [0-${#valid_files[@]}]: " choice
        if [[ "$choice" == "0" ]]; then
            return 0
        fi
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#valid_files[@]} )); then
            log_error "无效选择"
            pause_function
            continue
        fi

        local selected_idx=$((choice - 1))
        local selected_file="${valid_files[$selected_idx]}"
        local selected_name="${valid_names[$selected_idx]}"
        local selected_author="${valid_authors[$selected_idx]}"
        local selected_version="${valid_versions[$selected_idx]}"
        local selected_url="${THIRD_PARTY_MODULES_RAW_BASE_URL}/${selected_file}"
        local selected_mirror_url="${GITHUB_MIRROR_PREFIX}${selected_url}"
        local selected_preferred_url="$selected_url"
        local selected_fallback_url="$selected_mirror_url"
        local selected_preferred_label="GitHub"
        local selected_fallback_label="加速镜像"

        if [[ $USE_MIRROR_FOR_UPDATE -eq 1 ]]; then
            selected_preferred_url="$selected_mirror_url"
            selected_fallback_url="$selected_url"
            selected_preferred_label="加速镜像"
            selected_fallback_label="GitHub"
        fi

        clear
        show_menu_header "第三方脚本执行确认"
        echo "  脚本名称: $selected_name"
        echo "  作者:     $selected_author"
        echo "  版本:     $selected_version"
        echo "  来源:     $selected_url"
        echo "${UI_DIVIDER}"
        echo "  本工具仅负责下载和执行，不审计脚本内容。"
        echo "  第三方脚本可能修改系统配置、安装/卸载软件、访问网络。"
        echo "  执行前请务必前往上述仓库审计脚本内容，并备份关键配置。"
        echo "${UI_DIVIDER}"
        if ! confirm_high_risk_action \
            "执行第三方脚本: $selected_name" \
            "将下载并直接执行该第三方脚本，PVE-Tools 不对其内容负责。" \
            "第三方脚本可能包含任意操作，包括修改系统配置、安装或卸载软件、访问网络资源。" \
            "建议先前往脚本仓库审计源码，备份关键配置，并保留控制台访问。" \
            "RUN"; then
            log_info "已取消执行 $selected_name"
            pause_function
            continue
        fi

        local tmp_script
        if ! tmp_script=$(mktemp /tmp/pve-third-party-run.XXXXXX.sh); then
            log_error "无法创建临时脚本文件"
            pause_function
            continue
        fi

        log_info "使用 $selected_preferred_label 下载脚本 ($selected_file)..."
        if ! "${download_cmd[@]}" "$tmp_script" "$selected_preferred_url"; then
            log_warn "$selected_preferred_label 下载失败，尝试改用 $selected_fallback_label..."
            : > "$tmp_script"
            if ! "${download_cmd[@]}" "$tmp_script" "$selected_fallback_url"; then
                log_error "脚本下载失败: $selected_file"
                rm -f "$tmp_script"
                pause_function
                continue
            fi
        fi

        chmod +x "$tmp_script"
        echo "${UI_BORDER}"
        sh "$tmp_script"
        local run_status=$?
        echo "${UI_BORDER}"
        rm -f "$tmp_script"

        if [[ $run_status -eq 0 ]]; then
            log_success "$selected_name 执行完成"
        else
            log_error "$selected_name 执行失败 (退出码: $run_status)"
        fi
        pause_function
    done
}
#---------FastPVE 虚拟机快速下载-----------

# Community Scripts 提示
