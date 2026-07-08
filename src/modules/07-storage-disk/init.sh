#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_storage_disk() {
    while true; do
        clear
        show_menu_header "存储与硬盘"
        show_menu_option "1" "存储位置查询面板 ${CYAN}(ISO/备份/SCP路径)${NC}"
        show_menu_option "2" "磁盘挂载向导 ${CYAN}(复用已有 ext4/xfs 分区)${NC}"
        show_menu_option "3" "合并 ${CYAN}local${NC} 与 ${CYAN}local-lvm${NC}"
        show_menu_option "4" "${CYAN}Ceph${NC} 管理 (安装/卸载/换源)"
        show_menu_option "5" "硬盘休眠配置 ${CYAN}(hdparm)${NC}"
        show_menu_option "6" "垃圾清理 ${CYAN}(缓存/备份/快照扫描)${NC}"
        show_menu_option "7" "${RED}删除 Swap 分区${NC}"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-7]: " choice
        case $choice in
            1) pve_storage_location_panel ;;
            2) pve_storage_mount_wizard ;;
            3) merge_local_storage ;;
            4) ceph_management_menu ;;
            5) 
                lsblk -o NAME,MODEL,TYPE,SIZE,MOUNTPOINT | grep disk
                read -p "请输入要配置休眠的硬盘盘符 (如 sdb, 不含/dev/): " disk_name
                if [ -b "/dev/$disk_name" ]; then
                    read -p "请输入休眠时间 (1-255, 120=10分钟, 240=20分钟, 0=禁用): " sleep_val
                    if [[ "$sleep_val" =~ ^[0-9]+$ ]]; then
                        hdparm -S "$sleep_val" "/dev/$disk_name"
                        log_success "配置已应用到 /dev/$disk_name"
                    else
                        log_error "无效的时间值"
                    fi
                else
                    log_error "未找到磁盘 /dev/$disk_name"
                fi
                ;;
            6) garbage_cleanup_menu ;;
            7) remove_swap ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：工具与关于
