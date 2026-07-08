#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

get_installed_kernel_packages() {
    local status_regex="${1:-ii|hi}"

    dpkg -l 2>/dev/null | awk -v sr="$status_regex" '
        $1 ~ ("^(" sr ")$") &&
        $2 ~ /^(pve-kernel|proxmox-kernel)-[0-9].*-pve(-signed)?$/ {
            print $2
        }
    ' | sort -Vu
}

# 获取可用的真实内核包（优先 proxmox-kernel，再回退 pve-kernel）
get_available_kernel_packages_raw() {
    local kernel_url="https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/Packages"
    local packages_text=""
    local available_kernels=""

    packages_text="$(curl -fsSL "$kernel_url" 2>/dev/null || true)"
    if [[ -n "$packages_text" ]]; then
        available_kernels="$(
            printf '%s\n' "$packages_text" | sed -nE 's/^Package: (proxmox-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?)$/\1/p' | sort -V | uniq
        )"
        if [[ -z "$available_kernels" ]]; then
            available_kernels="$(
                printf '%s\n' "$packages_text" | sed -nE 's/^Package: (pve-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?)$/\1/p' | sort -V | uniq
            )"
        fi
    fi

    if [[ -z "$available_kernels" ]]; then
        available_kernels="$(apt-cache search --names-only '^proxmox-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?$' 2>/dev/null | awk '{print $1}' | sort -V | uniq)"
        if [[ -z "$available_kernels" ]]; then
            available_kernels="$(apt-cache search --names-only '^pve-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?$' 2>/dev/null | awk '{print $1}' | sort -V | uniq)"
        fi
    fi

    [[ -n "$available_kernels" ]] || return 1
    printf '%s\n' "$available_kernels"
}
kernel_package_is_valid() {
    local package_name="$1"
    [[ "$package_name" =~ ^(proxmox-kernel|pve-kernel)-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?$ ]]
}
kernel_package_release_from_name() {
    local package_name="$1"

    if [[ "$package_name" =~ ^(proxmox-kernel|pve-kernel)-([0-9][0-9A-Za-z.+:~-]*-pve)(-signed)?$ ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}
kernel_package_normalize_input() {
    local kernel_input="$1"
    local kernel_version=""

    if [[ -z "$kernel_input" ]]; then
        return 1
    fi

    if kernel_package_is_valid "$kernel_input"; then
        echo "$kernel_input"
        return 0
    fi

    case "$kernel_input" in
        proxmox-kernel-*)
            kernel_version="${kernel_input#proxmox-kernel-}"
            ;;
        pve-kernel-*)
            kernel_version="${kernel_input#pve-kernel-}"
            ;;
        *)
            kernel_version="$kernel_input"
            ;;
    esac

    if [[ "$kernel_version" != *-pve && "$kernel_version" != *-pve-signed ]]; then
        kernel_version="${kernel_version}-pve"
    fi

    echo "proxmox-kernel-$kernel_version"
}

# 检测当前内核版本
check_kernel_version() {
    log_info "检测当前内核信息..."
    local current_kernel=$(uname -r)
    local kernel_arch=$(uname -m)
    local kernel_variant=""
    
    # 检测内核变体（普通/企业版/测试版）
    if [[ $current_kernel == *"pve"* ]]; then
        kernel_variant="PVE标准内核"
    elif [[ $current_kernel == *"edge"* ]]; then
        kernel_variant="PVE边缘内核"
    elif [[ $current_kernel == *"test"* ]]; then
        kernel_variant="测试内核"
    else
        kernel_variant="未知类型"
    fi
    
    echo -e "${CYAN}当前内核信息：${NC}"
    echo -e "  版本: ${GREEN}$current_kernel${NC}"
    echo -e "  架构: ${GREEN}$kernel_arch${NC}"
    echo -e "  类型: ${GREEN}$kernel_variant${NC}"
    
    # 检测可用的内核版本
    local installed_kernels=$(get_installed_kernel_packages)
    if [[ -n "$installed_kernels" ]]; then
        echo -e "${CYAN}已安装的内核版本：${NC}"
        while IFS= read -r kernel; do
            echo -e "  ${GREEN}•${NC} $kernel"
        done <<< "$installed_kernels"
    fi
    
    return 0
}

# 获取可用内核列表
get_available_kernels() {
    log_info "正在从 Tuna 镜像站获取可用内核列表..."
    
    # 检查网络连接
    if [[ "$IS_OFFLINE_MODE" -eq 1 ]]; then
        log_warn "离线模式下无法获取可用内核列表"
        return 1
    fi
    if ! network_can_access_internet; then
        log_error "网络连接失败，无法获取内核列表！"
        return 1
    fi
    
    local available_kernels
    if ! available_kernels="$(get_available_kernel_packages_raw)"; then
        log_error "无法获取可用内核列表"
        return 1
    fi
    
    if [[ -n "$available_kernels" ]]; then
        echo -e "${CYAN}可用内核版本：${NC}"
        while IFS= read -r kernel; do
            [[ -n "$kernel" ]] || continue
            echo -e "  ${BLUE}•${NC} $kernel"
        done <<< "$available_kernels"
    else
        log_error "无法找到可用内核"
        return 1
    fi
    
    return 0
}

