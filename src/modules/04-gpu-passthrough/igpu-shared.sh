#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

igpu_management_menu_simple() {
    while true; do
        clear
        show_menu_header "Intel 核显虚拟化管理"
        show_menu_option "1" "Intel 11-15代 SR-IOV 配置 (DKMS)"
        show_menu_option "2" "Intel 6-10代 GVT-g 配置 (传统模式)"
        show_menu_option "3" "验证核显虚拟化状态"
        show_menu_option "4" "清理核显虚拟化配置 (恢复默认)"
        show_menu_option "0" "返回主菜单"
        show_menu_footer

        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1) igpu_sriov_setup ;;
            2) igpu_gvtg_setup ;;
            3) igpu_verify ;;
            4) restore_igpu_config ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# Intel 11-15代 SR-IOV 核显虚拟化配置
restore_igpu_config() {
    log_step "开始清理核显虚拟化配置 (恢复默认)"
    echo -e "  此操作将执行以下步骤："
    echo -e "    1. 移除 ${CYAN}GRUB${NC} 中的核显相关参数"
    echo -e "    2. 从 ${CYAN}/etc/modules${NC} 移除核显相关模块"
    echo -e "    3. 更新 ${CYAN}GRUB${NC} 和 ${CYAN}initramfs${NC}"
    echo -e "  适用于因配置核显虚拟化导致系统异常或想要重置配置的情况。"
    echo

    if ! confirm_action "是否继续执行清理操作？"; then
        return
    fi

    # 1. 恢复 GRUB 配置
    log_info "正在清理 GRUB 参数..."
    if [[ -f "/etc/default/grub" ]]; then
        grub_remove_param "intel_iommu"
        grub_remove_param "iommu"
        grub_remove_param "i915.enable_gvt"
        grub_remove_param "i915.enable_guc"
        grub_remove_param "i915.max_vfs"

        log_success "GRUB 参数清理完成"
    else
        log_error "未找到 /etc/default/grub 文件"
    fi

    # 2. 恢复 /etc/modules
    log_info "正在清理 /etc/modules..."
    if [[ -f "/etc/modules" ]]; then
        backup_file "/etc/modules"
        sed -i '/vfio/d' /etc/modules
        sed -i '/vfio_iommu_type1/d' /etc/modules
        sed -i '/vfio_pci/d' /etc/modules
        sed -i '/vfio_virqfd/d' /etc/modules
        sed -i '/kvmgt/d' /etc/modules
        log_success "/etc/modules 清理完成"
    fi

    # 3. 更新系统配置
    log_info "正在更新 GRUB..."
    update-grub
    
    log_info "正在更新 initramfs..."
    update-initramfs -u -k all
    
    log_success "清理完成！核显虚拟化配置已重置。"
    if confirm_action "是否现在重启系统？"; then
        reboot
    fi
}

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

    # 总结
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  检查完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    pause_function
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

    update-grub
    echo -e "  ✓ GRUB 配置已恢复"

    # 清理 /etc/modules
    echo "清理内核模块配置..."
    backup_file "/etc/modules"

    sed -i '/^vfio$/d; /^vfio_iommu_type1$/d; /^vfio_pci$/d; /^vfio_virqfd$/d; /^kvmgt$/d' /etc/modules
    echo -e "  ✓ 内核模块配置已清理"

    # 清理 /etc/sysfs.conf
    if [ -f "/etc/sysfs.conf" ]; then
        echo "清理 sysfs 配置..."
        backup_file "/etc/sysfs.conf"
        sed -i '/sriov_numvfs/d' /etc/sysfs.conf
        echo -e "  ✓ sysfs 配置已清理"
    fi

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

# 核显高级功能菜单
igpu_management_menu() {
    while true; do
        clear
        show_menu_header "核显虚拟化高级功能"
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
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        echo
        read -p "请选择操作 [0-8]: " choice

        case $choice in
            1)
                igpu_sriov_setup
                ;;
            2)
                igpu_gvtg_setup
                ;;
            3)
                igpu_verify
                ;;
            4)
                igpu_remove
                ;;
            5)
                show_grub_config
                pause_function
                ;;
            6)
                echo
                echo "请输入备份备注（例如：手动备份_测试）："
                read -p "> " backup_note
                backup_note=${backup_note:-"手动备份"}
                backup_grub_with_note "$backup_note"
                pause_function
                ;;
            7)
                list_grub_backups
                pause_function
                ;;
            8)
                restore_grub_backup
                ;;
            0)
                echo "返回主菜单"
                return 0
                ;;
            *)
                echo -e "无效的选择，请输入 0-8"
                pause_function
                ;;
        esac
    done
}
#--------------核显虚拟化管理----------------

#---------PVE8/9添加ceph-squid源-----------
