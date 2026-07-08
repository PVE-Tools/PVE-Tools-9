#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

qm_is_q35_machine() {
    local vmid="$1"
    local machine
    machine="$(qm config "$vmid" 2>/dev/null | awk -F': ' '/^machine:/{print $2}' | head -n 1)"
    if echo "$machine" | grep -q 'q35'; then
        return 0
    fi
    return 1
}

# 获取可用的 hostpci 插槽号（0-15）
qm_find_free_hostpci_index() {
    local vmid="$1"
    local cfg used
    cfg="$(qm config "$vmid" 2>/dev/null)"
    used="$(echo "$cfg" | awk -F'[: ]' '/^hostpci[0-9]+:/{gsub("hostpci","",$1); print $1}' | sort -n | uniq)"

    local i
    for ((i=0; i<=15; i++)); do
        if ! echo "$used" | grep -qx "$i"; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# 从 VM 配置中查找某个 BDF 是否已被直通
qm_has_hostpci_bdf() {
    local vmid="$1"
    local bdf="$2"
    qm config "$vmid" 2>/dev/null | grep -qE "^hostpci[0-9]+:.*\\b${bdf}\\b"
}

# 直通整个 SATA/SCSI/RAID 控制器到 VM（含系统盘控制器保护）
storage_controller_passthrough() {
    log_step "磁盘控制器直通 - 扫描控制器"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local controllers
    controllers="$(list_storage_controllers)"
    if [[ -z "$controllers" ]]; then
        display_error "未发现 SATA/SCSI/RAID 控制器" "可尝试手工执行 lspci -Dnn 确认控制器是否存在。"
        return 1
    fi

    echo -e "${CYAN}可用控制器列表：${NC}"
    echo "$controllers" | awk '{printf "  [%d] %s\n", NR, $0}'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择控制器序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$controllers" | awk -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$line" ]]; then
        display_error "无效的序号: $pick"
        return 1
    fi
    bdf="$(echo "$line" | awk '{print $1}')"

    echo -e "${CYAN}该控制器下识别到的整盘设备：${NC}"
    show_disks_under_pci_bdf "$bdf"
    echo -e "${UI_DIVIDER}"

    local protected
    protected="$(get_protected_pci_bdfs)"
    if echo "$protected" | grep -qx "$bdf"; then
        display_error "安全拦截：禁止直通系统盘所在控制器 $bdf" "请勿直通包含 PVE 系统盘的控制器，否则会导致宿主机不可用。"
        return 1
    fi

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi

    if qm_has_hostpci_bdf "$vmid" "$bdf"; then
        display_error "该控制器已在 VM 配置中存在直通记录" "无需重复直通。"
        return 1
    fi

    local idx
    idx="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15 后再试。"
        return 1
    }

    local hostpci_value="$bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci_value="${hostpci_value},pcie=1"
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 直通控制器（hostpci$idx = $hostpci_value）"; then
        return 0
    fi

    if qm set "$vmid" "-hostpci${idx}" "$hostpci_value" >/dev/null 2>&1; then
        local status
        status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}' | head -n 1)"
        display_success "控制器直通已写入 VM 配置" "当前 VM 状态: ${status:-unknown}（如在运行中，需重启 VM 后生效）"
        return 0
    else
        display_error "qm set 执行失败" "请检查 IOMMU/IOMMU group、VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi
}

# 判断 NVMe 设备是否建议启用 MSI-X 重定位（启发式：存在 MSI-X 且存在 BAR2/Region 2）
nvme_should_enable_msix_relocation() {
    local bdf="$1"
    local vv
    vv="$(lspci -vv -s "$bdf" 2>/dev/null || true)"
    if echo "$vv" | grep -q 'MSI-X:' && echo "$vv" | grep -qE 'Region 2: Memory|Region 2:.*Memory'; then
        return 0
    fi
    return 1
}

