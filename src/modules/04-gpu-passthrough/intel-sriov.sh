#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

igpu_sriov_setup() {
    echo -e "${H2}开始配置 Intel 11-15代 SR-IOV 核显虚拟化${NC}"
    echo -e "详细原理与教程： ${CYAN}https://pve.oowo.cc/advanced/gpu-virtualization${NC}"
    echo -e "如果配置失败，请访问文档站下方留言反馈。"
    echo

    # 检查内核版本
    kernel_version=$(uname -r | awk -F'-' '{print $1}')
    kernel_major=$(echo $kernel_version | cut -d'.' -f1)
    kernel_minor=$(echo $kernel_version | cut -d'.' -f2)

    if [ "$kernel_major" -lt 6 ] || ([ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -lt 8 ]); then
        echo -e "${RED}SR-IOV 需要内核版本 6.8 或更高${NC}"
        echo -e "  ${YELLOW}提示:${NC} 当前内核版本: $(uname -r)"
        echo -e "  ${YELLOW}提示:${NC} 请先使用内核管理功能升级到 6.8 内核"
        pause_function
        return 1
    fi

    echo -e "${GREEN}✓ 内核版本检查通过: $(uname -r)${NC}"

    # 展示当前 GRUB 配置
    echo
    show_grub_config
    echo

    # 危险性警告
    echo "$UI_BORDER"
    echo -e "  ${RED}【高危操作警告】${NC} SR-IOV 核显虚拟化配置"
    echo "$UI_BORDER"
    echo -e "  此操作属于${RED}【高危险性】${NC}系统配置，配置错误可能导致："
    echo -e "    - ${YELLOW}系统无法正常启动${NC}（GRUB 配置错误）"
    echo -e "    - ${YELLOW}核显完全不可用${NC}（参数配置错误）"
    echo -e "    - ${YELLOW}虚拟机黑屏或无法启动${NC}（直通配置错误）"
    echo -e "    - ${YELLOW}需要通过恢复模式修复系统${NC}"
    echo "$UI_BORDER"
    echo -e "  此功能将修改以下系统配置："
    echo -e "    1. 修改 ${CYAN}GRUB 引导参数${NC}（启用 IOMMU 和 SR-IOV）"
    echo -e "    2. 加载 ${CYAN}VFIO${NC} 内核模块"
    echo -e "    3. 下载并安装 ${CYAN}i915-sriov-dkms${NC} 驱动（约 10MB）"
    echo -e "    4. 配置虚拟核显数量（VFs）"
    echo
    echo -e "  ${GREEN}前置要求（请确认已完成）：${NC}"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}VT-d${NC} 虚拟化"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}SR-IOV${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}Above 4GB${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已关闭 ${CYAN}Secure Boot${NC} 安全启动"
    echo -e "    ${GREEN}✓${NC} CPU 为 ${CYAN}Intel 11-15 代${NC} 处理器"
    echo -e "  ${RED}重要：${NC}物理核显 (00:02.0) 不能直通，否则所有虚拟核显将消失"
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
        echo "请输入备份备注（例如：SR-IOV配置前备份）："
        read -p "> " backup_note
        backup_note=${backup_note:-"SR-IOV配置前备份"}
        backup_grub_with_note "$backup_note"
        echo
    fi

    if ! confirm_action "确认继续配置 SR-IOV 核显虚拟化"; then
        echo "用户取消操作"
        return 0
    fi

    # 安装必要的软件包
    echo "安装必要的软件包..."
    apt-get update

    echo "安装 pve-headers..."
    apt-get install -y "pve-headers-$(uname -r)" || {
        echo -e "${RED}安装 pve-headers 失败${NC}"
        pause_function
        return 1
    }

    echo "安装构建工具..."
    apt-get install -y build-essential dkms sysfsutils || {
        echo -e "安装构建工具失败"
        pause_function
        return 1
    }

    echo -e "✓ 软件包安装完成"

    # 备份并修改 GRUB 配置
    echo "配置 GRUB 引导参数..."
    backup_file "/etc/default/grub"

    # 使用幂等的 GRUB 参数管理函数
    echo "配置 GRUB 参数..."

    # 移除旧的 GVT-g 配置（如果有）
    grub_remove_param "i915.enable_gvt"
    grub_remove_param "pcie_acs_override"

    # 添加 SR-IOV 参数（幂等操作，不会重复添加）
    # 针对 6.8+ 内核，必须屏蔽 xe 驱动以防止冲突
    # 参考: https://github.com/strongtz/i915-sriov-dkms
    grub_add_param "intel_iommu=on"
    grub_add_param "iommu=pt"
    grub_add_param "i915.enable_guc=3"
    grub_add_param "i915.max_vfs=7"
    grub_add_param "module_blacklist=xe"

    echo -e "✓ GRUB 配置已更新 (已添加 module_blacklist=xe 以兼容 PVE 9.1)"

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

    # 清理可能存在的 i915 及音视频相关黑名单 (SR-IOV 需要 i915 驱动加载)
    echo "清理可能存在的 i915 及音视频相关黑名单..."
    for f in /etc/modprobe.d/blacklist.conf /etc/modprobe.d/pve-blacklist.conf; do
        if [ -f "$f" ]; then
            sed -i '/blacklist i915/d' "$f"
            sed -i '/blacklist snd_hda_intel/d' "$f"
            sed -i '/blacklist snd_hda_codec_hdmi/d' "$f"
        fi
    done

    # 添加 VFIO 模块（如果未添加）
    for module in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
        if ! grep -q "^$module$" /etc/modules; then
            echo "$module" >> /etc/modules
            echo "已添加模块: $module"
        fi
    done

    # 移除 kvmgt 模块（如果有 GVT-g 配置）
    sed -i '/^kvmgt$/d' /etc/modules

    echo -e "✓ 内核模块配置完成"

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all || {
        echo -e "更新 initramfs 失败，但可以继续"
    }

    # 下载并安装 i915-sriov-dkms 驱动
    echo "下载 i915-sriov-dkms 驱动..."
    echo "  提示: 请在浏览器访问 https://github.com/strongtz/i915-sriov-dkms/releases 选择匹配的版本"
    echo "  一般建议选择最新的 release 版本以兼容最新的内核版本"
    echo "  输入格式：例如：2025.11.10"
    echo "  不输入回车的默认版本为 2025.11.10，可能不兼容老版本内核，故障表现在无法虚拟出 VFs" 

    default_dkms_version="2025.11.10"
    read -p "请输入要安装的 release 版本号 [默认: ${default_dkms_version}]: " dkms_version_input
    dkms_version_input=$(echo "$dkms_version_input" | xargs)

    if [ -z "$dkms_version_input" ]; then
        dkms_version_input="$default_dkms_version"
    fi

    # release 标签可能以 v 打头，但 deb 文件名不包含 v
    dkms_asset_version=$(echo "$dkms_version_input" | sed 's/^[vV]//')
    dkms_tag="$dkms_version_input"

    dkms_url="https://github.com/strongtz/i915-sriov-dkms/releases/download/${dkms_tag}/i915-sriov-dkms_${dkms_asset_version}_amd64.deb"
    dkms_file="/tmp/i915-sriov-dkms_${dkms_asset_version}_amd64.deb"

    # 检查是否已下载
    if [ -f "$dkms_file" ]; then
        echo "驱动文件已存在，跳过下载"
    else
        echo "从 GitHub 下载驱动..."
        echo "  提示: 如果下载失败，请检查网络或手动下载后放到 /tmp/ 目录"

        wget -O "$dkms_file" "$dkms_url" || {
            echo -e "下载驱动失败"
            echo "  提示: 请手动下载: $dkms_url"
            echo "  提示: 并上传到 PVE 的 /tmp/ 目录后重试"
            pause_function
            return 1
        }
    fi

    echo "安装 i915-sriov-dkms 驱动..."
    echo -e "驱动安装可能需要较长时间，请耐心等待..."

    dpkg -i "$dkms_file" || {
        echo -e "安装驱动失败"
        pause_function
        return 1
    }

    # 验证驱动安装
    echo "验证驱动安装..."
    if modinfo i915 2>/dev/null | grep -q "max_vfs"; then
        echo -e "✓ i915-sriov 驱动安装成功"
    else
        echo -e "驱动验证失败，请检查安装过程"
        pause_function
        return 1
    fi

    # 配置 VFs 数量
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "配置虚拟核显（VFs）数量"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "虚拟核显数量范围: 1-7"
    echo "推荐配置："
    echo "  - 1 个 VF: 性能最强，适合单个高性能虚拟机"
    echo "  - 2-3 个 VF: 平衡性能，适合多个虚拟机"
    echo "  - 4-7 个 VF: 最多虚拟机数量，性能较弱"
    echo
    read -p "请输入 VFs 数量 [1-7, 默认: 3]: " vfs_num

    # 验证输入
    if [[ -z "$vfs_num" ]]; then
        vfs_num=3
    elif ! [[ "$vfs_num" =~ ^[1-7]$ ]]; then
        echo -e "无效的 VFs 数量，必须是 1-7"
        pause_function
        return 1
    fi

    echo "配置 $vfs_num 个虚拟核显"

    # 写入 sysfs.conf
    echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = $vfs_num" > /etc/sysfs.conf
    echo -e "✓ VFs 数量配置完成"

    # 完成提示
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ SR-IOV 核显虚拟化配置完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "配置摘要："
    echo "  • 内核参数: intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7"
    echo "  • VFIO 模块: 已加载"
    echo "  • i915-sriov 驱动: 已安装"
    echo "  • 虚拟核显数量: $vfs_num 个"
    echo
    echo -e "下一步操作："
    echo -e "  1. 重启系统使配置生效"
    echo "  2. 重启后使用 '验证核显虚拟化状态' 检查配置"
    echo "  3. 在虚拟机配置中添加核显 SR-IOV 设备"
    echo
    echo -e "重要提示："
    echo -e "  • 物理核显 (00:02.0) 不能直通给虚拟机"
    echo -e "  • 只能直通虚拟核显 (00:02.1 ~ 00:02.$vfs_num)"
    echo -e "  • 虚拟机需要勾选 ROM-Bar 和 PCIE 选项"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo -e "请记得手动重启系统以使配置生效"
    fi
}

# Intel 6-10代 GVT-g 核显虚拟化配置
