#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_tools_about() {
    while true; do
        clear
        show_menu_header "工具与关于"
        show_menu_option "1" "系统信息概览"
        show_menu_option "2" "应急救砖工具箱"
        show_menu_option "3" "本地脚本快捷更新"
        show_menu_option "4" "${RED}本地脚本快捷卸载${NC}"
        show_menu_option "5" "给作者点个 Star 吧"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-5]: " choice
        case $choice in
            1) show_system_info ;;
            2) show_menu_rescue ;;
            3) pve_tools_local_update ;;
            4) pve_tools_local_uninstall ;;
            5) 
                echo -e "${YELLOW}项目地址：https://github.com/PVE-Tools/PVE-Tools-9${NC}"
                echo -e "${GREEN}您的支持是我更新的最大动力，谢谢喵~${NC}"
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 一键配置
show_menu_rescue() {
    while true; do
        clear
        show_menu_header "应急救砖工具箱"
        echo -e "${RED}警告：本工具箱用于修复因误操作导致的系统问题，请谨慎使用！${NC}"
        echo
        show_menu_option "1" "恢复官方 Web UI 文件 (重装 pve-manager / proxmox-widget-toolkit)"
        show_menu_option "2" "恢复官方 pve-qemu-kvm (修复修改版 QEMU 问题)"
        show_menu_option "3" "清理驱动黑名单 (i915/snd_hda_intel)"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case $choice in
            1) restore_proxmoxlib ;;
            2) restore_qemu_kvm ;;
            3) 
                if confirm_action "确定要清理显卡和声卡驱动的黑名单设置吗？"; then
                    log_info "正在清理黑名单配置..."
                    sed -i '/blacklist i915/d' /etc/modprobe.d/pve-blacklist.conf
                    sed -i '/blacklist snd_hda_intel/d' /etc/modprobe.d/pve-blacklist.conf
                    sed -i '/blacklist snd_hda_codec_hdmi/d' /etc/modprobe.d/pve-blacklist.conf
                    log_info "正在更新 initramfs..."
                    update-initramfs -u -k all
                    log_success "黑名单清理完成，请重启系统"
                fi
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：系统优化
