#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

coolercontrol_local_url() {
    local first_ip
    first_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -n "$first_ip" ]]; then
        echo "http://${first_ip}:11987"
    else
        echo "http://<PVE-IP>:11987"
    fi
}
coolercontrol_print_manual_install() {
    clear
    show_menu_header "CoolerControl 手动安装命令"
    echo "  官方项目: $COOLERCONTROL_PROJECT_URL"
    echo "  官方文档: $COOLERCONTROL_DOCS_URL"
    echo
    echo "  # 1. 下载并运行 Cloudsmith 官方 Debian 源配置脚本"
    echo "  wget -O /tmp/coolercontrol-setup.deb.sh \"$COOLERCONTROL_DEB_SETUP_URL\""
    echo "  bash /tmp/coolercontrol-setup.deb.sh"
    echo
    echo "  # 2. 安装守护进程并启动内置 Web UI"
    echo "  apt-get update"
    echo "  apt-get install -y coolercontrold"
    echo "  systemctl enable --now coolercontrold"
    echo
    echo "  # 可选：桌面 UI 和更广硬件支持"
    echo "  apt-get install -y coolercontrol lm-sensors liquidctl"
    echo
    echo "  Web UI: $(coolercontrol_local_url)"
}
coolercontrol_detect_status() {
    local service_state="未安装/未找到进程信息"

    if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W coolercontrold >/dev/null 2>&1; then
        service_state="已安装/未找到进程信息"
        if command -v systemctl >/dev/null 2>&1; then
            service_state="$(systemctl is-active coolercontrold 2>/dev/null || echo inactive)"
            case "$service_state" in
                active) service_state="已安装/运行中" ;;
                inactive) service_state="已安装/未运行" ;;
                failed) service_state="已安装/服务异常" ;;
                *) service_state="已安装/${service_state}" ;;
            esac
        fi
    elif pgrep -x coolercontrold >/dev/null 2>&1; then
        service_state="已安装/运行中"
    fi

    echo "$service_state"
}
coolercontrol_detect_version() {
    local daemon_version desktop_version

    if command -v dpkg-query >/dev/null 2>&1; then
        daemon_version="$(dpkg-query -W -f='${Version}' coolercontrold 2>/dev/null || true)"
        desktop_version="$(dpkg-query -W -f='${Version}' coolercontrol 2>/dev/null || true)"
    fi

    if [[ -n "$daemon_version" && -n "$desktop_version" && "$daemon_version" != "$desktop_version" ]]; then
        echo "coolercontrold ${daemon_version} / coolercontrol ${desktop_version}"
    elif [[ -n "$daemon_version" ]]; then
        echo "$daemon_version"
    elif [[ -n "$desktop_version" ]]; then
        echo "$desktop_version"
    else
        echo "未安装/未找到进程信息"
    fi
}
coolercontrol_install() {
    block_non_pve9_destructive "安装 CoolerControl 第三方风扇控制工具" || return 1

    local install_desktop install_optional tmp_script install_pkgs=()
    if ! command -v apt-get >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
        display_error "缺少 apt-get 或 systemctl" "请在 Debian/PVE 宿主机环境中运行。"
        return 1
    fi

    clear
    show_menu_header "安装 CoolerControl"
    echo -e "${CYAN}项目:${NC} $COOLERCONTROL_PROJECT_URL"
    echo -e "${CYAN}文档:${NC} $COOLERCONTROL_DOCS_URL"
    echo -e "${CYAN}源配置脚本:${NC} $COOLERCONTROL_DEB_SETUP_URL"
    echo "$UI_DIVIDER"
    echo "  将安装官方 Debian 包 coolercontrold。"
    echo "  coolercontrold 是系统守护进程，包含内置 Web UI。"
    echo "  PVE-Tools 不接管风扇曲线、不写入 CoolerControl 配置。"
    echo "$UI_DIVIDER"

    read -p "是否安装桌面 UI coolercontrol？PVE 宿主机通常不需要 [no]: " install_desktop
    install_desktop="${install_desktop:-no}"
    read -p "是否安装可选硬件支持包 lm-sensors/liquidctl？[yes]: " install_optional
    install_optional="${install_optional:-yes}"

    if ! confirm_high_risk_action "安装 CoolerControl 并添加第三方 APT 源" "会下载并运行 CoolerControl 官方 Cloudsmith 源配置脚本，并安装第三方软件包。" "第三方仓库或包异常可能影响 apt 源状态；风扇控制配置错误可能造成散热或噪音问题。" "建议先确认硬件支持情况，并保留 PVE 控制台访问；安装后先观察温度与风扇状态，再配置自动曲线。" "COOLER"; then
        return 0
    fi

    if ! tmp_script=$(mktemp /tmp/coolercontrol-setup.XXXXXX.sh); then
        display_error "无法创建临时文件" "请检查 /tmp 是否可写。"
        return 1
    fi

    log_info "下载 CoolerControl 官方 Debian 源配置脚本..."
    if ! pve_tools_download_file "$COOLERCONTROL_DEB_SETUP_URL" "$tmp_script" 60; then
        rm -f "$tmp_script"
        display_error "CoolerControl 源配置脚本下载失败" "请检查网络，或使用手动安装命令。"
        return 1
    fi

    chmod +x "$tmp_script"
    log_step "配置 CoolerControl APT 源..."
    if ! bash "$tmp_script"; then
        rm -f "$tmp_script"
        display_error "CoolerControl APT 源配置失败" "请检查脚本输出，或参考官方文档手动配置。"
        return 1
    fi
    rm -f "$tmp_script"

    log_step "更新软件包索引..."
    if ! apt-get update; then
        display_error "apt-get update 失败" "第三方源可能未正确配置，已停止安装。"
        return 1
    fi

    install_pkgs=(coolercontrold)
    [[ "$install_desktop" == "yes" || "$install_desktop" == "YES" ]] && install_pkgs+=(coolercontrol)
    [[ "$install_optional" == "yes" || "$install_optional" == "YES" ]] && install_pkgs+=(lm-sensors liquidctl)

    log_step "安装软件包: ${install_pkgs[*]}"
    if ! apt-get install -y "${install_pkgs[@]}"; then
        display_error "CoolerControl 安装失败" "请检查包名、软件源和网络连接。"
        return 1
    fi

    if systemctl enable --now coolercontrold; then
        display_success "CoolerControl 安装完成" "打开 Web UI: $(coolercontrol_local_url)"
    else
        display_error "CoolerControl 已安装，但服务启动失败" "请运行 systemctl status coolercontrold 查看原因。"
        return 1
    fi
}
coolercontrol_update() {
    block_non_pve9_destructive "更新 CoolerControl" || return 1

    local upgrade_pkgs=()

    if ! command -v apt-get >/dev/null 2>&1; then
        display_error "缺少 apt-get" "请在 Debian/PVE 宿主机环境中运行。"
        return 1
    fi

    if ! confirm_high_risk_action "更新 CoolerControl 软件包" "会刷新 apt 索引并升级 coolercontrold/coolercontrol 相关包。" "第三方源异常可能导致更新失败；服务重启期间风扇控制策略可能短暂不可用。" "请确认当前散热状态稳定，并保留控制台访问。" "COOLER-UPDATE"; then
        return 0
    fi

    apt-get update || {
        display_error "apt-get update 失败" "请检查 CoolerControl 源和网络连接。"
        return 1
    }

    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W coolercontrold >/dev/null 2>&1 && upgrade_pkgs+=(coolercontrold)
        dpkg-query -W coolercontrol >/dev/null 2>&1 && upgrade_pkgs+=(coolercontrol)
        dpkg-query -W lm-sensors >/dev/null 2>&1 && upgrade_pkgs+=(lm-sensors)
        dpkg-query -W liquidctl >/dev/null 2>&1 && upgrade_pkgs+=(liquidctl)
    fi

    if [[ ${#upgrade_pkgs[@]} -eq 0 ]]; then
        display_error "未检测到已安装的 CoolerControl 相关包" "请先执行安装，或使用手动安装命令。"
        return 1
    fi

    if ! apt-get install --only-upgrade -y "${upgrade_pkgs[@]}"; then
        display_error "CoolerControl 更新失败" "请检查软件包是否已安装以及 apt 输出。"
        return 1
    fi

    systemctl restart coolercontrold 2>/dev/null || log_warn "coolercontrold 重启失败，请手动检查服务状态。"
    display_success "CoolerControl 更新完成" "Web UI: $(coolercontrol_local_url)"
}
coolercontrol_uninstall() {
    block_non_pve9_destructive "卸载 CoolerControl" || return 1

    if ! command -v apt-get >/dev/null 2>&1; then
        display_error "缺少 apt-get" "请在 Debian/PVE 宿主机环境中运行。"
        return 1
    fi

    clear
    show_menu_header "卸载 CoolerControl"
    echo "  将停止 coolercontrold 服务，并卸载 coolercontrol/coolercontrold 软件包。"
    echo "  默认不会删除 Cloudsmith 源配置和用户配置目录，便于后续重新安装。"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "卸载 CoolerControl" "会停止第三方风扇控制服务并移除相关软件包。" "卸载后风扇控制将回到系统/固件默认行为，可能影响噪音和散热策略。" "请确认当前硬件默认风扇策略可接受，且已记录需要保留的 CoolerControl 配置。" "COOLER-REMOVE"; then
        return 0
    fi

    systemctl disable --now coolercontrold 2>/dev/null || true
    if apt-get remove -y coolercontrol coolercontrold; then
        display_success "CoolerControl 已卸载" "如需清理配置，可按官方文档手动处理。"
    else
        display_error "CoolerControl 卸载失败" "请检查 apt 输出并手动处理。"
        return 1
    fi
}
coolercontrol_manager_menu() {
    while true; do
        clear
        show_menu_header "Cooler Control 管理器"
        echo -e "当前状态 ： $(coolercontrol_detect_status)"
        echo -e "当前版本 ： $(coolercontrol_detect_version)"
        echo "$UI_DIVIDER"
        show_menu_option "1" "安装"
        show_menu_option "2" "更新"
        show_menu_option "3" "手动安装"
        show_menu_option "4" "卸载"
        echo "$UI_DIVIDER"
        echo "注意：本功能仅作为安装服务和服务管理，如需反馈问题请前往项目官方开源仓库反馈！"
        echo "$UI_DIVIDER"
        echo "项目官网：$COOLERCONTROL_PROJECT_URL"
        echo "开源协议：GNU General Public License v3.0 or later."
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) coolercontrol_install ;;
            2) coolercontrol_update ;;
            3) coolercontrol_print_manual_install ;;
            4) coolercontrol_uninstall ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
