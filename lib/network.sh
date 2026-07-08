#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

detect_network_region() {
    local timeout=5
    USER_COUNTRY_CODE=""
    USE_MIRROR_FOR_UPDATE=0

    if ! command -v curl &> /dev/null; then
        return 1
    fi

    local trace_output
    trace_output=$(curl -s --connect-timeout $timeout --max-time $timeout "$CF_TRACE_URL" 2>/dev/null)
    if [[ -z "$trace_output" ]]; then
        return 1
    fi

    local loc
    loc=$(echo "$trace_output" | awk -F= '/^loc=/{print $2}' | tr -d '\r')
    if [[ -z "$loc" ]]; then
        return 1
    fi

    USER_COUNTRY_CODE="$loc"
    if [[ "$USER_COUNTRY_CODE" == "CN" ]]; then
        USE_MIRROR_FOR_UPDATE=1
    fi

    return 0
}
fetch_session_tip() {
    if [[ -n "$SESSION_TIP" ]]; then
        return 0
    fi

    if [[ "$IS_OFFLINE_MODE" -eq 1 ]]; then
        SESSION_TIP="离线模式已启用，本次会话不获取在线 Tips。"
        return 0
    fi

    local timeout=5
    local response=""

    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s --connect-timeout "$timeout" --max-time "$timeout" "$HITOKOTO_API_URL" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        response=$(wget -q -T "$timeout" -O - "$HITOKOTO_API_URL" 2>/dev/null)
    else
        SESSION_TIP="当前环境缺少 curl 或 wget，无法获取在线 Tips。"
        return 0
    fi

    if [[ -z "$response" ]]; then
        SESSION_TIP="一言获取失败，本次会话不再重试。"
        return 0
    fi

    local hitokoto from from_who
    hitokoto=$(printf '%s' "$response" | sed -n 's/.*"hitokoto":"\([^"]*\)".*/\1/p' | head -n 1)
    from=$(printf '%s' "$response" | sed -n 's/.*"from":"\([^"]*\)".*/\1/p' | head -n 1)
    from_who=$(printf '%s' "$response" | sed -n 's/.*"from_who":\("[^"]*"\|null\).*/\1/p' | head -n 1 | sed 's/^"//; s/"$//')

    hitokoto=$(printf '%s' "$hitokoto" | sed 's/\\"/"/g; s/\\\\/\\/g')
    from=$(printf '%s' "$from" | sed 's/\\"/"/g; s/\\\\/\\/g')
    from_who=$(printf '%s' "$from_who" | sed 's/\\"/"/g; s/\\\\/\\/g')

    if [[ -z "$hitokoto" ]]; then
        SESSION_TIP="一言解析失败，本次会话不再重试。"
        return 0
    fi

    SESSION_TIP="$hitokoto"
    if [[ -n "$from" ]]; then
        SESSION_TIP="${SESSION_TIP} —— ${from}"
        if [[ -n "$from_who" && "$from_who" != "null" ]]; then
            SESSION_TIP="${SESSION_TIP} / ${from_who}"
        fi
    fi
}
network_show_diagnostics() {
    echo "${UI_DIVIDER}"
    echo -e "${CYAN}当前网络诊断信息：${NC}"
    echo -e "${CYAN}IPv4 地址：${NC}"
    ip -4 -o addr show scope global 2>/dev/null | awk '{print "  "$2": "$4}' || true
    echo -e "${CYAN}默认路由：${NC}"
    ip route 2>/dev/null | sed -n '1,3p' | sed 's/^/  /' || true
    echo -e "${CYAN}DNS 配置：${NC}"
    grep -E '^\s*nameserver\s+' /etc/resolv.conf 2>/dev/null | sed 's/^/  /' || true
    echo "${UI_DIVIDER}"
}
network_can_access_internet() {
    local test_url="https://www.tencent.com/"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 5 --max-time 8 "$test_url" >/dev/null 2>&1
        return $?
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q --timeout=8 -O - "$test_url" >/dev/null 2>&1
        return $?
    fi
    return 1
}
network_offline_guard() {
    IS_OFFLINE_MODE=0
    if [[ "$NETWORK_MODE" == "offline" ]]; then
        IS_OFFLINE_MODE=1
        log_warn "已配置为离线模式：将跳过在线更新检查与在线资源拉取。"
        return 0
    fi

    if network_can_access_internet; then
        log_success "网络连通性检测通过。"
        return 0
    fi

    IS_OFFLINE_MODE=1
    log_warn "检测到当前主机无法访问互联网，在线资源可能不可用。"
    network_show_diagnostics
    echo -e "${YELLOW}请先确认是否为本机网络问题（网关、DNS、NAT、防火墙）再继续。${NC}"
    echo -e "${YELLOW}如果你确定当前环境需要离线使用，可继续，但涉及在线下载/更新的功能会失败。${NC}"
    read -p "输入 'offline' 继续离线模式，其他任意键退出排查网络: " offline_confirm
    if [[ "$offline_confirm" != "offline" ]]; then
        log_info "已取消执行，请先修复网络后重试。"
        exit 0
    fi
    return 0
}
disable_ups_service() {
    local managed_any=false
    local service
    local services=("nut-monitor.service" "nut-server.service")

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "系统不支持 systemctl，无法自动管理 UPS 服务"
        return 1
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
            systemctl stop "${service%.service}" >/dev/null 2>&1 || true
            systemctl disable "${service%.service}" >/dev/null 2>&1 || true
            managed_any=true
        fi
    done

    if [[ "$managed_any" != true ]]; then
        log_info "未检测到可管理的 NUT 服务，跳过 UPS 服务管理"
        return 0
    fi

    log_success "已执行 UPS 服务关闭: systemctl stop/disable nut-monitor nut-server"
    return 0
}
enable_ups_service() {
    local managed_any=false
    local service
    local services=("nut-server.service" "nut-monitor.service")

    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
            systemctl enable "${service%.service}" >/dev/null 2>&1 || true
            systemctl start "${service%.service}" >/dev/null 2>&1 || true
            managed_any=true
        fi
    done

    [[ "$managed_any" == true ]]
}
show_ups_diagnostics() {
    local service active_state enabled_state has_nut_service=false
    local upsc_path ups_list

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "UPS / NUT 诊断信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if upsc_path=$(command -v upsc 2>/dev/null); then
        log_success "检测到 upsc: $upsc_path"
        if command -v timeout >/dev/null 2>&1; then
            ups_list=$(timeout --signal=TERM 3s upsc -l 2>/dev/null || true)
            if [[ -n "$ups_list" ]]; then
                echo "已发现 UPS 设备名："
                printf '%s\n' "$ups_list"
            else
                log_info "未列出 UPS 设备名；请确认 NUT 已由系统正确配置"
            fi
        else
            log_warn "未检测到 timeout，脚本不会在 Web UI 热路径里直接调用 upsc"
        fi
    else
        log_warn "未检测到 upsc（nut-client 未安装），无法读取 UPS 数据"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        for service in nut-server.service nut-monitor.service; do
            if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
                active_state=$(systemctl is-active "${service%.service}" 2>/dev/null || echo unknown)
                enabled_state=$(systemctl is-enabled "${service%.service}" 2>/dev/null || echo unknown)
                echo "${service%.service} 状态: active=${active_state}, enabled=${enabled_state}"
                has_nut_service=true
            fi
        done
        if [[ "$has_nut_service" != true ]]; then
            log_info "未检测到可管理的 NUT systemd 服务"
        fi
    else
        log_info "系统不支持 systemctl，跳过 NUT 服务状态检查"
    fi

    echo "说明：温度监控中的 UPS 展示仅做安全读取，不会自动启停 NUT 服务。"
}

