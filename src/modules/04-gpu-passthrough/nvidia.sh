#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

nvidia_t() {
    local key="$1"
    case "$key" in
        MENU_TITLE) echo "NVIDIA 显卡管理" ;;
        MENU_DESC) echo "请选择功能模块（高风险操作会强制二次确认）" ;;
        OPT_PT) echo "显卡直通虚拟机" ;;
        OPT_DRV_INFO) echo "驱动信息与监控" ;;
        OPT_DRV_SWITCH) echo "驱动切换（开源/闭源）" ;;
        OPT_HOST_PREP) echo "宿主机预配置（IOMMU/VFIO/黑名单）" ;;
        OPT_UNLOCK) echo "部署 vGPU Unlock（外部库）" ;;
        OPT_BACK) echo "返回" ;;
        ERR_NO_GPU) echo "未检测到 NVIDIA GPU" ;;
        ERR_IOMMU) echo "未检测到 IOMMU 已开启" ;;
        TIP_ENABLE_IOMMU) echo "请先开启 BIOS 的 VT-d/AMD-Vi，并在脚本中启用 IOMMU（硬件直通一键配置）。" ;;
        INPUT_CHOICE) echo "请选择操作" ;;
        INPUT_PICK) echo "请选择序号" ;;
        WARN_HIGH_RISK) echo "高风险操作：不同驱动性能侧重点不同，误操作可能导致宿主机不可用。" ;;
        OK_DONE) echo "操作完成" ;;
        *) echo "$key" ;;
    esac
}
nvidia_get_cols() {
    tput cols 2>/dev/null || echo 80
}
nvidia_trunc() {
    local s="$1"
    local w="$2"
    if [[ -z "$w" || "$w" -le 0 ]]; then
        echo "$s"
        return 0
    fi
    if [[ "${#s}" -le "$w" ]]; then
        echo "$s"
        return 0
    fi
    echo "${s:0:$((w-3))}..."
}
nvidia_list_vms() {
    qm list 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}'
}
nvidia_list_nvidia_gpus() {
    lspci -Dnn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller' | grep -i 'NVIDIA' | awk '{bdf=$1; sub(/^[0-9a-f]{4}:/,"",bdf); print $1 "|" $0}'
}
nvidia_get_pci_ids() {
    local bdf="$1"
    lspci -n -s "$bdf" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$/){print tolower($i); exit}}'
}
nvidia_pci_has_function() {
    local bdf="$1"
    local func="$2"
    local base
    base="${bdf%.*}"
    lspci -Dnn 2>/dev/null | awk '{print $1}' | grep -qx "${base}.${func}"
}
nvidia_pci_kernel_driver() {
    local bdf="$1"
    lspci -nnk -s "$bdf" 2>/dev/null | awk -F': ' '/Kernel driver in use:/{print $2; exit}'
}
nvidia_select_vmid() {
    local vms
    vms="$(nvidia_list_vms)"
    if [[ -z "$vms" ]]; then
        log_error "未发现虚拟机"
        log_tips "请先创建虚拟机后再操作。"
        return 1
    fi

    {
        echo -e "${CYAN}可用虚拟机列表：${NC}"
        echo "$vms" | awk -F'|' '{printf "  [%d] VMID: %-6s Name: %-22s Status: %s\n", NR, $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "$(nvidia_t INPUT_PICK) (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line vmid
    line="$(echo "$vms" | awk -v n="$pick" -F'|' 'NR==n{print $0}')"
    vmid="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$vmid" ]]; then
        log_error "无效选择"
        return 1
    fi
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi
    echo "$vmid"
    return 0
}
nvidia_select_gpu_bdf() {
    local gpus
    gpus="$(nvidia_list_nvidia_gpus)"
    if [[ -z "$gpus" ]]; then
        log_error "$(nvidia_t ERR_NO_GPU)"
        log_tips "请先确认已安装 NVIDIA GPU 并执行 lspci 可见。"
        return 1
    fi

    local cols
    cols="$(nvidia_get_cols)"
    local max_line=$((cols-6))
    if [[ "$max_line" -lt 40 ]]; then
        max_line=40
    fi

    {
        echo -e "${CYAN}可用 NVIDIA GPU 列表：${NC}"
        echo "$gpus" | awk -F'|' -v w="$max_line" '{
            line=$2;
            if (length(line)>w) line=substr(line,1,w-3)"...";
            printf "  [%d] %s\n", NR, line
        }'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "$(nvidia_t INPUT_PICK) (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$gpus" | awk -v n="$pick" -F'|' 'NR==n{print $0}')"
    bdf="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$bdf" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$bdf"
    return 0
}
nvidia_show_passthrough_status() {
    local bdf="$1"
    local drv
    drv="$(nvidia_pci_kernel_driver "$bdf")"
    echo -e "${CYAN}设备: ${NC}$bdf"
    echo -e "${CYAN}Kernel driver in use: ${NC}${drv:-unknown}"
    lspci -nnk -s "$bdf" 2>/dev/null | sed 's/^/  /'
}
nvidia_try_write_vfio_ids_conf() {
    local ids_csv="$1"
    local file="/etc/modprobe.d/pve-tools-nvidia-vfio.conf"

    local other
    other="$(grep -RhsE '^\s*options\s+vfio-pci\s+ids=' /etc/modprobe.d 2>/dev/null | grep -vF "pve-tools-nvidia-vfio.conf" || true)"
    if [[ -n "$other" ]]; then
        display_error "检测到系统已存在 vfio-pci ids 配置" "为避免冲突，本功能不会自动写入。请手工合并 vfio-pci ids 后再 update-initramfs -u。"
        return 1
    fi

    if ! confirm_action "写入 VFIO 绑定配置（$file）并要求重启宿主机？"; then
        return 0
    fi

    local content
    content="options vfio-pci ids=${ids_csv}"
    apply_block "$file" "NVIDIA_VFIO_IDS" "$content"
    display_success "VFIO 绑定配置已写入" "请执行 update-initramfs -u 并重启宿主机后再进行直通。"
    return 0
}
nvidia_gpu_passthrough_vm() {
    log_step "$(nvidia_t OPT_PT)"

    if ! iommu_is_enabled; then
        display_error "$(nvidia_t ERR_IOMMU)" "$(nvidia_t TIP_ENABLE_IOMMU)"
        return 1
    fi

    local vmid
    vmid="$(nvidia_select_vmid)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local gpu_bdf
    gpu_bdf="$(nvidia_select_gpu_bdf)"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$gpu_bdf" ]]; then
        return 1
    fi

    clear
    show_menu_header "$(nvidia_t OPT_PT)"
    echo -e "${YELLOW}VMID: ${NC}$vmid"
    echo -e "${YELLOW}GPU: ${NC}$gpu_bdf"
    echo -e "${UI_DIVIDER}"
    nvidia_show_passthrough_status "$gpu_bdf"

    local audio_bdf=""
    if nvidia_pci_has_function "$gpu_bdf" "1"; then
        audio_bdf="${gpu_bdf%.*}.1"
        echo -e "${UI_DIVIDER}"
        nvidia_show_passthrough_status "$audio_bdf"
    fi

    local gpu_id audio_id ids_csv
    gpu_id="$(nvidia_get_pci_ids "$gpu_bdf")"
    audio_id=""
    if [[ -n "$audio_bdf" ]]; then
        audio_id="$(nvidia_get_pci_ids "$audio_bdf")"
    fi
    ids_csv="$gpu_id"
    if [[ -n "$audio_id" ]]; then
        ids_csv="${ids_csv},${audio_id}"
    fi

    echo -e "${UI_DIVIDER}"
    if [[ -n "$ids_csv" ]]; then
        echo -e "${CYAN}VFIO ids 建议: ${NC}$ids_csv"
    fi
    echo -e "${YELLOW}提示：如果宿主机正在加载 nvidia/nouveau 驱动，直通可能失败。${NC}"
    echo -e "${UI_DIVIDER}"

    local include_audio="yes"
    if [[ -n "$audio_bdf" ]]; then
        read -p "是否同时直通显卡音频功能（${audio_bdf}）？(yes/no) [yes]: " include_audio
        include_audio="${include_audio:-yes}"
    else
        include_audio="no"
    fi

    if qm_has_hostpci_bdf "$vmid" "$gpu_bdf"; then
        display_error "该 GPU 已存在于 VM 的 hostpci 配置中" "无需重复添加。"
        return 1
    fi

    local idx0
    idx0="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15。"
        return 1
    }

    local hostpci0_value="${gpu_bdf}"
    if qm_is_q35_machine "$vmid"; then
        hostpci0_value="${hostpci0_value},pcie=1,x-vga=1"
    else
        hostpci0_value="${hostpci0_value},x-vga=1"
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 添加 GPU 直通（hostpci${idx0} = ${hostpci0_value}）"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx0}" "$hostpci0_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$include_audio" == "yes" && -n "$audio_bdf" ]]; then
        local idx1
        idx1="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
            display_error "显卡已添加，但未找到可用 hostpci 插槽添加音频功能" "请手工添加 $audio_bdf。"
            return 1
        }

        local hostpci1_value="${audio_bdf}"
        if qm_is_q35_machine "$vmid"; then
            hostpci1_value="${hostpci1_value},pcie=1"
        fi

        if ! qm set "$vmid" "-hostpci${idx1}" "$hostpci1_value" >/dev/null 2>&1; then
            log_warn "音频功能直通写入失败（GPU 已写入）"
        else
            log_success "音频功能已写入: hostpci${idx1} = $hostpci1_value"
        fi
    fi

    local ignore_msrs="no"
    read -p "是否写入 KVM ignore_msrs（Windows/NVIDIA 常见告警缓解）（yes/no）[no]: " ignore_msrs
    ignore_msrs="${ignore_msrs:-no}"
    if [[ "$ignore_msrs" == "yes" || "$ignore_msrs" == "YES" ]]; then
        if confirm_action "写入 /etc/modprobe.d/kvm.conf 的 ignore_msrs 配置并要求重启？"; then
            local kvm_content
            kvm_content="options kvm ignore_msrs=1 report_ignored_msrs=0"
            apply_block "/etc/modprobe.d/kvm.conf" "NVIDIA_IGNORE_MSRS" "$kvm_content"
            log_success "已写入 KVM ignore_msrs 配置"
        fi
    fi

    if [[ -n "$ids_csv" ]]; then
        local set_vfio="no"
        read -p "是否写入 VFIO ids 绑定配置（用于将设备绑定到 vfio-pci）（yes/no）[no]: " set_vfio
        set_vfio="${set_vfio:-no}"
        if [[ "$set_vfio" == "yes" || "$set_vfio" == "YES" ]]; then
            nvidia_try_write_vfio_ids_conf "$ids_csv" || true
        fi
    fi

    display_success "$(nvidia_t OK_DONE)" "如 VM 正在运行中，请重启 VM；如写入了 VFIO/kvm 配置，请按提示重启宿主机。"
    return 0
}
nvidia_driver_info() {
    clear
    show_menu_header "$(nvidia_t OPT_DRV_INFO)"

    local open_loaded="no"
    local prop_loaded="no"
    if lsmod 2>/dev/null | grep -q '^nouveau'; then
        open_loaded="yes"
    fi
    if lsmod 2>/dev/null | grep -q '^nvidia'; then
        prop_loaded="yes"
    fi

    echo -e "${CYAN}驱动状态：${NC}"
    echo "  nouveau 已加载: $open_loaded"
    echo "  nvidia 已加载:  $prop_loaded"
    echo -e "${UI_DIVIDER}"

    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "${CYAN}nvidia-smi：${NC}"
        nvidia-smi 2>/dev/null | sed 's/^/  /' || true
        echo -e "${UI_DIVIDER}"
        echo -e "${CYAN}GPU 指标（CSV）：${NC}"
        nvidia-smi --query-gpu=index,name,driver_version,temperature.gpu,utilization.gpu,power.draw,power.limit,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | sed 's/^/  /' || true
    else
        display_error "未找到 nvidia-smi" "如需查看驱动信息，请先安装 NVIDIA 驱动或确认 PATH。"
    fi
}
nvidia_driver_export_report() {
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local out="/var/log/pve-tools-nvidia-report-${ts}.txt"
    {
        echo "time: $(date)"
        echo "pveversion: $(pveversion 2>/dev/null || true)"
        echo "kernel: $(uname -r)"
        echo
        echo "lspci (nvidia):"
        lspci -Dnn 2>/dev/null | grep -i nvidia || true
        echo
        echo "lsmod (nvidia/nouveau):"
        lsmod 2>/dev/null | grep -E '^(nvidia|nouveau)\b' || true
        echo
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "nvidia-smi:"
            nvidia-smi 2>/dev/null || true
            echo
            echo "nvidia-smi -q (head):"
            nvidia-smi -q 2>/dev/null | head -n 200 || true
        fi
    } > "$out" 2>/dev/null || {
        display_error "导出失败" "请检查 /var/log 写入权限与磁盘空间。"
        return 1
    }
    log_success "已导出: $out"
    return 0
}
nvidia_driver_info_menu() {
    while true; do
        clear
        show_menu_header "$(nvidia_t OPT_DRV_INFO)"
        show_menu_option "1" "查看驱动与监控面板"
        show_menu_option "2" "导出驱动诊断报告"
        show_menu_option "0" "$(nvidia_t OPT_BACK)"
        show_menu_footer
        read -p "$(nvidia_t INPUT_CHOICE) [0-2]: " choice
        case "$choice" in
            1) nvidia_driver_info ;;
            2) nvidia_driver_export_report ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
