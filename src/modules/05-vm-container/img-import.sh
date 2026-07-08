#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

img_bytes_to_human() {
    local bytes="$1"
    if [[ -z "$bytes" || ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "?"
        return 0
    fi
    awk -v b="$bytes" 'BEGIN{
        split("B KB MB GB TB PB", u, " ");
        i=1; x=b;
        while (x>=1024 && i<6) {x/=1024; i++}
        if (i==1) printf "%d%s", b, u[i];
        else printf "%.1f%s", x, u[i];
    }'
}
img_discover_img_files() {
    vm_discover_disk_image_files
}
img_select_img_file() {
    local files
    files="$(img_discover_img_files)"
    if [[ -z "$files" ]]; then
        log_error "未发现磁盘镜像文件"
        log_tips "已扫描目录：/root、/var/lib/vz/template/iso、/home（支持 .img/.raw/.qcow2）"
        return 1
    fi

    {
        echo -e "${CYAN}已发现磁盘镜像文件：${NC}"
        echo "$files" | awk -F'|' '
            function human(x,   u,i){
                split("B KB MB GB TB PB", u, " ");
                i=1;
                while (x>=1024 && i<6){x/=1024;i++}
                if (i==1) return sprintf("%d%s", x, u[i]);
                return sprintf("%.1f%s", x, u[i]);
            }
            {
                printf "  [%d] %-9s %-16s %s\n", NR, human($2), $3, $1
            }'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择镜像序号 (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line path
    line="$(echo "$files" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    path="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$path" || ! -f "$path" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$path"
    return 0
}
img_select_vmid() {
    local vms
    vms="$(qm list 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}')"
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
    read -p "请选择虚拟机序号 (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line vmid
    line="$(echo "$vms" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
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
img_select_storage() {
    local stores
    stores="$(pvesm status 2>/dev/null | awk 'NR>1{print $1 "|" $2}')"
    if [[ -z "$stores" ]]; then
        local manual
        read -p "未能获取存储列表，请手动输入存储名（如 local-lvm）: " manual
        if [[ -z "$manual" ]]; then
            log_error "存储名不能为空"
            return 1
        fi
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}可用存储列表：${NC}"
        echo "$stores" | awk -F'|' '{printf "  [%d] %-18s (%s)\n", NR, $1, $2}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择存储序号 (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line store
    line="$(echo "$stores" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    store="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$store" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$store"
    return 0
}
img_convert_and_import_to_vm() {
    log_step "磁盘镜像转换并导入虚拟机"

    if ! command -v qemu-img >/dev/null 2>&1; then
        display_error "未找到 qemu-img" "请先安装：apt install -y qemu-utils"
        return 1
    fi
    if ! command -v qm >/dev/null 2>&1; then
        display_error "未找到 qm 命令" "请确认当前环境为 PVE 宿主机。"
        return 1
    fi

    local img_path
    img_path="$(img_select_img_file)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$img_path" ]]; then
        return 1
    fi

    local vmid
    vmid="$(img_select_vmid)"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local store
    store="$(img_select_storage)"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$store" ]]; then
        return 1
    fi

    local out_fmt
    read -p "请选择目标格式 (qcow2/raw) [qcow2]: " out_fmt
    out_fmt="${out_fmt:-qcow2}"
    if [[ "$out_fmt" != "qcow2" && "$out_fmt" != "raw" ]]; then
        display_error "不支持的格式: $out_fmt" "仅支持 qcow2/raw"
        return 1
    fi

    local ts ext out_path out_dir
    local src_fmt
    src_fmt="$(vm_detect_image_format "$img_path")"
    if [[ -z "$src_fmt" ]]; then
        display_error "无法识别镜像格式" "请确认文件可被 qemu-img 识别，且格式为 img/raw/qcow2。"
        return 1
    fi
    ts="$(date +%Y%m%d_%H%M%S)"
    ext="$out_fmt"
    out_dir="$(dirname "$img_path")"
    out_path="${out_dir}/vm-${vmid}-disk-import-${ts}.${ext}"
    if [[ -e "$out_path" ]]; then
        out_path="${out_dir}/vm-${vmid}-disk-import-${ts}-1.${ext}"
    fi

    clear
    show_menu_header "磁盘镜像转换并导入虚拟机"
    local sz
    sz="$(stat -c '%s' "$img_path" 2>/dev/null || echo "")"
    echo -e "${YELLOW}源镜像:${NC} $img_path"
    echo -e "${YELLOW}源格式:${NC} $src_fmt"
    if [[ -n "$sz" ]]; then
        echo -e "${YELLOW}大小:${NC} $(img_bytes_to_human "$sz")"
    fi
    echo -e "${YELLOW}目标 VMID:${NC} $vmid"
    echo -e "${YELLOW}目标存储:${NC} $store"
    echo -e "${YELLOW}目标格式:${NC} $out_fmt"
    echo -e "${YELLOW}临时输出:${NC} $out_path"
    echo -e "${UI_DIVIDER}"

    if ! confirm_action "开始转换并导入磁盘？"; then
        return 0
    fi

    log_step "开始转换（qemu-img convert）"
    if ! qemu-img convert -p -f "$src_fmt" -O "$out_fmt" "$img_path" "$out_path"; then
        display_error "镜像转换失败" "请检查镜像文件是否损坏，或查看日志输出。"
        return 1
    fi

    log_step "开始导入（qm importdisk）"
    local import_out vol
    if ! import_out="$(qm importdisk "$vmid" "$out_path" "$store" 2>&1)"; then
        echo "$import_out" | sed 's/^/  /'
        display_error "导入失败" "请检查存储名称与空间，或查看上方输出。"
        return 1
    fi

    vol="$(echo "$import_out" | sed -n "s/.*as '\\([^']\\+\\)'.*/\\1/p" | tail -n 1)"
    [[ -z "$vol" ]] && vol="$(echo "$import_out" | grep -oE "${store}:[^ ]+" | tail -n 1)"

    if [[ -n "$vol" ]]; then
        log_success "导入完成: $vol"
    else
        log_success "导入完成"
    fi

    local attach_bus attach_slot cfg
    local auto_attach="yes"
    read -p "是否自动挂载到 VM？(yes/no) [yes]: " auto_attach
    auto_attach="${auto_attach:-yes}"
    if [[ "$auto_attach" == "yes" || "$auto_attach" == "YES" ]]; then
        read -p "请选择总线类型 (scsi/sata/ide) [scsi]: " attach_bus
        attach_bus="${attach_bus:-scsi}"
        if [[ "$attach_bus" != "scsi" && "$attach_bus" != "sata" && "$attach_bus" != "ide" ]]; then
            log_warn "不支持的总线类型，跳过自动挂载: $attach_bus"
        else
            cfg="$(qm config "$vmid" 2>/dev/null || true)"
            if [[ -n "$vol" && -n "$cfg" ]] && echo "$cfg" | grep -Fq "$vol"; then
                log_info "检测到该卷已写入 VM 配置（可能为 unusedX 或已挂载），跳过自动挂载。"
            elif [[ -z "$vol" ]]; then
                log_info "未能解析导入卷 ID，跳过自动挂载。"
            else
                attach_slot="$(vm_find_free_disk_slot "$vmid" "$attach_bus" 2>/dev/null)" || true
                if [[ -z "$attach_slot" ]]; then
                    log_warn "未找到可用插槽，跳过自动挂载"
                else
                    if confirm_action "将磁盘挂载到 VM $vmid（${attach_slot} = ${vol}）"; then
                        if qm set "$vmid" "-$attach_slot" "$vol" >/dev/null 2>&1; then
                            log_success "已挂载: $attach_slot"
                        else
                            log_warn "自动挂载失败，请在 PVE WebUI 中手动添加该磁盘"
                        fi
                    fi
                fi
            fi
        fi
    fi

    local del_tmp="yes"
    read -p "是否删除临时输出文件 $out_path ？(yes/no) [yes]: " del_tmp
    del_tmp="${del_tmp:-yes}"
    if [[ "$del_tmp" == "yes" || "$del_tmp" == "YES" ]]; then
        rm -f "$out_path" >/dev/null 2>&1 || true
    fi

    display_success "处理完成" "如需从该磁盘引导，请在 VM 启动顺序中选择对应磁盘。"
    return 0
}
img_convert_import_menu() {
    clear
    show_menu_header "磁盘镜像导入（转换为 QCOW2/RAW）"
    echo -e "${CYAN}功能说明：${NC}"
    echo -e "  - 自动扫描：/root、/var/lib/vz/template/iso、/home 下的 .img/.raw/.qcow2 文件"
    echo -e "  - 自动识别源格式，使用 qemu-img 转换后，通过 qm importdisk 导入到指定 VM 与存储"
    echo -e "${UI_DIVIDER}"
    img_convert_and_import_to_vm
}

# ============ VM 高级运维功能 ============