# 显示横幅
show_banner() {
    clear
    echo -ne "${NC}"
    cat << 'EOF'
██████╗ ██╗   ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗    ██████╗ ██████╗  ██████╗ 
██╔══██╗██║   ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝    ██╔══██╗██╔══██╗██╔═══██╗
██████╔╝██║   ██║█████╗         ██║   ██║   ██║██║   ██║██║     ███████╗    ██████╔╝██████╔╝██║   ██║
██╔═══╝ ╚██╗ ██╔╝██╔══╝         ██║   ██║   ██║██║   ██║██║     ╚════██║    ██╔═══╝ ██╔══██╗██║   ██║
██║      ╚████╔╝ ███████╗       ██║   ╚██████╔╝╚██████╔╝███████╗███████║    ██║     ██║  ██║╚██████╔╝
╚═╝       ╚═══╝  ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ 
EOF
    echo -ne "${NC}"
    echo "$UI_BORDER"
    echo -e "  ${H1}PVE-Tools-Pro | ${BUILD_NICKNAME} Build | Support PVE 9.x.x${NC}"
    echo "  让每个人都能体验虚拟化技术的的便利。"
    echo -e "  作者: ${PINK}Maple${NC} | 交流Q群: ${CYAN}1031976463${NC}"
    echo -e "  当前版本: ${GREEN}$CURRENT_VERSION${NC} | 最新版本: ${remote_version:-"Not Found"}"
    echo "$UI_BORDER"
}

