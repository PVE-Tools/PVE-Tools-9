#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

temp_monitoring_menu() {
    while true; do
        clear
        show_menu_header "温度监控管理"
        show_menu_option "1" "配置温度监控 ${CYAN}(CPU/硬盘温度显示)${NC}"
        show_menu_option "2" "${RED}移除温度监控${NC} (移除温度监控功能)"
        show_menu_option "3" "UPS 状态诊断 ${CYAN}(NUT / upsc)${NC}"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回上级菜单"
        show_menu_footer
        echo
        read -p "请选择 [0-3]: " temp_choice
        echo
        
        case $temp_choice in
            1)
                cpu_add
                ;;
            2)
                cpu_del
                ;;
            3)
                show_ups_diagnostics
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        pause_function
    done
}

# 自定义温度监控配置
# 已经死了。

# Ceph管理菜单
