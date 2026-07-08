#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_cluster_migrate() {
    vm_require_commands qm || return 1

    local vmid target_node with_local live_mode storage_mode target_storage cfg status
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    target_node="$(vm_select_target_node)"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_node" ]] || {
        display_error "未发现可用的目标节点" "请确认当前处于多节点集群环境。"
        return 1
    }

    cfg="$(qm config "$vmid" 2>/dev/null)"
    if echo "$cfg" | grep -qE '^hostpci[0-9]+:'; then
        log_warn "检测到该 VM 使用 PCI/直通设备，迁移前请确认目标节点拥有相同硬件。"
    fi

    read -p "是否携带本地磁盘一起迁移？(yes/no) [yes]: " with_local
    with_local="${with_local:-yes}"
    status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}' | head -n 1)"
    if [[ "$status" == "running" ]]; then
        read -p "是否启用在线迁移？(yes/no) [yes]: " live_mode
        live_mode="${live_mode:-yes}"
    else
        live_mode="no"
    fi

    {
        show_menu_option "1" "目标节点同名存储映射（--targetstorage 1）"
        show_menu_option "2" "统一迁移到指定存储"
        show_menu_option "3" "不指定 targetstorage"
    }
    read -p "请选择目标存储策略 [1-3]: " storage_mode
    case "$storage_mode" in
        1) target_storage='1' ;;
        2)
            target_storage="$(vm_select_storage_by_content images "请选择迁移目标存储")"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 0
            [[ -n "$target_storage" ]] || return 1
            ;;
        3) target_storage='' ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    local -a cmd=(qm migrate "$vmid" "$target_node")
    if [[ "$with_local" == "yes" || "$with_local" == "YES" ]]; then
        cmd+=(--with-local-disks 1)
    fi
    if [[ "$live_mode" == "yes" || "$live_mode" == "YES" ]]; then
        cmd+=(--online 1)
    fi
    [[ -n "$target_storage" ]] && cmd+=(--targetstorage "$target_storage")

    if ! confirm_high_risk_action "将 VM $vmid 迁移到节点 $target_node" "迁移会改写 VM 所在节点与磁盘位置；带本地盘迁移时对网络、存储映射和目标节点能力要求更高。" "目标节点、目标存储或在线迁移条件判断错误时，可能造成任务失败、停机或业务抖动。" "请确认目标节点在线、存储映射正确，并已评估直通设备与维护窗口。" "MIGRATE"; then
        return 0
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "迁移失败" "请检查节点连通性、存储映射和日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    display_success "迁移任务已提交" "目标节点: $target_node"
}