# 安装指定内核版本
install_kernel() {
    local kernel_input=$1
    local kernel_version=""
    
    # 验证内核版本格式
    if [[ -z "$kernel_input" ]]; then
        log_error "请指定要安装的内核版本"
        return 1
    fi
    
    if kernel_package_is_valid "$kernel_input"; then
        if [[ "$kernel_input" == pve-kernel-* ]]; then
            kernel_version="proxmox-kernel-${kernel_input#pve-kernel-}"
            log_info "检测到旧包名格式，自动转换为: $kernel_version"
        else
            kernel_version="$kernel_input"
            log_info "检测到完整包名格式: $kernel_version"
        fi
    else
        kernel_version="$(kernel_package_normalize_input "$kernel_input")"
        log_info "检测到版本号格式，自动补全包名为 $kernel_version"
    fi
    
    if ! kernel_package_is_valid "$kernel_version"; then
        log_error "无效的内核包名: $kernel_version"
        return 1
    fi

    log_info "开始安装内核: $kernel_version"
    
    # 检查内核是否已安装
    if dpkg -l 2>/dev/null | awk -v pkg="$kernel_version" '$1 == "ii" && $2 == pkg {found=1} END {exit !found}'; then
        log_warn "内核 $kernel_version 已经安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            return 0
        fi
    fi
    
    # 更新软件包列表
    log_info "更新软件包列表..."
    if ! apt-get update; then
        log_error "更新软件包列表失败"
        return 1
    fi
    
    # 安装内核
    log_info "正在安装内核 $kernel_version ..."
    if ! apt-get install -y "$kernel_version"; then
        log_error "内核安装失败"
        return 1
    fi
    
    log_success "内核 $kernel_version 安装成功"
    
    # 更新引导配置
    update_grub_config
    
    return 0
}

# 更新 GRUB 配置
set_default_kernel() {
    local kernel_version=$1
    
    if [[ -z "$kernel_version" ]]; then
        log_error "请指定要设置为默认的内核版本"
        return 1
    fi
    
    log_info "设置默认启动内核: ${GREEN}$kernel_version${NC}"
    
    # 检查内核是否存在
    if ! [[ -f "/boot/initrd.img-$kernel_version" && -f "/boot/vmlinuz-$kernel_version" ]]; then
        log_error "内核文件不存在，请先安装该内核"
        log_error "缺失文件: /boot/vmlinuz-$kernel_version 或 /boot/initrd.img-$kernel_version"
        return 1
    fi
    
    # 使用 grub-set-default 设置默认内核
    if command -v grub-set-default &> /dev/null; then
        # 查找内核在 GRUB 菜单中的位置
        local menu_entry=$(grep -n "$kernel_version" /boot/grub/grub.cfg | head -1 | cut -d: -f1)
        if [[ -n "$menu_entry" ]]; then
            # 计算 GRUB 菜单项索引（从0开始）
            local grub_index=$(( (menu_entry - 1) / 2 ))
            if grub-set-default "$grub_index"; then
                log_success "默认启动内核设置成功"
                return 0
            fi
        fi
    fi
    
    # 备用方法：手动编辑 GRUB 配置
    log_warn "使用备用方法设置默认内核"
    
    # 备份当前 GRUB 配置
    backup_file "/etc/default/grub"
    
    # 设置 GRUB_DEFAULT 为内核版本
    if sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"Advanced options for Proxmox VE GNU\/Linux>Proxmox VE GNU\/Linux, with Linux $kernel_version\"/" /etc/default/grub; then
        log_success "GRUB 配置更新成功"
        update_grub_config
        return 0
    else
        log_error "GRUB 配置更新失败"
        return 1
    fi
}

