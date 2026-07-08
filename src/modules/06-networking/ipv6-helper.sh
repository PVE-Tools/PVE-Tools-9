#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

ipv6_helper_detect_host_readiness() {
    clear
    show_menu_header "IPv6 宿主机就绪度"
    echo -e "${CYAN}全局 IPv6 地址：${NC}"
    ip -6 -o addr show scope global 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}IPv6 默认路由：${NC}"
    ip -6 route show default 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}IPv6 连通性测试：${NC}"
    if ping -6 -c 2 -W 2 2606:4700:4700::1111 >/dev/null 2>&1; then
        echo "  Cloudflare DNS IPv6 连通正常"
    else
        echo "  Cloudflare DNS IPv6 连通失败"
    fi
    echo "$UI_DIVIDER"
}
ipv6_helper_detect_vm_readiness() {
    clear
    show_menu_header "VM IPv6 就绪度（Guest Agent 最佳）"
    local vmid name ips
    while read -r vmid name _; do
        [[ -n "$vmid" && "$vmid" != "VMID" ]] || continue
        ips="$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | grep -oE '([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F]{0,4}(/[0-9]+)?' | grep -v '^fe80' | sort -u | tr '\n' ' ')"
        if [[ -n "$ips" ]]; then
            printf '  VM %s (%s): %s\n' "$vmid" "$name" "$ips"
        else
            printf '  VM %s (%s): 无法通过 Guest Agent 获取 IPv6（可能未安装 agent 或未启动）\n' "$vmid" "$name"
        fi
    done < <(qm list 2>/dev/null)
    echo "$UI_DIVIDER"
}
ipv6_helper_configure_passthrough() {
    local bridge_name preserved tmp block
    bridge_name="$(host_network_select_bridge_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bridge_name" ]] || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$bridge_name" inet6)"
    host_network_remove_iface_family_from_candidate "$tmp" "$bridge_name" inet6
    host_network_ensure_auto_line_in_candidate "$tmp" "$bridge_name"
    block="$(host_network_build_family_stanza "$bridge_name" inet6 'auto|||accept-ra 2' "$preserved")"
    host_network_append_text_to_candidate "$tmp" "$block"
    host_network_commit_candidate "$tmp" "为桥接 $bridge_name 启用 IPv6 透传 / SLAAC" "会调整桥接的 IPv6 获取方式和 RA 行为。" "若上游 IPv6/RA 不可用或桥接承载管理口，可能导致地址和默认路由改变。" "请确认上游已提供 IPv6 RA，并通过控制台执行。"
    rm -f "$tmp"
}
ipv6_helper_configure_nat6() {
    local bridge_name uplink prefix bridge_addr preserved tmp block
    bridge_name="$(host_network_select_bridge_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bridge_name" ]] || return 1
    uplink="$(host_network_select_interface_name)"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$uplink" ]] || return 1
    [[ "$uplink" != "$bridge_name" ]] || {
        display_error "NAT6 上联接口不能与桥接接口相同"
        return 1
    }
    command -v ip6tables >/dev/null 2>&1 || {
        display_error "未检测到 ip6tables" "请先确认系统已安装并启用 IPv6 NAT 所需工具。"
        return 1
    }
    host_network_iface_exists "$uplink" || {
        display_error "上联接口不存在: $uplink"
        return 1
    }

    read -p "请输入 NAT6 内网前缀（示例 fd10:10:10::/64）: " prefix
    host_network_validate_static_address inet6 "$prefix" || {
        display_error "前缀格式无效: $prefix" "请使用类似 fd10:10:10::/64 的 IPv6 前缀。"
        return 1
    }
    read -p "请输入桥接 IPv6 地址（示例 fd10:10:10::1/64）: " bridge_addr
    host_network_validate_static_address inet6 "$bridge_addr" || {
        display_error "桥接 IPv6 地址格式无效: $bridge_addr"
        return 1
    }

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$bridge_name" inet6)"
    host_network_remove_iface_family_from_candidate "$tmp" "$bridge_name" inet6
    host_network_ensure_auto_line_in_candidate "$tmp" "$bridge_name"
    block=$(cat <<EOF_NAT6
iface $bridge_name inet6 static
$(while IFS= read -r line; do [[ -n "$line" ]] && printf '    %s\n' "$line"; done <<< "$preserved")    address $bridge_addr
    post-up sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
    post-up ip6tables -t nat -C POSTROUTING -s $prefix -o $uplink -j MASQUERADE || ip6tables -t nat -A POSTROUTING -s $prefix -o $uplink -j MASQUERADE
    post-down ip6tables -t nat -D POSTROUTING -s $prefix -o $uplink -j MASQUERADE || true
EOF_NAT6
)
    host_network_append_text_to_candidate "$tmp" "$block"
    host_network_commit_candidate "$tmp" "为桥接 $bridge_name 配置 NAT6" "会开启 IPv6 转发并对 $prefix 执行 NAT6 出口伪装。" "错误的 uplink、前缀或防火墙策略会导致 IPv6 业务不可达。" "请确认上游具备 IPv6 出口、ip6tables 可用，并已在控制台中准备回滚。"
    rm -f "$tmp"
}
ipv6_helper_test_connectivity() {
    local target
    read -p "请输入要测试的 IPv6 目标 [2606:4700:4700::1111]: " target
    target="${target:-2606:4700:4700::1111}"
    clear
    show_menu_header "IPv6 连通性测试"
    echo -e "${CYAN}ping -6 ${target}${NC}"
    ping -6 -c 4 -W 2 "$target" 2>&1 | sed 's/^/  /'
    echo "$UI_DIVIDER"
}
ipv6_helper_menu() {
    while true; do
        clear
        show_menu_header "IPv6 助手"
        host_network_show_risk_banner
        show_menu_option "1" "检测宿主机 IPv6 就绪度"
        show_menu_option "2" "检测 VM IPv6 就绪度（Guest Agent）"
        show_menu_option "3" "一键配置桥接 IPv6 透传 / SLAAC"
        show_menu_option "4" "一键配置桥接 NAT6"
        show_menu_option "5" "测试 IPv6 连通性"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-5]: " choice
        case "$choice" in
            1) ipv6_helper_detect_host_readiness ;;
            2) ipv6_helper_detect_vm_readiness ;;
            3) ipv6_helper_configure_passthrough ;;
            4) ipv6_helper_configure_nat6 ;;
            5) ipv6_helper_test_connectivity ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
