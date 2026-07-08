#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

garbage_cleanup_sum_sizes() {
    awk -F'|' '{sum += $2} END {print sum + 0}'
}
garbage_cleanup_count_records() {
    awk 'NF {count++} END {print count + 0}'
}
garbage_cleanup_temp_file_candidates() {
    local age_days="${1:-3}"

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=3
    if [[ -d /tmp ]]; then
        find /tmp -maxdepth 1 -type f \( \
            -name 'pve-tools-*' -o \
            -name 'pve-third-party-*' -o \
            -name 'fastpve-install.*.sh' -o \
            -name 'pve8to9_check.log' -o \
            -name 'pve-qemu-kvm.deb' \
        \) -mtime +"$age_days" -printf '%p|%s|%TY-%Tm-%Td %TH:%TM|临时文件\n' 2>/dev/null || true
    fi
}
garbage_cleanup_pve_tools_old_file_candidates() {
    local age_days="${1:-90}"
    local root

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=90
    for root in "/var/backups/pve-tools" "$VM_CONFIG_EXPORT_DIR"; do
        if [[ -d "$root" ]]; then
            find "$root" -type f -mtime +"$age_days" -printf '%p|%s|%TY-%Tm-%Td %TH:%TM|PVE-Tools 旧文件\n' 2>/dev/null || true
        fi
    done
}
garbage_cleanup_print_file_records() {
    local records="$1"
    local idx=1 path size mtime reason

    printf "%-5s %-10s %-16s %-18s %s\n" "序号" "大小" "时间" "类型" "文件"
    echo "$UI_DIVIDER"
    while IFS='|' read -r path size mtime reason; do
        [[ -n "$path" ]] || continue
        printf "%-5s %-10s %-16s %-18s %s\n" "$idx" "$(pve_tools_human_bytes "$size")" "$mtime" "$reason" "$path"
        idx=$((idx + 1))
    done <<< "$records"
}
garbage_cleanup_delete_file_records() {
    local records="$1"
    local success=0 failed=0 skipped=0 path size mtime reason mode answer

    if [[ -z "$records" ]]; then
        log_warn "没有可删除的候选文件。"
        return 0
    fi

    read -p "删除模式：输入 all 批量删除，输入 item 逐项确认 [item]: " mode
    mode="${mode:-item}"
    [[ "$mode" == "all" || "$mode" == "item" ]] || mode="item"

    while IFS='|' read -r path size mtime reason; do
        [[ -n "$path" && -f "$path" ]] || {
            skipped=$((skipped + 1))
            continue
        }
        if [[ "$mode" == "item" ]]; then
            read -p "删除 $path ? 输入 yes 确认: " answer
            if [[ "$answer" != "yes" && "$answer" != "YES" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
        fi
        if rm -f -- "$path"; then
            log_success "已删除: $path"
            success=$((success + 1))
        else
            log_error "删除失败: $path"
            failed=$((failed + 1))
        fi
    done <<< "$records"

    log_info "删除完成：成功 $success，失败 $failed，跳过 $skipped"
}
garbage_cleanup_basic() {
    block_non_pve9_destructive "垃圾清理（缓存/日志/临时文件）" || return 1

    local temp_age journal_days pve_age auto_remove records total_size
    read -p "清理 /tmp 中超过多少天的 PVE-Tools 临时文件 [3]: " temp_age
    temp_age="${temp_age:-3}"
    [[ "$temp_age" =~ ^[0-9]+$ ]] || temp_age=3

    read -p "systemd-journal 保留天数 [14]: " journal_days
    journal_days="${journal_days:-14}"
    [[ "$journal_days" =~ ^[0-9]+$ ]] || journal_days=14

    read -p "PVE-Tools 备份/导出文件保留天数 [90]: " pve_age
    pve_age="${pve_age:-90}"
    [[ "$pve_age" =~ ^[0-9]+$ ]] || pve_age=90

    read -p "是否执行 apt autoremove 清理孤立依赖？输入 yes 启用 [no]: " auto_remove
    auto_remove="${auto_remove:-no}"

    records="$(
        garbage_cleanup_temp_file_candidates "$temp_age"
        garbage_cleanup_pve_tools_old_file_candidates "$pve_age"
    )"
    total_size="$(echo "$records" | garbage_cleanup_sum_sizes)"

    clear
    show_menu_header "垃圾清理预览"
    echo -e "${CYAN}将执行:${NC}"
    echo "  - apt-get autoclean 清理过期软件包缓存"
    echo "  - journalctl --vacuum-time=${journal_days}d 压缩系统日志保留窗口"
    echo "  - 删除超过 ${temp_age} 天的 PVE-Tools 临时文件"
    echo "  - 删除超过 ${pve_age} 天的 PVE-Tools 备份/导出文件"
    [[ "$auto_remove" == "yes" || "$auto_remove" == "YES" ]] && echo "  - apt-get autoremove -y 清理孤立依赖"
    echo "$UI_DIVIDER"
    if [[ -n "$records" ]]; then
        garbage_cleanup_print_file_records "$records"
        echo "$UI_DIVIDER"
        echo -e "${YELLOW}候选文件合计:${NC} $(pve_tools_human_bytes "$total_size")"
    else
        echo "  未发现符合年龄条件的 PVE-Tools 临时/旧文件。"
    fi

    if ! confirm_high_risk_action "执行垃圾清理" "会删除上方列出的本工具临时/旧文件，并清理 apt 缓存与 journal 日志窗口。" "文件删除不可逆；apt autoremove 如果启用，可能移除系统认为不再需要的依赖包。" "请确认候选列表只包含可丢弃文件，重要备份已另存。" "CLEAN"; then
        return 0
    fi

    log_step "清理 apt 过期缓存..."
    apt-get autoclean -y || log_warn "apt-get autoclean 执行失败，请检查 apt 状态。"

    if [[ "$auto_remove" == "yes" || "$auto_remove" == "YES" ]]; then
        log_step "清理孤立依赖..."
        apt-get autoremove -y || log_warn "apt-get autoremove 执行失败，请检查 apt 状态。"
    fi

    if command -v journalctl >/dev/null 2>&1; then
        log_step "压缩 systemd journal 日志..."
        journalctl --vacuum-time="${journal_days}d" || log_warn "journalctl 日志清理失败。"
    fi

    garbage_cleanup_delete_file_records "$records"
}
garbage_cleanup_backup_candidates() {
    local mode="${1:-both}"
    local age_days="${2:-180}"
    local now cutoff path size mtime type vmid epoch old orphan reason

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=180
    now="$(date +%s)"
    cutoff=$((now - age_days * 86400))

    while IFS='|' read -r path size mtime; do
        [[ -n "$path" && -f "$path" ]] || continue
        type="$(vm_backup_archive_guest_type "$path")"
        vmid="$(vm_backup_archive_vmid "$path")"
        epoch="$(stat -c '%Y' "$path" 2>/dev/null || echo 0)"
        old=0
        orphan=0
        reason=""

        if [[ "$epoch" =~ ^[0-9]+$ ]] && (( epoch > 0 && epoch < cutoff )); then
            old=1
            reason="超过 ${age_days} 天"
        fi
        if [[ -n "$vmid" && "$type" != "未知" ]] && ! pve_guest_exists "$type" "$vmid"; then
            orphan=1
            [[ -n "$reason" ]] && reason+=","
            reason+="无对应 ${type} ${vmid}"
        fi

        case "$mode" in
            old) (( old == 1 )) || continue ;;
            orphan) (( orphan == 1 )) || continue ;;
            both|*) (( old == 1 || orphan == 1 )) || continue ;;
        esac
        printf '%s|%s|%s|%s|%s|%s\n' "$path" "$size" "$mtime" "$type" "${vmid:-?}" "$reason"
    done < <(vm_discover_all_backup_archives)
}
garbage_cleanup_print_backup_records() {
    local records="$1"
    local idx=1 path size mtime type vmid reason

    printf "%-5s %-5s %-7s %-10s %-16s %-24s %s\n" "序号" "类型" "VMID" "大小" "时间" "原因" "文件"
    echo "$UI_DIVIDER"
    while IFS='|' read -r path size mtime type vmid reason; do
        [[ -n "$path" ]] || continue
        printf "%-5s %-5s %-7s %-10s %-16s %-24s %s\n" "$idx" "$type" "$vmid" "$(pve_tools_human_bytes "$size")" "$mtime" "$reason" "$path"
        idx=$((idx + 1))
    done <<< "$records"
}
garbage_cleanup_delete_backup_records() {
    local records="$1"
    local success=0 failed=0 skipped=0 path size mtime type vmid reason mode answer

    if [[ -z "$records" ]]; then
        log_warn "没有可删除的备份候选。"
        return 0
    fi

    read -p "删除模式：输入 all 批量删除，输入 item 逐项确认 [item]: " mode
    mode="${mode:-item}"
    [[ "$mode" == "all" || "$mode" == "item" ]] || mode="item"

    while IFS='|' read -r path size mtime type vmid reason; do
        [[ -n "$path" && -f "$path" ]] || {
            skipped=$((skipped + 1))
            continue
        }
        if [[ "$mode" == "item" ]]; then
            echo "备份: ${type:-?} ${vmid:-?} | $(pve_tools_human_bytes "$size") | ${reason:-未标注原因}"
            read -p "删除 $path ? 输入 yes 确认: " answer
            if [[ "$answer" != "yes" && "$answer" != "YES" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
        fi
        if rm -f -- "$path"; then
            log_success "已删除备份: $path"
            success=$((success + 1))
        else
            log_error "备份删除失败: $path"
            failed=$((failed + 1))
        fi
    done <<< "$records"

    log_info "备份清理完成：成功 $success，失败 $failed，跳过 $skipped"
}
garbage_cleanup_prune_backups() {
    block_non_pve9_destructive "清理过期/无主备份文件" || return 1
    vm_require_commands pvesm || return 1

    local scope age_days records total_size
    clear
    show_menu_header "备份文件清理"
    show_menu_option "1" "只列出无对应 VM/CT 的备份"
    show_menu_option "2" "只列出超过指定天数的备份"
    show_menu_option "3" "同时列出无主备份和过期备份"
    echo "$UI_DIVIDER"
    read -p "请选择筛选范围 [3]: " scope
    scope="${scope:-3}"
    case "$scope" in
        1) scope="orphan" ;;
        2) scope="old" ;;
        *) scope="both" ;;
    esac

    read -p "过期备份阈值天数 [180]: " age_days
    age_days="${age_days:-180}"
    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=180

    records="$(garbage_cleanup_backup_candidates "$scope" "$age_days")"
    clear
    show_menu_header "备份文件清理预览"
    if [[ -z "$records" ]]; then
        log_warn "未发现符合条件的备份文件。"
        return 0
    fi

    garbage_cleanup_print_backup_records "$records"
    total_size="$(echo "$records" | garbage_cleanup_sum_sizes)"
    echo "$UI_DIVIDER"
    echo -e "${YELLOW}候选备份合计:${NC} $(pve_tools_human_bytes "$total_size")"
    echo -e "${YELLOW}提醒:${NC} NFS/CIFS 共享备份可能仍被其他节点使用，删除前请确认跨机恢复需求。"

    if ! confirm_high_risk_action "删除上方列出的 vzdump 备份文件" "会永久删除备份文件，删除后无法通过这些备份恢复 VM/CT。" "如果误删最后一个可用备份，后续故障将缺少恢复点。" "请确认已有其他可用备份或确定这些备份不再需要。" "DELETE-BACKUP"; then
        return 0
    fi

    garbage_cleanup_delete_backup_records "$records"
}
garbage_cleanup_snapshot_candidates() {
    local age_days="${1:-90}"
    local cutoff conf vmid guest_type

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=90
    cutoff=$(($(date +%s) - age_days * 86400))

    for conf in /etc/pve/qemu-server/*.conf /etc/pve/lxc/*.conf; do
        [[ -f "$conf" ]] || continue
        vmid="$(basename "$conf" .conf)"
        guest_type="VM"
        [[ "$conf" == /etc/pve/lxc/* ]] && guest_type="CT"
        awk -v guest_type="$guest_type" -v vmid="$vmid" -v cutoff="$cutoff" '
            /^\[[^]]+\]$/ {
                snap = $0
                gsub(/^\[/, "", snap)
                gsub(/\]$/, "", snap)
                next
            }
            snap != "" && /^snaptime:[[:space:]]*[0-9]+/ {
                ts = $2
                if (ts < cutoff) {
                    print guest_type "|" vmid "|" snap "|" ts
                }
                snap = ""
            }
        ' "$conf"
    done
}
garbage_cleanup_prune_snapshots() {
    block_non_pve9_destructive "清理旧快照" || return 1

    local age_days records count idx guest_type vmid snapshot_name epoch time_text mode answer success=0 failed=0 skipped=0
    read -p "列出超过多少天的快照 [90]: " age_days
    age_days="${age_days:-90}"
    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=90

    records="$(garbage_cleanup_snapshot_candidates "$age_days")"
    clear
    show_menu_header "旧快照清理预览"
    if [[ -z "$records" ]]; then
        log_warn "未发现超过 ${age_days} 天且带 snaptime 的 VM/CT 快照。"
        return 0
    fi

    printf "%-5s %-5s %-7s %-24s %-20s\n" "序号" "类型" "VMID" "快照名" "创建时间"
    echo "$UI_DIVIDER"
    idx=1
    while IFS='|' read -r guest_type vmid snapshot_name epoch; do
        [[ -n "$snapshot_name" ]] || continue
        time_text="$(date -d "@$epoch" '+%F %T' 2>/dev/null || echo "$epoch")"
        printf "%-5s %-5s %-7s %-24s %-20s\n" "$idx" "$guest_type" "$vmid" "$snapshot_name" "$time_text"
        idx=$((idx + 1))
    done <<< "$records"
    count="$(echo "$records" | garbage_cleanup_count_records)"
    echo "$UI_DIVIDER"
    echo -e "${YELLOW}候选快照数量:${NC} $count"

    if ! confirm_high_risk_action "删除上方列出的旧快照" "删除快照后将失去对应时间点的快速回滚能力。" "如果快照是业务回退基线，误删后只能依赖外部备份恢复。" "请确认这些快照已经过期，且已有必要的外部备份。" "DELETE-SNAP"; then
        return 0
    fi

    read -p "删除模式：输入 all 批量删除，输入 item 逐项确认 [item]: " mode
    mode="${mode:-item}"
    [[ "$mode" == "all" || "$mode" == "item" ]] || mode="item"

    while IFS='|' read -r guest_type vmid snapshot_name epoch; do
        [[ -n "$snapshot_name" ]] || continue
        if [[ "$mode" == "item" ]]; then
            read -p "删除 ${guest_type} ${vmid} 快照 ${snapshot_name} ? 输入 yes 确认: " answer
            if [[ "$answer" != "yes" && "$answer" != "YES" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
        fi

        if [[ "$guest_type" == "VM" ]]; then
            if qm delsnapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
                log_success "已删除 VM $vmid 快照: $snapshot_name"
                success=$((success + 1))
            else
                log_error "删除 VM $vmid 快照失败: $snapshot_name"
                failed=$((failed + 1))
            fi
        else
            if pct delsnapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
                log_success "已删除 CT $vmid 快照: $snapshot_name"
                success=$((success + 1))
            else
                log_error "删除 CT $vmid 快照失败: $snapshot_name"
                failed=$((failed + 1))
            fi
        fi
    done <<< "$records"

    log_info "快照清理完成：成功 $success，失败 $failed，跳过 $skipped"
}
garbage_cleanup_collect_referenced_volumes() {
    {
        grep -hoE '[A-Za-z0-9_.-]+:(vm|base|subvol)-[0-9]+-[^,[:space:]]+' /etc/pve/qemu-server/*.conf 2>/dev/null || true
        grep -hoE '[A-Za-z0-9_.-]+:(vm|base|subvol)-[0-9]+-[^,[:space:]]+' /etc/pve/lxc/*.conf 2>/dev/null || true
    } | sort -u
}
garbage_cleanup_orphan_disk_report() {
    vm_require_commands pvesm || return 1

    local refs store type status total used avail percent content line volid size vmid owner_id records=""
    refs="$(garbage_cleanup_collect_referenced_volumes)"

    while IFS='|' read -r store type status total used avail percent; do
        [[ -n "$store" ]] || continue
        for content in images rootdir; do
            vm_storage_supports_content "$store" "$content" || continue
            while read -r line; do
                [[ -n "$line" ]] || continue
                volid="$(echo "$line" | awk '{print $1}')"
                size="$(echo "$line" | awk '{print $4}')"
                vmid="$(echo "$line" | awk '{print $5}')"
                [[ "$volid" =~ :((vm|base|subvol)-[0-9]+-) ]] || continue
                if echo "$refs" | grep -Fxq "$volid"; then
                    continue
                fi
                owner_id="$(echo "$volid" | sed -nE 's/.*:(vm|base|subvol)-([0-9]+)-.*/\2/p')"
                if [[ -n "$owner_id" ]] && pve_guest_exists any "$owner_id"; then
                    continue
                fi
                records+="${volid}|${size:-0}|${vmid:-${owner_id:-?}}|${content}|${store}"$'\n'
            done < <(pvesm list "$store" --content "$content" 2>/dev/null | awk 'NR>1')
        done
    done < <(pve_storage_status_records)

    clear
    show_menu_header "疑似孤立磁盘扫描（只读）"
    echo -e "${YELLOW}说明:${NC} 该功能只扫描，不删除。底层卷误删风险很高，请先在 Web UI / VM 配置中二次核对。"
    echo "$UI_DIVIDER"
    if [[ -z "$records" ]]; then
        log_success "未发现明显的孤立磁盘候选。"
        return 0
    fi

    printf "%-5s %-18s %-8s %-10s %-8s %s\n" "序号" "存储" "VMID" "内容" "大小" "卷"
    echo "$UI_DIVIDER"
    local idx=1
    while IFS='|' read -r volid size vmid content store; do
        [[ -n "$volid" ]] || continue
        printf "%-5s %-18s %-8s %-10s %-8s %s\n" "$idx" "$store" "$vmid" "$content" "$(pve_tools_human_bytes "$size")" "$volid"
        echo "      人工核对后可用命令: pvesm free \"$volid\""
        idx=$((idx + 1))
    done <<< "$records"
    echo "$UI_DIVIDER"
    echo -e "${RED}未在脚本中提供自动删除孤立磁盘入口。${NC}"
}
garbage_cleanup_scan_report() {
    local temp_records old_records backup_records snap_records
    local temp_count old_count backup_count snap_count apt_cache_size pve_backup_size pve_export_size

    temp_records="$(garbage_cleanup_temp_file_candidates 3)"
    old_records="$(garbage_cleanup_pve_tools_old_file_candidates 90)"
    backup_records="$(garbage_cleanup_backup_candidates both 180)"
    snap_records="$(garbage_cleanup_snapshot_candidates 90)"
    temp_count="$(echo "$temp_records" | garbage_cleanup_count_records)"
    old_count="$(echo "$old_records" | garbage_cleanup_count_records)"
    backup_count="$(echo "$backup_records" | garbage_cleanup_count_records)"
    snap_count="$(echo "$snap_records" | garbage_cleanup_count_records)"
    apt_cache_size="$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')"
    pve_backup_size="$(du -sh /var/backups/pve-tools 2>/dev/null | awk '{print $1}')"
    pve_export_size="$(du -sh "$VM_CONFIG_EXPORT_DIR" 2>/dev/null | awk '{print $1}')"

    clear
    show_menu_header "垃圾清理扫描报告"
    echo -e "${CYAN}缓存与日志:${NC}"
    echo "  apt 缓存目录: ${apt_cache_size:-未发现}"
    if command -v journalctl >/dev/null 2>&1; then
        echo -n "  systemd journal: "
        journalctl --disk-usage 2>/dev/null || echo "无法读取"
    fi
    echo "$UI_DIVIDER"
    echo -e "${CYAN}本工具旧文件:${NC}"
    echo "  /tmp 中超过 3 天的 PVE-Tools 临时文件: $temp_count"
    echo "  /var/backups/pve-tools 总大小: ${pve_backup_size:-未发现}"
    echo "  $VM_CONFIG_EXPORT_DIR 总大小: ${pve_export_size:-未发现}"
    echo "  超过 90 天的 PVE-Tools 备份/导出文件: $old_count"
    echo "$UI_DIVIDER"
    echo -e "${CYAN}PVE 资源候选:${NC}"
    echo "  无主或超过 180 天的 vzdump 备份: $backup_count"
    echo "  超过 90 天且带 snaptime 的 VM/CT 快照: $snap_count"
    echo "  疑似孤立磁盘请使用菜单中的只读扫描单独查看。"
}
garbage_cleanup_menu() {
    while true; do
        clear
        show_menu_header "垃圾清理"
        show_menu_option "1" "一键扫描报告 ${CYAN}(只读)${NC}"
        show_menu_option "2" "清理缓存、日志与本工具旧文件"
        show_menu_option "3" "清理过期/无主 vzdump 备份"
        show_menu_option "4" "清理旧 VM/CT 快照"
        show_menu_option "5" "扫描疑似孤立磁盘 ${YELLOW}(只读，不删除)${NC}"
        echo "$UI_DIVIDER"
        echo -e "${YELLOW}说明:${NC} 清理前会列出候选项；备份和快照删除均需要高风险确认。"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-5]: " choice
        case "$choice" in
            1) garbage_cleanup_scan_report ;;
            2) garbage_cleanup_basic ;;
            3) garbage_cleanup_prune_backups ;;
            4) garbage_cleanup_prune_snapshots ;;
            5) garbage_cleanup_orphan_disk_report ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
