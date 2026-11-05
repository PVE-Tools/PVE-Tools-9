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

# 分发软件源菜单；换源时保留 change_sources 的退出状态，不能掩盖部分失败。
menu_sources_updates_dispatch() {
    case "$1" in
        1) change_sources; return $? ;;
        2) update_system ;;
        3) pve8_to_pve9_upgrade ;;
        *) return 1 ;;
    esac
    return 0
}
