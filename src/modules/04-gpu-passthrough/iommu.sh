#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

iommu_is_enabled() {
    if [[ -d /sys/kernel/iommu_groups ]]; then
        local group_count
        group_count="$(find /sys/kernel/iommu_groups -maxdepth 1 -type d 2>/dev/null | wc -l)"
        if [[ "${group_count:-0}" -gt 1 ]]; then
            return 0
        fi
    fi

    if dmesg 2>/dev/null | grep -Eiq 'DMAR: IOMMU enabled|IOMMU enabled|AMD-Vi:.*enabled'; then
        return 0
    fi

    return 1
}

# 从 udev 路径中解析 PCI BDF（格式：0000:00:00.0）
enable_pass() {
    echo
    log_step "开启硬件直通..."
    if [ `dmesg | grep -e DMAR -e IOMMU|wc -l` = 0 ];then
        log_error "您的硬件不支持直通！不如检查一下主板的BIOS设置？"
        pause_function
        return
    fi
    if [ `cat /proc/cpuinfo|grep Intel|wc -l` = 0 ];then
        iommu="amd_iommu=on"
    else
        iommu="intel_iommu=on"
    fi
    if ! grep -qw "$(echo "$iommu" | cut -d'=' -f1)" /etc/default/grub; then
        if grub_add_param "$iommu"; then
            update-grub
        fi
        if [ `grep "vfio" /etc/modules|wc -l` = 0 ];then
            cat <<-EOF >> /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
kvmgt
EOF
        fi
        
        # 使用安全的配置块管理
        blacklist_content="blacklist snd_hda_intel
blacklist snd_hda_codec_hdmi
blacklist i915"
        apply_block "/etc/modprobe.d/blacklist.conf" "HARDWARE_PASSTHROUGH" "$blacklist_content"

        # 使用安全的配置块管理
        vfio_content="options vfio-pci ids=8086:3185"
        apply_block "/etc/modprobe.d/vfio.conf" "HARDWARE_PASSTHROUGH" "$vfio_content"
        
        log_success "开启设置后需要重启系统，请准备就绪后重启宿主机"
        log_tips "重启后才可以应用对内核引导的修改哦！命令是 reboot"
    else
        log_warn "您已经配置过!"
    fi
}

# 关闭硬件直通
disable_pass() {
    echo
    log_step "关闭硬件直通..."
    if [ `dmesg | grep -e DMAR -e IOMMU|wc -l` = 0 ];then
        log_error "您的硬件不支持直通！"
        log_tips "不如检查一下主板的BIOS设置？"
        pause_function
        return
    fi
    if [ `cat /proc/cpuinfo|grep Intel|wc -l` = 0 ];then
        iommu="amd_iommu=on"
    else
        iommu="intel_iommu=on"
    fi
    if [ `grep $iommu /etc/default/grub|wc -l` = 0 ];then
        log_warn "您还没有配置过该项"
    else
        grub_remove_param "$iommu"
        sed -i '/vfio/d' /etc/modules
        # 使用安全的配置块删除，而不是直接删除整个文件
        remove_block "/etc/modprobe.d/blacklist.conf" "HARDWARE_PASSTHROUGH"
        remove_block "/etc/modprobe.d/vfio.conf" "HARDWARE_PASSTHROUGH"
        update-grub
        log_success "关闭设置后需要重启系统，请准备就绪后重启宿主机。"
        log_tips "重启后才可以应用对内核引导的修改哦！命令是 reboot"
    fi
}

# 硬件直通菜单
hw_passth() {
    while :; do
        clear
        show_menu_header "配置硬件直通"
        show_menu_option "1" "开启硬件直通"
        show_menu_option "2" "关闭硬件直通"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择: [ ]" -n 1 hwmenuid
        echo  # New line after input
        hwmenuid=${hwmenuid:-0}
        case "${hwmenuid}" in
            1)
                enable_pass
                pause_function
                ;;
            2)
                disable_pass
                pause_function
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选项!"
                pause_function
                ;;
        esac
    done
}
#--------------磁盘/控制器直通----------------

