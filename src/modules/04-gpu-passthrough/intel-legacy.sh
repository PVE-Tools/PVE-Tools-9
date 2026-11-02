#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

restore_qemu_kvm() {
    log_step "开始恢复官方 pve-qemu-kvm"
    echo "此操作将执行以下步骤："
    echo "1. 解除 pve-qemu-kvm 的版本锁定 (unhold)"
    echo "2. 强制重新安装官方版本的 pve-qemu-kvm"
    echo "3. 恢复官方的 initramfs 设置"
    echo "适用于因安装修改版 QEMU 导致虚拟机无法启动或系统异常的情况。"
    echo

    if ! confirm_action "是否继续执行恢复操作？"; then
        return
    fi

    # 1. 解除锁定
    log_info "正在解除软件包锁定..."
    apt-mark unhold pve-qemu-kvm
    
    # 2. 强制重装官方版本
    log_info "正在重新安装官方 pve-qemu-kvm..."
    if apt-get update && apt-get install --reinstall -y pve-qemu-kvm; then
        log_success "官方 pve-qemu-kvm 恢复成功"
    else
        log_error "恢复失败，请检查网络连接或手动尝试: apt-get install --reinstall pve-qemu-kvm"
        return 1
    fi

    # 3. 清理黑名单 (可选)
    if confirm_action "是否同时清理 Intel 核显相关的驱动黑名单？"; then
        log_info "正在清理黑名单配置..."
        remove_block "/etc/modprobe.d/pve-blacklist.conf" "INTEL_LEGACY_BLACKLIST"
        sed -i '/blacklist i915/d' /etc/modprobe.d/pve-blacklist.conf
        sed -i '/blacklist snd_hda_intel/d' /etc/modprobe.d/pve-blacklist.conf
        sed -i '/blacklist snd_hda_codec_hdmi/d' /etc/modprobe.d/pve-blacklist.conf
        
        log_info "正在更新 initramfs..."
        update-initramfs -u -k all
        log_success "黑名单清理完成"
    fi

    log_success "救砖操作完成！建议重启系统。"
    if confirm_action "是否现在重启系统？"; then
        reboot
    fi
}

#英特尔核显直通
intel_gpu_passthrough() {
    log_step "开始 Intel 核显直通配置"
    echo "注意：此功能基于 AICodo 的修改版 QEMU 和 ROM"
    echo "详细原理与教程：https://pve.ciriu.com/tutorial/gpu-passthrough"
    echo "适用于需要将 Intel 核显直通给 Windows 虚拟机且遇到代码 43 或黑屏的情况"
    echo "支持的 CPU 架构：6代(Skylake) 到 14代(Raptor Lake Refresh)"
    echo "项目地址：https://github.com/AICodo/intel6-14rom"
    echo
    log_warn "警告"
    log_warn "本功能并非能100%一次成功！"
    echo 
    log_warn "由于 Intel 牙膏厂混乱的代号和半代升级策略（如 N5105 Jasper Lake 等）"
    log_warn "通用 ROM 无法保证 100% 适用于所有 CPU 型号！"
    log_warn "直通失败属于正常现象，请尝试更换其他版本的 ROM 或自行寻找专用 ROM"
    log_warn "本功能仅提供自动化配置辅助，作者精力有限，无法提供免费的一对一排错服务"
    log_warn "折腾有风险，入坑需谨慎！"
    echo
    log_tips "如果配置失败，请访问文档站查看详细教程并留言反馈："
    log_tips "🔗 https://pve.ciriu.com/tutorial/gpu-passthrough"
    echo
    log_tips "如需要反馈或者请求更新ROM文件适配你的CPU，请前往AICodo的GitHub仓库开ISSUE反馈，不是找我。"
    echo

    echo "请选择操作："
    echo "  1) 开始配置 (安装修改版 QEMU + 下载 ROM)"
    echo "  2) 救砖模式 (恢复官方 QEMU + 清理配置)"
    echo "  0) 返回上级菜单"
    read -p "请输入选择 [0-2]: " choice
    
    case $choice in
        1)
            # 继续执行配置流程
            ;;
        2)
            restore_qemu_kvm
            return
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            return
            ;;
    esac

    gpu_warn_active_stacks

    if ! confirm_high_risk_action \
        "安装第三方修改版 QEMU 并配置核显直通" \
        "将屏蔽宿主机 i915 驱动（本地控制台会黑屏），并安装来自 AICodo 仓库的非官方 pve-qemu-kvm" \
        "第三方 deb 包无官方签名校验，且会被 apt-mark hold 锁定版本、无法收到官方安全更新" \
        "请确认已有可用的 SSH/Web 管理通道；出问题可用本菜单的救砖模式恢复官方 QEMU" \
        "QEMU-MOD"; then
        return 1
    fi

    # 1. 配置黑名单（marker 配置块写入，apply_block 自动备份并幂等）
    log_step "配置驱动黑名单 (屏蔽宿主机占用核显)"
    if ! grep -q "blacklist i915" /etc/modprobe.d/pve-blacklist.conf; then
        apply_block "/etc/modprobe.d/pve-blacklist.conf" "INTEL_LEGACY_BLACKLIST" "blacklist i915
