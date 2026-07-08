#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_gpu_passthrough() {
    while true; do
        clear
        show_menu_header "直通与显卡"
        show_menu_option "1" "Intel 核显虚拟化管理 (SR-IOV/GVT-g)"
        show_menu_option "2" "Intel 核显直通配置 (修改版 QEMU)"
        show_menu_option "3" "NVIDIA 显卡直通/虚拟化"
        show_menu_option "4" "AMD 独显直通"
        show_menu_option "5" "AMD 核显直通 (需自备 ROM / vBIOS)"
        show_menu_option "6" "硬件直通一键配置 (IOMMU)"
        show_menu_option "7" "磁盘/控制器直通 (RDM/PCIe/NVMe)"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-7]: " choice
        case $choice in
            1) igpu_management_menu ;;
            2) intel_gpu_passthrough ;;
            3) nvidia_gpu_management_menu ;;
            4) amd_gpu_management_menu ;;
            5) amd_igpu_management_menu ;;
            6) hw_passth ;;
            7) menu_disk_controller_passthrough ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 虚拟机/容器定时开关机管理
menu_disk_controller_passthrough() {
    while true; do
        clear
        show_menu_header "磁盘/控制器直通"
        show_menu_option "1" "RDM（裸磁盘映射）- 单个磁盘直通"
        show_menu_option "2" "RDM 取消直通（--delete）"
        show_menu_option "3" "磁盘控制器直通（PCIe）"
        show_menu_option "4" "NVMe 直通（含 MSI-X 重定位）"
        show_menu_option "5" "引导配置辅助（UEFI/Legacy）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-6]: " choice
        case "$choice" in
            1) rdm_single_disk_attach ;;
            2) rdm_single_disk_detach ;;
            3) storage_controller_passthrough ;;
            4) nvme_passthrough ;;
            5) boot_config_assistant ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# ============ RDM（裸磁盘映射）单盘直通 ============

# 获取 VM 配置文件路径（不保证一定存在，需调用方自行判断）
