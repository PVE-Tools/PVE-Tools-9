#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

menu_tools_about() {
    run_menu "工具与关于" menu_tools_about_render menu_tools_about_dispatch "0-6"
}

menu_tools_about_render() {
    show_menu_option "1" "系统信息概览"
    show_menu_option "2" "应急救砖工具箱"
    show_menu_option "3" "本地脚本快捷更新"
    show_menu_option "4" "${RED}本地脚本快捷卸载${NC}"
    show_menu_option "5" "安装环境诊断 (doctor)"
    show_menu_option "6" "给作者点个 Star 吧"
}

menu_tools_about_dispatch() {
    case "$1" in
        1) show_system_info ;;
        2) show_menu_rescue ;;
        3) pve_tools_local_update ;;
        4) pve_tools_local_uninstall ;;
        5) pve_tools_doctor_run ;;
        6)
            echo -e "${YELLOW}项目地址：https://github.com/PVE-Tools/PVE-Tools-9${NC}"
            echo -e "${GREEN}您的支持是我更新的最大动力，谢谢喵~${NC}"
            ;;
        *) return 1 ;;
    esac
    return 0
}

# NOTE: show_menu_rescue() intentionally calls restore_proxmoxlib() (defined in
# 01-optimization/popup.sh) and restore_qemu_kvm() (defined in
# 04-gpu-passthrough/intel-legacy.sh). This is a deliberate cross-module
# dependency for the rescue/repair menu. Since all modules are sourced
# globally, these symbols are always available. Moving to lib/ is the ideal
# long-term approach but deferred.
show_menu_rescue() {
    run_menu "应急救砖工具箱" show_menu_rescue_render show_menu_rescue_dispatch "0-3"
}

show_menu_rescue_render() {
    echo -e "  ${RED}警告：本工具箱用于修复因误操作导致的系统问题，请谨慎使用！${NC}"
    echo
    show_menu_option "1" "恢复官方 Web UI 文件 (重装 pve-manager / proxmox-widget-toolkit)"
    show_menu_option "2" "恢复官方 pve-qemu-kvm (修复修改版 QEMU 问题)"
    show_menu_option "3" "清理驱动黑名单 (i915/snd_hda_intel)"
}

show_menu_rescue_dispatch() {
    case "$1" in
        1) restore_proxmoxlib ;;
        2) restore_qemu_kvm ;;
        3) rescue_clear_driver_blacklist ;;
        *) return 1 ;;
    esac
    return 0
}

rescue_clear_driver_blacklist() {
    if ! confirm_high_risk_action \
        "清理驱动黑名单" \
        "将修改 /etc/modprobe.d/pve-blacklist.conf 并运行 update-initramfs -u -k all。" \
        "错误还原可能导致显卡/声卡驱动冲突或系统无法启动。" \
        "请确认你需要移除黑名单中的显卡和声卡驱动限制。" \
        "CONFIRM"; then
        return 0
    fi
    log_info "正在清理黑名单配置..."
    if ! backup_file "/etc/modprobe.d/pve-blacklist.conf"; then
        display_error "无法备份 /etc/modprobe.d/pve-blacklist.conf，操作中止"
        return 1
    fi
    sed -i '/blacklist i915/d' /etc/modprobe.d/pve-blacklist.conf
    sed -i '/blacklist snd_hda_intel/d' /etc/modprobe.d/pve-blacklist.conf
    sed -i '/blacklist snd_hda_codec_hdmi/d' /etc/modprobe.d/pve-blacklist.conf
    log_info "正在更新 initramfs..."
    update-initramfs -u -k all
    log_success "黑名单清理完成，请重启系统"
}
