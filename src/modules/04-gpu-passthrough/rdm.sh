#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

get_qm_conf_path() {
    local vmid="$1"
    echo "/etc/pve/qemu-server/${vmid}.conf"
}

# 校验 VMID 并确保 VM 存在
validate_qm_vmid() {
    local vmid="$1"
    if [[ -z "$vmid" || ! "$vmid" =~ ^[0-9]+$ ]]; then
        log_error "VMID 必须是数字"
        return 1
    fi
    if ! qm status "$vmid" >/dev/null 2>&1; then
        log_error "VMID 不存在或无法访问: $vmid"
        return 1
    fi
    return 0
}

# 将 /dev/disk/by-id 的链接解析为真实磁盘设备，并过滤不可直通设备
# 过滤规则：
# - 排除分区：by-id 名称包含 -partX 或目标设备为分区（lsblk TYPE=part）
# - 排除 DM/LVM：目标设备为 dm-* 或 /dev/mapper/*
# - 仅保留 TYPE=disk 的完整磁盘
rdm_discover_whole_disks() {
    local byid_dir="/dev/disk/by-id"
    if [[ ! -d "$byid_dir" ]]; then
        log_error "未找到目录: $byid_dir"
        return 1
    fi

    local -A best_id_for_dev=()
    local -A best_pri_for_dev=()
    local -A ata_id_for_dev=()

    local link
    while IFS= read -r -d '' link; do
        local base_name real_dev dev_name dev_type pri
        base_name="$(basename "$link")"

        if [[ "$base_name" =~ -part[0-9]+$ ]]; then
            continue
        fi

        real_dev="$(readlink -f "$link" 2>/dev/null)"
        if [[ -z "$real_dev" ]]; then
            continue
        fi

        if [[ "$real_dev" == /dev/mapper/* || "$(basename "$real_dev")" == dm-* ]]; then
            continue
        fi

        if [[ ! -b "$real_dev" ]]; then
            continue
        fi

        dev_type="$(lsblk -dn -o TYPE "$real_dev" 2>/dev/null | head -n 1)"
        if [[ "$dev_type" != "disk" ]]; then
            continue
        fi

        pri=50
        if [[ "$base_name" =~ ^wwn- ]]; then pri=10; fi
        if [[ "$base_name" =~ ^nvme-eui ]]; then pri=10; fi
        if [[ "$base_name" =~ ^nvme-uuid ]]; then pri=15; fi
        if [[ "$base_name" =~ ^ata- ]]; then pri=20; fi
        if [[ "$base_name" =~ ^scsi- ]]; then pri=30; fi
        if [[ "$base_name" =~ ^pci- ]]; then pri=40; fi

        if [[ "$base_name" =~ ^ata- ]] && [[ -z "${ata_id_for_dev[$real_dev]:-}" ]]; then
            ata_id_for_dev["$real_dev"]="$link"
        fi

        if [[ -z "${best_id_for_dev[$real_dev]:-}" || "$pri" -lt "${best_pri_for_dev[$real_dev]}" ]]; then
            best_id_for_dev["$real_dev"]="$link"
            best_pri_for_dev["$real_dev"]="$pri"
        fi
    done < <(find "$byid_dir" -maxdepth 1 -type l -print0 2>/dev/null)

    local dev
    for dev in "${!best_id_for_dev[@]}"; do
        local id_path size model ata_path
        id_path="${best_id_for_dev[$dev]}"
        ata_path="${ata_id_for_dev[$dev]:-}"
        size="$(lsblk -dn -o SIZE "$dev" 2>/dev/null | head -n 1)"
        model="$(lsblk -dn -o MODEL "$dev" 2>/dev/null | head -n 1)"
        printf '%s|%s|%s|%s|%s\n' "$id_path" "$dev" "${size:-?}" "${model:-?}" "$ata_path"
    done | sort -t'|' -k2,2
}

# 自动查找总线类型下可用插槽（sata 最多 6 个，ide 最多 4 个）
rdm_find_free_slot() {
    local vmid="$1"
    local bus="$2"

    local max_idx=0
    case "$bus" in
        sata) max_idx=5 ;;
        ide) max_idx=3 ;;
        scsi) max_idx=30 ;;
        *) log_error "不支持的总线类型: $bus"; return 1 ;;
    esac

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if [[ -z "$cfg" ]]; then
        log_error "无法读取 VM 配置: $vmid"
        return 1
    fi

    local i
    for ((i=0; i<=max_idx; i++)); do
        if ! echo "$cfg" | grep -qE "^${bus}${i}:"; then
            echo "${bus}${i}"
            return 0
        fi
    done

    log_error "无可用插槽: $bus (0-$max_idx)"
    return 1
}

# RDM 单盘直通（添加）
rdm_single_disk_attach() {
    log_step "RDM 单盘直通 - 磁盘发现"

    local disks
    disks="$(rdm_discover_whole_disks)"
    if [[ -z "$disks" ]]; then
        display_error "未发现可直通的完整磁盘" "请检查 /dev/disk/by-id 是否存在可用磁盘，或确认磁盘未被 DM/LVM 接管。"
        return 1
    fi

    echo -e "${CYAN}可直通磁盘列表（完整磁盘）：${NC}"
    echo "$disks" | awk -F'|' '{
        ata=$5;
        if (ata == "") ata="-";
        else {
            n=split(ata,a,"/");
            ata=a[n];
        }
        printf "  [%d] %-55s -> %-12s  %-8s  %-28s  ATA:%s\n", NR, $1, $2, $3, $4, ata
    }'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择磁盘序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "磁盘序号必须是数字"
        return 1
    fi

    local selected
    selected="$(echo "$disks" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$selected" ]]; then
        display_error "无效的磁盘序号: $pick"
        return 1
    fi

    local id_path real_dev
    id_path="$(echo "$selected" | awk -F'|' '{print $1}')"
    real_dev="$(echo "$selected" | awk -F'|' '{print $2}')"

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        pause_function
        return 1
    fi

    local bus
    read -p "请选择总线类型 (scsi/sata/ide) [scsi]: " bus
    bus="${bus:-scsi}"
    if [[ "$bus" != "scsi" && "$bus" != "sata" && "$bus" != "ide" ]]; then
        display_error "不支持的总线类型: $bus" "仅支持 scsi/sata/ide"
        return 1
    fi

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if echo "$cfg" | grep -Fq "$id_path" || echo "$cfg" | grep -Fq "$real_dev"; then
        display_error "该磁盘已在 VM 配置中存在直通记录" "请先执行取消直通，或选择其他磁盘。"
        return 1
    fi

    local slot
    slot="$(rdm_find_free_slot "$vmid" "$bus")" || return 1

    log_info "将直通磁盘: $id_path -> $real_dev"
    log_info "目标 VM: $vmid, 插槽: $slot"

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 添加直通磁盘（$slot = $id_path）"; then
        return 0
    fi

    if qm set "$vmid" "-$slot" "$id_path" >/dev/null 2>&1; then
        display_success "直通配置已写入" "如需引导此磁盘，请在 VM 启动顺序中选择该磁盘。"
        return 0
    else
        display_error "qm set 执行失败" "请检查磁盘是否被占用、VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi
}

# RDM 取消直通（--delete）
rdm_single_disk_detach() {
    log_step "RDM 取消直通（--delete）"

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if [[ -z "$cfg" ]]; then
        display_error "无法读取 VM 配置: $vmid"
        return 1
    fi

    local disks_lines
    disks_lines="$(echo "$cfg" | grep -E '^(scsi|sata|ide)[0-9]+:')"
    if [[ -z "$disks_lines" ]]; then
        display_error "该 VM 未发现任何磁盘插槽配置" "如果只是没有直通盘，可忽略此提示。"
        return 1
    fi

    echo -e "${CYAN}当前 VM 磁盘插槽：${NC}"
    echo "$disks_lines" | awk '{printf "  [%d] %s\n", NR, $0}'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择要删除的插槽序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "序号必须是数字"
        return 1
    fi

    local line slot
    line="$(echo "$disks_lines" | awk -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$line" ]]; then
        display_error "无效的序号: $pick"
        return 1
    fi
    slot="$(echo "$line" | cut -d':' -f1)"

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "从 VM $vmid 删除磁盘插槽（--delete $slot）"; then
        return 0
    fi

    if qm set "$vmid" --delete "$slot" >/dev/null 2>&1; then
        display_success "插槽已删除: $slot"
        return 0
    else
        display_error "qm set --delete 执行失败" "请检查 VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi
}

# ============ PCIe 控制器 / NVMe 直通 ============

# 检查 IOMMU 是否已开启（用于 PCIe 设备直通的前置条件）
