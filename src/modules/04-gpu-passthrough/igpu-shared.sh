#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# 验证核显虚拟化状态
igpu_verify() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  核显虚拟化状态检查"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # 检查 IOMMU
    echo "1. 检查 IOMMU 状态..."
    if dmesg | grep -qi "DMAR.*IOMMU\|iommu.*enabled"; then
        echo -e "  ✓ IOMMU 已启用"
        echo "  $(dmesg | grep -i "DMAR.*IOMMU\|iommu.*enabled" | head -3)"
    else
        echo -e "  ✗ IOMMU 未启用"
        echo "  提示: 请检查 BIOS 是否开启 VT-d"
        echo "  提示: 请检查 GRUB 配置是否包含 intel_iommu=on"
    fi
    echo

    # 检查 VFIO 模块
    echo "2. 检查 VFIO 模块加载状态..."
    if lsmod | grep -q vfio; then
        echo -e "  ✓ VFIO 模块已加载"
        echo "  $(lsmod | grep vfio)"
    else
        echo -e "  ✗ VFIO 模块未加载"
        echo "  提示: 请检查 /etc/modules 配置"
    fi
    echo

    # 检查 SR-IOV
    echo "3. 检查 SR-IOV 虚拟核显..."
    if lspci | grep -i "VGA.*Intel" | wc -l | grep -q "^[2-9]"; then
        vf_count=$(($(lspci | grep -i "VGA.*Intel" | wc -l) - 1))
        echo -e "  ✓ 检测到 $vf_count 个虚拟核显 (SR-IOV)"
        echo
        lspci | grep -i "VGA.*Intel"
        echo
        echo "  提示: 物理核显 00:02.0 不能直通"
        echo "  提示: 虚拟核显 00:02.1 ~ 00:02.$vf_count 可直通给虚拟机"
    else
        echo -e "  ! 未检测到 SR-IOV 虚拟核显"
    fi
    echo

    # 检查 GVT-g
    echo "4. 检查 GVT-g mdev 类型..."
    if [ -d "/sys/bus/pci/devices/0000:00:02.0/mdev_supported_types" ]; then
        mdev_types=$(ls /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types 2>/dev/null | wc -l)
        if [ "$mdev_types" -gt 0 ]; then
            echo -e "  ✓ GVT-g 已启用，可用 Mdev 类型: $mdev_types 个"
            echo
            ls -1 /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types
        else
            echo -e "  ! GVT-g 未正确配置"
        fi
    else
        echo -e "  ! 未检测到 GVT-g 支持"
        echo "  提示: 此 CPU 可能不支持 GVT-g 或未配置"
    fi
    echo

    # 检查 kvmgt 模块（GVT-g 需要）
    echo "5. 检查 kvmgt 模块（GVT-g）..."
    if lsmod | grep -q kvmgt; then
        echo -e "  ✓ kvmgt 模块已加载（GVT-g 模式）"
    else
        echo "  kvmgt 模块未加载（SR-IOV 模式或未配置 GVT-g）"
    fi
    echo

    # 检查 i915 驱动参数
    echo "6. 检查 i915 驱动参数..."
    if [ -f "/sys/module/i915/parameters/enable_guc" ]; then
        guc_value=$(cat /sys/module/i915/parameters/enable_guc)
        if [ "$guc_value" = "3" ]; then
            echo -e "  ✓ i915.enable_guc = 3 (SR-IOV 模式)"
        else
            echo "  i915.enable_guc = $guc_value"
        fi
    fi

    if [ -f "/sys/module/i915/parameters/enable_gvt" ]; then
        gvt_value=$(cat /sys/module/i915/parameters/enable_gvt)
        if [ "$gvt_value" = "Y" ]; then
            echo -e "  ✓ i915.enable_gvt = Y (GVT-g 模式)"
        else
            echo "  i915.enable_gvt = $gvt_value"
        fi
    fi
    echo

    # 检查 CCS0 兼容参数（i915-sriov-dkms 2026.09.16 起为可选参数）
    echo "7. 检查 CCS0 兼容参数（Xe_LP 平台）..."
    if [ -f "/sys/module/i915/parameters/xelp_enable_ccs" ]; then
        ccs0_value=$(cat /sys/module/i915/parameters/xelp_enable_ccs 2>/dev/null)
        if [ "$ccs0_value" = "Y" ] || [ "$ccs0_value" = "1" ]; then
            echo -e "  ✓ i915.xelp_enable_ccs = $ccs0_value (CCS0 兼容模式已启用)"
        else
            echo "  i915.xelp_enable_ccs = $ccs0_value (CCS0 兼容模式未启用)"
            echo "  提示: 若 Windows 虚拟机无法加载核显驱动，可在 SR-IOV 配置中选择启用 CCS0 后重启"
        fi
    else
        echo "  ! 当前 i915 模块未提供 xelp_enable_ccs 参数（驱动版本早于 2026.09.16 时属正常）"
    fi
    echo

    # 总结
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  检查完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 移除核显虚拟化配置
igpu_remove() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e " 警告 - 移除核显虚拟化配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo -e "  此操作将："
    echo "  • 恢复 GRUB 配置为默认值"
    echo "  • 清理 /etc/modules 中的 VFIO 和 kvmgt 模块"
    echo "  • 删除 /etc/sysfs.conf 中的 VFs 配置"
    echo "  • 清理本工具写入的 i915 相关驱动黑名单（如有）"
    echo "  • 卸载 i915-sriov-dkms 驱动（如已安装）"
    echo
    echo -e "  注意：此操作不会自动重启系统"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ! confirm_action "确认移除核显虚拟化配置"; then
        echo "用户取消操作"
        return 0
    fi

    # 恢复 GRUB 配置
    echo "恢复 GRUB 配置..."

    grub_remove_param "intel_iommu"
    grub_remove_param "iommu"
    grub_remove_param "i915.enable_guc"
    grub_remove_param "i915.max_vfs"
    grub_remove_param "module_blacklist=xe"
    grub_remove_param "i915.enable_gvt"
    grub_remove_param "pcie_acs_override"
    # 移除 SR-IOV 专用的 CCS0 兼容参数（仅移除本工具写入的，保留用户自行添加的同名参数）
    sriov_remove_ccs_param_if_owned

    update-grub
    echo -e "  ✓ GRUB 配置已恢复"

    # 清理 /etc/modules（先移除 marker 配置块，再清理旧版本裸行）
    echo "清理内核模块配置..."
    backup_file "/etc/modules"

    remove_block "/etc/modules" "INTEL_SRIOV_MODULES"
    remove_block "/etc/modules" "INTEL_GVTG_MODULES"
    sed -i '/^vfio$/d; /^vfio_iommu_type1$/d; /^vfio_pci$/d; /^vfio_virqfd$/d; /^kvmgt$/d' /etc/modules
    echo -e "  ✓ 内核模块配置已清理"

    # 清理 /etc/sysfs.conf
    if [ -f "/etc/sysfs.conf" ]; then
        echo "清理 sysfs 配置..."
        backup_file "/etc/sysfs.conf"
        sed -i '/sriov_numvfs/d' /etc/sysfs.conf
        echo -e "  ✓ sysfs 配置已清理"
    fi

    # 清理本工具写入的 i915 相关驱动黑名单（如有），避免恢复后核显仍被屏蔽
    for f in /etc/modprobe.d/blacklist.conf /etc/modprobe.d/pve-blacklist.conf; do
        if [ -f "$f" ]; then
            remove_block "$f" "HARDWARE_PASSTHROUGH"
            remove_block "$f" "INTEL_LEGACY_BLACKLIST"
        fi
    done

    # 卸载 i915-sriov-dkms
    echo "检查 i915-sriov-dkms 驱动..."
    if dpkg -l | grep -q i915-sriov-dkms; then
        echo "卸载 i915-sriov-dkms 驱动..."
        dpkg -P i915-sriov-dkms || echo -e "${YELLOW}警告: 卸载驱动失败，可能需要手动处理${NC}"
        echo -e "✓ 驱动已卸载"
    else
        echo "未安装 i915-sriov-dkms 驱动，跳过"
    fi

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ 核显虚拟化配置已移除"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "提示: 请重启系统使更改生效"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo "请记得手动重启系统"
    fi
}

