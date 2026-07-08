#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_sources_updates() {
    while true; do
        clear
        show_menu_header "软件源与更新"
        show_menu_option "1" "更换软件源"
        show_menu_option "2" "更新系统软件包"
        show_menu_option "3" "${YELLOW}PVE 8.x 升级到 PVE 9.x${NC}"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case $choice in
            1) change_sources ;;
            2) update_system ;;
            3) pve8_to_pve9_upgrade ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：启动与内核