# 检查是否为 root 用户
mirror_uri_by_type() {
    local source_type="$1"
    local idx="$2"

    case "$source_type" in
        debian) echo "${MIRROR_DEBIAN_URIS[$idx]}" ;;
        security) echo "${MIRROR_SECURITY_URIS[$idx]}" ;;
        pve) echo "${MIRROR_PVE_URIS[$idx]}" ;;
        ceph) echo "${MIRROR_CEPH_URIS[$idx]}" ;;
        ct) echo "${MIRROR_CT_URIS[$idx]}" ;;
        *) echo "" ;;
    esac
}
mirror_set_selected() {
    local source_type="$1"
    local idx="$2"

    case "$source_type" in
        debian) MIRROR_SELECTED_DEBIAN="$idx" ;;
        security) MIRROR_SELECTED_SECURITY="$idx" ;;
        pve) MIRROR_SELECTED_PVE="$idx" ;;
        ceph) MIRROR_SELECTED_CEPH="$idx" ;;
        ct) MIRROR_SELECTED_CT="$idx" ;;
        *) return 1 ;;
    esac
}
mirror_reset_selection() {
    MIRROR_SELECTED_DEBIAN=-1
    MIRROR_SELECTED_SECURITY=-1
    MIRROR_SELECTED_PVE=-1
    MIRROR_SELECTED_CEPH=-1
    MIRROR_SELECTED_CT=-1
}
mirror_selection_complete() {
    [[ "$MIRROR_SELECTED_DEBIAN" =~ ^[0-9]+$ && "$MIRROR_SELECTED_DEBIAN" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_SECURITY" =~ ^[0-9]+$ && "$MIRROR_SELECTED_SECURITY" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_PVE" =~ ^[0-9]+$ && "$MIRROR_SELECTED_PVE" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_CEPH" =~ ^[0-9]+$ && "$MIRROR_SELECTED_CEPH" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_CT" =~ ^[0-9]+$ && "$MIRROR_SELECTED_CT" -ge 0 ]] || return 1
}
mirror_selected_index_by_type() {
    local source_type="$1"

    case "$source_type" in
        debian) echo "$MIRROR_SELECTED_DEBIAN" ;;
        security) echo "$MIRROR_SELECTED_SECURITY" ;;
        pve) echo "$MIRROR_SELECTED_PVE" ;;
        ceph) echo "$MIRROR_SELECTED_CEPH" ;;
        ct) echo "$MIRROR_SELECTED_CT" ;;
        *) echo "-1" ;;
    esac
}
mirror_source_label() {
    local source_type="$1"

    case "$source_type" in
        debian) echo "Debian 软件源" ;;
        security) echo "Debian Security 安全源" ;;
        pve) echo "Proxmox VE no-subscription 源" ;;
        ceph) echo "Ceph Squid 源" ;;
        ct) echo "CT 模板源" ;;
        *) echo "$source_type" ;;
    esac
}
mirror_print_selection_summary() {
    echo "$UI_DIVIDER"
    echo -e "${CYAN}当前镜像源配置:${NC}"
    local source_type idx uri
    for source_type in debian security pve ceph ct; do
        idx="$(mirror_selected_index_by_type "$source_type")"
        if [[ "$idx" =~ ^[0-9]+$ && "$idx" -ge 0 ]]; then
            uri="$(mirror_uri_by_type "$source_type" "$idx")"
            [[ -n "$uri" ]] || uri="官方源兜底"
            printf "  %-12s %-24s %s\n" "$(mirror_source_label "$source_type"):" "${MIRROR_NAMES[$idx]}" "$uri"
        else
            printf "  %-12s %s\n" "$(mirror_source_label "$source_type"):" "未选择"
        fi
    done
    echo "$UI_DIVIDER"
}
mirror_print_recommendation_notice() {
    echo -e "  ${YELLOW}推荐优先选择靠前的镜像源。地区性高校源可能会起到反向作用，例如：同步慢、高峰期丢包、随时不可用等。${NC}"
    echo -e "  ${YELLOW}如使用生产环境，请优先使用官方源或商业源（阿里云/腾讯云）。${NC}"
    echo "$UI_DIVIDER"
}
select_mirror_for_source() {
    local source_type="$1"
    local label="$2"
    local selected_var="$3"
    local candidates=()
    local idx uri pick selected_idx

    while true; do
        clear
        show_menu_header "$label"
        mirror_print_recommendation_notice
        candidates=()
        for idx in "${!MIRROR_NAMES[@]}"; do
            uri="$(mirror_uri_by_type "$source_type" "$idx")"
            [[ -n "$uri" ]] || continue
            candidates+=("$idx")
            printf "  ${PRIMARY}%-3s${NC}. %-28s %s\n" "${#candidates[@]}" "${MIRROR_NAMES[$idx]}" "$uri"
        done
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回"
        show_menu_footer

        read -p "请选择 $label [0-${#candidates[@]}]: " pick
        pick="${pick:-0}"
        [[ "$pick" == "0" ]] && return 1
        if [[ ! "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#candidates[@]} )); then
            log_error "无效选择，请重新输入"
            pause_function
            continue
        fi

        selected_idx="${candidates[$((pick - 1))]}"
        mirror_set_selected "$source_type" "$selected_idx" || return 1
        [[ -n "$selected_var" ]] && printf -v "$selected_var" '%s' "$selected_idx"
        log_success "$label 已选择: ${MIRROR_NAMES[$selected_idx]}"
        return 0
    done
}
select_mirror_unified() {
    local candidates=()
    local idx pick selected_idx

    while true; do
        clear
        show_menu_header "全部使用同一镜像"
        mirror_print_recommendation_notice
        echo "  仅展示同时支持 Debian / Security / PVE / Ceph / CT 的镜像。"
        echo "$UI_DIVIDER"
        candidates=()
        for idx in "${!MIRROR_NAMES[@]}"; do
            [[ -n "${MIRROR_DEBIAN_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_SECURITY_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_PVE_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_CEPH_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_CT_URIS[$idx]}" ]] || continue
            candidates+=("$idx")
            printf "  ${PRIMARY}%-3s${NC}. %s\n" "${#candidates[@]}" "${MIRROR_NAMES[$idx]}"
        done
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回"
        show_menu_footer

        read -p "请选择统一镜像 [0-${#candidates[@]}]: " pick
        pick="${pick:-0}"
        [[ "$pick" == "0" ]] && return 1
        if [[ ! "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#candidates[@]} )); then
            log_error "无效选择，请重新输入"
            pause_function
            continue
        fi

        selected_idx="${candidates[$((pick - 1))]}"
        MIRROR_SELECTED_DEBIAN="$selected_idx"
        MIRROR_SELECTED_SECURITY="$selected_idx"
        MIRROR_SELECTED_PVE="$selected_idx"
        MIRROR_SELECTED_CEPH="$selected_idx"
        MIRROR_SELECTED_CT="$selected_idx"
        mirror_print_selection_summary
        return 0
    done
}
select_mirror_per_source() {
    mirror_reset_selection
    select_mirror_for_source debian "Debian 软件源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source security "Debian Security 安全源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source pve "Proxmox VE no-subscription 源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source ceph "Ceph Squid 源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source ct "CT 模板源" || { mirror_reset_selection; return 1; }

    clear
    show_menu_header "镜像源选择摘要"
    mirror_print_selection_summary
    read -p "确认使用以上配置？输入 yes 确认，其他任意键返回: " confirm
    [[ "$confirm" == "yes" || "$confirm" == "YES" ]] || { mirror_reset_selection; return 1; }
}
select_mirror() {
    while true; do
        clear
        show_menu_header "镜像源配置"
        mirror_print_recommendation_notice
        show_menu_option "1" "全部使用同一镜像（快速）"
        show_menu_option "2" "按源类型分别选择（推荐）"
        show_menu_option "3" "跳过（稍后在菜单中配置）"
        echo "$UI_DIVIDER"
        echo "  跳过时不会写入软件源；再次执行更换软件源会重新进入本配置。"
        show_menu_footer

        local choice
        read -p "请选择 [1-3]: " choice
        case "$choice" in
            1) select_mirror_unified && return 0 ;;
            2) select_mirror_per_source && return 0 ;;
            3) mirror_reset_selection; log_info "已跳过镜像源配置"; return 1 ;;
            *) log_error "无效选择，请重新输入"; pause_function ;;
        esac
    done
}

# 版本检查函数
