#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

pve_storage_mount_wizard_validate_storage_id() {
    local storage_id="$1"

    if [[ -z "$storage_id" || ! "$storage_id" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{1,30}$ ]]; then
        display_error "存储 ID 不合法: $storage_id" "请使用字母、数字、点、下划线或短横线，长度 2-31。"
        return 1
    fi
    if pvesm status 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$storage_id"; then
        display_error "存储 ID 已存在: $storage_id" "请换一个名称，避免覆盖现有 PVE 存储。"
        return 1
    fi
}
pve_storage_mount_wizard_validate_mountpoint() {
    local mountpoint="$1"

    if [[ -z "$mountpoint" || "$mountpoint" != /* ]]; then
        display_error "挂载点必须是绝对路径"
        return 1
    fi
    case "$mountpoint" in
        /|/boot|/boot/*|/etc|/etc/*|/usr|/usr/*|/var|/var/lib/vz|/var/lib/vz/*|/root|/root/*)
            display_error "挂载点过于危险: $mountpoint" "建议使用 /mnt/pve/<存储ID> 或 /mnt/data/<名称>。"
            return 1
            ;;
    esac
}
pve_storage_mount_wizard() {
    block_non_pve9_destructive "磁盘挂载向导" || return 1

    local candidates idx pick line dev fstype size uuid mountpoint storage_id content_types current_mount backup_path fstab_line output

    if ! command -v lsblk >/dev/null 2>&1 || ! command -v pvesm >/dev/null 2>&1; then
        display_error "缺少 lsblk 或 pvesm" "请在 Proxmox VE 节点上运行。"
        return 1
    fi

    candidates="$(lsblk -rP -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT,UUID 2>/dev/null | awk '
        function val(key,    pat, out) {
            pat = key "=\"[^\"]*\""
            if (match($0, pat)) {
                out = substr($0, RSTART + length(key) + 2, RLENGTH - length(key) - 3)
                return out
            }
            return ""
        }
        val("TYPE") == "part" && (val("FSTYPE") == "ext4" || val("FSTYPE") == "xfs") {
            print val("NAME") "|" val("FSTYPE") "|" val("SIZE") "|" val("MOUNTPOINT") "|" val("UUID")
        }
    ')"
    clear
    show_menu_header "磁盘挂载向导"
    echo -e "${RED}高风险提醒:${NC} 该向导只挂载已有 ext4/xfs 分区并添加 dir 存储，不会格式化磁盘。仍请先确认数据已备份。"
    echo -e "${YELLOW}已挂载分区、无文件系统分区、LVM/ZFS 成员不会作为候选。${NC}"
    echo "$UI_DIVIDER"

    if [[ -z "$candidates" ]]; then
        display_error "未发现可挂载的 ext4/xfs 分区" "可用 lsblk -f 手动确认磁盘状态。"
        return 1
    fi

    idx=1
    while IFS='|' read -r dev fstype size current_mount uuid; do
        printf "  [%d] %-22s %-6s %-8s 当前挂载:%s UUID:%s\n" "$idx" "$dev" "$fstype" "$size" "${current_mount:--}" "${uuid:--}"
        idx=$((idx + 1))
    done <<< "$candidates"
    echo "$UI_DIVIDER"

    read -p "请选择要挂载的分区序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$candidates" | awk -v n="$pick" 'NR==n{print}')"
    [[ -n "$line" ]] || return 1
    IFS='|' read -r dev fstype size current_mount uuid <<< "$line"

    if [[ -n "$current_mount" && "$current_mount" != "-" ]]; then
        display_error "该分区已挂载: $current_mount" "为避免误操作，请先人工确认是否已被使用。"
        return 1
    fi
    if [[ -z "$uuid" || "$uuid" == "-" ]]; then
        uuid="$(blkid -s UUID -o value "$dev" 2>/dev/null || true)"
    fi
    if [[ -z "$uuid" ]]; then
        display_error "无法读取分区 UUID: $dev" "请检查 blkid 输出。"
        return 1
    fi

    read -p "请输入新的 PVE 存储 ID [data-$(basename "$dev")]: " storage_id
    storage_id="${storage_id:-data-$(basename "$dev")}"
    pve_storage_mount_wizard_validate_storage_id "$storage_id" || return 1

    read -p "请输入挂载点 [/mnt/pve/$storage_id]: " mountpoint
    mountpoint="${mountpoint:-/mnt/pve/$storage_id}"
    pve_storage_mount_wizard_validate_mountpoint "$mountpoint" || return 1

    if findmnt -rn --target "$mountpoint" >/dev/null 2>&1; then
        display_error "挂载点已被占用: $mountpoint" "请换一个空目录。"
        return 1
    fi

    read -p "请输入 PVE 内容类型 [images,iso,backup,vztmpl,snippets]: " content_types
    content_types="${content_types:-images,iso,backup,vztmpl,snippets}"
    content_types="$(echo "$content_types" | tr -d ' ')"
    if [[ ! "$content_types" =~ ^[A-Za-z0-9_,]+$ ]]; then
        display_error "内容类型包含非法字符" "示例: images,iso,backup"
        return 1
    fi

    clear
    show_menu_header "确认挂载配置"
    echo -e "${CYAN}分区:${NC} $dev"
    echo -e "${CYAN}文件系统:${NC} $fstype"
    echo -e "${CYAN}UUID:${NC} $uuid"
    echo -e "${CYAN}挂载点:${NC} $mountpoint"
    echo -e "${CYAN}PVE 存储 ID:${NC} $storage_id"
    echo -e "${CYAN}内容类型:${NC} $content_types"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "挂载已有分区并添加 PVE dir 存储" "会修改 /etc/fstab、创建挂载点，并向 PVE 添加新的 dir 存储。" "UUID 或挂载点选错可能导致启动时挂载失败；存储 ID 选错会造成 PVE 存储配置混乱。" "请确认该分区确实是要复用的数据盘，已完成外部备份，并准备控制台回滚方式。" "MOUNT-DIR"; then
        return 0
    fi

    mkdir -p "$mountpoint" || {
        display_error "无法创建挂载点: $mountpoint"
        return 1
    }

    backup_file "/etc/fstab" backup_path >/dev/null 2>&1 || true
    if ! grep -Eq "UUID=${uuid}[[:space:]]" /etc/fstab 2>/dev/null; then
        fstab_line="UUID=${uuid} ${mountpoint} ${fstype} defaults,nofail 0 2"
        printf '%s\n' "$fstab_line" >> /etc/fstab
        log_success "已写入 /etc/fstab: $fstab_line"
    else
        log_warn "/etc/fstab 已存在 UUID=${uuid}，跳过重复写入。"
    fi

    if ! output="$(mount "$mountpoint" 2>&1)"; then
        [[ -n "$backup_path" && -f "$backup_path" ]] && cp -a "$backup_path" /etc/fstab >/dev/null 2>&1 || true
        echo "$output" | sed 's/^/  /'
        display_error "挂载失败，已尝试回滚 /etc/fstab" "请检查分区、文件系统和挂载点。"
        return 1
    fi

    if ! pvesm add dir "$storage_id" --path "$mountpoint" --content "$content_types" >/dev/null 2>&1; then
        umount "$mountpoint" >/dev/null 2>&1 || true
        [[ -n "$backup_path" && -f "$backup_path" ]] && cp -a "$backup_path" /etc/fstab >/dev/null 2>&1 || true
        display_error "PVE dir 存储添加失败，已尝试卸载并回滚 /etc/fstab" "请检查 pvesm 输出或手动添加存储。"
        return 1
    fi

    display_success "已有分区挂载并添加为 PVE dir 存储完成" "存储 ID: $storage_id，路径: $mountpoint"
}
