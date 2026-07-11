#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "哎呀！需要超级管理员权限才能运行哦"
        echo "请使用以下命令重新运行："
        echo "sudo $0"
        exit 1
    fi
}

# 检查调试模式
check_debug_mode() {
    for arg in "$@"; do
        if [[ "$arg" == "--i-know-what-i-do" ]]; then
            RISK_ACK_BYPASS=true
        fi
    done

    for arg in "$@"; do
        if [[ "$arg" == "--debug" ]]; then
            log_warn "警告：您正在使用调试模式！"
            echo "此模式将跳过 PVE 系统版本检测"
            echo "仅在开发和测试环境中使用"
            echo "在非 PVE (Debian 系) 系统上使用可能导致系统损坏"
            echo "您确定要继续吗？输入 'yes' 确认，其他任意键退出: "
            read -r confirm
            if [[ "$confirm" != "yes" ]]; then
                log_info "已取消操作，退出脚本"
                exit 0
            fi
            DEBUG_MODE=true
            log_success "已启用调试模式"
            return
        fi
    done
    DEBUG_MODE=false
}

# 检查是否安装依赖软件包
check_packages() {
    # 程序依赖的软件包: `sudo` `curl`
    local packages=("sudo" "curl")
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log_error "哎呀！需要安装 $pkg 软件包才能运行哦"
            echo "请使用以下命令安装：apt install -y $pkg"
            exit 1
        fi
    done
 }
    



