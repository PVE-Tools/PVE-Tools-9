#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

igpu_gvtg_setup() {
    echo -e "${H2}开始配置 Intel 6-10代 GVT-g 核显虚拟化${NC}"
    echo -e "详细原理与教程： ${CYAN}https://pve.oowo.cc/advanced/gpu-virtualization${NC}"
    echo -e "如果配置失败，请访问文档站下方留言反馈。"
    echo

    # 展示当前 GRUB 配置
    echo
    show_grub_config
    echo

    # 危险性警告
    echo "$UI_BORDER"
    echo -e "  ${RED}【高危操作警告】${NC} GVT-g 核显虚拟化配置"
    echo "$UI_BORDER"
    echo -e "  此操作属于${RED}【高危险性】${NC}系统配置，配置错误可能导致："
    echo -e "    - ${YELLOW}系统无法正常启动${NC}（GRUB 配置错误）"
    echo -e "    - ${YELLOW}核显完全不可用${NC}（参数配置错误）"
    echo -e "    - ${YELLOW}虚拟机黑屏或无法启动${NC}（直通配置错误）"
    echo -e "    - ${YELLOW}需要通过恢复模式修复系统${NC}"
    echo "$UI_BORDER"
    echo
    echo -e "  此功能将修改以下系统配置："
    echo -e "    1. 修改 ${CYAN}GRUB 引导参数${NC}（启用 IOMMU 和 GVT-g）"
    echo -e "    2. 加载 ${CYAN}VFIO${NC} 和 ${CYAN}kvmgt${NC} 内核模块"
    echo
    echo -e "  ${GREEN}前置要求（请确认已完成）：${NC}"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}VT-d${NC} 虚拟化"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}SR-IOV${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}Above 4GB${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已关闭 ${CYAN}Secure Boot${NC} 安全启动"
    echo -e "    ${GREEN}✓${NC} CPU 为 ${CYAN}Intel 6-10 代${NC} 处理器"
    echo
    echo -e "  ${PRIMARY}支持的处理器代号：${NC}"
    echo -e "    ${BLUE}•${NC} Skylake (6代)"
    echo -e "    ${BLUE}•${NC} Kaby Lake (7代)"
    echo -e "    ${BLUE}•${NC} Coffee Lake (8代)"
    echo -e "    ${BLUE}•${NC} Coffee Lake Refresh (9代)"
    echo -e "    ${BLUE}•${NC} Comet Lake (10代)"
    echo
    echo -e "  ${MAGENTA}特殊的处理器代号：${NC}"
    echo -e "    ${MAGENTA}•${NC} Rocket Lake / Tiger Lake (11代) 因处在当前代与上一代交界"
    echo -e "      部分型号支持，但是不保证兼容性，请谨慎使用"
    echo "$UI_BORDER"
    echo
    echo -e "${YELLOW}强烈建议：${NC}"
    echo -e "  ${CYAN}提示 1:${NC} 在继续前先备份当前 GRUB 配置"
    echo -e "  ${CYAN}提示 2:${NC} 确保了解核显虚拟化的工作原理"
    echo -e "  ${CYAN}提示 3:${NC} 准备好通过 SSH 或物理访问恢复系统"
    echo

    # 询问是否要备份
    if confirm_action "是否先备份当前 GRUB 配置（强烈推荐）"; then
        echo
        echo "请输入备份备注（例如：GVT-g配置前备份）："
        read -p "> " backup_note
        backup_note=${backup_note:-"GVT-g配置前备份"}
        backup_grub_with_note "$backup_note"
        echo
    fi

    if ! confirm_action "确认继续配置 GVT-g 核显虚拟化"; then
        echo "用户取消操作"
        return 0
    fi

    # 备份并修改 GRUB 配置
    echo "配置 GRUB 引导参数..."
    backup_file "/etc/default/grub"

    # 使用幂等的 GRUB 参数管理函数
    echo "配置 GRUB 参数..."

    # 移除旧的 SR-IOV 配置（如果有）
    grub_remove_param "i915.enable_guc"
    grub_remove_param "i915.max_vfs"
    grub_remove_param "module_blacklist"

    # 添加 GVT-g 参数（幂等操作，不会重复添加）
    grub_add_param "intel_iommu=on"
    grub_add_param "iommu=pt"
    grub_add_param "i915.enable_gvt=1"
    grub_add_param "pcie_acs_override=downstream,multifunction"

    echo -e "✓ GRUB 配置已更新"

    # 更新 GRUB
    echo "更新 GRUB..."
    update-grub || {
        echo -e "更新 GRUB 失败"
        pause_function
        return 1
    }

    # 配置内核模块
    echo "配置内核模块..."
    backup_file "/etc/modules"

    # 清理可能存在的 i915 及音视频相关黑名单 (GVT-g 需要 i915 驱动加载)
    echo "清理可能存在的 i915 及音视频相关黑名单..."
    for f in /etc/modprobe.d/blacklist.conf /etc/modprobe.d/pve-blacklist.conf; do
        if [ -f "$f" ]; then
            sed -i '/blacklist i915/d' "$f"
            sed -i '/blacklist snd_hda_intel/d' "$f"
            sed -i '/blacklist snd_hda_codec_hdmi/d' "$f"
        fi
    done

    # 添加 VFIO 和 kvmgt 模块
    for module in vfio vfio_iommu_type1 vfio_pci vfio_virqfd kvmgt; do
        if ! grep -q "^$module$" /etc/modules; then
            echo "$module" >> /etc/modules
            echo "已添加模块: $module"
        fi
    done

    echo -e "✓ 内核模块配置完成"

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all || {
        echo -e "更新 initramfs 失败，但可以继续"
    }

    # 完成提示
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ GVT-g 核显虚拟化配置完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "配置摘要："
    echo "  • 内核参数: intel_iommu=on iommu=pt i915.enable_gvt=1"
    echo "  • VFIO 模块: 已加载"
    echo "  • kvmgt 模块: 已加载"
    echo
    echo -e "下一步操作："
    echo -e "  1. 重启系统使配置生效"
    echo "  2. 重启后使用 '验证核显虚拟化状态' 检查配置"
    echo "  3. 在虚拟机配置中添加核显 GVT-g 设备（Mdev 类型）"
    echo
    echo "常见 Mdev 类型："
    echo "  • i915-GVTg_V5_4: 低性能，可创建更多虚拟机"
    echo "  • i915-GVTg_V5_8: 高性能，推荐使用（UHD630 最多 2 个）"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo -e "请记得手动重启系统以使配置生效"
    fi
}

# 清理 GVT-g 和 SR-IOV 配置 (恢复默认)
