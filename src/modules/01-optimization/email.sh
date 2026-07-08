#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

pve_mail_send_test() {
    local from_addr="$1"
    local to_addr="$2"
    local subject="$3"
    local body="$4"

    if ! command -v sendmail >/dev/null 2>&1; then
        display_error "未找到 sendmail" "请确认 postfix 已安装并提供 sendmail。"
        return 1
    fi

    {
        echo "From: ${from_addr}"
        echo "To: ${to_addr}"
        echo "Subject: ${subject}"
        echo
        echo "${body}"
    } | sendmail -f "${from_addr}" -t >/dev/null 2>&1
}
pve_mail_configure_postfix_smtp() {
    local relay_host="$1"
    local relay_port="$2"
    local tls_mode="$3"
    local sasl_user="$4"
    local sasl_pass="$5"

    if ! command -v postconf >/dev/null 2>&1; then
        display_error "未找到 postconf" "请先安装 postfix 并确保其命令可用。"
        return 1
    fi

    local relay
    relay="[${relay_host}]:${relay_port}"

    backup_file "/etc/postfix/main.cf" >/dev/null 2>&1 || true
    postconf -e "relayhost = ${relay}"
    postconf -e "smtp_use_tls = yes"
    postconf -e "smtp_tls_security_level = encrypt"
    postconf -e "smtp_sasl_auth_enable = yes"
    postconf -e "smtp_sasl_security_options ="
    postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    postconf -e "smtp_tls_CApath = /etc/ssl/certs"
    postconf -e "smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache"
    postconf -e "smtp_tls_session_cache_timeout = 3600s"

    if [[ "$tls_mode" == "wrapper" ]]; then
        postconf -e "smtp_tls_wrappermode = yes"
    else
        postconf -e "smtp_tls_wrappermode = no"
    fi

    local sasl_file="/etc/postfix/sasl_passwd"
    backup_file "$sasl_file" >/dev/null 2>&1 || true
    umask 077
    printf '%s %s:%s\n' "${relay}" "${sasl_user}" "${sasl_pass}" > "$sasl_file"
    chmod 600 "$sasl_file" >/dev/null 2>&1 || true

    if ! command -v postmap >/dev/null 2>&1; then
        display_error "未找到 postmap" "请确认 postfix 已安装完整。"
        return 1
    fi
    postmap "hash:${sasl_file}" >/dev/null 2>&1 || {
        display_error "postmap 执行失败" "请检查 /etc/postfix/sasl_passwd 格式与权限。"
        return 1
    }

    postfix reload >/dev/null 2>&1 || {
        systemctl reload postfix >/dev/null 2>&1 || systemctl restart postfix >/dev/null 2>&1 || true
    }

    return 0
}
pve_mail_configure_datacenter_emails() {
    local from_addr="$1"
    local root_addr="$2"

    if ! command -v pvesh >/dev/null 2>&1; then
        display_error "未找到 pvesh" "请确认当前环境为 PVE 宿主机。"
        return 1
    fi

    pvesh set /cluster/options --email-from "$from_addr" >/dev/null 2>&1 || {
        display_error "设置“来自…邮件”失败" "请在 WebUI：数据中心 -> 选项 -> 电子邮件（From）中手动设置。"
        return 1
    }

    pvesh set /access/users/root@pam --email "$root_addr" >/dev/null 2>&1 || {
        display_error "设置 root 邮箱失败" "请在 WebUI：数据中心 -> 权限 -> 用户 -> root@pam 中手动设置邮箱。"
        return 1
    }

    return 0
}
pve_mail_configure_zed_mail() {
    local from_addr="$1"
    local to_addr="$2"

    local zed_rc="/etc/zfs/zed.d/zed.rc"
    if [[ ! -f "$zed_rc" ]]; then
        log_warn "未找到 zed.rc（跳过 ZFS ZED 邮件配置）"
        return 0
    fi

    backup_file "$zed_rc" >/dev/null 2>&1 || true

    if grep -qE '^ZED_EMAIL_ADDR=' "$zed_rc"; then
        sed -i "s|^ZED_EMAIL_ADDR=.*|ZED_EMAIL_ADDR=\"${to_addr}\"|g" "$zed_rc"
    else
        printf '\nZED_EMAIL_ADDR="%s"\n' "$to_addr" >> "$zed_rc"
    fi

    if grep -qE '^ZED_EMAIL_OPTS=' "$zed_rc"; then
        sed -i "s|^ZED_EMAIL_OPTS=.*|ZED_EMAIL_OPTS=\"-r ${from_addr}\"|g" "$zed_rc"
    else
        printf 'ZED_EMAIL_OPTS="-r %s"\n' "$from_addr" >> "$zed_rc"
    fi

    systemctl restart zfs-zed >/dev/null 2>&1 || true
    return 0
}
pve_mail_notification_setup() {
    block_non_pve9_destructive "配置邮件通知（SMTP）" || return 1
    log_step "配置 PVE 邮件通知（商业邮箱 SMTP）"

    if ! command -v postfix >/dev/null 2>&1 && ! command -v postconf >/dev/null 2>&1; then
        display_error "未检测到 postfix" "请先安装 postfix 后再配置（安装过程可能需要交互）。"
        return 1
    fi

    local from_addr root_addr
    read -p "请输入“来自…邮件”（发件人邮箱）: " from_addr
    if [[ -z "$from_addr" ]]; then
        display_error "发件人邮箱不能为空"
        return 1
    fi

    read -p "请输入 root 通知邮箱（收件人邮箱）: " root_addr
    if [[ -z "$root_addr" ]]; then
        display_error "收件人邮箱不能为空"
        return 1
    fi

    local preset
    echo -e "${CYAN}请选择 SMTP 预设：${NC}"
    echo "  1) QQ 邮箱（smtp.qq.com:465 SSL）"
    echo "  2) 163 邮箱（smtp.163.com:465 SSL）"
    echo "  3) Gmail（smtp.gmail.com:587 STARTTLS）"
    echo "  4) 自定义（SMTP 兼容）"
    read -p "请选择 [1-4] (默认: 1): " preset
    preset="${preset:-1}"

    local smtp_host smtp_port tls_mode
    case "$preset" in
        1) smtp_host="smtp.qq.com"; smtp_port="465"; tls_mode="wrapper" ;;
        2) smtp_host="smtp.163.com"; smtp_port="465"; tls_mode="wrapper" ;;
        3) smtp_host="smtp.gmail.com"; smtp_port="587"; tls_mode="starttls" ;;
        4)
            read -p "请输入 SMTP 服务器地址（如 smtp.xxx.com）: " smtp_host
            read -p "请输入 SMTP 端口（如 465/587）: " smtp_port
            read -p "TLS 模式（wrapper/starttls）[wrapper]: " tls_mode
            tls_mode="${tls_mode:-wrapper}"
            ;;
        *) smtp_host="smtp.qq.com"; smtp_port="465"; tls_mode="wrapper" ;;
    esac

    if [[ -z "$smtp_host" || -z "$smtp_port" ]]; then
        display_error "SMTP 参数不完整"
        return 1
    fi
    if [[ "$tls_mode" != "wrapper" && "$tls_mode" != "starttls" ]]; then
        display_error "TLS 模式无效" "仅支持 wrapper 或 starttls"
        return 1
    fi

    local smtp_user smtp_pass
    read -p "请输入 SMTP 登录账号（通常为邮箱地址）[${from_addr}]: " smtp_user
    smtp_user="${smtp_user:-$from_addr}"
    if [[ -z "$smtp_user" ]]; then
        display_error "SMTP 账号不能为空"
        return 1
    fi

    echo -n "请输入 SMTP 密码/授权码（输入不回显）: "
    read -r -s smtp_pass
    echo
    if [[ -z "$smtp_pass" ]]; then
        display_error "SMTP 密码/授权码不能为空"
        return 1
    fi

    clear
    show_menu_header "邮件通知配置确认"
    echo -e "${YELLOW}发件人（From）:${NC} $from_addr"
    echo -e "${YELLOW}收件人（root 邮箱）:${NC} $root_addr"
    echo -e "${YELLOW}SMTP 服务器:${NC} ${smtp_host}:${smtp_port}"
    echo -e "${YELLOW}TLS 模式:${NC} ${tls_mode}"
    echo -e "${YELLOW}SMTP 账号:${NC} ${smtp_user}"
    echo -e "${UI_DIVIDER}"
    echo -e "${RED}提醒：此功能会修改 postfix 配置并写入 SMTP 凭据文件。${NC}"
    echo -e "${RED}请确保你使用的是邮箱提供商的 SMTP 授权码/应用专用密码，而非登录密码。${NC}"
    echo -e "${UI_DIVIDER}"

    if ! confirm_action "开始应用配置并重载 postfix？"; then
        return 0
    fi

    log_step "配置 PVE 数据中心邮件选项"
    pve_mail_configure_datacenter_emails "$from_addr" "$root_addr" || return 1

    log_step "安装 SASL 模块（libsasl2-modules）"
    apt-get update >/dev/null 2>&1 || true
    if ! apt-get install -y libsasl2-modules >/dev/null 2>&1; then
        display_error "安装 libsasl2-modules 失败" "请检查网络与软件源。"
        return 1
    fi

    log_step "配置 postfix 通过 SMTP 中继发信"
    pve_mail_configure_postfix_smtp "$smtp_host" "$smtp_port" "$tls_mode" "$smtp_user" "$smtp_pass" || return 1

    local test_choice="yes"
    read -p "是否发送测试邮件？(yes/no) [yes]: " test_choice
    test_choice="${test_choice:-yes}"
    if [[ "$test_choice" == "yes" || "$test_choice" == "YES" ]]; then
        log_step "发送测试邮件"
        if pve_mail_send_test "$from_addr" "$root_addr" "PVE-Tools 邮件测试" "这是一封测试邮件：如果你收到，说明 SMTP 中继已可用。"; then
            log_success "测试邮件已提交发送队列（请检查收件箱与垃圾箱）"
        else
            log_warn "测试邮件发送失败，请检查 postfix 日志与 SMTP 配置"
            log_tips "可查看：journalctl -u postfix -n 200 或 tail -n 200 /var/log/mail.log"
        fi
    fi

    local zed_choice="no"
    read -p "是否额外配置 ZFS ZED 邮件（ZFS 阵列事件通知）？(yes/no) [no]: " zed_choice
    zed_choice="${zed_choice:-no}"
    if [[ "$zed_choice" == "yes" || "$zed_choice" == "YES" ]]; then
        log_step "配置 ZFS ZED 邮件参数"
        pve_mail_configure_zed_mail "$from_addr" "$root_addr" || true
        log_success "ZED 配置已处理（建议手动制造一次 ZFS 事件验证）"
    fi

    display_success "邮件通知配置完成" "建议在 WebUI 里触发一次通知或检查系统事件确认生效。"
    return 0
}

# 获取已安装的 PVE 内核包（兼容 pve-kernel / proxmox-kernel 以及 -signed 后缀）
