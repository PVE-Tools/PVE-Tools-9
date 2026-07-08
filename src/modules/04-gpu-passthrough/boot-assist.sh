#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

resolve_whole_disk() {
    local input="$1"
    if [[ -z "$input" ]]; then
        return 1
    fi

    local real
    if [[ "$input" == /dev/disk/by-id/* ]]; then
        real="$(readlink -f "$input" 2>/dev/null || true)"
    else
        real="$input"
    fi

    if [[ ! -b "$real" ]]; then
        return 1
    fi

    local t
    t="$(lsblk -dn -o TYPE "$real" 2>/dev/null | head -n 1)"
    if [[ "$t" == "disk" ]]; then
        echo "$real"
        return 0
    fi

    local pk
    pk="$(lsblk -dn -o PKNAME "$real" 2>/dev/null | head -n 1)"
    if [[ -n "$pk" && -b "/dev/$pk" ]]; then
        echo "/dev/$pk"
        return 0
    fi

    return 1
}

# 识别直通磁盘上的引导类型（UEFI / Legacy / Unknown）
detect_disk_boot_mode() {
    local disk="$1"
    if [[ -z "$disk" || ! -b "$disk" ]]; then
        echo "Unknown"
        return 1
    fi

    if command -v lsblk >/dev/null 2>&1; then
        local esp_guid="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
        local parts
        parts="$(lsblk -rno NAME,PARTTYPE,FSTYPE "$disk" 2>/dev/null | awk 'NF>=2{print}')"
        if echo "$parts" | grep -qi "$esp_guid"; then
            echo "UEFI"
            return 0
        fi
        if echo "$parts" | awk '{print $3}' | grep -qi '^vfat$'; then
            if echo "$parts" | grep -Eqi 'EFI|esp'; then
                echo "UEFI"
                return 0
            fi
        fi
    fi

    if command -v parted >/dev/null 2>&1; then
        local out
        out="$(parted -s "$disk" print 2>/dev/null || true)"
        if echo "$out" | grep -Eqi 'Partition Table:\s*gpt'; then
            if echo "$out" | grep -Eqi '\besp\b|EFI System|boot, esp'; then
                echo "UEFI"
                return 0
            fi
            echo "Unknown"
            return 0
        fi
        if echo "$out" | grep -Eqi 'Partition Table:\s*msdos'; then
            echo "Legacy"
            return 0
        fi
    fi

    echo "Unknown"
    return 0
}

# 根据磁盘引导类型与直通方式给出 VM 配置建议（仅提示，不修改配置）
boot_config_assistant() {
    log_step "引导配置辅助"

    local disk_input
    read -p "请输入直通磁盘路径（/dev/disk/by-id/... 或 /dev/sdX /dev/nvme0n1）（返回请输入 0）: " disk_input
    disk_input="${disk_input:-0}"
    if [[ "$disk_input" == "0" ]]; then
        return 0
    fi

    local disk
    disk="$(resolve_whole_disk "$disk_input" 2>/dev/null || true)"
    if [[ -z "$disk" ]]; then
        display_error "磁盘路径无效或不可访问: $disk_input" "请确认输入为块设备或 by-id 路径，并在宿主机上存在。"
        return 1
    fi

    local boot_mode
    boot_mode="$(detect_disk_boot_mode "$disk")"

    echo -e "${CYAN}检测结果：${NC}"
    echo "  磁盘: $disk"
    echo "  引导类型: $boot_mode"
    echo -e "${UI_DIVIDER}"

    echo -e "${CYAN}直通方式选择（用于生成更贴近场景的建议）：${NC}"
    echo "  1) 单个磁盘直通（RDM）"
    echo "  2) 整控制器直通（SATA/SCSI/RAID）"
    echo "  3) NVMe 控制器直通"
    local mode
    read -p "请选择直通方式 [1-3] [1]: " mode
    mode="${mode:-1}"
    if [[ "$mode" != "1" && "$mode" != "2" && "$mode" != "3" ]]; then
        display_error "无效选择: $mode" "请输入 1/2/3"
        return 1
    fi

    local slot=""
    if [[ "$mode" == "1" ]]; then
        read -p "如果已知 VM 插槽（如 scsi0/sata1/ide0）可输入用于 boot order（回车跳过）: " slot
        if [[ -n "$slot" && ! "$slot" =~ ^(scsi|sata|ide)[0-9]+$ ]]; then
            display_error "插槽格式不合法: $slot" "示例：scsi0 / sata0 / ide0"
            return 1
        fi
    fi

    echo -e "${UI_DIVIDER}"
    echo -e "${CYAN}配置建议（不自动修改）：${NC}"

    if [[ "$boot_mode" == "UEFI" ]]; then
        echo "  1) 固件建议：OVMF（UEFI）"
        echo "  2) 额外建议：添加 efidisk0 用于 NVRAM（PVE 界面可创建）"
        if [[ "$mode" != "1" ]]; then
            echo "  3) 机器类型建议：q35（PCIe 设备直通更友好）"
        fi
    elif [[ "$boot_mode" == "Legacy" ]]; then
        echo "  1) 固件建议：SeaBIOS（Legacy）"
    else
        echo "  1) 未能可靠判断 UEFI/Legacy：建议检查磁盘分区表与是否存在 ESP"
        echo "  2) 如果是 UEFI 系统：优先使用 OVMF + q35"
    fi

    if [[ "$mode" == "1" ]]; then
        echo "  4) 总线类型建议：优先 scsi；总线受限时使用 sata/ide"
        if [[ -n "$slot" ]]; then
            echo "  5) 启动顺序建议：boot: order=${slot};ide2;net0（按实际设备调整）"
        else
            echo "  5) 启动顺序建议：确保直通磁盘所在插槽在 boot order 中靠前"
        fi
    else
        echo "  4) 启动建议：控制器/NVMe 直通后，来宾系统会直接看到物理设备；建议使用 UEFI 启动管理器选择启动项"
    fi
    return 0
}

#--------------开启硬件直通----------------

#--------------设置CPU电源模式----------------
# 设置CPU电源模式
