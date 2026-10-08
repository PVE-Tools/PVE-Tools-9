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

# 读取 Proxmox 官方内核固定 (pin) 机制记录的 release
# proxmox-boot-tool kernel pin / next-boot 分别把内核 release 写入这两个文件的首行，
# 与 proxmox-ve 的 pve-apt-hook 使用同一数据来源；文件不存在或为空时静默跳过。
kernel_pinned_releases() {
    local pin_file=""
    local pinned=""

    for pin_file in /etc/kernel/proxmox-boot-pin /etc/kernel/next-boot-pin; do
        [[ -r "$pin_file" ]] || continue
        pinned=""
        IFS= read -r pinned < "$pin_file" || pinned=""
        pinned="${pinned%%[[:space:]]*}"
        [[ -n "$pinned" ]] || continue
        printf '%s\n' "$pinned"
    done

    return 0
}

# 计算待清理的内核包（纯逻辑，无副作用，便于用 mock 输入验证）
#
# 用法: printf '%s\n' "${installed_packages[@]}" \
#           | kernel_cleanup_select_removals <当前运行 release> [额外保护的 release...]
#
# 保护集合 = 最新 2 个内核 release ∪ 当前运行内核 release ∪ 额外保护 release(pin)
#   - 版本判定以 kernel release 为基本单位（signed / unsigned 视为同一 release）
#   - 输出: 待删除的内核包名，每行一个
#   - 返回: 0 计算成功；1 输入无法可靠解析（调用方必须放弃自动删除）
kernel_cleanup_select_removals() {
    local current_release="$1"
    shift
    local -a extra_protected=("$@")
    local keep_count=2

    if [[ -z "$current_release" ]]; then
        return 1
    fi

    local package=""
    local release=""
    local protected=""
    local i=0
    local current_found=0
    local -a installed_packages=()
    local -a installed_releases=()
    local -a sorted_releases=()
    local -A protected_map=()

    while IFS= read -r package; do
        package="${package%%[[:space:]]*}"
        [[ -n "$package" ]] || continue
        # 包名无法解析时不允许猜测，交由调用方走 fail-safe
        if ! release="$(kernel_package_release_from_name "$package")"; then
            return 1
        fi
        installed_packages+=("$package")
        installed_releases+=("$release")
        if [[ "$release" == "$current_release" ]]; then
            current_found=1
        fi
    done

    [[ ${#installed_packages[@]} -gt 0 ]] || return 1
    # 当前运行内核必须能对应到某个已安装包，否则放弃自动删除
    [[ $current_found -eq 1 ]] || return 1

    mapfile -t sorted_releases < <(printf '%s\n' "${installed_releases[@]}" | sort -Vu)
    if [[ ${#sorted_releases[@]} -lt $keep_count ]]; then
        keep_count=${#sorted_releases[@]}
    fi

    for ((i = ${#sorted_releases[@]} - keep_count; i < ${#sorted_releases[@]}; i++)); do
        protected_map["${sorted_releases[$i]}"]=1
    done
    protected_map["$current_release"]=1
    for protected in "${extra_protected[@]}"; do
        [[ -n "$protected" ]] || continue
        protected_map["$protected"]=1
    done

    # 按已安装包逐个判定：受保护 release 的 signed / unsigned 包一并保留
    for i in "${!installed_packages[@]}"; do
        release="${installed_releases[$i]}"
        if [[ -n "${protected_map[$release]:-}" ]]; then
            continue
        fi
        printf '%s\n' "${installed_packages[$i]}"
    done

    return 0
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
    
    # 首选 proxmox-boot-tool kernel pin：PVE 官方机制，GRUB 与 systemd-boot（UEFI/ZFS）环境均适用
    if command -v proxmox-boot-tool >/dev/null 2>&1; then
        if proxmox-boot-tool kernel pin "$kernel_version"; then
            log_success "默认启动内核已通过 proxmox-boot-tool 固定 (pin)"
            log_tips "如需恢复自动选择最新内核，可执行: proxmox-boot-tool kernel unpin"
            return 0
        fi
        log_warn "proxmox-boot-tool kernel pin 执行失败，尝试 GRUB 备用方法"
    fi

    # 备用：grub-set-default（仅适用于直接由 GRUB 引导且存在 grub.cfg 的环境）
    if command -v grub-set-default &> /dev/null && [[ -f /boot/grub/grub.cfg ]]; then
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

# 删除旧内核（始终保留当前运行内核 + 最新 2 个内核 release）
remove_old_kernels() {
    log_info "清理旧内核..."

    local current_release=""
    current_release="$(uname -r)"

    # 获取所有已安装的内核
    local installed_kernels
    installed_kernels="$(get_installed_kernel_packages "ii")"
    local -a kernel_list
    mapfile -t kernel_list < <(printf '%s\n' "$installed_kernels" | sed '/^$/d')

    if [[ ${#kernel_list[@]} -eq 0 ]]; then
        log_warn "未检测到任何已安装的内核包，跳过清理"
        return 0
    fi

    # 额外保护：proxmox-boot-tool kernel pin / next-boot 固定的内核 release
    local -a pinned_releases
    mapfile -t pinned_releases < <(kernel_pinned_releases)

    # 计算待删除列表；无法可靠识别当前运行内核对应的包时放弃删除（fail-safe）
    local removals=""
    if ! removals="$(printf '%s\n' "${kernel_list[@]}" | kernel_cleanup_select_removals "$current_release" "${pinned_releases[@]}")"; then
        log_error "无法可靠识别当前运行内核 $current_release 对应的已安装内核包，已放弃自动清理"
        log_warn "为防止误删正在运行的内核，本次不执行任何删除操作，请手动确认后再处理"
        return 1
    fi

    local -a kernels_to_remove
    mapfile -t kernels_to_remove < <(printf '%s\n' "$removals" | sed '/^$/d')

    echo -e "${CYAN}当前运行内核: ${GREEN}$current_release${NC} ${YELLOW}(始终保留)${NC}"
    if [[ ${#pinned_releases[@]} -gt 0 ]]; then
        echo -e "${CYAN}已固定 (pin) 内核: ${GREEN}${pinned_releases[*]}${NC} ${YELLOW}(始终保留)${NC}"
    fi

    if [[ ${#kernels_to_remove[@]} -eq 0 ]]; then
        log_success "没有需要清理的旧内核（保留当前运行内核与最新 2 个内核 release）"
        return 0
    fi

    echo -e "${YELLOW}将删除以下 ${#kernels_to_remove[@]} 个旧内核包（保留最新 2 个内核 release 与当前运行内核）：${NC}"
    local kernel=""
    for kernel in "${kernels_to_remove[@]}"; do
        echo -e "  ${RED}•${NC} $kernel"
    done

    local confirm=""
    read -p "是否继续？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "取消内核清理"
        return 0
    fi

    # 删除旧内核
    local removed_count=0
    local failed_count=0
    for kernel in "${kernels_to_remove[@]}"; do
        log_info "正在删除内核: $kernel"
        if apt-get remove -y --purge "$kernel"; then
            log_success "内核 $kernel 删除成功"
            removed_count=$((removed_count + 1))
        else
            log_error "删除内核 $kernel 失败"
            failed_count=$((failed_count + 1))
        fi
    done

    # 更新引导配置
    update_grub_config

    if [[ $failed_count -gt 0 ]]; then
        log_error "旧内核清理未全部完成：成功 $removed_count 个，失败 $failed_count 个"
        log_tips "失败的内核包仍保留在系统中，请根据上方 apt 输出手动处理后重试"
        return 1
    fi

    log_success "旧内核清理完成（共删除 $removed_count 个内核包）"
    return 0
}

# 内核管理主菜单
kernel_management_menu() {
    run_menu "内核管理菜单" kernel_management_menu_render kernel_management_menu_dispatch "0-6"
}

kernel_management_menu_render() {
    show_menu_option "1" "显示当前内核信息"
    show_menu_option "2" "查看可用内核列表"
    show_menu_option "3" "安装新内核"
    show_menu_option "4" "设置默认启动内核"
    show_menu_option "5" "${RED}清理旧内核${NC}"
    show_menu_option "6" "${YELLOW}重启系统应用新内核${NC}"
}

kernel_management_menu_dispatch() {
    case "$1" in
        1) check_kernel_version ;;
        2) get_available_kernels ;;
        3) install_kernel_prompt ;;
        4) set_default_kernel_prompt ;;
        5) remove_old_kernels ;;
        6) kernel_reboot_prompt ;;
        *) return 1 ;;
    esac
    return 0
}

# 交互收集内核标识后安装
install_kernel_prompt() {
    local kernel_ver=""
    echo "请输入要安装的内核版本："
    echo "  - 完整包名格式 (推荐): 如 proxmox-kernel-6.14.8-2-pve"
    echo "  - 简化版本格式: 如 6.8.8-1 (将自动补全为 proxmox-kernel-6.8.8-1-pve)"
    prompt_value kernel_ver "请输入内核标识" || return 0
    install_kernel "$kernel_ver"
}

# 交互收集内核版本后设为默认启动项
set_default_kernel_prompt() {
    local kernel_ver=""
    prompt_value kernel_ver "请输入要设置为默认的内核版本 (例如: 6.8.8-1-pve)" || return 0
    set_default_kernel "$kernel_ver"
}

# 高风险确认后重启宿主机
kernel_reboot_prompt() {
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
