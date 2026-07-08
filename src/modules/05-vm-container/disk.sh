#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_resize_disk() {
    vm_require_commands qm || return 1

    local vmid slot size_change
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_disk_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    read -p "请输入扩容值（示例 +10G 或 64G）: " size_change
    [[ -n "$size_change" ]] || return 1

    if ! confirm_high_risk_action "为 VM $vmid 的 $slot 执行磁盘扩容" "扩容通常不可逆；访客系统内若未正确扩展分区/文件系统，可能导致识别异常。" "错误的磁盘槽位或大小参数会把变更写到错误磁盘对象。" "请确认磁盘槽位、目标容量和访客系统扩容方案已准备完毕。" "RESIZE"; then
        return 0
    fi

    if qm disk resize "$vmid" "$slot" "$size_change" >/dev/null 2>&1 || qm resize "$vmid" "$slot" "$size_change" >/dev/null 2>&1; then
        display_success "磁盘扩容完成" "$slot -> $size_change"
    else
        display_error "磁盘扩容失败" "请检查磁盘插槽、大小参数和日志输出。"
        return 1
    fi
}
vm_add_disk() {
    vm_require_commands qm pvesm || return 1

    local vmid store bus slot disk_size
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    store="$(vm_select_storage_by_content images "请选择新磁盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$store" ]] || return 1

    read -p "磁盘总线类型 (scsi/sata/virtio/ide) [scsi]: " bus
    bus="${bus:-scsi}"
    slot="$(vm_find_free_disk_slot "$vmid" "$bus")"
    [[ -n "$slot" ]] || {
        display_error "未找到可用磁盘插槽" "请先释放对应总线插槽后再试。"
        return 1
    }

    read -p "磁盘大小（示例 32G / 512M）: " disk_size
    [[ "$disk_size" =~ ^[0-9]+[KMGTP]$ ]] || {
        display_error "磁盘大小格式错误" "请使用类似 32G、512M 的格式。"
        return 1
    }

    vm_ensure_vm_config_backup "$vmid"
    if ! confirm_high_risk_action "为 VM $vmid 添加磁盘 $slot" "将立即在目标存储分配新卷并写入 VM 配置。" "错误的总线、存储或容量选择会造成资源浪费，甚至影响后续系统盘识别。" "请确认目标存储、总线类型与容量规划已核对。" "ADDDISK"; then
        return 0
    fi

    if ! qm set "$vmid" "-$slot" "$store:$disk_size" >/dev/null 2>&1; then
        display_error "添加磁盘失败" "请检查存储、容量与日志输出。"
        return 1
    fi

    display_success "磁盘添加完成" "$slot = $store:$disk_size"
}
vm_remove_disk() {
    vm_require_commands qm || return 1

    local vmid slot
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_disk_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    vm_ensure_vm_config_backup "$vmid"
    if ! confirm_high_risk_action "从 VM $vmid 删除磁盘插槽 $slot" "删除磁盘配置会让访客系统失去该磁盘引用，若误删系统盘或关键数据盘会导致业务中断。" "后续若继续写入或重新分配卷，数据恢复难度会快速上升。" "请确认该槽位不是系统关键盘，且已完成卷级备份或快照。" "DELETE"; then
        return 0
    fi

    if ! qm set "$vmid" --delete "$slot" >/dev/null 2>&1; then
        display_error "删除磁盘失败" "请检查 VM 锁定状态和日志输出。"
        return 1
    fi

    display_success "磁盘已移除" "$slot"
}
vm_move_disk() {
    vm_require_commands qm pvesm || return 1

    local vmid slot target_store delete_source
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_disk_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1
    target_store="$(vm_select_storage_by_content images "请选择目标存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_store" ]] || return 1
    read -p "迁移后是否删除源磁盘？(yes/no) [yes]: " delete_source
    delete_source="${delete_source:-yes}"

    if ! confirm_high_risk_action "将 VM $vmid 的 $slot 迁移到 $target_store" "迁移磁盘会复制或移动底层卷；若启用删除源盘，源卷在流程完成后会被清理。" "目标存储选错或空间不足时可能导致任务失败；删除源盘后回退复杂度更高。" "请确认目标存储、可用空间和是否删除源盘的策略已核对。" "MOVE-DISK"; then
        return 0
    fi

    if [[ "$delete_source" == "yes" || "$delete_source" == "YES" ]]; then
        qm disk move "$vmid" "$slot" "$target_store" --delete 1 >/dev/null 2>&1 || qm move_disk "$vmid" "$slot" "$target_store" --delete 1 >/dev/null 2>&1 || {
            display_error "磁盘迁移失败" "请检查存储状态和日志输出。"
            return 1
        }
    else
        qm disk move "$vmid" "$slot" "$target_store" >/dev/null 2>&1 || qm move_disk "$vmid" "$slot" "$target_store" >/dev/null 2>&1 || {
            display_error "磁盘迁移失败" "请检查存储状态和日志输出。"
            return 1
        }
    fi

    display_success "磁盘迁移完成" "$slot -> $target_store"
}
vm_disk_management_menu() {
    while true; do
        clear
        show_menu_header "虚拟机磁盘管理"
        vm_show_data_risk_banner
        show_menu_option "1" "磁盘扩容"
        show_menu_option "2" "添加磁盘"
        show_menu_option "3" "移除磁盘"
        show_menu_option "4" "迁移磁盘到其他存储"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_resize_disk ;;
            2) vm_add_disk ;;
            3) vm_remove_disk ;;
            4) vm_move_disk ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