# 检查 PVE 版本
check_pve_version() {
    # 如果在调试模式下，跳过 PVE 版本检测
    if [[ "$DEBUG_MODE" == "true" ]]; then
        log_warn "调试模式：跳过 PVE 版本检测"
        echo "请注意：您正在非 PVE 系统上运行此脚本，某些功能可能无法正常工作，某些操作可能会导致系统损坏，请谨慎使用！"
        PVE_VERSION_DETECTED="debug"
        PVE_MAJOR_VERSION="debug"
        return
    fi
    
    if ! command -v pveversion &> /dev/null; then
        log_error "咦？这里好像不是 PVE 环境呢"
        echo "请在 Proxmox VE 系统上运行此脚本"
        exit 1
    fi
    
    local pve_version pkg_ver out
    out="$(pveversion 2>/dev/null || true)"
    if [[ "$out" =~ pve-manager/([0-9]+(\.[0-9]+)*) ]]; then
        pve_version="${BASH_REMATCH[1]}"
    else
        pve_version=""
    fi
    if [[ -z "$pve_version" ]] && command -v dpkg-query >/dev/null 2>&1; then
        pkg_ver="$(dpkg-query -W -f='${Version}' pve-manager 2>/dev/null || true)"
        pve_version="$(echo "$pkg_ver" | grep -oE '^[0-9]+(\.[0-9]+)*' | head -n 1)"
    fi
    if [[ -z "$pve_version" ]]; then
        pve_version="unknown"
    fi

    PVE_VERSION_DETECTED="$pve_version"
    if [[ "$pve_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        PVE_MAJOR_VERSION="$(echo "$pve_version" | cut -d'.' -f1)"
    else
        PVE_MAJOR_VERSION="unknown"
    fi

    log_info "太好了！检测到 PVE 版本: $pve_version"

    if [[ "$PVE_MAJOR_VERSION" != "9" && "$RISK_ACK_BYPASS" != "true" ]]; then
        clear
        show_menu_header "高风险提示：非 PVE9 环境"
        echo -e "${RED}警告：检测到当前不是 PVE 9.x（当前：${PVE_VERSION_DETECTED}）。${NC}"
        echo -e "${RED}本脚本面向 PVE 9.x（Debian 13 / trixie）编写。${NC}"
        echo -e "${RED}在 PVE 7/8 等系统上执行“换源/升级/一键优化”等自动化修改，可能是毁灭性的：${NC}"
        echo -e "${RED}可能导致软件源错配、系统升级路径错误、依赖冲突、宿主机不可用。${NC}"
        echo -e "${UI_DIVIDER}"
        echo -e "${YELLOW}严禁在非 PVE9 上使用的选项（脚本将强制拦截）：${NC}"
        echo -e "  - 一键优化（换源+删弹窗+更新）"
        echo -e "  - 软件源与更新（更换软件源/更新系统软件包/PVE 8 升级到 9）"
        echo -e "${UI_DIVIDER}"
        echo -e "${CYAN}如你仍要继续使用脚本的其它功能，请手动输入以下任意一项以确认风险：${NC}"
        echo -e "  - 确认"
        echo -e "  - Confirm with Risks"
        echo -e "${UI_DIVIDER}"
        local ack ack_lc
        read -r -p "请输入确认文本以继续（回车退出）: " ack
        if [[ -z "$ack" ]]; then
            log_info "未确认风险，退出脚本"
            exit 0
        fi
        ack_lc="$(echo "$ack" | tr 'A-Z' 'a-z' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ +| +$//g')"
        if [[ "$ack" != "确认" && "$ack_lc" != "confirm with risks" ]]; then
            log_error "确认文本不匹配，已退出"
            exit 1
        fi
        log_warn "已确认风险：当前为非 PVE9 环境，将拦截毁灭性自动化修改功能"
    fi
}
block_non_pve9_destructive() {
    local feature="$1"
    if [[ "$DEBUG_MODE" == "true" ]]; then
        return 0
    fi
    if [[ "$RISK_ACK_BYPASS" == "true" ]]; then
        return 0
    fi
    if [[ "${PVE_MAJOR_VERSION:-}" != "9" ]]; then
        display_error "已拦截：非 PVE9 环境禁止执行该自动化操作" "功能：${feature}。请在 PVE9 上使用，或手动参考文档/自行处理。如需强制执行，请加启动参数 --i-know-what-i-do"
        return 1
    fi
    return 0
}
show_menu() {
    show_banner 
    show_menu_option "" "请选择您需要的功能："
    show_menu_option "1" "日常优化与通知 ${CYAN}( 弹窗 / 温度 / 电源 / 邮件 )${NC}"
    show_menu_option "2" "软件源与系统升级 ${CYAN}( 换源 / 更新 / PVE升级 )${NC}"
    show_menu_option "3" "启动与内核管理 ${CYAN}( 内核 / GRUB )${NC}"
    show_menu_option "4" "硬件直通与显卡 ${CYAN}( IOMMU / GPU / RDM / NVMe )${NC}"
    show_menu_option "5" "虚拟机运维与导入 ${CYAN}( 镜像 / 备份 / 恢复 / Cloud-Init )${NC}"
    show_menu_option "6" "宿主机网络与防火墙 ${CYAN}( 网桥 / VLAN / Bond / 规则 )${NC}"
    show_menu_option "7" "存储与磁盘维护 ${CYAN}( 路径 / 挂载 / 清理 / Ceph )${NC}"
    show_menu_option "8" "诊断工具与项目信息 ${CYAN}( 系统信息 / 救砖 / 脚本管理 )${NC}"
    show_menu_option "9" "安全中心 ${CYAN}( 风险检查 / SSH加固 )${NC}"
    show_menu_option "10" "第三方工具 ${CYAN}( CoolerControl / Modules / 社区脚本 )${NC}"
    echo "$UI_DIVIDER"
    show_menu_option "0" "${RED}退出脚本${NC}"
    show_menu_footer
    echo
    echo -e "  ${YELLOW}Tips: ${SESSION_TIP:-一言获取失败，本次会话不再重试。}${NC}"
    echo -e "本项目正在收集用户意见，如您愿意，请前往填写问卷，这能帮到整个项目！"
    echo -e "-> https://wj.qq.com/s2/27286538/9d9d/"
    echo
    echo -ne "  ${PRIMARY}请输入您的选择 [0-10]: ${NC}"
}
# 应急救砖工具箱菜单
main() {
    check_root
    ensure_legal_acceptance
    check_debug_mode "$@"
    check_pve_version
    network_offline_guard

    if [[ "$IS_OFFLINE_MODE" -eq 0 ]]; then
        detect_network_region >/dev/null 2>&1 || true
    fi
    fetch_session_tip

    if [[ "$IS_OFFLINE_MODE" -eq 1 ]]; then
        log_warn "离线模式下将跳过更新检查与镜像自动策略。"
    else
        check_update
    fi
    
    while true; do

        show_menu
        read -r choice
        echo
        
        case $choice in
            1)
                menu_optimization
                ;;
            2)
                menu_sources_updates
                ;;
            3)
                menu_boot_kernel
                ;;
            4)
                menu_gpu_passthrough
                ;;
            5)
                menu_vm_container
                ;;
            6)
                menu_host_networking
                ;;
            7)
                menu_storage_disk
                ;;
            8)
                menu_tools_about
                ;;
            9)
                security_center_menu
                ;;
            10)
                third_party_tools_menu
                ;;
            0)
                echo "感谢使用,谢谢喵"
                echo "再见！"
                exit 0
                ;;
            *)
                log_error "哎呀，这个选项不存在呢"
                log_warn "请输入 0-10 之间的数字"
                ;;
        esac
        
        echo
        pause_function
    done
}
