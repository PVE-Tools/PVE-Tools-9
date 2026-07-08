#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_host_networking() {
    while true; do
        clear
        show_menu_header "宿主机网络配置向导"
        host_network_show_risk_banner
        show_menu_option "1" "列出当前网卡与桥接（vmbr0~N）"
        show_menu_option "2" "桥接管理（创建 / 删除）"
        show_menu_option "3" "配置接口静态 IPv4 / IPv6 / SLAAC / DHCP"
        show_menu_option "4" "VLAN 子接口管理"
        show_menu_option "5" "Bond 管理（模式 0 / 1 / 4 / 6）"
        show_menu_option "6" "PVE 防火墙管理"
        show_menu_option "7" "IPv6 助手"
        show_menu_option "8" "网络诊断工具箱"
        echo -e "${RED}警告：应用宿主机网络修改时，建议在控制台或带外管理环境中执行，避免误断 SSH / WebUI。${NC}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-8]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_bridge_menu ;;
            3) host_network_configure_interface_addressing ;;
            4) host_network_vlan_menu ;;
            5) host_network_bond_menu ;;
            6) host_firewall_menu ;;
            7) ipv6_helper_menu ;;
            8) netdiag_toolbox_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：存储与硬盘