blacklist snd_hda_intel
blacklist snd_hda_codec_hdmi"
        log_success "已添加黑名单配置"
        
        log_info "正在更新 initramfs..."
        update-initramfs -u -k all
    else
        log_info "黑名单配置已存在，跳过"
    fi

    # 2. 安装修改版 QEMU
    log_step "安装修改版 pve-qemu-kvm"
    echo "正在获取最新 release 版本..."
    
    # 尝试获取最新下载链接 (这里为了稳定性暂时写死或使用最新已知的逻辑，实际可爬虫获取)
    # 根据用户提供的信息，修改版 QEMU 下载地址: https://github.com/AICodo/pve-anti-detection/releases
    # 为了简化，我们使用 ghfast.top 加速下载最新的 release
    # 注意：这里需要动态获取最新 deb 包链接，或者让用户手动输入链接
    # 为方便起见，这里演示自动获取逻辑
    
    local qemu_releases_url="https://api.github.com/repos/AICodo/pve-anti-detection/releases/latest"
    local qemu_deb_url
    qemu_deb_url=$(curl -s "$qemu_releases_url" | grep "browser_download_url.*deb" | cut -d '"' -f 4 | head -n 1)

    if [ -z "$qemu_deb_url" ]; then
        log_warn "无法自动获取修改版 QEMU 下载链接，尝试使用备用链接或手动下载"
        # 备用逻辑：提示用户手动下载
        echo "请访问 https://github.com/AICodo/pve-anti-detection/releases 下载最新 deb 包"
        echo "然后使用 dpkg -i 安装"
    else
        # 加速下载
        local fast_qemu_url="https://ghfast.top/${qemu_deb_url}"
        local qemu_deb_file qemu_deb_sha256
        qemu_deb_file="$(mktemp --suffix=.deb)"
        log_info "正在下载: $fast_qemu_url"
        if ! wget -O "$qemu_deb_file" "$fast_qemu_url"; then
            log_warn "加速源下载失败，改用 GitHub 原始地址重试..."
            if ! wget -O "$qemu_deb_file" "$qemu_deb_url"; then
                rm -f "$qemu_deb_file"
                log_error "下载失败，已中止配置（未修改 QEMU）"
                return 1
            fi
        fi

        if [[ ! -s "$qemu_deb_file" ]]; then
            rm -f "$qemu_deb_file"
            log_error "下载结果为空，已中止配置（未修改 QEMU）"
            return 1
        fi

        # 上游无官方签名可验，至少展示摘要与来源，供用户与 release 页核对及事后追溯
        qemu_deb_sha256="$(sha256sum "$qemu_deb_file" | awk '{print $1}')"
        log_info "deb 包 SHA256: ${qemu_deb_sha256}"
        log_info "下载来源: ${qemu_deb_url}"

        log_info "正在安装修改版 QEMU..."
        if dpkg -i "$qemu_deb_file"; then
            rm -f "$qemu_deb_file"
            log_success "安装完成"

            # 阻止更新
            apt-mark hold pve-qemu-kvm
            log_info "已锁定 pve-qemu-kvm 防止自动更新（救砖模式可解除）"
        else
            rm -f "$qemu_deb_file"
            log_error "安装修改版 QEMU 失败，请检查 deb 包完整性"
            return 1
        fi
    fi

    # 3. 下载 ROM 文件
    log_step "下载核显 ROM 文件"
    echo "正在检测 CPU 型号..."
    local cpu_model=$(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)
    echo "CPU 型号: $cpu_model"
    
    # 优先推荐的通用 ROM
    local recommended_rom="6-14-qemu10.rom"
    
    # 特殊 CPU 型号映射表 (根据 release 信息整理)
    # 格式: "关键字|ROM文件名"
    local special_cpus=(
        "J6412|11-J6412-q10.rom"
        "N5095|11-n5095-q10.rom"
        "1240P|12-1240p-q10.rom"
        "N100|12-n100-q10.rom"
        "J4125|j4125-q10.rom"
        "N2930|N2930-q10.rom"
        "N3350|N3350-q10.rom"
        "11700H|nb-11-11700h-q10.rom"
        "1185G7|nb-11-1185G7E-q10.rom"
        "12700H|nb-12-12700h-q10.rom"
        "13700H|nb-13-13700h-q10.rom"
    )
    
    # 检测是否为特殊 CPU
    for item in "${special_cpus[@]}"; do
        local keyword="${item%%|*}"
        local rom_name="${item##*|}"
        if echo "$cpu_model" | grep -qi "$keyword"; then
            recommended_rom="$rom_name"
            log_success "检测到特殊 CPU ($keyword)，推荐使用专用 ROM: $recommended_rom"
            break
        fi
    done

    # 下载 ROM 文件
    local rom_releases_url="https://api.github.com/repos/AICodo/intel6-14rom/releases/latest"
    log_info "正在获取 ROM 列表..."
    
    # 获取 release 信息
    # 注意：这里我们使用 grep 简单提取下载链接和文件名
    local release_info=$(curl -s $rom_releases_url)
    local assets=$(echo "$release_info" | grep "browser_download_url" | cut -d '"' -f 4)
    
    if [ -z "$assets" ]; then
         log_error "无法获取 ROM 下载链接"
         return
    fi

    # 显示 ROM 列表供用户选择
    echo "------------------------------------------------"
    echo "可用的 ROM 文件列表："
    local i=1
    local rom_list=()
    local recommended_index=0
    
    for url in $assets; do
        local fname=$(basename "$url")
        # 过滤非 .rom 文件 (如 patch)
        if [[ "$fname" != *.rom ]]; then
            continue
        fi
        
        rom_list+=("$fname|$url")
        
        if [[ "$fname" == "$recommended_rom" ]]; then
            echo -e "  $i) ${GREEN}$fname (推荐)${NC}"
            recommended_index=$i
        else
            echo "  $i) $fname"
        fi
        ((i++))
    done
    echo "------------------------------------------------"
    
    # 让用户选择
    local choice
    if [ $recommended_index -gt 0 ]; then
        read -p "请输入序号选择 ROM [默认 $recommended_index]: " choice
        choice=${choice:-$recommended_index}
    else
        read -p "请输入序号选择 ROM: " choice
    fi
    
    # 验证选择
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge $i ]; then
        log_error "无效选择"
        return
    fi
    
    # 获取选中的 ROM 信息
    local selected_item="${rom_list[$((choice-1))]}"
    local selected_fname="${selected_item%%|*}"
    local selected_url="${selected_item##*|}"
    
    # 下载选中的 ROM
    local fast_url="https://ghfast.top/${selected_url}"
    log_info "正在下载: $selected_fname"
    wget -O "/usr/share/kvm/$selected_fname" "$fast_url"
    
    if [ ! -s "/usr/share/kvm/$selected_fname" ]; then
        log_error "下载失败"
        return
    fi
    log_success "ROM 文件已就绪: $selected_fname"
    local rom_filename="$selected_fname"

    # 4. 自动配置虚拟机
    log_step "配置虚拟机参数"
    
    # 获取 VMID
    echo "请选择要配置直通的虚拟机 ID (VMID):"
    ls /etc/pve/qemu-server/*.conf | awk -F/ '{print $NF}' | sed 's/.conf//' | xargs -n1 echo "  -"
    read -p "请输入 VMID: " vmid
    
    if [ -z "$vmid" ] || [ ! -f "/etc/pve/qemu-server/$vmid.conf" ]; then
        log_error "无效的 VMID 或配置文件不存在"
        return
    fi
    
    # 获取核显 PCI ID
    echo "正在查找 Intel 核显设备..."
    local igpu_pci=$(lspci -D | grep -i "VGA compatible controller" | grep -i "Intel" | head -n1 | awk '{print $1}')
    
    if [ -z "$igpu_pci" ]; then
        log_error "未找到 Intel 核显设备"
        return
    fi
    echo "找到核显设备: $igpu_pci"
    
    # 获取声卡 PCI ID (通常和核显在一起，但也可能分开)
    local audio_pci=$(lspci -D | grep -i "Audio device" | grep -i "Intel" | head -n1 | awk '{print $1}')
    if [ -n "$audio_pci" ]; then
        echo "找到声卡设备: $audio_pci"
    else
        log_warn "未找到配套声卡设备，将只直通核显"
    fi

    if ! confirm_action "即将修改虚拟机 $vmid 的配置，是否继续？"; then
        return
    fi
    
    # 备份配置文件
    backup_file "/etc/pve/qemu-server/$vmid.conf"
    
    # 修改 args
    local args_line="-set device.hostpci0.bus=pcie.0 -set device.hostpci0.addr=0x02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on -set device.hostpci0.x-igd-lpc=on"
    
    # 如果有声卡，添加 hostpci1 的 args 配置
    if [ -n "$audio_pci" ]; then
        args_line="$args_line -set device.hostpci1.bus=pcie.0 -set device.hostpci1.addr=0x03.0"
    fi
    
    # 通过 qm set 写入：直接追加/就地 sed 会绕过 pmxcfs 加锁，
    # 且在带快照的 conf 上会把配置行写进快照段导致配置损坏
    if grep -q '^args:' "/etc/pve/qemu-server/$vmid.conf"; then
        log_warn "检测到 VM $vmid 已有 args 配置，将被新 args 覆盖"
        log_warn "原 args 内容: $(grep '^args:' "/etc/pve/qemu-server/$vmid.conf")"
    fi
    if ! qm set "$vmid" --args "$args_line"; then
        log_error "写入 args 失败，虚拟机配置未完成"
        return 1
    fi

    # 写入 hostpci0 (核显)，格式: 0000:00:02.0,romfile=xxx.rom
    if ! qm set "$vmid" --hostpci0 "$igpu_pci,romfile=$rom_filename"; then
        log_error "写入 hostpci0 失败，虚拟机配置未完成"
        return 1
    fi

    # 写入 hostpci1 (声卡)
    if [ -n "$audio_pci" ]; then
        if ! qm set "$vmid" --hostpci1 "$audio_pci"; then
            log_error "写入 hostpci1 失败，请手动检查虚拟机配置"
            return 1
        fi
    fi
    
    log_success "虚拟机 $vmid 配置完成"
    echo "已添加 args 参数和 hostpci 设备"
    echo "请记得在虚拟机中安装驱动: https://downloadmirror.intel.com/854560/gfx_win_101.6793.exe"
    
    echo
    echo "注意：需要重启宿主机使黑名单生效"
    if confirm_action "是否现在重启系统？"; then
        reboot
    fi
}

# NVIDIA显卡管理菜单