# 删除旧内核（保留最近2个版本）
remove_old_kernels() {
    log_info "清理旧内核..."
    
    # 获取所有已安装的内核
    local installed_kernels
    installed_kernels="$(get_installed_kernel_packages "ii")"
    local -a kernel_list
    mapfile -t kernel_list < <(printf '%s\n' "$installed_kernels" | sed '/^$/d')
    local kernel_count=${#kernel_list[@]}
    
    if [[ $kernel_count -le 2 ]]; then
        log_info "当前只有 $kernel_count 个内核，无需清理"
        return 0
    fi
    
    # 计算需要保留的内核数量（保留最新的2个）
    local keep_count=2
    local remove_count=$((kernel_count - keep_count))
    
    echo -e "${YELLOW}将删除 $remove_count 个旧内核，保留最新的 $keep_count 个内核${NC}"
    
    # 获取要删除的内核列表（最旧的几个）
    local kernels_to_remove=("${kernel_list[@]:0:$remove_count}")
    
    read -p "是否继续？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "取消内核清理"
        return 0
    fi
    
    # 删除旧内核
    for kernel in "${kernels_to_remove[@]}"; do
        log_info "正在删除内核: $kernel"
        if apt-get remove -y --purge "$kernel"; then
            log_success "内核 $kernel 删除成功"
        else
            log_error "删除内核 $kernel 失败"
        fi
    done
    
    # 更新引导配置
    update_grub_config
    
    log_success "旧内核清理完成"
    return 0
}

# 内核管理主菜单
kernel_management_menu() {
    while true; do
        clear
        show_menu_header "内核管理菜单"
        show_menu_option "1" "显示当前内核信息"
        show_menu_option "2" "查看可用内核列表"
        show_menu_option "3" "安装新内核"
        show_menu_option "4" "设置默认启动内核"
        show_menu_option "5" "${RED}清理旧内核${NC}"
        show_menu_option "6" "${YELLOW}重启系统应用新内核${NC}"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        
        read -p "请选择操作 [0-6]: " choice
        
        case $choice in
            1)
                check_kernel_version
                ;;
            2)
                get_available_kernels
                ;;
            3)
                echo "请输入要安装的内核版本："
                echo "  - 完整包名格式 (推荐): 如 proxmox-kernel-6.14.8-2-pve"
                echo "  - 简化版本格式: 如 6.8.8-1 (将自动补全为 proxmox-kernel-6.8.8-1-pve)"
                read -p "请输入内核标识: " kernel_ver
                if [[ -n "$kernel_ver" ]]; then
                    install_kernel "$kernel_ver"
                else
                    log_error "请输入有效的内核版本"
                fi
                ;;
            4)
                read -p "请输入要设置为默认的内核版本 (例如: 6.8.8-1-pve): " kernel_ver
                if [[ -n "$kernel_ver" ]]; then
                    set_default_kernel "$kernel_ver"
                else
                    log_error "请输入有效的内核版本"
                fi
                ;;
            5)
                remove_old_kernels
                ;;
            6)
                if confirm_high_risk_action \
                    "重启宿主机" \
                    "将立即重启当前 Proxmox VE 宿主机，所有运行中的 VM/CT 将被中断。" \
                    "重启过程中管理面不可用，请确保维护窗口内执行。" \
                    "请先正常关机或迁移所有 VM/CT。" \
                    "REBOOT"; then
                    log_info "系统将在5秒后重启..."
                    echo "按 Ctrl+C 取消重启"
                    sleep 5
                    reboot
                else
                    log_info "取消重启"
                fi
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择，请重新输入"
                ;;
        esac
        
        echo
        pause_function
    done
}

# 内核同步更新（自动检测并更新到最新稳定版）
sync_kernel_update() {
    log_info "开始内核同步更新检查..."
    
    # 获取当前内核版本
    local current_kernel=$(uname -r)
    log_info "当前内核版本: ${GREEN}$current_kernel${NC}"
    
    # 获取最新可用内核包
    local available_kernel_text=""
    local -a available_kernel_packages=()
    if ! available_kernel_text="$(get_available_kernel_packages_raw)"; then
        log_error "无法获取最新内核信息"
        return 1
    fi

    mapfile -t available_kernel_packages < <(printf '%s\n' "$available_kernel_text" | sed '/^$/d')
    if [[ ${#available_kernel_packages[@]} -eq 0 ]]; then
        log_error "无法获取最新内核信息"
        return 1
    fi

    local latest_kernel_index=$(( ${#available_kernel_packages[@]} - 1 ))
    local latest_kernel_package="${available_kernel_packages[$latest_kernel_index]}"
    local latest_kernel_release=""
    if ! latest_kernel_release="$(kernel_package_release_from_name "$latest_kernel_package")"; then
        log_error "无法解析最新内核包名: $latest_kernel_package"
        return 1
    fi

    log_info "最新可用内核包: ${GREEN}$latest_kernel_package${NC}"
    log_info "最新可用内核版本: ${GREEN}$latest_kernel_release${NC}"
    
    # 检查是否需要更新
    if [[ "$current_kernel" == "$latest_kernel_release" ]]; then
        log_success "当前已是最新内核，无需更新"
        return 0
    fi
    
    echo -e "${YELLOW}发现新内核版本: $latest_kernel_release${NC}"
    read -p "是否安装并更新到最新内核？(Y/n): " update_confirm
    
    if [[ "$update_confirm" == "n" || "$update_confirm" == "N" ]]; then
        log_info "取消内核更新"
        return 0
    fi
    
    # 安装最新内核
    if install_kernel "$latest_kernel_package"; then
        # 设置新内核为默认启动项
        if set_default_kernel "$latest_kernel_release"; then
            log_success "内核同步更新完成"
            echo -e "${YELLOW}建议重启系统以应用新内核${NC}"
            return 0
        else
            log_warn "内核安装成功但设置默认启动项失败"
            return 1
        fi
    else
        log_error "内核更新失败"
        return 1
    fi
}

# 备份函数统一定义于顶部配置文件安全管理区域，避免后续重复覆盖。
# 换源功能
