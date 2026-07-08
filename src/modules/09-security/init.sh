#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

security_center_menu() {
    while true; do
        clear
        show_menu_header "安全中心"
        show_menu_option "1" "安全风险检查 ${CYAN}(只读报告)${NC}"
        show_menu_option "2" "SSH 一键加固 ${CYAN}(端口/密钥/fail2ban)${NC}"
        show_menu_option "3" "CVE 漏洞修补 ${RED}(Januscape/内核漏洞)${NC}"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) security_risk_check ;;
            2) security_ssh_hardening ;;
            3) security_cve_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 温度监控管理菜单
