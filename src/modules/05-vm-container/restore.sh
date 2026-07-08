#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_select_backup_archive() {
    local archives
    archives="$(vm_discover_backup_archives)"
    if [[ -z "$archives" ]]; then
        local manual
        read -p "未自动发现备份文件，请手动输入备份文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}已发现备份文件：${NC}"
        echo "$archives" | awk -F'|' '{printf "  [%d] %-10s %-16s %s\n", NR, $2, $3, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line path
    read -p "请选择备份序号 (0 手动输入): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        local manual
        read -p "请输入备份文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$archives" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    path="$(echo "$line" | awk -F'|' '{print $1}')"
    [[ -n "$path" && -f "$path" ]] || return 1
    echo "$path"
}
vm_restore_from_backup() {
    vm_require_commands qmrestore qm pvesm || return 1

    local archive
    archive="$(vm_select_backup_archive)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$archive" ]] || return 1

    local new_vmid
    read -p "请输入新的 VMID: " new_vmid
    vm_validate_new_vmid "$new_vmid" || return 1

    local store
    store="$(vm_select_storage_by_content images "请选择恢复后的磁盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$store" ]] || return 1

    local unique start_after
    read -p "是否重新生成唯一标识（推荐 yes）?(yes/no) [yes]: " unique
    unique="${unique:-yes}"
    read -p "恢复后是否自动启动 VM？(yes/no) [no]: " start_after
    start_after="${start_after:-no}"

    clear
    show_menu_header "从备份恢复 VM"
    echo -e "${YELLOW}备份文件:${NC} $archive"
    echo -e "${YELLOW}新 VMID:${NC} $new_vmid"
    echo -e "${YELLOW}目标存储:${NC} $store"
    echo -e "${YELLOW}唯一标识重建:${NC} $unique"
    echo -e "${UI_DIVIDER}"

    if ! confirm_high_risk_action "从备份恢复为新 VM $new_vmid" "恢复会创建新的 VM 和磁盘卷；如果关闭唯一标识重建，还可能引入 MAC/系统标识冲突。" "可能大量占用目标存储，并在误选备份文件时恢复出错误业务数据。" "请确认备份文件来源、目标 VMID 与目标存储均已核对，并预留足够空间。" "RESTORE"; then
        return 0
    fi

    local -a cmd=(qmrestore "$archive" "$new_vmid" --storage "$store")
    if [[ "$unique" == "yes" || "$unique" == "YES" ]]; then
        cmd+=(--unique 1)
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "qmrestore 执行失败" "请检查备份文件、目标存储和日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    if [[ "$start_after" == "yes" || "$start_after" == "YES" ]]; then
        qm start "$new_vmid" >/dev/null 2>&1 || log_warn "自动启动 VM 失败，请手动检查。"
    fi
    display_success "恢复完成" "新 VMID: $new_vmid"
}
vm_backup_restore_menu() {
    while true; do
        clear
        show_menu_header "VM 备份与恢复"
        vm_show_data_risk_banner
        show_menu_option "1" "创建 VM 备份（vzdump）"
        show_menu_option "2" "从备份恢复为新 VM"
        show_menu_option "3" "定时备份任务管理"
        show_menu_option "4" "备份文件跨机恢复引导"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_backup_create ;;
            2) vm_restore_from_backup ;;
            3) vm_schedule_backup_menu ;;
            4) vm_backup_transfer_guide ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