# 获取当前 VM args（不存在则返回空）
qm_get_args() {
    local vmid="$1"
    qm config "$vmid" 2>/dev/null | awk -F': ' '/^args:/{sub(/^args: /,""); print $0; exit}'
}

# 幂等追加 VM args 片段（通过 qm set -args 覆盖式写入，但内容基于现有 args 合并）
qm_append_args() {
    local vmid="$1"
    local token="$2"

    if [[ -z "$token" ]]; then
        return 1
    fi

    local current
    current="$(qm_get_args "$vmid")"
    if echo "$current" | grep -Fq "$token"; then
        return 0
    fi

    local new_args
    if [[ -z "$current" ]]; then
        new_args="$token"
    else
        new_args="${current} ${token}"
    fi

    qm set "$vmid" -args "$new_args" >/dev/null 2>&1
}

# NVMe 控制器直通到 VM（含系统盘控制器保护与 MSI-X 重定位 args）
nvme_passthrough() {
    log_step "NVMe 直通 - 扫描 NVMe 控制器"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local controllers
    controllers="$(list_nvme_controllers)"
    if [[ -z "$controllers" ]]; then
        display_error "未发现 NVMe 控制器" "可尝试手工执行 lspci -Dnn | grep -i NVMe 确认设备是否存在。"
        return 1
    fi

    echo -e "${CYAN}可用 NVMe 控制器列表：${NC}"
    echo "$controllers" | awk '{printf "  [%d] %s\n", NR, $0}'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择 NVMe 控制器序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$controllers" | awk -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$line" ]]; then
        display_error "无效的序号: $pick"
        return 1
    fi
    bdf="$(echo "$line" | awk '{print $1}')"

    echo -e "${CYAN}该 NVMe 控制器下识别到的整盘设备：${NC}"
    show_disks_under_pci_bdf "$bdf"
    echo -e "${UI_DIVIDER}"

    local protected
    protected="$(get_protected_pci_bdfs)"
    if echo "$protected" | grep -qx "$bdf"; then
        display_error "安全拦截：禁止直通系统盘所在 NVMe 控制器 $bdf" "请勿直通包含 PVE 系统盘的 NVMe 控制器，否则会导致宿主机不可用。"
        return 1
    fi

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi

    if qm_has_hostpci_bdf "$vmid" "$bdf"; then
        display_error "该 NVMe 已在 VM 配置中存在直通记录" "无需重复直通。"
        return 1
    fi

    local idx
    idx="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15 后再试。"
        return 1
    }

    local hostpci_value="$bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci_value="${hostpci_value},pcie=1"
    fi

    local enable_msix="no"
    if nvme_should_enable_msix_relocation "$bdf"; then
        echo -e "${YELLOW}检测到该 NVMe 可能需要 MSI-X 重定位（bar2）以提高兼容性。${NC}"
        local ans
        read -p "是否写入 MSI-X 重定位 args？(yes/no) [yes]: " ans
        ans="${ans:-yes}"
        if [[ "$ans" == "yes" || "$ans" == "YES" ]]; then
            enable_msix="yes"
        fi
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 直通 NVMe（hostpci$idx = $hostpci_value），并写入 MSI-X 重定位参数（${enable_msix}）"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx}" "$hostpci_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 IOMMU/IOMMU group、VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$enable_msix" == "yes" ]]; then
        local token
        token="-set device.hostpci${idx}.x-msix-relocation=bar2"
        if qm_append_args "$vmid" "$token"; then
            log_success "已写入 args: $token"
        else
            log_warn "args 写入失败（已完成 hostpci 直通）"
        fi
    fi

    local status
    status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}' | head -n 1)"
    display_success "NVMe 直通已写入 VM 配置" "当前 VM 状态: ${status:-unknown}（如在运行中，需重启 VM 后生效）"
    return 0
}

# ============ 引导配置辅助 ============

# 解析用户输入的磁盘路径为真实整盘设备（返回 /dev/sdX 或 /dev/nvme0n1）
