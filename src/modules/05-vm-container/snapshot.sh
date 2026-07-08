#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_get_snapshot_names() {
    local vmid="$1"
    qm listsnapshot "$vmid" 2>/dev/null | awk 'NR>1 && $1 != "current" {print $1}'
}
vm_select_snapshot_name() {
    local vmid="$1"
    local snapshots
    snapshots="$(vm_get_snapshot_names "$vmid")"
    [[ -n "$snapshots" ]] || return 1

    {
        echo -e "${CYAN}当前快照列表：${NC}"
        echo "$snapshots" | awk '{printf "  [%d] %s\n", NR, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick name
    read -p "请选择快照序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    name="$(echo "$snapshots" | awk -v n="$pick" 'NR==n{print $1}')"
    [[ -n "$name" ]] || return 1
    echo "$name"
}
vm_create_snapshot() {
    vm_require_commands qm || return 1

    local vmids_text snapshot_name description
    vmids_text="$(vm_collect_target_vmids)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmids_text" ]] || return 1
    local -a vmids
    mapfile -t vmids < <(printf '%s\n' "$vmids_text" | awk 'NF')

    read -p "请输入快照名称: " snapshot_name
    [[ "$snapshot_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
        display_error "快照名称格式无效" "仅支持字母、数字、点、下划线和中划线。"
        return 1
    }
    read -p "请输入快照描述（留空跳过）: " description

    local success=0 failed=0 vmid
    for vmid in "${vmids[@]}"; do
        if [[ -n "$description" ]]; then
            if qm snapshot "$vmid" "$snapshot_name" --description "$description" >/dev/null 2>&1; then
                ((success++))
            else
                ((failed++))
            fi
        else
            if qm snapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
                ((success++))
            else
                ((failed++))
            fi
        fi
    done

    display_success "快照创建任务完成" "成功: $success, 失败: $failed"
}
vm_list_snapshots() {
    vm_require_commands qm || return 1
    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    clear
    show_menu_header "快照列表"
    qm listsnapshot "$vmid" 2>/dev/null | sed 's/^/  /'
    echo -e "${UI_DIVIDER}"
}
vm_delete_snapshot() {
    vm_require_commands qm || return 1
    local vmid snapshot_name
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    snapshot_name="$(vm_select_snapshot_name "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$snapshot_name" ]] || return 1

    if ! confirm_high_risk_action "删除 VM $vmid 的快照 $snapshot_name" "删除快照后将失去对应时间点的快速回退能力。" "若该快照是重要恢复点，误删后只能依赖外部备份或更高成本的恢复手段。" "请确认该快照不再承担回滚基线，并已保留外部备份。" "DROP-SNAP"; then
        return 0
    fi

    if ! qm delsnapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
        display_error "删除快照失败" "请检查快照名称和日志输出。"
        return 1
    fi

    display_success "快照已删除" "$snapshot_name"
}
vm_rollback_snapshot() {
    vm_require_commands qm || return 1
    local vmid snapshot_name
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    snapshot_name="$(vm_select_snapshot_name "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$snapshot_name" ]] || return 1

    if ! confirm_high_risk_action "将 VM $vmid 回滚到快照 $snapshot_name" "回滚会把磁盘与配置状态拉回到旧时间点，之后的数据写入可能丢失。" "如果当前业务数据尚未导出或备份，回滚可能造成不可逆的新数据丢失。" "请确认当前数据已备份，且业务方已批准回退到该时间点。" "ROLLBACK"; then
        return 0
    fi

    if ! qm rollback "$vmid" "$snapshot_name" >/dev/null 2>&1; then
        display_error "快照回滚失败" "请检查 VM 状态和日志输出。"
        return 1
    fi

    display_success "快照回滚完成" "$snapshot_name"
}
vm_snapshot_menu() {
    while true; do
        clear
        show_menu_header "快照管理"
        vm_show_data_risk_banner
        show_menu_option "1" "创建快照（支持批量）"
        show_menu_option "2" "列出 VM 快照"
        show_menu_option "3" "删除快照"
        show_menu_option "4" "回滚到快照"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_create_snapshot ;;
            2) vm_list_snapshots ;;
            3) vm_delete_snapshot ;;
            4) vm_rollback_snapshot ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
