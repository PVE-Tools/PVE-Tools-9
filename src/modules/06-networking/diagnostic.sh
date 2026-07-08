#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

netdiag_require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        display_error "缺少命令: $cmd" "请先安装对应工具后再试。"
        return 1
    fi
}
netdiag_run_traceroute() {
    netdiag_require_cmd traceroute || return 1
    local target
    read -p "请输入 traceroute 目标 [1.1.1.1]: " target
    target="${target:-1.1.1.1}"
    traceroute "$target"
}
netdiag_run_mtr() {
    netdiag_require_cmd mtr || return 1
    local target
    read -p "请输入 mtr 目标 [1.1.1.1]: " target
    target="${target:-1.1.1.1}"
    mtr -rwzc 10 "$target"
}
netdiag_run_nmap() {
    netdiag_require_cmd nmap || return 1
    local target
    read -p "请输入 nmap 扫描目标: " target
    [[ -n "$target" ]] || return 1
    nmap -Pn -T4 "$target"
}
netdiag_run_tcpdump() {
    netdiag_require_cmd tcpdump || return 1
    local iface_name filter_expr seconds
    iface_name="$(host_network_select_interface_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$iface_name" ]] || return 1
    read -p "请输入抓包过滤表达式（留空抓全部）: " filter_expr
    read -p "抓包秒数 [15]: " seconds
    seconds="${seconds:-15}"
    [[ "$seconds" =~ ^[0-9]+$ ]] || return 1
    timeout "$seconds" tcpdump -ni "$iface_name" ${filter_expr:+$filter_expr}
}
netdiag_pick_vm_ip() {
    local vmid ips vm_ip
    vmid="$(host_firewall_select_guest vm)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 2
    [[ -n "$vmid" ]] || return 1
    ips="$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F]{0,4}' | grep -v '^fe80' | sort -u)"
    if [[ -z "$ips" ]]; then
        read -p "Guest Agent 未返回 IP，请手工输入 VM IP: " vm_ip
        [[ -n "$vm_ip" ]] && printf '%s\n' "$vm_ip"
        return 0
    fi
    host_network_select_from_text "VM $vmid 的可用 IP：" "$ips"
}
netdiag_check_port_connectivity() {
    local target_mode target port
    echo "  [1] 检查宿主机管理口"
    echo "  [2] 检查 VM 端口"
    echo "  [3] 自定义目标"
    read -p "请选择目标类型 [1-3]: " target_mode
    case "$target_mode" in
        1)
            target="$(ip -4 -o addr show scope global 2>/dev/null | awk 'NR==1 {print $4}' | cut -d'/' -f1)"
            [[ -n "$target" ]] || target="127.0.0.1"
            ;;
        2)
            target="$(netdiag_pick_vm_ip)"
            local rc=$?
            [[ "$rc" -eq 2 ]] && return 0
            [[ -n "$target" ]] || return 1
            ;;
        3)
            read -p "请输入目标 IP / 主机名: " target
            [[ -n "$target" ]] || return 1
            ;;
        *) return 1 ;;
    esac
    read -p "请输入端口号: " port
    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    clear
    show_menu_header "端口连通性测试"
    echo -e "${CYAN}目标: ${target}:${port}${NC}"
    if command -v nc >/dev/null 2>&1; then
        nc -zvw 3 "$target" "$port"
    else
        timeout 3 bash -c "</dev/tcp/${target}/${port}" >/dev/null 2>&1 && echo "端口可达" || echo "端口不可达"
    fi
    echo "$UI_DIVIDER"
}
netdiag_quick_stack_check() {
    clear
    show_menu_header "网络诊断摘要"
    network_show_diagnostics
    echo -e "${CYAN}IPv6 地址：${NC}"
    ip -6 -o addr show scope global 2>/dev/null | awk '{print "  "$2": "$4}' || true
    echo -e "${CYAN}监听端口（前 20 条）：${NC}"
    ss -lntup 2>/dev/null | sed -n '1,20p' | sed 's/^/  /' || true
    echo "$UI_DIVIDER"
}
netdiag_toolbox_menu() {
    while true; do
        clear
        show_menu_header "网络诊断工具箱"
        show_menu_option "1" "网络摘要与监听端口"
        show_menu_option "2" "traceroute"
        show_menu_option "3" "mtr"
        show_menu_option "4" "nmap"
        show_menu_option "5" "tcpdump"
        show_menu_option "6" "端口连通性检查（宿主机 / VM / 自定义）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-6]: " choice
        case "$choice" in
            1) netdiag_quick_stack_check ;;
            2) netdiag_run_traceroute ;;
            3) netdiag_run_mtr ;;
            4) netdiag_run_nmap ;;
            5) netdiag_run_tcpdump ;;
            6) netdiag_check_port_connectivity ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
