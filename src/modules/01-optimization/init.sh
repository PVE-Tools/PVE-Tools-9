#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_optimization() {
    run_menu "系统优化" menu_optimization_render menu_optimization_dispatch "0-6"
}

menu_optimization_render() {
    echo -e "  ${YELLOW}功能 1/2 请在外部 SSH 环境下使用！否则 PVE WebUI 重启会导致 Shell 断连、修改失效。${NC}"
    echo -e "  ${YELLOW}SSH 连接教程: https://pve.ciriu.com/tutorial/how-to-connect-ssh${NC}"
    echo "$UI_DIVIDER"
    show_menu_option "1" "删除订阅弹窗"
    show_menu_option "2" "${MAGENTA}一键优化 (换源+删弹窗+更新)${NC}"
    show_menu_option "3" "温度监控管理 ${CYAN}(CPU/硬盘监控设置)${NC}"
    show_menu_option "4" "CPU 电源模式配置"
    show_menu_option "5" "配置邮件通知 ${CYAN}(SMTP/Postfix)${NC}"
    show_menu_option "6" "UPS 电源诊断 ${CYAN}(NUT / upsc)${NC}"
}

menu_optimization_dispatch() {
    case "$1" in
        1) remove_subscription_popup ;;
        2) quick_setup ;;
        3) temp_monitoring_menu ;;
        4) cpupower ;;
        5) pve_mail_notification_setup ;;
        6) show_ups_diagnostics ;;
        *) return 1 ;;
    esac
    return 0
}
