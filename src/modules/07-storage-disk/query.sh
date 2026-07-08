#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

pve_storage_location_panel() {
    if ! command -v pvesm >/dev/null 2>&1; then
        display_error "未找到 pvesm" "请在 Proxmox VE 节点上运行。"
        return 1
    fi

    clear
    show_menu_header "存储位置查询面板"
    echo -e "${YELLOW}说明:${NC} 文件级存储会显示可通过 SCP/SFTP 操作的目录；LVM/ZFS/RBD 等块存储不适合直接上传 ISO/备份文件。"
    echo "$UI_DIVIDER"

    local store type status total used avail percent contents root usage
    printf "%-18s %-10s %-8s %-18s %s\n" "存储" "类型" "状态" "内容类型" "根路径/说明"
    echo "$UI_DIVIDER"
    while IFS='|' read -r store type status total used avail percent; do
        [[ -n "$store" ]] || continue
        contents="$(pve_storage_config_value "$store" content | tr -d ' ')"
        if pve_storage_file_backend "$type" && root="$(pve_storage_mount_path "$store" "$type")"; then
            usage="$(pve_storage_usage_text "$root")"
            printf "%-18s %-10s %-8s %-18s %s (%s)\n" "$store" "$type" "$status" "${contents:-unknown}" "$root" "$usage"
        else
            printf "%-18s %-10s %-8s %-18s %s\n" "$store" "$type" "$status" "${contents:-unknown}" "块/对象存储：请通过 PVE 管理卷，不直接 SCP 文件"
        fi
    done < <(pve_storage_status_records)

    echo "$UI_DIVIDER"
    echo -e "${CYAN}常用上传路径:${NC}"
    local path
    local found=false
    while IFS='|' read -r store type status path; do
        found=true
        usage="$(pve_storage_usage_text "$path")"
        echo -e "  ${GREEN}[ISO]${NC} $store ($type): $path"
        echo "       磁盘: $usage"
        echo "       scp ./file.iso root@<PVE-IP>:\"$path/\""
    done < <(pve_storage_list_content_paths iso)
    [[ "$found" == true ]] || echo "  未发现支持 iso 内容类型的文件级存储。"

    found=false
    while IFS='|' read -r store type status path; do
        found=true
        usage="$(pve_storage_usage_text "$path")"
        echo -e "  ${GREEN}[备份]${NC} $store ($type): $path"
        echo "         磁盘: $usage"
        echo "         scp ./vzdump-qemu-100.vma.zst root@<PVE-IP>:\"$path/\""
    done < <(pve_storage_list_content_paths backup)
    [[ "$found" == true ]] || echo "  未发现支持 backup 内容类型的文件级存储。"
}
