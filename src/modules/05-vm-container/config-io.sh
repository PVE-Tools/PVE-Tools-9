#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_discover_export_files() {
    if [[ -d "$VM_CONFIG_EXPORT_DIR" ]]; then
        find "$VM_CONFIG_EXPORT_DIR" -maxdepth 1 -type f -name 'vm-*.conf' -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null | sort -u
    fi
}
vm_select_export_file() {
    local files
    files="$(vm_discover_export_files)"
    if [[ -z "$files" ]]; then
        local manual
        read -p "未自动发现导出文件，请手动输入配置文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}已发现 VM 配置导出文件：${NC}"
        echo "$files" | awk -F'|' '{printf "  [%d] %-10s %-16s %s\n", NR, $2, $3, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line path
    read -p "请选择配置文件序号 (0 手动输入): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        local manual
        read -p "请输入配置文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$files" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    path="$(echo "$line" | awk -F'|' '{print $1}')"
    [[ -n "$path" && -f "$path" ]] || return 1
    echo "$path"
}
vm_export_config() {
    vm_require_commands qm || return 1

    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    mkdir -p "$VM_CONFIG_EXPORT_DIR"
    local output_file timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    output_file="$VM_CONFIG_EXPORT_DIR/vm-${vmid}-${timestamp}.conf"

    {
        echo "# PVE-Tools VM Export"
        echo "# source_vmid=${vmid}"
        echo "# source_node=$(hostname)"
        echo "# exported_at=$(date +%F' '%T)"
        qm config "$vmid"
    } > "$output_file"

    display_success "VM 配置已导出" "$output_file"
}
vm_import_config() {
    vm_require_commands qm || return 1

    local file
    file="$(vm_select_export_file)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$file" ]] || return 1

    local new_vmid
    read -p "请输入新的 VMID: " new_vmid
    vm_validate_new_vmid "$new_vmid" || return 1

    local exported_name new_name import_mode regenerate_mac
    exported_name="$(awk -F': ' '/^name: /{print $2; exit}' "$file")"
    read -p "请输入新 VM 名称 [${exported_name:-vm-$new_vmid}]: " new_name
    new_name="${new_name:-${exported_name:-vm-$new_vmid}}"
    read -p "导入模式 (config/rebind-disks) [config]: " import_mode
    import_mode="${import_mode:-config}"
    case "$import_mode" in
        config|rebind-disks) ;;
        *)
            display_error "不支持的导入模式: $import_mode" "仅支持 config 或 rebind-disks。"
            return 1
            ;;
    esac
    read -p "是否重建网卡 MAC 地址？(yes/no) [yes]: " regenerate_mac
    regenerate_mac="${regenerate_mac:-yes}"
    case "$regenerate_mac" in
        yes|YES|no|NO) ;;
        *)
            display_error "是否重建网卡 MAC 地址仅支持 yes/no"
            return 1
            ;;
    esac

    if [[ "$import_mode" == "rebind-disks" ]]; then
        if ! confirm_high_risk_action "以 rebind-disks 模式导入 VM $new_vmid" "该模式会把导出配置中的磁盘引用重新绑定到新 VM，选错卷会直接指向现有数据。" "错误重绑可能造成数据卷误挂载、业务串卷或后续误删风险。" "请逐项核对导出文件中的磁盘卷 ID，仅在确实理解每个卷来源时继续。" "REBIND-DISKS"; then
            return 0
        fi
    fi

    if ! confirm_high_risk_action "导入配置文件并创建新 VM $new_vmid" "配置回放会逐项写入新 VM；如果选择 rebind-disks，错误的磁盘引用可能绑定到不应接管的数据卷。" "可能造成新 VM 配置错误、网络冲突，或因错误重绑磁盘而影响现有数据卷识别。" "请确认导入文件来源可信，目标 VMID 空闲，并已核对磁盘引用与网卡规划。" "IMPORT-CONFIG"; then
        return 0
    fi

    local -a option_lines disk_lines failed_keys attached_disk_keys
    local bootdisk_value=""
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        [[ "$line" != *': '* ]] && continue
        local key="${line%%:*}"
        local value="${line#*: }"
        case "$key" in
            name|template|digest|lock|meta|parent|vmgenid|unused*|snapstate|runningmachine|runningcpu)
                continue
                ;;
            bootdisk)
                bootdisk_value="$value"
                continue
                ;;
            scsi*|sata*|virtio*|ide*|efidisk0|tpmstate0)
                disk_lines+=("$key|$value")
                continue
                ;;
            net*)
                if [[ "$regenerate_mac" == "yes" || "$regenerate_mac" == "YES" ]]; then
                    value="$(vm_network_strip_mac "$value")"
                fi
                option_lines+=("$key|$value")
                ;;
            *)
                option_lines+=("$key|$value")
                ;;
        esac
    done < "$file"

    if ! qm create "$new_vmid" --name "$new_name" >/dev/null 2>&1; then
        display_error "qm create 失败" "请检查 VMID 是否冲突，或查看任务日志。"
        return 1
    fi

    local entry key value
    for entry in "${option_lines[@]}"; do
        key="${entry%%|*}"
        value="${entry#*|}"
        if ! qm set "$new_vmid" "-$key" "$value" >/dev/null 2>&1; then
            failed_keys+=("$key")
        fi
    done

    if [[ "$import_mode" == "rebind-disks" ]]; then
        for entry in "${disk_lines[@]}"; do
            key="${entry%%|*}"
            value="${entry#*|}"
            if qm set "$new_vmid" "-$key" "$value" >/dev/null 2>&1; then
                attached_disk_keys+=("$key")
            else
                failed_keys+=("$key")
            fi
        done
        if [[ -n "$bootdisk_value" ]]; then
            if ! qm set "$new_vmid" --bootdisk "$bootdisk_value" >/dev/null 2>&1; then
                failed_keys+=("bootdisk")
            fi
        fi
    fi

    if (( ${#failed_keys[@]} > 0 )); then
        if [[ "$import_mode" == "rebind-disks" ]]; then
            local attached_key
            for attached_key in "${attached_disk_keys[@]}"; do
                qm set "$new_vmid" --delete "$attached_key" >/dev/null 2>&1 || log_warn "回滚重绑磁盘槽位失败: $attached_key"
            done
        fi

        if qm destroy "$new_vmid" --purge 1 >/dev/null 2>&1; then
            display_error "VM 配置导入失败，已自动回滚" "失败项: ${failed_keys[*]}"
        else
            display_error "VM 配置导入失败" "失败项: ${failed_keys[*]}；已尝试回滚，但自动清理未完成，请立即检查 VM $new_vmid。"
        fi
        return 1
    fi

    display_success "VM 配置导入完成" "新 VMID: $new_vmid"
}
vm_config_io_menu() {
    while true; do
        clear
        show_menu_header "VM 配置导入/导出"
        vm_show_data_risk_banner
        show_menu_option "1" "导出 VM 配置"
        show_menu_option "2" "导入 VM 配置"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) vm_export_config ;;
            2) vm_import_config ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
