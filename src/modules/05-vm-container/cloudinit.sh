#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

vm_ensure_vm_config_backup() {
    local vmid="$1"
    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi
}
vm_ensure_cloudinit_drive() {
    local vmid="$1"
    local store="$2"
    local cfg slot
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if echo "$cfg" | grep -Eq '^(ide2|scsi2): .*cloudinit'; then
        return 0
    fi

    slot="ide2"
    if echo "$cfg" | grep -q '^ide2:'; then
        slot="scsi2"
        if echo "$cfg" | grep -q '^scsi2:'; then
            display_error "无法自动添加 Cloud-Init 盘" "ide2 与 scsi2 都已被占用，请先释放一个插槽。"
            return 1
        fi
    fi

    if ! qm set "$vmid" "-$slot" "$store:cloudinit" >/dev/null 2>&1; then
        display_error "添加 Cloud-Init 盘失败" "请检查存储 $store 是否支持 images 内容类型。"
        return 1
    fi
}
vm_validate_cicustom_volumes() {
    local raw="$1"
    local ref volume store
    IFS=',' read -r -a refs <<< "$raw"
    for ref in "${refs[@]}"; do
        volume="${ref#*=}"
        store="${volume%%:*}"
        if [[ -z "$store" || "$store" == "$volume" ]]; then
            log_error "cicustom 引用格式无效: $ref"
            return 1
        fi
        if ! vm_storage_supports_content "$store" snippets; then
            log_error "存储 $store 不支持 snippets 内容类型，无法作为 cicustom 来源"
            return 1
        fi
    done
}
vm_cloudinit_configure_for_vmid() {
    local vmid="$1"
    vm_require_commands qm pvesm || return 1

    local cfg ci_store
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if ! echo "$cfg" | grep -Eq '^(ide2|scsi2): .*cloudinit'; then
        ci_store="$(vm_select_storage_by_content images "请选择 Cloud-Init 盘存储")"
        local rc=$?
        [[ "$rc" -eq 2 ]] && return 0
        [[ -n "$ci_store" ]] || return 1
        vm_ensure_cloudinit_drive "$vmid" "$ci_store" || return 1
    fi

    local ciuser cipassword ipconfig0 nameserver searchdomain citype sshkeys_path cicustom console_mode
    read -p "Cloud-Init 用户名（留空跳过）: " ciuser
    read -p "Cloud-Init 密码（留空跳过）: " cipassword
    read -p "网络配置 ipconfig0（示例 ip=dhcp 或 ip=192.168.1.10/24,gw=192.168.1.1，留空跳过）: " ipconfig0
    read -p "nameserver（留空跳过）: " nameserver
    read -p "searchdomain（留空跳过）: " searchdomain
    read -p "citype (nocloud/configdrive2/opennebula，留空跳过) [nocloud]: " citype
    citype="${citype:-nocloud}"
    read -p "SSH 公钥文件路径（留空跳过）: " sshkeys_path
    if [[ -n "$sshkeys_path" && ! -f "$sshkeys_path" ]]; then
        display_error "SSH 公钥文件不存在: $sshkeys_path"
        return 1
    fi
    read -p "cicustom（示例 user=local:snippets/user.yaml，留空跳过）: " cicustom
    if [[ -n "$cicustom" ]]; then
        vm_validate_cicustom_volumes "$cicustom" || return 1
    fi
    read -p "是否启用串口控制台输出？(yes/no) [yes]: " console_mode
    console_mode="${console_mode:-yes}"

    local -a cmd=(qm set "$vmid")
    [[ -n "$ciuser" ]] && cmd+=(--ciuser "$ciuser")
    [[ -n "$cipassword" ]] && cmd+=(--cipassword "$cipassword")
    [[ -n "$ipconfig0" ]] && cmd+=(--ipconfig0 "$ipconfig0")
    [[ -n "$nameserver" ]] && cmd+=(--nameserver "$nameserver")
    [[ -n "$searchdomain" ]] && cmd+=(--searchdomain "$searchdomain")
    [[ -n "$citype" ]] && cmd+=(--citype "$citype")
    [[ -n "$sshkeys_path" ]] && cmd+=(--sshkeys "$sshkeys_path")
    [[ -n "$cicustom" ]] && cmd+=(--cicustom "$cicustom")

    if (( ${#cmd[@]} > 2 )); then
        if ! confirm_high_risk_action "写入 VM $vmid 的 Cloud-Init 参数" "会直接覆盖现有 Cloud-Init 用户、密码、网络、DNS、SSH 密钥或 cicustom 指向。" "后续启动、重新生成 cloud-init 数据或交付克隆时，实例身份与网络行为可能发生变化。" "请确认参数、snippets 来源与 SSH 公钥均正确，并已记录旧配置。" "CLOUDINIT"; then
            return 0
        fi
        if ! "${cmd[@]}" >/dev/null 2>&1; then
            display_error "Cloud-Init 参数写入失败" "请检查参数格式、snippets 存储和日志输出。"
            return 1
        fi
    fi

    if [[ "$console_mode" == "yes" || "$console_mode" == "YES" ]]; then
        qm set "$vmid" --serial0 socket --vga serial0 >/dev/null 2>&1 || log_warn "串口控制台配置失败，可稍后手工设置。"
    fi

    display_success "Cloud-Init 配置已写入" "可使用 qm cloudinit dump $vmid user 查看生成结果。"
}
vm_cloudinit_configure() {
    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    vm_cloudinit_configure_for_vmid "$vmid"
}
vm_cloud_image_to_template() {
    vm_require_commands qm pvesm qemu-img || return 1

    local image_path
    image_path="$(img_select_img_file)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$image_path" ]] || return 1

    local vmid vm_name memory cores bridge image_store ci_store
    read -p "请输入新的 VMID: " vmid
    vm_validate_new_vmid "$vmid" || return 1
    read -p "请输入 VM 名称 [cloud-template-$vmid]: " vm_name
    vm_name="${vm_name:-cloud-template-$vmid}"
    read -p "内存大小 MB [2048]: " memory
    memory="${memory:-2048}"
    read -p "CPU 核心数 [2]: " cores
    cores="${cores:-2}"
    read -p "默认桥接 [${VM_DEFAULT_CLOUDINIT_BRIDGE}]: " bridge
    bridge="${bridge:-$VM_DEFAULT_CLOUDINIT_BRIDGE}"

    image_store="$(vm_select_storage_by_content images "请选择系统盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$image_store" ]] || return 1
    ci_store="$(vm_select_storage_by_content images "请选择 Cloud-Init 盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$ci_store" ]] || return 1

    if ! confirm_high_risk_action "基于镜像 $image_path 创建 VM $vmid 并导入系统盘" "该流程会创建新 VM、写入磁盘卷并占用目标存储；镜像、VMID 或目标存储选错时会把流程导向错误对象。" "可能产生错误模板、错误网络配置或额外占用大量存储空间。" "请确认镜像来源可信，目标 VMID 空闲，系统盘存储与 Cloud-Init 存储已核对。" "IMPORT-IMAGE"; then
        return 0
    fi

    if ! qm create "$vmid" --name "$vm_name" --memory "$memory" --cores "$cores" --net0 "virtio,bridge=$bridge" >/dev/null 2>&1; then
        display_error "基础 VM 创建失败" "请检查参数和当前集群状态。"
        return 1
    fi

    local import_out vol
    if ! import_out="$(qm importdisk "$vmid" "$image_path" "$image_store" 2>&1)"; then
        echo "$import_out" | sed 's/^/  /'
        display_error "云镜像导入失败" "请检查镜像格式、目标存储空间和日志输出。"
        return 1
    fi

    vol="$(echo "$import_out" | sed -n "s/.*as '\([^']\+\)'.*/\1/p" | tail -n 1)"
    [[ -z "$vol" ]] && vol="$(echo "$import_out" | grep -oE "${image_store}:[^ ]+" | tail -n 1)"
    if [[ -z "$vol" ]]; then
        display_error "无法解析导入后的卷 ID" "请手动查看 qm importdisk 输出后继续处理。"
        return 1
    fi

    if ! qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$vol" --boot order=scsi0 --ide2 "$ci_store:cloudinit" --serial0 socket --vga serial0 --agent 1 >/dev/null 2>&1; then
        display_error "模板基础参数写入失败" "请检查存储、控制器类型与日志输出。"
        return 1
    fi

    vm_cloudinit_configure_for_vmid "$vmid"

    if confirm_high_risk_action "将 VM $vmid 转换为云镜像模板" "模板化后该 VM 会被视为母版，后续克隆将继承当前磁盘与 Cloud-Init 状态。" "如果模板内容未校验，错误会被批量复制到后续所有实例。" "请确认系统盘、Cloud-Init 与基础软件状态均已验证，再执行模板转换。" "TEMPLATE"; then
        qm template "$vmid" >/dev/null 2>&1 || {
            display_error "模板转换失败" "请检查当前任务状态。"
            return 1
        }
    fi

    display_success "云镜像模板准备完成" "VMID: $vmid"
}
vm_template_cloudinit_menu() {
    while true; do
        clear
        show_menu_header "模板 / 克隆 / Cloud-Init"
        vm_show_data_risk_banner
        show_menu_option "1" "列出所有模板"
        show_menu_option "2" "将现有 VM 转换为模板"
        show_menu_option "3" "完整克隆 VM"
        show_menu_option "4" "链接克隆模板"
        show_menu_option "5" "导入云镜像并生成模板"
        show_menu_option "6" "配置 Cloud-Init 参数"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-6]: " choice
        case "$choice" in
            1) vm_show_template_records ;;
            2) vm_convert_to_template ;;
            3) vm_clone_vm full ;;
            4) vm_clone_vm linked ;;
            5) vm_cloud_image_to_template ;;
            6) vm_cloudinit_configure ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
