#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

pve8_to_pve9_upgrade() {
    block_non_pve9_destructive "PVE 8.x 升级到 PVE 9.x" || return 1
    log_step "开始 PVE 8.x 升级到 PVE 9.x"
    
    # 检查当前 PVE 版本
    local current_pve_version=$(pveversion | head -n1 | cut -d'/' -f2 | cut -d'-' -f1)
    local major_version=$(echo $current_pve_version | cut -d'.' -f1)
    
    if [[ "$major_version" != "8" ]]; then
        log_error "当前 PVE 版本为 $current_pve_version，不是 PVE 8.x 版本，无法执行此升级"
        log_info "PVE7 请先试用ISO或升级教程升级哦! ：https://pve.proxmox.com/wiki/Upgrade_from_7_to_8"
        log_tips "如果你已经是PVE 9.x了，你还来用这个脚本，敲你额头！"
        return 1
    fi
    
    log_error "此操作将把 PVE 8.x 宿主机 不可逆的 升级到 PVE 9.x"
    log_error "已知风险包括但不限于："
    log_error "  • 系统无法启动（内核/引导变更）"
    log_error "  • 虚拟机/容器配置文件丢失或损坏"
    log_error "  • ZFS 池无法导入或数据集损坏"
    log_error "  • 网络配置被重置，导致失联"
    log_error "  • 集群节点脱离，需要手动修复"
    log_error "  • 第三方订阅/源被禁用，恢复困难"
    log_error ""
    log_error "【必须】完成以下准备工作，否则升级后无法恢复："
    echo "  1. 全系统备份（推荐使用 PBS 或 dd 备份系统盘）"
    echo "  2. 手动备份 /etc/pve, /var/lib/pve-cluster, /etc/network"
    echo "  3. 确保有 IPMI / iDRAC / 物理访问或急救系统可用"
    echo "  4. 阅读官方升级指南：https://pve.proxmox.com/wiki/Upgrade_from_8_to_9"
    log_error ""
    log_error "本脚本不提供任何回滚功能，不承担任何数据丢失责任"
    log_error "本脚本不提供任何回滚功能，不承担任何数据丢失责任"
    log_error "本脚本不提供任何回滚功能，不承担任何数据丢失责任"
    # 确认用户要继续执行升级
    echo "您确定要继续升级吗？本次任务执行以下操作："
    echo "注意：升级过程中可能会遇到一些警告或错误，请根据提示进行处理！脚本无法处理故障提示！(脚本只能把提示扔给你..) )"
    if ! confirm_high_risk_action \
        "PVE 8.x 升级到 PVE 9.x（不可逆）" \
        "系统可能无法启动、VM/CT 配置丢失、ZFS 池损坏、网络失联。" \
        "将更换 Debian 13 源、升级所有软件包、修改引导配置并强制重启。" \
        "请先完成 PBS/dd 全系统备份，手动备份 /etc/pve、/var/lib/pve-cluster、/etc/network，确保有 IPMI/iDRAC/物理访问。" \
        "yesido"; then
        log_info "已取消升级操作，明智之举"
        return 0
    fi
    
    # 1. 更新当前系统到最新 PVE 8.x 版本
    log_info "更新当前系统到最新 PVE 8.x 版本..."
    if ! apt update; then
        log_error "apt update 失败，请检查网络连接或源配置"
        return 1
    fi
    if ! apt dist-upgrade -y; then
        log_error "apt dist-upgrade 失败，请检查软件包冲突或前往作者的GitHub反馈issue"
        return 1
    fi
    
    # 再次检查当前版本
    current_pve_version=$(pveversion | head -n1 | cut -d'/' -f2 | cut -d'-' -f1)
    log_info "更新后 PVE 版本: ${GREEN}$current_pve_version${NC}"
    
    # PVE8.4 自带这个包，此处无需检查安装，apt 源无此包会报错。
    # 2. 安装和运行 pve8to9 检查工具
    # log_info "安装 pve8to9 升级检查工具..."
    # if ! apt install -y pve8to9; then
    #     log_warn "pve8to9 工具安装失败，尝试手动安装..."
    #     # 尝试手动添加 PVE 8 仓库安装 pve8to9
    #     if ! apt install -y pve8to9; then
    #         log_error "无法安装 pve8to9 检查工具,奇怪！请检查网络连接或源配置，或者前往作者的GitHub反馈issue.."
    #         return 1
    #     fi
    # fi
    
    log_info "运行升级前检查..."
    echo -e "${CYAN}pve8to9 检查结果：${NC}"
    # 运行 pve8to9 检查，但不直接退出，而是捕获输出并分析
    echo -e "检查结果会保存到 /tmp/pve8to9_check.log 文件中，如出现故障建议查看该文件以获取详细信息"
    echo -e "再次提示，脚本只能做到把错误扔给你，无法修复问题，请根据提示自行解决(或前往作者issue反馈问题)..."
    local check_result=$(pve8to9 | tee /tmp/pve8to9_check.log)
    echo "$check_result"
    
    # 检查是否有 FAIL 标记（这意味着有严重错误需要修复）
    if echo "$check_result" | grep -E -i "FAIL" > /dev/null; then
        log_error "pve8to9 检查发现严重错误!! 一般是软件包冲突或是其他报错!建议修复后再进行升级！"
        echo -e "${YELLOW}升级检查结果详情：${NC}"
        cat /tmp/pve8to9_check.log
        if ! confirm_high_risk_action \
            "忽略 pve8to9 严重错误并强制升级" \
            "pve8to9 检测到 FAIL 级别错误，忽略可能导致升级失败、系统无法启动或数据丢失。" \
            "将跳过 pve8to9 检查并继续执行 PVE 8.x → 9.x 升级流程。" \
            "这不是在开玩笑！请确保已完整备份并有回滚方案。" \
            "FORCE-UPGRADE"; then
            log_info "由于存在严重错误，已取消升级操作...返回主界面"
            return 1
        fi
    else
        log_success "pve8to9 检查通过，没有发现严重错误，太好了！"
        
        # 检查是否有 WARNING 标记
        if echo "$check_result" | grep -E -i "WARN" > /dev/null; then
            log_warn "pve8to9 检查发现一些警告信息，请查看以上详情并根据需要处理。(有些可能是软件包没升级上去，不是关键软件包可以无视先升级喔)"
            read -p "是否继续升级？(Y/n): " continue_check
            if [[ "$continue_check" == "n" || "$continue_check" == "N" ]]; then
                log_info "已取消升级操作"
                return 0
            fi
        fi
    fi
    
    # 3. 安装 CPU 微码（如果提示需要）
    log_info "检查是否需要安装 CPU 微码..."
    if command -v lscpu &> /dev/null; then
        local cpu_vendor=$(lscpu | grep "Vendor ID" | awk '{print $3}')
        if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
            log_info "检测到 Intel CPU，安装 Intel 微码..."
            apt install -y intel-microcode
        elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
            log_info "检测到 AMD CPU，安装 AMD 微码..."
            apt install -y amd64-microcode
        fi
    fi
    
    # 4. 检查当前启动方式并更新引导配置
    log_info "检查系统启动方式..."
    local boot_method="unknown"
    if [[ -d "/boot/efi" ]]; then
        boot_method="efi"
        log_info "检测到 EFI 启动模式"
        # 为 EFI 系统配置 GRUB
        echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections -v -u
    else
        boot_method="bios"
        log_info "检测到 BIOS 启动模式"
        log_tips "怎么还在用BIOS启用呀？建议升级到UEFI启动方式，提升系统兼容性和安全性"
    fi
    
    # 5. 备份当前源文件
    log_info "备份当前源文件..."
    local backup_dir="/etc/pve-tools-9-bak"
    mkdir -p "$backup_dir"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # 备份各种源文件
    if [[ -f "/etc/apt/sources.list" ]]; then
        cp /etc/apt/sources.list "${backup_dir}/sources.list.backup.${timestamp}"
    fi
    
    if [[ -f "/etc/apt/sources.list.d/pve-enterprise.list" ]]; then
        cp /etc/apt/sources.list.d/pve-enterprise.list "${backup_dir}/pve-enterprise.list.backup.${timestamp}"
    fi

    # 备份 PVE 核心数据库
    log_info "备份 PVE 核心数据库..."
    if [[ -d "/var/lib/pve-cluster" ]]; then
        cp -r /var/lib/pve-cluster "${backup_dir}/pve-cluster.backup.${timestamp}"
        log_success "核心数据库已备份至 ${backup_dir}"
    fi
    
    # 6. 更新源到 Debian 13 (Trixie) 并添加 PVE 9.x 源
    log_info "更新软件源到 Debian 13 (Trixie)..."
    
    # 将所有 bookworm 源替换为 trixie
    log_step "替换 sources.list 和 pve-enterprise.list 中的 bookworm 为 trixie"
    sed -i 's/bookworm/trixie/g' /etc/apt/sources.list 2>/dev/null || true
    sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
    
    # 创建 PVE 9.x 的 sources 配置文件
    log_step "创建 PVE 9.x 的 sources 配置文件..."
    cat > /etc/apt/sources.list.d/proxmox.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    # 创建 Ceph Squid 源配置文件
    log_step "创建 Ceph Squid 源配置文件..."
    cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    log_info "软件源已更新到 Debian 13 (Trixie) 和 PVE 9.x 配置"
    
    # 7. 再次运行升级前检查确认源更新无误
    log_info "再次运行 pve8to9 检查以确认源配置..."
    local final_check_result=$(pve8to9)
    if echo "$final_check_result" | grep -E -i "FAIL" > /dev/null; then
        log_error "pve8to9 最终检查发现错误，请手动检查源配置后再继续"
        echo "$final_check_result"
        return 1
    else
        log_success "源更新配置检查通过"
    fi
    
    # 8. 更新包列表并开始升级
    log_info "更新包列表..."
    if ! apt update; then
        log_error "更新包列表失败，请检查网络连接和源配置"
        return 1
    fi
    
    log_info "开始 PVE 9.x 升级过程，这可能需要较长时间..."
    log_warn "如果你正在使用Web UI内置的终端，建议改用SSH连接以防止连接中断"
    echo -e "${YELLOW}升级过程中可能会出现多个提示，通常按回车键或选择默认选项即可${NC}"
    
    # 使用非交互模式升级，自动回答问题
    DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"
    
    if [[ $? -ne 0 ]]; then
        log_error "PVE 升级过程失败，请查看日志并手动处理...如果是在看不明白可以试试问AI或者提交issue"
        return 1
    fi
    
    # 9. 清理无用包
    log_info "清理无用软件包..."
    apt autoremove -y
    apt autoclean
    
    # 10. 检查升级结果
    local new_pve_version=$(pveversion | head -n1 | cut -d'/' -f2 | cut -d'-' -f1)
    local new_major_version=$(echo $new_pve_version | cut -d'.' -f1)
    
    if [[ "$new_major_version" == "9" ]]; then
        log_success "（撒花）PVE 升级成功！新的 PVE 版本: ${GREEN}$new_pve_version${NC}"
        
        # 运行最终的升级后检查
        log_info "运行升级后检查..."
        pve8to9 2>/dev/null || true
        
        log_info "系统将在 30 秒后重启以完成升级..."
        log_success "如果一切顺利，重启后就能体验到PVE9啦！"
        log_warn "如果升级后出现问题，例如卡内核卡Grub，请先使用LiveCD抢修内核，提取日志文件后联系作者寻求帮助"
        echo -e "${YELLOW}按 Ctrl+C 可取消自动重启${NC}"
        sleep 30
        
        # 重启系统以完成升级
        log_info "正在重启系统以完成 PVE 9.x 升级..."
        reboot
    else
        log_error "升级完成后检查发现，PVE 版本仍为 $new_pve_version，升级可能未完全成功"
        log_tips "请手动检查系统状态，并确认是否需要重试升级"
        return 1
    fi
}

# 显示系统信息
