#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_backup_create() {
    vm_require_commands qm vzdump pvesm || return 1

    local vmids_text
    vmids_text="$(vm_collect_target_vmids)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmids_text" ]] || return 1

    mapfile -t vmids < <(printf '%s\n' "$vmids_text" | awk 'NF')

    local store
    store="$(vm_select_storage_by_content backup "请选择备份存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$store" ]] || return 1

    local compress mode keep_last
    read -p "请选择压缩方式 (zstd/gzip/lzo) [zstd]: " compress
    compress="${compress:-zstd}"
    if [[ "$compress" != "zstd" && "$compress" != "gzip" && "$compress" != "lzo" ]]; then
        display_error "不支持的压缩方式: $compress" "仅支持 zstd / gzip / lzo"
        return 1
    fi

    read -p "请选择备份模式 (snapshot/suspend/stop) [snapshot]: " mode
    mode="${mode:-snapshot}"
    if [[ "$mode" != "snapshot" && "$mode" != "suspend" && "$mode" != "stop" ]]; then
        display_error "不支持的备份模式: $mode" "仅支持 snapshot / suspend / stop"
        return 1
    fi

    read -p "请输入保留份数（0 表示不启用自动清理） [7]: " keep_last
    keep_last="${keep_last:-7}"
    if [[ ! "$keep_last" =~ ^[0-9]+$ ]]; then
        display_error "保留份数必须是数字"
        return 1
    fi

    clear
    show_menu_header "VM 备份与恢复"
    echo -e "${YELLOW}目标 VM:${NC} ${vmids[*]}"
    echo -e "${YELLOW}备份存储:${NC} $store"
    echo -e "${YELLOW}压缩方式:${NC} $compress"
    echo -e "${YELLOW}备份模式:${NC} $mode"
    echo -e "${YELLOW}保留份数:${NC} $keep_last"
    echo -e "${UI_DIVIDER}"

    if ! confirm_high_risk_action "为 VM ${vmids[*]} 执行 vzdump 备份" "备份任务会占用大量 IO 与备份存储空间，错误的保留策略可能挤占生产容量。" "可能触发快照/锁定/短暂性能抖动，存储空间不足时任务会失败。" "请确认目标存储可用空间、保留策略和维护窗口，再执行备份。" "BACKUP"; then
        return 0
    fi

    local -a cmd=(vzdump)
    cmd+=("${vmids[@]}")
    cmd+=(--storage "$store" --compress "$compress" --mode "$mode")
    if (( keep_last > 0 )); then
        cmd+=(--prune-backups "keep-last=$keep_last")
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "vzdump 执行失败" "请检查目标存储空间、任务锁定状态或日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    display_success "备份完成" "可在对应存储的 dump 目录中查看生成的备份文件。"
}
vm_schedule_add_backup_job() {
    vm_require_commands qm vzdump pvesm || return 1

    local scope job_targets target_label
    {
        show_menu_option "1" "单个 VM"
        show_menu_option "2" "多个 VM"
        show_menu_option "3" "全部 VM"
    }
    read -p "请选择定时备份范围 [1-3]: " scope
    case "$scope" in
        1|2)
            job_targets="$(vm_collect_target_vmids)"
            local rc=$?
            [[ "$rc" -eq 2 ]] && return 0
            [[ -n "$job_targets" ]] || return 1
            target_label="$(echo "$job_targets" | tr '\n' '-' | sed 's/-$//')"
            ;;
        3)
            target_label="all"
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    local store
    store="$(vm_select_storage_by_content backup "请选择备份存储")" || return 1
    vm_validate_backup_storage_name "$store" || return 1

    local compress mode keep_last run_time
    read -p "请选择压缩方式 (zstd/gzip/lzo) [zstd]: " compress
    compress="${compress:-zstd}"
    vm_validate_backup_compress "$compress" || return 1

    read -p "请选择备份模式 (snapshot/suspend/stop) [snapshot]: " mode
    mode="${mode:-snapshot}"
    vm_validate_backup_mode "$mode" || return 1

    read -p "请输入保留份数（0 表示不启用自动清理） [7]: " keep_last
    keep_last="${keep_last:-7}"
    vm_validate_backup_keep_last "$keep_last" || return 1

    read -p "请输入每日执行时间 (HH:MM) [03:00]: " run_time
    run_time="${run_time:-03:00}"
    if [[ ! "$run_time" =~ ^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
        display_error "时间格式错误: $run_time" "请使用 HH:MM 格式。"
        return 1
    fi

    local hour minute
    hour="$((10#${BASH_REMATCH[1]}))"
    minute="$((10#${BASH_REMATCH[2]}))"

    local command_text target_args vmid
    command_text="/usr/sbin/vzdump"
    if [[ "$scope" == "3" ]]; then
        command_text+=" --all 1"
    else
        target_args=""
        while IFS= read -r vmid; do
            [[ "$vmid" =~ ^[0-9]+$ ]] || {
                display_error "检测到非法 VMID: $vmid" "已拒绝将未经校验的文本写入 root cron。"
                return 1
            }
            target_args+=" $vmid"
        done <<< "$job_targets"
        [[ -n "$target_args" ]] || {
            display_error "未生成有效的 VMID 参数"
            return 1
        }
        command_text+="$target_args"
    fi
    command_text+=" --storage $store --compress $compress --mode $mode"
    if (( keep_last > 0 )); then
        command_text+=" --prune-backups keep-last=$keep_last"
    fi

    if ! confirm_high_risk_action "写入 VM 定时备份任务" "计划任务会以 root 权限定期执行 vzdump，并持续占用 IO、CPU 与备份存储容量。" "错误的 VMID、存储或保留策略会周期性影响生产负载，问题会反复发生。" "请确认执行时间、目标范围、备份存储与保留策略均已核对。" "CRON-BACKUP"; then
        return 0
    fi

    local marker="VMBACKUP_${target_label}_$(date +%Y%m%d%H%M%S)"
    local cron_line="$minute $hour * * * root $command_text >/var/log/pve-tools-vm-backup.log 2>&1"

    touch "$VM_BACKUP_CRON_FILE"
    apply_block "$VM_BACKUP_CRON_FILE" "$marker" "$cron_line"
    systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    display_success "定时备份任务已写入" "cron 标记: $marker"
}
vm_schedule_remove_backup_job() {
    if [[ ! -f "$VM_BACKUP_CRON_FILE" ]]; then
        display_error "当前没有定时备份任务"
        return 1
    fi

    local markers
    markers="$(grep '^# PVE-TOOLS BEGIN VMBACKUP_' "$VM_BACKUP_CRON_FILE" 2>/dev/null | awk '{print $4}')"
    if [[ -z "$markers" ]]; then
        display_error "当前没有定时备份任务"
        return 1
    fi

    echo -e "${CYAN}当前定时备份任务：${NC}"
    grep -E '^[^#]' "$VM_BACKUP_CRON_FILE" 2>/dev/null | sed 's/^/  /'
    echo -e "${UI_DIVIDER}"
    echo "$markers" | awk '{printf "  [%d] %s\n", NR, $1}'
    echo -e "${UI_DIVIDER}"

    local pick marker
    read -p "请选择要删除的任务序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    marker="$(echo "$markers" | awk -v n="$pick" 'NR==n{print $1}')"
    [[ -n "$marker" ]] || return 1

    remove_block "$VM_BACKUP_CRON_FILE" "$marker"
    systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    display_success "定时备份任务已删除" "$marker"
}
vm_schedule_backup_menu() {
    while true; do
        clear
        show_menu_header "VM 定时备份"
        echo -e "${YELLOW}当前任务：${NC}"
        if [[ -f "$VM_BACKUP_CRON_FILE" ]]; then
            grep -E '^[^#]' "$VM_BACKUP_CRON_FILE" 2>/dev/null | sed 's/^/  /' || true
        else
            echo "  暂无定时任务"
        fi
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "新增定时备份任务"
        show_menu_option "2" "删除定时备份任务"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) vm_schedule_add_backup_job ;;
            2) vm_schedule_remove_backup_job ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