nvidia_apt_has_pkg() {
    local pkg="$1"
    apt-cache show "$pkg" >/dev/null 2>&1
}
nvidia_driver_switch_to_proprietary() {
    echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
    if ! confirm_action "安装并启用官方 NVIDIA 驱动（闭源）？"; then
        return 0
    fi

    log_step "更新软件包列表..."
    apt-get update -y >/dev/null 2>&1 || true

    if nvidia_apt_has_pkg "nvidia-driver"; then
        log_step "安装 nvidia-driver..."
        apt-get install -y nvidia-driver
    else
        display_error "未找到可用的 nvidia-driver 软件包" "请检查软件源，或使用 NVIDIA 官方安装方式。"
        return 1
    fi

    if confirm_action "安装完成，是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}
nvidia_driver_switch_to_open() {
    echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
    if ! confirm_action "卸载 NVIDIA 驱动并切回开源驱动（nouveau）？"; then
        return 0
    fi

    log_step "卸载 NVIDIA 驱动..."
    apt-get purge -y 'nvidia-*' || true
    apt-get autoremove -y || true

    if confirm_action "是否更新 initramfs（推荐）？"; then
        update-initramfs -u || true
    fi

    if confirm_action "操作完成，是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}
nvidia_restore_latest_backup_file() {
    local target="$1"
    local backup_dir="/var/backups/pve-tools"
    local base
    base="$(basename "$target")"

    if [[ ! -d "$backup_dir" ]]; then
        return 1
    fi

    local latest
    latest="$(ls -1t "${backup_dir}/${base}."*.bak 2>/dev/null | head -n 1)"
    if [[ -z "$latest" ]]; then
        return 1
    fi

    backup_file "$target" >/dev/null 2>&1 || true
    if cp -a "$latest" "$target" >/dev/null 2>&1; then
        log_success "已回滚: $target"
        log_info "使用备份: $latest"
        return 0
    fi
    return 1
}
nvidia_driver_rollback() {
    echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
    if ! confirm_action "回滚最近一次驱动相关配置备份？"; then
        return 0
    fi

    local files=(
        "/etc/modprobe.d/pve-blacklist.conf"
        "/etc/modprobe.d/kvm.conf"
        "/etc/modprobe.d/pve-tools-nvidia-vfio.conf"
        "/etc/modprobe.d/vfio.conf"
        "/etc/default/grub"
        "/etc/nvidia/gridd.conf"
    )

    local ok=0
    local f
    for f in "${files[@]}"; do
        if nvidia_restore_latest_backup_file "$f"; then
            ok=$((ok+1))
        fi
    done

    if [[ "$ok" -le 0 ]]; then
        display_error "未找到可用备份" "请确认之前确实产生过备份（/var/backups/pve-tools），或手工回滚配置。"
        return 1
    fi

    display_success "回滚完成" "建议执行 update-initramfs -u，并按需重启宿主机。"
    return 0
}
nvidia_driver_switch_menu() {
    while true; do
        clear
        show_menu_header "$(nvidia_t OPT_DRV_SWITCH)"
        echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "切换到闭源驱动（官方 NVIDIA）"
        show_menu_option "2" "切换到开源驱动（nouveau）"
        show_menu_option "3" "回滚最近一次备份"
        show_menu_option "0" "$(nvidia_t OPT_BACK)"
        show_menu_footer
        read -p "$(nvidia_t INPUT_CHOICE) [0-3]: " choice
        case "$choice" in
            1) nvidia_driver_switch_to_proprietary ;;
            2) nvidia_driver_switch_to_open ;;
            3) nvidia_driver_rollback ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
