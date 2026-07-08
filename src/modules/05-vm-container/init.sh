#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_advanced_operations_menu() {
    while true; do
        clear
        show_menu_header "虚拟机高级运维工具箱"
        vm_show_data_risk_banner
        show_menu_option "1" "VM 备份与恢复"
        show_menu_option "2" "VM 配置导入/导出"
        show_menu_option "3" "模板 / 克隆 / Cloud-Init"
        show_menu_option "4" "虚拟机磁盘管理"
        show_menu_option "5" "快照管理"
        show_menu_option "6" "启动顺序与网络管理"
        show_menu_option "7" "集群内迁移 VM"
        echo -e "${RED}警告：涉及备份恢复、磁盘、快照、模板与迁移时，必须先确认备份可用，再核对 VMID / 槽位 / 目标存储。${NC}"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-7]: " choice
        case "$choice" in
            1) vm_backup_restore_menu ;;
            2) vm_config_io_menu ;;
            3) vm_template_cloudinit_menu ;;
            4) vm_disk_management_menu ;;
            5) vm_snapshot_menu ;;
            6) vm_startup_network_menu ;;
            7) vm_cluster_migrate ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
# 二级菜单：虚拟机与容器
menu_vm_container() {
    while true; do
        clear
        show_menu_header "虚拟机与容器"
        show_menu_option "1" "${CYAN}FastPVE${NC} - 虚拟机快速下载"
        show_menu_option "2" "虚拟机/容器定时开关机"
        show_menu_option "3" "IMG 镜像导入（转 QCOW2/RAW）"
        show_menu_option "4" "虚拟机高级运维工具箱"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1) fastpve_quick_download_menu ;;
            2) manage_vm_schedule ;;
            3) img_convert_import_menu ;;
            4) vm_advanced_operations_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# ============ 宿主机网络 / 防火墙 / IPv6 / 诊断工具箱 ============
