#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

third_party_tools_menu() {
    while true; do
        clear
        show_menu_header "第三方工具"
        show_menu_option "1" "第三方软件市场 ${CYAN}(Modules)${NC}"
        show_menu_option "2" "CoolerControl ${CYAN}(更好的管理风扇控制工具)${NC}"
        show_menu_option "3" "Community Scripts ${CYAN}(社区脚本集合)${NC}"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) third_party_market_menu ;;
            2) coolercontrol_manager_menu ;;
            3) third_party_community_scripts_info ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# PVE8 to PVE9 升级功能