# 磁盘/控制器直通总菜单
parse_pci_bdf_from_udev_path() {
    local udev_path="$1"
    if [[ "$udev_path" =~ ([0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# 获取指定块设备所在的 PCI BDF（用于系统盘控制器保护、控制器磁盘映射）
get_blockdev_pci_bdf() {
    local dev_path="$1"
    if [[ -z "$dev_path" || ! -b "$dev_path" ]]; then
        return 1
    fi

    local udev_path
    udev_path="$(udevadm info --query=path --name="$dev_path" 2>/dev/null)"
    if [[ -n "$udev_path" ]]; then
        parse_pci_bdf_from_udev_path "$udev_path" && return 0
    fi

    return 1
}

# 获取 PVE 系统盘对应的“整盘设备名”列表（sda / nvme0n1 等）
get_system_whole_disks() {
    local -A disks=()
    local mount_src

    for mp in / /boot /boot/efi; do
        mount_src="$(findmnt -n -o SOURCE "$mp" 2>/dev/null || true)"
        if [[ -z "$mount_src" ]]; then
            continue
        fi

        if [[ "$mount_src" == /dev/mapper/* ]]; then
            if command -v pvs >/dev/null 2>&1; then
                while IFS= read -r pv; do
                    pv="$(echo "$pv" | awk '{$1=$1;print}')"
                    if [[ -n "$pv" && -b "$pv" ]]; then
                        local pk
                        pk="$(lsblk -dn -o PKNAME "$pv" 2>/dev/null | head -n 1)"
                        if [[ -n "$pk" ]]; then
                            disks["$pk"]=1
                        else
                            disks["$(basename "$pv")"]=1
                        fi
                    fi
                done < <(pvs --noheadings -o pv_name 2>/dev/null)
            fi
            continue
        fi

        if [[ -b "$mount_src" ]]; then
            local pk
            pk="$(lsblk -dn -o PKNAME "$mount_src" 2>/dev/null | head -n 1)"
            if [[ -n "$pk" ]]; then
                disks["$pk"]=1
            else
                disks["$(basename "$mount_src")"]=1
            fi
        fi
    done

    for d in "${!disks[@]}"; do
        echo "$d"
    done | sort
}

# 获取“必须保护”的 PCI BDF（包含系统盘的控制器）
get_protected_pci_bdfs() {
    local -A bdfs=()
    local disk
    while IFS= read -r disk; do
        local bdf
        bdf="$(get_blockdev_pci_bdf "/dev/$disk" 2>/dev/null || true)"
        if [[ -n "$bdf" ]]; then
            bdfs["$bdf"]=1
        fi
    done < <(get_system_whole_disks)

    for b in "${!bdfs[@]}"; do
        echo "$b"
    done | sort
}

# 列出系统内的 SATA/SCSI/RAID 控制器（用于整控制器直通）
list_storage_controllers() {
    lspci -Dnn 2>/dev/null | grep -Eiin 'SATA controller|RAID bus controller|SCSI storage controller|Serial Attached SCSI controller' | sed 's/^[0-9]\+://'
}

# 列出系统内的 NVMe 控制器（用于 NVMe 直通）
list_nvme_controllers() {
    lspci -Dnn 2>/dev/null | grep -Eiin 'Non-Volatile memory controller' | sed 's/^[0-9]\+://'
}

# 展示指定 PCI BDF 下的所有“整盘”设备（用于磁盘映射展示与保护提示）
show_disks_under_pci_bdf() {
    local bdf="$1"
    if [[ -z "$bdf" ]]; then
        return 1
    fi

    local found=0
    while IFS= read -r name; do
        local dev_bdf
        dev_bdf="$(get_blockdev_pci_bdf "/dev/$name" 2>/dev/null || true)"
        if [[ "$dev_bdf" == "$bdf" ]]; then
            local size model
            size="$(lsblk -dn -o SIZE "/dev/$name" 2>/dev/null | head -n 1)"
            model="$(lsblk -dn -o MODEL "/dev/$name" 2>/dev/null | head -n 1)"
            echo "  /dev/$name  ${size:-?}  ${model:-?}"
            found=1
        fi
    done < <(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')

    if [[ "$found" -eq 0 ]]; then
        echo "  （未能识别到该控制器下的磁盘，可能是映射方式不同或权限受限）"
    fi
    return 0
}

# 获取 VM 是否为 q35（决定 hostpci 是否添加 pcie=1）
