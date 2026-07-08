#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

amd_list_gpus() {
    lspci -Dnn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' | grep -iE 'AMD|ATI' | awk '{print $1 "|" $0}'
}
amd_select_gpu_bdf() {
    local title="${1:-可用 AMD GPU 列表：}"
    local prompt_label="${2:-请选择 AMD GPU 序号}"
    local gpus
    gpus="$(amd_list_gpus)"
    if [[ -z "$gpus" ]]; then
        log_error "未检测到 AMD GPU"
        log_tips "请先确认 AMD 显卡已安装，并执行 lspci -Dnn 可见。"
        return 1
    fi

    local cols max_line
    cols="$(nvidia_get_cols)"
    max_line=$((cols-6))
    if [[ "$max_line" -lt 40 ]]; then
        max_line=40
    fi

    {
        echo -e "${CYAN}${title}${NC}"
        echo "$gpus" | awk -F'|' -v w="$max_line" '{
            line=$2;
            if (length(line)>w) line=substr(line,1,w-3)"...";
            printf "  [%d] %s\n", NR, line
        }'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "${prompt_label} (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$gpus" | awk -v n="$pick" -F'|' 'NR==n{print $0}')"
    bdf="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$bdf" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$bdf"
    return 0
}
amd_try_write_vfio_ids_conf() {
    local ids_csv="$1"
    local file="/etc/modprobe.d/pve-tools-amd-vfio.conf"

    local other
    other="$(grep -RhsE '^\s*options\s+vfio-pci\s+ids=' /etc/modprobe.d 2>/dev/null | grep -vF 'pve-tools-amd-vfio.conf' || true)"
    if [[ -n "$other" ]]; then
        display_error "检测到系统已存在 vfio-pci ids 配置" "为避免冲突，本功能不会自动写入。请手工合并 vfio-pci ids 后再 update-initramfs -u。"
        return 1
    fi

    if ! confirm_action "写入 AMD 的 VFIO 绑定配置（$file）并要求重启宿主机？"; then
        return 0
    fi

    local content
    content="options vfio-pci ids=${ids_csv}"
    apply_block "$file" "AMD_VFIO_IDS" "$content"
    display_success "AMD 的 VFIO 绑定配置已写入" "请执行 update-initramfs -u 并重启宿主机后再进行直通。"
    return 0
}
amd_host_prepare_for_passthrough() {
    echo -e "${YELLOW}将执行以下操作：${NC}"
    echo "  1) 写入 GRUB IOMMU 参数"
    echo "  2) 写入 /etc/modules 的 VFIO 模块配置块"
    echo "  3) 写入 AMD 显卡黑名单配置 (amdgpu / radeon)"
    echo "  4) 执行 update-grub 与 update-initramfs"
    echo
    echo -e "${RED}重要提醒：如果宿主机当前依赖 AMD 核显或 AMD 独显输出，本地控制台画面可能在重启后消失。${NC}"
    echo -e "${YELLOW}如遇 Windows Code 43 或黑屏，请优先检查 BIOS 中的 Resizable BAR / Smart Access Memory 是否已关闭。${NC}"
    if lsmod 2>/dev/null | grep -Eq '^(amdgpu|radeon)\b'; then
        echo -e "${YELLOW}检测到 amdgpu / radeon 当前已加载，说明宿主机很可能正在占用 AMD 显卡。${NC}"
    fi
    echo

    if ! confirm_high_risk_action "为 AMD GPU 直通写入宿主机预配置" "会修改 GRUB、VFIO 模块和 AMD 显卡黑名单配置。" "错误配置可能导致宿主机本地输出消失、GPU 无法用于宿主机图形界面，甚至在重启后需要控制台修复。" "请确认已准备带外管理或物理控制台，并已理解回滚方式。" "AMD-HOST"; then
        return 0
    fi

    local cpu_vendor
    cpu_vendor="$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')"

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        grub_add_param "intel_iommu=on"
    elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
        grub_add_param "amd_iommu=on"
    else
        log_warn "未识别 CPU 厂商，跳过厂商特定 IOMMU 参数"
    fi
    grub_add_param "iommu=pt"
    grub_add_param "pcie_acs_override=downstream,multifunction"

    local modules_content
    modules_content=$(cat <<'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
)
    apply_block "/etc/modules" "AMD_VFIO_MODULES" "$modules_content"

    local blacklist_content
    blacklist_content=$(cat <<'EOF'
blacklist amdgpu
blacklist radeon
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF
)
    apply_block "/etc/modprobe.d/pve-tools-amd-blacklist.conf" "AMD_GPU_BLACKLIST" "$blacklist_content"

    if command -v update-grub >/dev/null 2>&1; then
        update-grub || log_warn "update-grub 执行失败，请手工检查"
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || log_warn "grub-mkconfig 执行失败，请手工检查"
    else
        log_warn "未找到 update-grub/grub-mkconfig，请手工更新 GRUB"
    fi

    update-initramfs -u -k all || log_warn "update-initramfs 执行失败，请手工检查"
    display_success "AMD 宿主机预配置已完成" "建议重启宿主机后再执行 AMD 显卡或核显直通。"

    if confirm_action "是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}
amd_gpu_passthrough_vm() {
    log_step "AMD 独显直通虚拟机"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local vmid
    vmid="$(nvidia_select_vmid)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local gpu_bdf
    gpu_bdf="$(amd_select_gpu_bdf '可用 AMD 独显 / GPU 列表：' '请选择 AMD 独显序号')"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$gpu_bdf" ]]; then
        return 1
    fi

    clear
    show_menu_header "AMD 独显直通虚拟机"
    echo -e "${YELLOW}VMID: ${NC}$vmid"
    echo -e "${YELLOW}GPU: ${NC}$gpu_bdf"
    echo -e "${UI_DIVIDER}"
    nvidia_show_passthrough_status "$gpu_bdf"

    local audio_bdf=""
    if nvidia_pci_has_function "$gpu_bdf" "1"; then
        audio_bdf="${gpu_bdf%.*}.1"
        echo -e "${UI_DIVIDER}"
        nvidia_show_passthrough_status "$audio_bdf"
    fi

    local gpu_id audio_id ids_csv
    gpu_id="$(nvidia_get_pci_ids "$gpu_bdf")"
    audio_id=""
    if [[ -n "$audio_bdf" ]]; then
        audio_id="$(nvidia_get_pci_ids "$audio_bdf")"
    fi
    ids_csv="$gpu_id"
    if [[ -n "$audio_id" ]]; then
        ids_csv="${ids_csv},${audio_id}"
    fi

    echo -e "${UI_DIVIDER}"
    if [[ -n "$ids_csv" ]]; then
        echo -e "${CYAN}VFIO ids 建议: ${NC}$ids_csv"
    fi
    echo -e "${YELLOW}提示：若宿主机仍在使用 amdgpu / radeon，直通可能失败。${NC}"
    echo -e "${YELLOW}如 Windows 来宾报 Code 43，请优先检查 BIOS 的 Resizable BAR / Smart Access Memory。${NC}"
    echo -e "${UI_DIVIDER}"

    local include_audio="no"
    if [[ -n "$audio_bdf" ]]; then
        read -p "是否同时直通显卡音频功能（${audio_bdf}）？(yes/no) [yes]: " include_audio
        include_audio="${include_audio:-yes}"
    fi

    local enable_x_vga="yes"
    read -p "是否为 AMD 显卡启用 x-vga=1（Windows 常见）？(yes/no) [yes]: " enable_x_vga
    enable_x_vga="${enable_x_vga:-yes}"

    if qm_has_hostpci_bdf "$vmid" "$gpu_bdf"; then
        display_error "该 AMD GPU 已存在于 VM 的 hostpci 配置中" "无需重复添加。"
        return 1
    fi

    local idx0
    idx0="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15。"
        return 1
    }

    local hostpci0_value="$gpu_bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci0_value="${hostpci0_value},pcie=1"
    fi
    if [[ "$enable_x_vga" == "yes" || "$enable_x_vga" == "YES" ]]; then
        hostpci0_value="${hostpci0_value},x-vga=1"
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 添加 AMD 独显直通（hostpci${idx0} = ${hostpci0_value}）"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx0}" "$hostpci0_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 VM 是否锁定、IOMMU / IOMMU group，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$include_audio" == "yes" || "$include_audio" == "YES" ]] && [[ -n "$audio_bdf" ]]; then
        local idx1
        idx1="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
            display_error "显卡已添加，但未找到可用 hostpci 插槽添加音频功能" "请手工添加 $audio_bdf。"
            return 1
        }

        local hostpci1_value="$audio_bdf"
        if qm_is_q35_machine "$vmid"; then
            hostpci1_value="${hostpci1_value},pcie=1"
        fi

        if ! qm set "$vmid" "-hostpci${idx1}" "$hostpci1_value" >/dev/null 2>&1; then
            log_warn "音频功能直通写入失败（GPU 已写入）"
        else
            log_success "音频功能已写入: hostpci${idx1} = $hostpci1_value"
        fi
    fi

    if [[ -n "$ids_csv" ]]; then
        local set_vfio="no"
        read -p "是否写入 AMD 的 VFIO ids 绑定配置（用于将设备绑定到 vfio-pci）（yes/no）[no]: " set_vfio
        set_vfio="${set_vfio:-no}"
        if [[ "$set_vfio" == "yes" || "$set_vfio" == "YES" ]]; then
            amd_try_write_vfio_ids_conf "$ids_csv" || true
        fi
    fi

    display_success "AMD 独显直通已写入" "如 VM 正在运行中，请重启 VM；如写入了 VFIO 配置，请按提示重启宿主机。"
    return 0
}
amd_gpu_management_menu() {
    while true; do
        clear
        show_menu_header "AMD 独显直通"
        echo -e "${CYAN}提示：如宿主机仍在使用 amdgpu / radeon，占用中的 AMD 独显通常无法直接直通。${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "AMD 显卡直通虚拟机"
        show_menu_option "2" "AMD 宿主机预配置 ( IOMMU / VFIO / 黑名单 )"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) amd_gpu_passthrough_vm ;;
            2) amd_host_prepare_for_passthrough ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
