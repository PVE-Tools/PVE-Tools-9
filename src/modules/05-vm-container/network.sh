#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_configure_startup_policy() {
    vm_require_commands qm || return 1
    local vmid onboot boot_order startup_cfg
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    read -p "是否开机自启？(yes/no/skip) [skip]: " onboot
    onboot="${onboot:-skip}"
    read -p "启动顺序（示例 scsi0;ide2;net0，留空跳过）: " boot_order
    read -p "启动策略（示例 order=1,up=30,down=30，留空跳过）: " startup_cfg

    if [[ "$onboot" == "yes" || "$onboot" == "YES" ]]; then
        qm set "$vmid" --onboot 1 >/dev/null 2>&1 || log_warn "设置 onboot 失败"
    elif [[ "$onboot" == "no" || "$onboot" == "NO" ]]; then
        qm set "$vmid" --onboot 0 >/dev/null 2>&1 || log_warn "设置 onboot 失败"
    fi

    [[ -n "$boot_order" ]] && qm set "$vmid" --boot "order=$boot_order" >/dev/null 2>&1 || true
    [[ -n "$startup_cfg" ]] && qm set "$vmid" --startup "$startup_cfg" >/dev/null 2>&1 || true
    display_success "启动策略已更新" "VMID: $vmid"
}
vm_add_network() {
    vm_require_commands qm || return 1
    local vmid bridge vlan model idx net_value
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    idx="$(vm_find_free_net_index "$vmid")"
    [[ -n "$idx" ]] || {
        display_error "未找到可用网卡插槽"
        return 1
    }

    read -p "网卡模型 (virtio/e1000/vmxnet3) [virtio]: " model
    model="${model:-virtio}"
    read -p "桥接名称 [vmbr0]: " bridge
    bridge="${bridge:-vmbr0}"
    read -p "VLAN Tag（留空不设置）: " vlan

    net_value="$model,bridge=$bridge"
    [[ -n "$vlan" ]] && net_value="$net_value,tag=$vlan"

    if ! qm set "$vmid" "-net$idx" "$net_value" >/dev/null 2>&1; then
        display_error "添加网卡失败" "请检查桥接、VLAN 和日志输出。"
        return 1
    fi

    display_success "网卡添加完成" "net$idx = $net_value"
}
vm_remove_network() {
    vm_require_commands qm || return 1
    local vmid slot
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_net_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    if ! confirm_action "删除 VM $vmid 的网卡 $slot？"; then
        return 0
    fi
    if ! qm set "$vmid" --delete "$slot" >/dev/null 2>&1; then
        display_error "删除网卡失败" "请检查 VM 状态和日志输出。"
        return 1
    fi

    display_success "网卡已删除" "$slot"
}
vm_modify_network() {
    vm_require_commands qm || return 1
    local vmid slot current bridge current_bridge current_tag vlan_input updated
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_net_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    current="$(vm_get_qm_value "$vmid" "$slot")"
    current_bridge="$(echo "$current" | sed -n 's/.*bridge=\([^,]*\).*/\1/p')"
    current_tag="$(echo "$current" | sed -n 's/.*tag=\([^,]*\).*/\1/p')"

    read -p "桥接名称 [${current_bridge:-vmbr0}]: " bridge
    bridge="${bridge:-${current_bridge:-vmbr0}}"
    read -p "VLAN Tag（留空保持当前，输入 none 清除） [${current_tag:-none}]: " vlan_input

    updated="$(vm_network_set_option "$current" bridge "$bridge")"
    if [[ "$vlan_input" == "none" || "$vlan_input" == "NONE" ]]; then
        updated="$(vm_network_remove_option "$updated" tag)"
    elif [[ -n "$vlan_input" ]]; then
        updated="$(vm_network_set_option "$updated" tag "$vlan_input")"
    fi

    if ! qm set "$vmid" "-$slot" "$updated" >/dev/null 2>&1; then
        display_error "更新网卡失败" "请检查 bridge/VLAN 参数和日志输出。"
        return 1
    fi

    display_success "网卡参数已更新" "$slot = $updated"
}
vm_startup_network_menu() {
    while true; do
        clear
        show_menu_header "启动顺序与网络管理"
        vm_show_data_risk_banner
        show_menu_option "1" "设置开机自启 / 启动顺序 / 启动延迟"
        show_menu_option "2" "添加网卡"
        show_menu_option "3" "移除网卡"
        show_menu_option "4" "修改 bridge / VLAN"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_configure_startup_policy ;;
            2) vm_add_network ;;
            3) vm_remove_network ;;
            4) vm_modify_network ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