# GRUB 备份（输入备注后调用 backup_grub_with_note）
igpu_grub_backup_prompt() {
    local backup_note=""
    prompt_value backup_note "请输入备份备注（例如：手动备份_测试）" "手动备份" || return 0
    backup_grub_with_note "$backup_note"
}

# 核显高级功能菜单
igpu_management_menu() {
    run_menu "核显虚拟化高级功能" igpu_management_menu_render igpu_management_menu_dispatch "0-8"
}

igpu_management_menu_render() {
    echo -e "  ${RED}【危险警告】${NC} 核显虚拟化属于高危操作"
    echo -e "  配置错误可能导致系统无法启动，请务必提前备份 GRUB 配置"
    echo "${UI_DIVIDER}"
    show_menu_option "1" "Intel 11-15代 SR-IOV 核显虚拟化"
    echo -e "     ${CYAN}支持:${NC} Rocket Lake, Alder Lake, Raptor Lake"
    echo -e "     ${CYAN}特性:${NC} 最多 7 个虚拟核显，性能较好"
    show_menu_option "2" "Intel 6-10代 GVT-g 核显虚拟化"
    echo -e "     ${CYAN}支持:${NC} Skylake ~ Comet Lake"
    echo -e "     ${CYAN}特性:${NC} 最多 2-8 个虚拟核显（取决于型号）"
    show_menu_option "3" "验证核显虚拟化状态"
    echo -e "     ${CYAN}检查:${NC} IOMMU、VFIO、SR-IOV/GVT-g 配置"
    show_menu_option "4" "移除核显虚拟化配置"
    echo -e "     ${CYAN}恢复:${NC} 默认配置，移除所有核显虚拟化设置"
    echo "${UI_DIVIDER}"
    show_menu_option "" "GRUB 配置管理（强烈推荐使用）"
    echo "${UI_DIVIDER}"
    show_menu_option "5" "查看当前 GRUB 配置"
    echo -e "     ${CYAN}展示:${NC} 当前的 GRUB 引导参数和关键配置"
    show_menu_option "6" "备份 GRUB 配置"
    echo -e "     ${CYAN}路径:${NC} /etc/pvetools9/backup/grub/"
    show_menu_option "7" "查看 GRUB 备份列表"
    show_menu_option "8" "恢复 GRUB 配置"
}

igpu_management_menu_dispatch() {
    case "$1" in
        1) igpu_sriov_setup ;;
        2) igpu_gvtg_setup ;;
        3) igpu_verify ;;
        4) igpu_remove ;;
        5) show_grub_config ;;
        6) igpu_grub_backup_prompt ;;
        7) list_grub_backups ;;
        8) restore_grub_backup ;;
        *) return 1 ;;
    esac
    return 0
}
#--------------核显虚拟化管理----------------

#---------PVE8/9添加ceph-squid源-----------
