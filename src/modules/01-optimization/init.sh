#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_optimization() {
    while true; do
        clear
        echo "功能 1/2 请在外部SSH环境下使用该功能！否则会导致PVE WebUi重启导致Shell断开连接修改失效！"
        echo "不要犟！查看如何连接到PVE SSH教程：https://pve.oowo.cc/advanced/how-to-connect-ssh.html"
        show_menu_header "系统优化"
        show_menu_option "1" "删除订阅弹窗"
        show_menu_option "2" "${MAGENTA}一键优化 (换源+删弹窗+更新)${NC}"
        show_menu_option "3" "温度监控管理 ${CYAN}(CPU/硬盘监控设置)${NC}"
        show_menu_option "4" "CPU 电源模式配置"
        show_menu_option "5" "配置邮件通知 ${CYAN}(SMTP/Postfix)${NC}"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-6]: " choice
        case $choice in
            1) remove_subscription_popup ;;
            2) quick_setup ;;
            3) temp_monitoring_menu ;;
            4) cpupower ;;
            5) pve_mail_notification_setup ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：软件源与更新
