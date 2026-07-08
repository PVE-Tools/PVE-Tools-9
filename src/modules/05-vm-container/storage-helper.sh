#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_require_commands() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        display_error "缺少命令: ${missing[*]}" "请确认当前运行环境为 PVE 宿主机，并安装缺失组件后重试。"
        return 1
    fi
}
vm_validate_new_vmid() {
    local vmid="$1"
    if [[ -z "$vmid" || ! "$vmid" =~ ^[0-9]+$ ]]; then
        log_error "新 VMID 必须是数字"
        return 1
    fi

    if qm status "$vmid" >/dev/null 2>&1; then
        log_error "VMID 已被虚拟机占用: $vmid"
        return 1
    fi

    if command -v pct >/dev/null 2>&1 && pct status "$vmid" >/dev/null 2>&1; then
        log_error "VMID 已被容器占用: $vmid"
        return 1
    fi

    return 0
}
vm_list_vm_records() {
    qm list 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}'
}
vm_show_vm_records() {
    local records="$1"
    {
        echo -e "${CYAN}可用虚拟机列表：${NC}"
        echo "$records" | awk -F'|' '{printf "  VMID: %-6s Name: %-22s Status: %s\n", $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2
}
vm_normalize_vmid_input() {
    printf '%s\n' "$1" | tr ', ' '\n\n' | awk 'NF' | sort -n -u
}
vm_collect_target_vmids() {
    local records
    records="$(vm_list_vm_records)"
    if [[ -z "$records" ]]; then
        log_error "未发现虚拟机"
        return 1
    fi

    vm_show_vm_records "$records"
    {
        show_menu_option "1" "单个 VM"
        show_menu_option "2" "多个 VM"
        show_menu_option "3" "全部 VM"
    } >&2

    local scope
    read -p "请选择目标范围 [1-3]: " scope
    case "$scope" in
        1)
            local vmid
            vmid="$(img_select_vmid)"
            local rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$vmid" ]] || return 1
            echo "$vmid"
            ;;
        2)
            local raw ids vmid
            read -p "请输入 VMID 列表（逗号或空格分隔）: " raw
            ids="$(vm_normalize_vmid_input "$raw")"
            if [[ -z "$ids" ]]; then
                log_error "未提供有效 VMID"
                return 1
            fi
            while IFS= read -r vmid; do
                validate_qm_vmid "$vmid" || return 1
            done <<< "$ids"
            echo "$ids"
            ;;
        3)
            echo "$records" | awk -F'|' '{print $1}'
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}
vm_validate_backup_compress() {
    local compress="$1"
    case "$compress" in
        zstd|gzip|lzo) return 0 ;;
        *)
            display_error "不支持的压缩方式: $compress" "仅支持 zstd / gzip / lzo"
            return 1
            ;;
    esac
}
vm_validate_backup_mode() {
    local mode="$1"
    case "$mode" in
        snapshot|suspend|stop) return 0 ;;
        *)
            display_error "不支持的备份模式: $mode" "仅支持 snapshot / suspend / stop"
            return 1
            ;;
    esac
}
vm_validate_backup_keep_last() {
    local keep_last="$1"
    if [[ ! "$keep_last" =~ ^[0-9]+$ ]]; then
        display_error "保留份数必须是数字"
        return 1
    fi
}
vm_validate_backup_storage_name() {
    local store="$1"
    if [[ -z "$store" || ! "$store" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        display_error "备份存储名称不合法: $store" "请重新选择存储，避免将异常字符写入 root cron。"
        return 1
    fi
}
pve_tools_human_bytes() {
    local bytes="$1"

    if command -v numfmt >/dev/null 2>&1 && [[ "$bytes" =~ ^[0-9]+$ ]]; then
        numfmt --to=iec --suffix=B "$bytes" 2>/dev/null && return 0
    fi
    echo "$bytes"
}
pve_storage_status_records() {
    pvesm status 2>/dev/null | awk 'NR>1 {print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7}'
}
pve_storage_config_value() {
    local store="$1"
    local key="$2"

    pvesm config "$store" 2>/dev/null | awk -v key="$key" '
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ "^" key "([[:space:]]|:)") {
                sub("^" key "[[:space:]]*:?[[:space:]]*", "", line)
                print line
                exit
            }
        }
    '
}
pve_storage_file_backend() {
    local type="$1"

    case "$type" in
        dir|nfs|cifs|cephfs|glusterfs) return 0 ;;
        *) return 1 ;;
    esac
}
pve_storage_mount_path() {
    local store="$1"
    local type="$2"
    local path

    path="$(pve_storage_config_value "$store" path)"
    if [[ -n "$path" ]]; then
        echo "$path"
        return 0
    fi

    case "$type" in
        nfs|cifs|cephfs|glusterfs)
            echo "/mnt/pve/$store"
            return 0
            ;;
    esac

    return 1
}
pve_storage_content_subdir() {
    local content="$1"

    case "$content" in
        iso) echo "template/iso" ;;
        backup) echo "dump" ;;
        vztmpl) echo "template/cache" ;;
        snippets) echo "snippets" ;;
        images) echo "images" ;;
        rootdir) echo "private" ;;
        import) echo "import" ;;
        *) return 1 ;;
    esac
}
pve_storage_content_dir_override() {
    local store="$1"
    local content="$2"
    local content_dirs entry key value

    content_dirs="$(pve_storage_config_value "$store" content-dirs | tr -d ' ')"
    [[ -n "$content_dirs" ]] || return 1
    IFS=',' read -r -a entries <<< "$content_dirs"
    for entry in "${entries[@]}"; do
        key="${entry%%=*}"
        value="${entry#*=}"
        if [[ "$key" == "$content" && -n "$value" && "$value" != "$entry" ]]; then
            echo "$value"
            return 0
        fi
    done
    return 1
}
pve_storage_content_path() {
    local store="$1"
    local type="$2"
    local content="$3"
    local root subdir

    pve_storage_file_backend "$type" || return 1
    root="$(pve_storage_mount_path "$store" "$type")" || return 1
    subdir="$(pve_storage_content_dir_override "$store" "$content" || pve_storage_content_subdir "$content")" || return 1
    printf '%s/%s\n' "${root%/}" "$subdir"
}
pve_storage_list_content_paths() {
    local content="$1"
    local store type status total used avail percent path

    while IFS='|' read -r store type status total used avail percent; do
        [[ -n "$store" ]] || continue
        if vm_storage_supports_content "$store" "$content" && path="$(pve_storage_content_path "$store" "$type" "$content")"; then
            printf '%s|%s|%s|%s\n' "$store" "$type" "$status" "$path"
        fi
    done < <(pve_storage_status_records)
}
pve_storage_usage_text() {
    local path="$1"
    local target="$path"

    while [[ ! -e "$target" && "$target" != "/" ]]; do
        target="$(dirname "$target")"
    done
    if [[ -e "$target" ]]; then
        df -hP "$target" 2>/dev/null | awk 'NR==2 {printf "%s/%s 可用:%s 使用率:%s", $3, $2, $4, $5}'
    else
        echo "路径不存在或未挂载"
    fi
}
pve_storage_find_owner_by_path() {
    local file_path="$1"
    local content="${2:-backup}"
    local store type status path best_store="" best_len=0 len

    while IFS='|' read -r store type status path; do
        [[ -n "$path" ]] || continue
        if [[ "$file_path" == "$path/"* || "$file_path" == "$path" ]]; then
            len=${#path}
            if (( len > best_len )); then
                best_store="$store"
                best_len=$len
            fi
        fi
    done < <(pve_storage_list_content_paths "$content")

    [[ -n "$best_store" ]] && echo "$best_store" || echo "unknown"
}
vm_storage_supports_content() {
    local store="$1"
    local content="$2"
    local configured
    configured="$(pve_storage_config_value "$store" content | tr -d '[:space:]')"
    [[ -n "$configured" ]] || return 1
    echo ",$configured," | grep -Fq ",$content,"
}
vm_list_storages_by_content() {
    local content="$1"
    while IFS='|' read -r store type active; do
        [[ -n "$store" ]] || continue
        if vm_storage_supports_content "$store" "$content"; then
            printf '%s|%s|%s\n' "$store" "$type" "${active:-?}"
        fi
    done < <(pvesm status 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}')
}
vm_select_storage_by_content() {
    local content="$1"
    local prompt="${2:-请选择存储}"
    local stores
    stores="$(vm_list_storages_by_content "$content")"

    if [[ -z "$stores" ]]; then
        local manual
        read -p "未发现支持 ${content} 内容类型的存储，请手动输入存储名: " manual
        [[ -n "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}${prompt}${NC}"
        echo "$stores" | awk -F'|' '{printf "  [%d] %-18s 类型:%-12s 状态:%s\n", NR, $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择存储序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1

    local line store
    line="$(echo "$stores" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    store="$(echo "$line" | awk -F'|' '{print $1}')"
    [[ -n "$store" ]] || return 1
    echo "$store"
}
vm_list_cluster_nodes() {
    if [[ -d /etc/pve/nodes ]]; then
        find /etc/pve/nodes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
    fi
}
vm_select_target_node() {
    local current_node nodes filtered
    current_node="$(hostname)"
    nodes="$(vm_list_cluster_nodes)"
    filtered="$(echo "$nodes" | grep -vx "$current_node" || true)"
    [[ -n "$filtered" ]] || return 1

    {
        echo -e "${CYAN}可迁移目标节点：${NC}"
        echo "$filtered" | awk '{printf "  [%d] %s\n", NR, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line
    read -p "请选择目标节点序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$filtered" | awk -v n="$pick" 'NR==n{print $1}')"
    [[ -n "$line" ]] || return 1
    echo "$line"
}
vm_find_free_disk_slot() {
    local vmid="$1"
    local bus="$2"
    local max_idx=0
    case "$bus" in
        scsi) max_idx=30 ;;
        sata) max_idx=5 ;;
        ide) max_idx=3 ;;
        virtio) max_idx=15 ;;
        *) return 1 ;;
    esac

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    [[ -n "$cfg" ]] || return 1

    local i
    for ((i=0; i<=max_idx; i++)); do
        if ! echo "$cfg" | grep -qE "^${bus}${i}:"; then
            echo "${bus}${i}"
            return 0
        fi
    done
    return 1
}
vm_find_free_net_index() {
    local vmid="$1"
    local cfg used i
    cfg="$(qm config "$vmid" 2>/dev/null)"
    used="$(echo "$cfg" | awk -F'[: ]' '/^net[0-9]+:/{gsub("net","",$1); print $1}' | sort -n | uniq)"
    for ((i=0; i<=31; i++)); do
        if ! echo "$used" | grep -qx "$i"; then
            echo "$i"
            return 0
        fi
    done
    return 1
}
vm_select_disk_slot() {
    local vmid="$1"
    local slots
    slots="$(qm config "$vmid" 2>/dev/null | grep -E '^(scsi|sata|virtio|ide)[0-9]+:' | grep -v 'cloudinit')"
    [[ -n "$slots" ]] || return 1

    {
        echo -e "${CYAN}当前磁盘插槽：${NC}"
        echo "$slots" | awk '{printf "  [%d] %s\n", NR, $0}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line slot
    read -p "请选择磁盘序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$slots" | awk -v n="$pick" 'NR==n{print $0}')"
    slot="${line%%:*}"
    [[ -n "$slot" ]] || return 1
    echo "$slot"
}
vm_select_net_slot() {
    local vmid="$1"
    local nets
    nets="$(qm config "$vmid" 2>/dev/null | grep -E '^net[0-9]+:')"
    [[ -n "$nets" ]] || return 1

    {
        echo -e "${CYAN}当前网卡列表：${NC}"
        echo "$nets" | awk '{printf "  [%d] %s\n", NR, $0}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line slot
    read -p "请选择网卡序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$nets" | awk -v n="$pick" 'NR==n{print $0}')"
    slot="${line%%:*}"
    [[ -n "$slot" ]] || return 1
    echo "$slot"
}
vm_get_qm_value() {
    local vmid="$1"
    local key="$2"
    qm config "$vmid" 2>/dev/null | awk -v key="$key" '$0 ~ "^" key ": " { sub("^[^:]+: ", "", $0); print; exit }'
}
vm_is_template() {
    local vmid="$1"
    [[ "$(vm_get_qm_value "$vmid" "template")" == "1" ]]
}
vm_network_strip_mac() {
    echo "$1" | sed -E 's/^([A-Za-z0-9_-]+)=[0-9A-Fa-f:]{17}(,|$)/\1\2/' | sed -E 's/,,+/,/g; s/,$//'
}
vm_network_set_option() {
    local current="$1"
    local key="$2"
    local value="$3"
    if echo "$current" | grep -qE "(^|,)$key="; then
        echo "$current" | sed -E "s/(^|,)$key=[^,]*/\1$key=$value/" | sed -E 's/^,//; s/,,+/,/g; s/,$//'
    else
        echo "$current,$key=$value" | sed -E 's/^,//; s/,,+/,/g; s/,$//'
    fi
}
vm_network_remove_option() {
    local current="$1"
    local key="$2"
    echo "$current" | sed -E "s/(^|,)$key=[^,]*//g" | sed -E 's/^,//; s/,,+/,/g; s/,$//'
}
vm_detect_image_format() {
    local image_path="$1"
    qemu-img info "$image_path" 2>/dev/null | awk -F': ' '/^file format:/{print $2; exit}'
}
vm_discover_disk_image_files() {
    local roots=("/root" "/var/lib/vz/template/iso" "/home")
    local root
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            find "$root" -xdev -type f \( -iname '*.img' -o -iname '*.raw' -o -iname '*.qcow2' \) -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
        fi
    done | sort -u
}
vm_discover_backup_archives() {
    local roots=("/var/lib/vz/dump" "/mnt/pve" "/backup" "/backups" "/root")
    local root
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            find "$root" -maxdepth 3 -type f \( -name 'vzdump-qemu-*.vma' -o -name 'vzdump-qemu-*.vma.gz' -o -name 'vzdump-qemu-*.vma.lzo' -o -name 'vzdump-qemu-*.vma.zst' \) -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
        fi
    done | sort -u
}
vm_discover_all_backup_archives() {
    local roots=("/var/lib/vz/dump" "/mnt/pve" "/backup" "/backups" "/root")
    local root
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            find "$root" -maxdepth 4 -type f \( \
                -name 'vzdump-qemu-*.vma' -o -name 'vzdump-qemu-*.vma.gz' -o -name 'vzdump-qemu-*.vma.lzo' -o -name 'vzdump-qemu-*.vma.zst' -o \
                -name 'vzdump-lxc-*.tar' -o -name 'vzdump-lxc-*.tar.gz' -o -name 'vzdump-lxc-*.tar.lzo' -o -name 'vzdump-lxc-*.tar.zst' \
            \) -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
        fi
    done | sort -u
}
vm_backup_archive_guest_type() {
    local file_name="$1"

    case "$(basename "$file_name")" in
        vzdump-qemu-*) echo "VM" ;;
        vzdump-lxc-*) echo "CT" ;;
        *) echo "未知" ;;
    esac
}
vm_backup_archive_vmid() {
    local file_name
    file_name="$(basename "$1")"
    echo "$file_name" | sed -nE 's/^vzdump-(qemu|lxc)-([0-9]+)-.*/\2/p'
}
vm_backup_transfer_guide() {
    if ! command -v pvesm >/dev/null 2>&1; then
        display_error "未找到 pvesm" "请在 Proxmox VE 节点上运行。"
        return 1
    fi

    local archives
    archives="$(vm_discover_all_backup_archives)"

    clear
    show_menu_header "备份文件跨机恢复引导"
    echo -e "${YELLOW}说明:${NC} PVE 备份文件通常放在支持 backup 内容类型的存储 dump 目录中；跨机迁移时把备份文件复制到目标节点对应 dump 目录后，再使用 Web UI 或 qmrestore/pct restore 恢复。"
    echo "$UI_DIVIDER"

    if [[ -z "$archives" ]]; then
        log_warn "未发现常见 vzdump 备份文件。"
    else
        printf "%-5s %-6s %-8s %-10s %-16s %s\n" "序号" "类型" "VMID" "大小" "时间" "文件"
        echo "$UI_DIVIDER"
        local idx=1 path size mtime type vmid store
        while IFS='|' read -r path size mtime; do
            type="$(vm_backup_archive_guest_type "$path")"
            vmid="$(vm_backup_archive_vmid "$path")"
            store="$(pve_storage_find_owner_by_path "$path" backup)"
            printf "%-5s %-6s %-8s %-10s %-16s %s\n" "$idx" "$type" "${vmid:-?}" "$(pve_tools_human_bytes "$size")" "$mtime" "$path"
            echo "      存储: $store"
            idx=$((idx + 1))
        done <<< "$archives"
    fi

    echo "$UI_DIVIDER"
    echo -e "${CYAN}当前节点可用于上传/恢复的备份目录:${NC}"
    local path found=false
    while IFS='|' read -r store type status path; do
        found=true
        echo "  - $store ($type): $path"
        echo "    从本地上传到目标 PVE: scp ./vzdump-qemu-100.vma.zst root@<目标PVE-IP>:\"$path/\""
    done < <(pve_storage_list_content_paths backup)
    [[ "$found" == true ]] || echo "  未发现支持 backup 内容类型的文件级存储。"

    echo "$UI_DIVIDER"
    echo -e "${CYAN}从当前机器下载到本地电脑示例:${NC}"
    echo "  scp root@<当前PVE-IP>:\"/var/lib/vz/dump/vzdump-qemu-100.vma.zst\" ./"
    echo -e "${CYAN}目标机器恢复示例:${NC}"
    echo "  VM: qmrestore /var/lib/vz/dump/vzdump-qemu-100.vma.zst <新VMID> --storage <磁盘存储>"
    echo "  CT: pct restore <新CTID> /var/lib/vz/dump/vzdump-lxc-100.tar.zst --storage <rootfs存储>"
    echo -e "${YELLOW}提示:${NC} NFS/CIFS 等共享备份存储在多节点间可能路径一致，但仍要确认目标节点能访问同一存储。"
}
pve_guest_exists() {
    local guest_type="$1"
    local vmid="$2"

    [[ "$vmid" =~ ^[0-9]+$ ]] || return 1

    case "$guest_type" in
        VM|vm|qemu)
            [[ -f "/etc/pve/qemu-server/${vmid}.conf" ]] && return 0
            command -v qm >/dev/null 2>&1 && qm status "$vmid" >/dev/null 2>&1
            ;;
        CT|ct|lxc)
            [[ -f "/etc/pve/lxc/${vmid}.conf" ]] && return 0
            command -v pct >/dev/null 2>&1 && pct status "$vmid" >/dev/null 2>&1
            ;;
        *)
            pve_guest_exists VM "$vmid" || pve_guest_exists CT "$vmid"
            ;;
    esac
}
