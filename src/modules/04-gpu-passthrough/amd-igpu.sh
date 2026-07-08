#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

amd_list_romfiles() {
    if [[ ! -d "$PVE_KVM_ROM_DIR" ]]; then
        return 0
    fi
    find "$PVE_KVM_ROM_DIR" -maxdepth 1 -type f \( -iname '*.rom' -o -iname '*.bin' \) 2>/dev/null | sort
}
amd_normalize_romfile_input() {
    local input="$1"
    local rom_path base

    if [[ -z "$input" ]]; then
        return 1
    fi

    if [[ "$input" == /* ]]; then
        rom_path="$input"
    else
        rom_path="${PVE_KVM_ROM_DIR}/${input}"
    fi

    case "$rom_path" in
        "${PVE_KVM_ROM_DIR}/"*) ;;
        *)
            log_error "ROM 文件路径必须位于 ${PVE_KVM_ROM_DIR}"
            echo -e "${YELLOW}提示: 请先把用户自备的 AMD ROM / vBIOS 文件放入 ${PVE_KVM_ROM_DIR} 后再试。${NC}" >&2
            return 1
            ;;
    esac

    if [[ ! -f "$rom_path" ]]; then
        log_error "未找到 ROM 文件: $rom_path"
        echo -e "${YELLOW}提示: 请确认文件已放入 ${PVE_KVM_ROM_DIR}，并由用户自行提取、确认来源与兼容性。${NC}" >&2
        return 1
    fi

    base="$(basename "$rom_path")"
    if [[ ! "$base" =~ ^[A-Za-z0-9._+-]+$ ]]; then
        log_error "ROM 文件名包含不安全字符: $base"
        echo -e "${YELLOW}提示: 请将文件重命名为简单英文/数字文件名后再试。${NC}" >&2
        return 1
    fi

    echo "$base"
    return 0
}
amd_prompt_romfile_basename() {
    local prompt="${1:-请输入 AMD ROM / vBIOS 文件路径或文件名}"
    local roms
    roms="$(amd_list_romfiles)"

    {
        echo -e "${CYAN}ROM 文件目录: ${NC}${PVE_KVM_ROM_DIR}"
        if [[ -n "$roms" ]]; then
            echo "$roms" | sed 's/^/  /'
        else
            echo "  (当前未发现 .rom / .bin 文件)"
        fi
        echo -e "${YELLOW}ROM / vBIOS 提取通常需要由用户自行完成，本脚本只负责校验并写入 romfile。${NC}"
        echo -e "${UI_DIVIDER}"
    } >&2

    local input
    read -p "${prompt} (0 返回): " input
    input="${input:-0}"
    if [[ "$input" == "0" ]]; then
        return 2
    fi

    amd_normalize_romfile_input "$input"
}
amd_igpu_show_guidance() {
    clear
    show_menu_header "AMD 核显直通说明"
    echo -e "${CYAN}使用建议：${NC}"
    echo "  1) AMD 核显直通通常比独显更依赖正确的 ROM / vBIOS 文件。"
    echo "  2) 建议 VM 使用 q35 + OVMF，并将核显作为主显示设备。"
    echo "  3) ROM / vBIOS 提取一般交给用户自行完成，脚本不提供自动提取。"
    echo "  4) 将 ROM 文件放入 ${PVE_KVM_ROM_DIR} 后，再通过本向导写入 romfile。"
    echo "  5) 如 Windows 来宾报 Code 43 / 黑屏，请优先检查 BIOS 中的 Resizable BAR / SAM。"
    echo
    echo -e "${CYAN}参考：${NC}"
    echo "  社区参考文章: https://diyforfun.cn/712.html"
    echo "  Proxmox 官方: https://pve.proxmox.com/wiki/PCI_Passthrough"
    echo
    echo -e "${RED}免责声明：ROM / vBIOS 文件的提取、来源合法性、兼容性与由此导致的黑屏、Code 43、设备不可用等后果，由用户自行承担。${NC}"
    echo "$UI_DIVIDER"
}
amd_igpu_check_romfile() {
    clear
    show_menu_header "AMD 核显 ROM / vBIOS 检查"
    local rom_base
    rom_base="$(amd_prompt_romfile_basename '请输入要校验的 AMD ROM / vBIOS 文件路径或文件名')"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$rom_base" ]]; then
        return 1
    fi
    display_success "ROM 文件校验通过" "可在 hostpci 中使用 romfile=${rom_base}。"
    return 0
}
amd_igpu_passthrough_vm() {
    log_step "AMD 核显直通配置"

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
    gpu_bdf="$(amd_select_gpu_bdf '可用 AMD GPU / 核显列表（请手工确认 APU 核显设备）:' '请选择 AMD 核显序号')"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$gpu_bdf" ]]; then
        return 1
    fi

    local rom_base
    rom_base="$(amd_prompt_romfile_basename '请输入 AMD 核显 ROM / vBIOS 文件路径或文件名')"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$rom_base" ]]; then
        return 1
    fi

    clear
    show_menu_header "AMD 核显直通配置"
    echo -e "${YELLOW}VMID: ${NC}$vmid"
    echo -e "${YELLOW}iGPU: ${NC}$gpu_bdf"
    echo -e "${YELLOW}ROM: ${NC}${PVE_KVM_ROM_DIR}/${rom_base}"
    echo -e "${UI_DIVIDER}"
    nvidia_show_passthrough_status "$gpu_bdf"

    local audio_bdf=""
    if nvidia_pci_has_function "$gpu_bdf" "1"; then
        audio_bdf="${gpu_bdf%.*}.1"
        echo -e "${UI_DIVIDER}"
        nvidia_show_passthrough_status "$audio_bdf"
    fi

    local include_audio="no"
    if [[ -n "$audio_bdf" ]]; then
        read -p "是否同时直通核显音频功能（${audio_bdf}）？(yes/no) [yes]: " include_audio
        include_audio="${include_audio:-yes}"
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
    echo -e "${YELLOW}提示：AMD 核显直通强依赖正确的 ROM / vBIOS；本脚本不会自动提取 ROM。${NC}"
    if ! qm_is_q35_machine "$vmid"; then
        echo -e "${YELLOW}警告：当前 VM 不是 q35 机型。AMD 核显直通通常更推荐 q35 + OVMF。${NC}"
    fi
    echo -e "${UI_DIVIDER}"

    if qm_has_hostpci_bdf "$vmid" "$gpu_bdf"; then
        display_error "该 AMD 核显已存在于 VM 的 hostpci 配置中" "无需重复添加。"
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
    hostpci0_value="${hostpci0_value},x-vga=1,romfile=${rom_base}"

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_high_risk_action "为 VM $vmid 写入 AMD 核显直通（hostpci${idx0} = ${hostpci0_value}）" "错误的 ROM / vBIOS、错误的 BDF 或错误的 hostpci 配置可能导致 VM 黑屏、来宾驱动报错或设备无法初始化。" "如果宿主机当前仍依赖该 AMD 核显输出，后续黑名单和 VFIO 绑定还可能导致宿主机本地画面丢失。" "请确认 ROM 文件由用户自行提取并已放入 ${PVE_KVM_ROM_DIR}，且已准备好回滚 hostpci 配置。" "AMD-iGPU"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx0}" "$hostpci0_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 VM 是否锁定、IOMMU / IOMMU group，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$include_audio" == "yes" || "$include_audio" == "YES" ]] && [[ -n "$audio_bdf" ]]; then
        local idx1
        idx1="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
            display_error "核显已添加，但未找到可用 hostpci 插槽添加音频功能" "请手工添加 $audio_bdf。"
            return 1
        }

        local hostpci1_value="$audio_bdf"
        if qm_is_q35_machine "$vmid"; then
            hostpci1_value="${hostpci1_value},pcie=1"
        fi

        if ! qm set "$vmid" "-hostpci${idx1}" "$hostpci1_value" >/dev/null 2>&1; then
            log_warn "核显音频功能直通写入失败（核显已写入）"
        else
            log_success "核显音频功能已写入: hostpci${idx1} = $hostpci1_value"
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

    display_success "AMD 核显直通已写入" "请在来宾中按需安装驱动；如写入了 VFIO 配置，请按提示重启宿主机。"
    return 0
}
amd_igpu_management_menu() {
    while true; do
        clear
        show_menu_header "AMD 核显直通"
        echo -e "${RED}注意：AMD 核显直通通常需要用户自备 ROM / vBIOS 文件，本脚本不负责提取。${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "配置 AMD 核显直通"
        show_menu_option "2" "检查 ROM / vBIOS 文件"
        show_menu_option "3" "查看 AMD 核显直通说明"
        show_menu_option "4" "AMD 宿主机预配置 ( IOMMU / VFIO / 黑名单 )"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) amd_igpu_passthrough_vm ;;
            2) amd_igpu_check_romfile ;;
            3) amd_igpu_show_guidance ;;
            4) amd_host_prepare_for_passthrough ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 主程序
