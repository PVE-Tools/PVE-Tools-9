#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_list_template_records() {
    local records vmid name status
    records="$(vm_list_vm_records)"
    [[ -n "$records" ]] || return 0
    while IFS='|' read -r vmid name status; do
        if vm_is_template "$vmid"; then
            printf '%s|%s|%s\n' "$vmid" "$name" "$status"
        fi
    done <<< "$records"
}
vm_show_template_records() {
    local templates
    templates="$(vm_list_template_records)"
    if [[ -z "$templates" ]]; then
        echo -e "${YELLOW}当前没有模板虚拟机${NC}"
        return 0
    fi
    echo -e "${CYAN}模板列表：${NC}"
    echo "$templates" | awk -F'|' '{printf "  VMID: %-6s Name: %-22s Status: %s\n", $1, $2, $3}'
}
vm_convert_to_template() {
    vm_require_commands qm || return 1

    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    if vm_is_template "$vmid"; then
        display_error "该 VM 已经是模板"
        return 1
    fi

    vm_ensure_vm_config_backup "$vmid"
    if ! confirm_high_risk_action "将 VM $vmid 转换为模板" "模板化会改变 VM 的交付语义，后续不应再把它当作普通生产实例直接运行。" "如果选错对象，可能误把正在使用的业务 VM 转为模板，影响后续运维与交付。" "请确认该 VM 已停机或处于预期状态，并已导出配置或留存快照。" "TEMPLATE"; then
        return 0
    fi

    if ! qm template "$vmid" >/dev/null 2>&1; then
        display_error "模板转换失败" "请检查 VM 状态和任务日志。"
        return 1
    fi

    display_success "模板转换完成" "VMID: $vmid"
}
vm_clone_vm() {
    vm_require_commands qm || return 1

    local mode="$1"
    local source_vmid
    source_vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$source_vmid" ]] || return 1

    if [[ "$mode" == "linked" ]] && ! vm_is_template "$source_vmid"; then
        display_error "链接克隆仅支持模板虚拟机" "请先将源 VM 转换为模板。"
        return 1
    fi

    local new_vmid new_name full_flag store
    read -p "请输入新的 VMID: " new_vmid
    vm_validate_new_vmid "$new_vmid" || return 1
    read -p "请输入新 VM 名称 [clone-$new_vmid]: " new_name
    new_name="${new_name:-clone-$new_vmid}"

    full_flag=1
    if [[ "$mode" == "linked" ]]; then
        full_flag=0
    else
        store="$(vm_select_storage_by_content images "请选择完整克隆目标存储")"
        rc=$?
        [[ "$rc" -eq 2 ]] && return 0
        [[ -n "$store" ]] || return 1
    fi

    local -a cmd=(qm clone "$source_vmid" "$new_vmid" --name "$new_name" --full "$full_flag")
    if [[ "$full_flag" -eq 1 && -n "$store" ]]; then
        cmd+=(--storage "$store")
    fi

    if ! confirm_high_risk_action "从 VM $source_vmid 创建 ${mode} 克隆到 $new_vmid" "克隆会复制或引用源磁盘，完整克隆会大量占用空间，链接克隆依赖模板与底层存储能力。" "目标存储、模板状态或 VMID 选择错误时，可能产生错误副本或交付错误实例。" "请确认源 VM、目标 VMID、目标存储和交付计划均已核对。" "CLONE"; then
        return 0
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "克隆失败" "请检查源 VM 状态、目标存储及日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    display_success "克隆完成" "新 VMID: $new_vmid"
}
