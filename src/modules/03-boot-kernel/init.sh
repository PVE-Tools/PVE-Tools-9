#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_boot_kernel() {
    while true; do
        clear
        show_menu_header "启动与内核"
        show_menu_option "1" "内核管理 ${CYAN}(内核切换/更新/清理)${NC}"
        show_menu_option "2" "查看/备份 GRUB 配置"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-2]: " choice
        case $choice in
            1) kernel_management_menu ;;
            2) 
                while true; do
                    clear
                    show_menu_header "GRUB 配置管理"
                    show_menu_option "1" "查看当前 GRUB 配置"
                    show_menu_option "2" "备份 GRUB 配置"
                    show_menu_option "3" "查看备份列表"
                    show_menu_option "4" "恢复 GRUB 备份"
                    show_menu_option "0" "返回上级菜单"
                    show_menu_footer
                    read -p "请选择操作 [0-4]: " grub_choice
                    case $grub_choice in
                        1) show_grub_config; pause_function ;;
                        2) 
                            echo "请输入备份备注："
                            read -p "> " note
                            backup_grub_with_note "${note:-手动备份}"
                            pause_function
                            ;;
                        3) list_grub_backups; pause_function ;;
                        4) restore_grub_backup ;;
                        0) break ;;
                        *) log_error "无效选择" ;;
                    esac
                done
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：直通与显卡
