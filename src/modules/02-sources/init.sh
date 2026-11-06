#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_sources_updates() {
    run_menu "软件源与更新" menu_sources_updates_render menu_sources_updates_dispatch "0-3"
}

menu_sources_updates_render() {
    show_menu_option "1" "更换软件源"
    show_menu_option "2" "更新系统软件包"
    show_menu_option "3" "${YELLOW}PVE 8.x 升级到 PVE 9.x${NC}"
}

# 分发软件源菜单；换源失败映射为2，取消映射为3，未知选项仍返回1。
menu_sources_updates_dispatch() {
    case "$1" in
        1)
            local status=0
            change_sources || status=$?
            [[ "$status" -eq 2 ]] && return 3
            [[ "$status" -eq 0 ]] || return 2
            ;;
        2) update_system ;;
        3) pve8_to_pve9_upgrade ;;
        *) return 1 ;;
    esac
    return 0
}