nvidia_host_prepare_for_passthrough() {
    echo -e "${YELLOW}将执行以下操作：${NC}"
    echo "  1) 写入 GRUB IOMMU 参数"
    echo "  2) 写入 /etc/modules 的 VFIO 模块配置块"
    echo "  3) 写入 /etc/modprobe.d/pve-blacklist.conf 的 NVIDIA 黑名单配置块"
    echo "  4) 执行 update-grub 与 update-initramfs"
    echo

    if ! confirm_action "确认执行宿主机预配置？"; then
        return 0
    fi

    local cpu_vendor
    cpu_vendor="$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')"

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        grub_add_param "intel_iommu=on"
    elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
        grub_add_param "amd_iommu=on"
    else
        log_warn "未识别 CPU 厂商，跳过厂商特定 IOMMU 参数"
    fi
    grub_add_param "iommu=pt"
    grub_add_param "pcie_acs_override=downstream,multifunction"

    local modules_content
    modules_content=$(cat <<'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
)
    apply_block "/etc/modules" "NVIDIA_VFIO_MODULES" "$modules_content"

    local blacklist_content
    blacklist_content=$(cat <<'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF
)
    apply_block "/etc/modprobe.d/pve-blacklist.conf" "NVIDIA_BLACKLIST" "$blacklist_content"

    if command -v update-grub >/dev/null 2>&1; then
        update-grub || log_warn "update-grub 执行失败，请手工检查"
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || log_warn "grub-mkconfig 执行失败，请手工检查"
    else
        log_warn "未找到 update-grub/grub-mkconfig，请手工更新 GRUB"
    fi

    update-initramfs -u -k all || log_warn "update-initramfs 执行失败，请手工检查"
    display_success "宿主机预配置已完成" "建议重启宿主机后再执行直通或 vGPU 操作。"

    if confirm_action "是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}
nvidia_setup_vgpu_unlock() {
    clear
    show_menu_header "vGPU Unlock 高风险提示"
    echo -e "${RED}  请先阅读文档后再操作。${NC}"
    echo "  本功能会修改 NVIDIA vGPU 服务启动参数并加载外部 .so 文件。"
    echo "  驱动/内核/补丁版本不匹配可能导致服务异常、宿主机告警或 VM 无法使用 vGPU。"
    echo
    echo -e "${CYAN}推荐先阅读 Wiki：${NC}"
    echo "  对应文章: https://pve.u3u.icu/advanced/nvidia-vgpu-driver-notes"
    echo "${UI_DIVIDER}"
    read -p "请输入 '确认' 或 'Sure' 继续: " response
    response=$(echo "$response" | xargs)
    if [[ "$response" != "确认" && "$response" != "Sure" && "${response,,}" != "sure" ]]; then
        echo "取消"
        return 0
    fi

    local default_url="$NVIDIA_VGPU_UNLOCK_SO_URL"
    local so_url
    read -p "请输入 libvgpu_unlock_rs.so 下载地址 [$default_url]: " so_url
    so_url="${so_url:-$default_url}"

    if [[ -z "$so_url" ]]; then
        display_error "下载地址不能为空"
        return 1
    fi

    echo -e "${YELLOW}将创建并写入：${NC}"
    echo "  /etc/vgpu_unlock/profile_override.toml"
    echo "  /etc/systemd/system/nvidia-vgpud.service.d/vgpu_unlock.conf"
    echo "  /etc/systemd/system/nvidia-vgpu-mgr.service.d/vgpu_unlock.conf"
    echo "  /opt/vgpu_unlock-rs/target/release/libvgpu_unlock_rs.so"
    echo

    if ! confirm_action "确认部署 vGPU Unlock（外部库）？"; then
        return 0
    fi

    mkdir -p /etc/vgpu_unlock
    touch /etc/vgpu_unlock/profile_override.toml
    mkdir -p /etc/systemd/system/nvidia-vgpud.service.d
    mkdir -p /etc/systemd/system/nvidia-vgpu-mgr.service.d
    mkdir -p /opt/vgpu_unlock-rs/target/release

    local unlock_conf
    unlock_conf=$(cat <<'EOF'
[Service]
Environment=LD_PRELOAD=/opt/vgpu_unlock-rs/target/release/libvgpu_unlock_rs.so
EOF
)
    apply_block "/etc/systemd/system/nvidia-vgpud.service.d/vgpu_unlock.conf" "NVIDIA_VGPU_UNLOCK" "$unlock_conf"
    apply_block "/etc/systemd/system/nvidia-vgpu-mgr.service.d/vgpu_unlock.conf" "NVIDIA_VGPU_UNLOCK" "$unlock_conf"

    local so_out="/opt/vgpu_unlock-rs/target/release/libvgpu_unlock_rs.so"
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL --connect-timeout 15 --max-time 300 -o "$so_out" "$so_url"; then
            display_error "下载失败" "请检查 URL 与网络连接。"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "$so_out" "$so_url"; then
            display_error "下载失败" "请检查 URL 与网络连接。"
            return 1
        fi
    else
        display_error "未检测到 curl 或 wget" "无法下载外部库文件。"
        return 1
    fi

    if [[ ! -s "$so_out" ]]; then
        display_error "下载结果为空" "请检查 URL 是否可访问。"
        return 1
    fi

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart nvidia-vgpud.service >/dev/null 2>&1 || true
    systemctl restart nvidia-vgpu-mgr.service >/dev/null 2>&1 || true
    display_success "vGPU Unlock 已部署" "可执行 systemctl status nvidia-vgpud nvidia-vgpu-mgr 验证状态。"
    return 0
}
nvidia_gpu_management_menu() {
    while true; do
        clear
        show_menu_header "$(nvidia_t MENU_TITLE)"
        echo -e "${CYAN}$(nvidia_t MENU_DESC)${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "$(nvidia_t OPT_PT)"
        show_menu_option "2" "$(nvidia_t OPT_DRV_INFO)"
        show_menu_option "3" "$(nvidia_t OPT_DRV_SWITCH)"
        show_menu_option "4" "$(nvidia_t OPT_HOST_PREP)"
        show_menu_option "5" "$(nvidia_t OPT_UNLOCK)"
        show_menu_option "0" "$(nvidia_t OPT_BACK)"
        show_menu_footer
        read -p "$(nvidia_t INPUT_CHOICE) [0-5]: " choice
        case "$choice" in
            1) nvidia_gpu_passthrough_vm ;;
            2) nvidia_driver_info_menu ;;
            3) nvidia_driver_switch_menu ;;
            4) nvidia_host_prepare_for_passthrough ;;
            5) nvidia_setup_vgpu_unlock ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
