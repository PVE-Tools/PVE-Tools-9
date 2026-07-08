#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

security_ssh_service_name() {
    local service

    for service in ssh.service sshd.service ssh; do
        if systemctl list-unit-files "$service" >/dev/null 2>&1 || systemctl status "$service" >/dev/null 2>&1; then
            echo "${service%.service}"
            return 0
        fi
    done
    echo "ssh"
}
security_sshd_effective_option() {
    local key="$1"
    local lower_key
    lower_key="$(echo "$key" | tr 'A-Z' 'a-z')"

    if command -v sshd >/dev/null 2>&1; then
        sshd -T 2>/dev/null | awk -v key="$lower_key" '$1 == key {print $2; exit}'
    fi
}
security_root_authorized_keys_ready() {
    local auth_file="/root/.ssh/authorized_keys"

    [[ -f "$auth_file" ]] || return 1
    grep -Ev '^[[:space:]]*(#|$)' "$auth_file" >/dev/null 2>&1
}
security_validate_ssh_port() {
    local port="$1"

    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
        display_error "SSH 端口不合法: $port" "请使用 1024-65535 之间的高位端口。"
        return 1
    fi
    if (( port == 8006 )); then
        display_error "端口 8006 是 PVE Web UI 常用端口" "请换一个端口。"
        return 1
    fi
}
security_random_ssh_port() {
    local port

    if command -v shuf >/dev/null 2>&1; then
        for _ in {1..20}; do
            port="$(shuf -i 20000-60999 -n 1)"
            if ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
                echo "$port"
                return 0
            fi
        done
    fi
    echo "22222"
}
security_ensure_sshd_include() {
    local config_file="/etc/ssh/sshd_config"

    if ! grep -Eiq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$config_file" 2>/dev/null; then
        local tmp
        tmp="$(mktemp)" || return 1
        {
            echo "Include /etc/ssh/sshd_config.d/*.conf"
            cat "$config_file"
        } > "$tmp"
        cat "$tmp" > "$config_file"
        rm -f "$tmp"
    fi
}
security_comment_global_sshd_directives() {
    local config_file="/etc/ssh/sshd_config"
    local tmp

    tmp="$(mktemp)" || return 1
    awk '
        BEGIN {
            in_match = 0
            keys["port"] = 1
            keys["passwordauthentication"] = 1
            keys["kbdinteractiveauthentication"] = 1
            keys["challengeresponseauthentication"] = 1
            keys["pubkeyauthentication"] = 1
            keys["permitemptypasswords"] = 1
        }
        /^[[:space:]]*Match[[:space:]]/ { in_match = 1 }
        {
            line = $0
            probe = line
            sub(/^[[:space:]]*/, "", probe)
            split(probe, parts, /[[:space:]]+/)
            key = tolower(parts[1])
            if (!in_match && line !~ /^[[:space:]]*#/ && keys[key]) {
                print "# PVE-Tools disabled global duplicate: " line
            } else {
                print line
            }
        }
    ' "$config_file" > "$tmp" || {
        rm -f "$tmp"
        return 1
    }
    cat "$tmp" > "$config_file"
    rm -f "$tmp"
}
security_write_sshd_hardening_dropin() {
    local port="$1"
    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="${dropin_dir}/99-pve-tools-hardening.conf"

    mkdir -p "$dropin_dir" || return 1
    cat > "$dropin_file" <<EOF
# Managed by PVE-Tools.
# Keep console or out-of-band access available before changing SSH policy.
Port $port
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
EOF
}
security_write_fail2ban_sshd_jail() {
    local port="$1"
    local maxretry="$2"
    local bantime="$3"
    local findtime="$4"
    local jail_dir="/etc/fail2ban/jail.d"
    local jail_file="${jail_dir}/pve-tools-sshd.conf"

    mkdir -p "$jail_dir" || return 1
    cat > "$jail_file" <<EOF
# Managed by PVE-Tools.
[sshd]
enabled = true
port = $port
maxretry = $maxretry
bantime = $bantime
findtime = $findtime
EOF
}
security_install_fail2ban_if_needed() {
    if command -v fail2ban-client >/dev/null 2>&1; then
        return 0
    fi

    log_warn "未检测到 fail2ban，准备通过 apt 安装。"
    if ! apt-get update; then
        display_error "apt-get update 失败" "请检查软件源和网络后重试。"
        return 1
    fi
    if ! apt-get install -y fail2ban; then
        display_error "fail2ban 安装失败" "请检查软件源和网络后重试。"
        return 1
    fi
}
security_restore_hardening_backups() {
    local ssh_backup="$1"
    local config_file="$2"
    local dropin_backup="$3"
    local dropin_file="$4"
    local jail_backup="$5"
    local jail_file="$6"

    [[ -n "$ssh_backup" && -f "$ssh_backup" ]] && cp -a "$ssh_backup" "$config_file" >/dev/null 2>&1 || true
    if [[ -n "$dropin_backup" && -f "$dropin_backup" ]]; then
        cp -a "$dropin_backup" "$dropin_file" >/dev/null 2>&1 || true
    else
        rm -f "$dropin_file" >/dev/null 2>&1 || true
    fi
    if [[ -n "$jail_backup" && -f "$jail_backup" ]]; then
        cp -a "$jail_backup" "$jail_file" >/dev/null 2>&1 || true
    else
        rm -f "$jail_file" >/dev/null 2>&1 || true
    fi
}
security_ssh_hardening() {
    block_non_pve9_destructive "SSH 一键加固" || return 1

    local current_port new_port maxretry bantime findtime ssh_service ssh_backup="" jail_backup="" dropin_backup=""
    local config_file="/etc/ssh/sshd_config"
    local jail_file="/etc/fail2ban/jail.d/pve-tools-sshd.conf"
    local dropin_file="/etc/ssh/sshd_config.d/99-pve-tools-hardening.conf"

    if [[ ! -f "$config_file" ]] || ! command -v sshd >/dev/null 2>&1; then
        display_error "未找到 OpenSSH Server 配置" "请确认 openssh-server 已安装。"
        return 1
    fi

    current_port="$(security_sshd_effective_option port)"
    current_port="${current_port:-22}"

    clear
    show_menu_header "SSH 一键加固"
    echo -e "${RED}重要:${NC} 禁用密码登录前，必须确认 SSH 密钥登录可用，或你有 PVE 控制台/带外管理方式。"
    echo -e "${CYAN}当前 SSH 端口:${NC} $current_port"
    echo -e "${CYAN}当前连接:${NC} ${SSH_CONNECTION:-未检测到 SSH_CONNECTION}"
    if security_root_authorized_keys_ready; then
        echo -e "${GREEN}检测到 /root/.ssh/authorized_keys 中存在公钥。${NC}"
    else
        echo -e "${RED}未检测到 root 公钥。继续后可能无法再通过密码 SSH 登录。${NC}"
    fi
    echo "$UI_DIVIDER"

    read -p "请输入新的 SSH 端口（留空随机生成高位端口）: " new_port
    new_port="${new_port:-$(security_random_ssh_port)}"
    security_validate_ssh_port "$new_port" || return 1

    read -p "fail2ban 最大失败次数 [5]: " maxretry
    maxretry="${maxretry:-5}"
    [[ "$maxretry" =~ ^[0-9]+$ && "$maxretry" -ge 1 ]] || {
        display_error "最大失败次数必须是正整数"
        return 1
    }
    read -p "fail2ban 封禁时间 [1h]: " bantime
    bantime="${bantime:-1h}"
    [[ "$bantime" =~ ^[0-9]+[smhd]?$ ]] || {
        display_error "封禁时间格式不合法" "示例: 3600 或 1h"
        return 1
    }
    read -p "fail2ban 检测时间窗口 [10m]: " findtime
    findtime="${findtime:-10m}"
    [[ "$findtime" =~ ^[0-9]+[smhd]?$ ]] || {
        display_error "检测窗口格式不合法" "示例: 600 或 10m"
        return 1
    }

    clear
    show_menu_header "SSH 加固确认"
    echo -e "${CYAN}新 SSH 端口:${NC} $new_port"
    echo -e "${CYAN}密码登录:${NC} 禁用"
    echo -e "${CYAN}密钥登录:${NC} 启用"
    echo -e "${CYAN}fail2ban:${NC} maxretry=$maxretry, bantime=$bantime, findtime=$findtime"
    echo -e "${YELLOW}执行后请使用:${NC} ssh -p $new_port root@<PVE-IP>"
    echo -e "${YELLOW}如启用 PVE/外部防火墙，请同步放行 TCP $new_port，并确认 8006 Web UI 或控制台可用。${NC}"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "修改 SSH 端口、禁用密码登录并配置 fail2ban" "错误配置可能导致 SSH 无法连接；未准备密钥时会失去密码登录入口。" "当前远程会话可能在 sshd 重启后无法重新连接，需要通过控制台修复。" "请确认密钥登录已测试成功，控制台/带外访问可用，并已记录原端口 $current_port。" "SSH-HARDEN"; then
        return 0
    fi

    backup_file "$config_file" ssh_backup >/dev/null 2>&1 || return 1
    [[ -f "$jail_file" ]] && backup_file "$jail_file" jail_backup >/dev/null 2>&1 || true
    [[ -f "$dropin_file" ]] && backup_file "$dropin_file" dropin_backup >/dev/null 2>&1 || true

    if ! security_install_fail2ban_if_needed; then
        return 1
    fi

    if ! security_ensure_sshd_include || ! security_comment_global_sshd_directives || ! security_write_sshd_hardening_dropin "$new_port"; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        display_error "写入 SSH 配置失败，已尝试回滚" "备份文件: $ssh_backup"
        return 1
    fi

    if ! sshd -t -f "$config_file" 2>/tmp/pve-tools-sshd-test.log; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        sed 's/^/  /' /tmp/pve-tools-sshd-test.log 2>/dev/null || true
        display_error "sshd 配置语法检查失败，已自动回滚" "请检查 $config_file。"
        return 1
    fi

    if ! security_write_fail2ban_sshd_jail "$new_port" "$maxretry" "$bantime" "$findtime"; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        display_error "写入 fail2ban 配置失败，已尝试回滚 SSH/fail2ban 配置" "请人工检查 $config_file 和 $jail_file。"
        return 1
    fi

    ssh_service="$(security_ssh_service_name)"
    if ! systemctl restart "$ssh_service" 2>/dev/null; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        systemctl restart "$ssh_service" 2>/dev/null || true
        display_error "SSH 服务重启失败，已尝试回滚" "请通过控制台检查 SSH 状态。"
        return 1
    fi

    if ! systemctl enable --now fail2ban >/dev/null 2>&1 && ! systemctl restart fail2ban >/dev/null 2>&1; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        systemctl restart "$ssh_service" 2>/dev/null || true
        display_error "fail2ban 启动失败，已尝试回滚 SSH/fail2ban 配置" "请检查 systemctl status fail2ban。"
        return 1
    fi
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status sshd >/dev/null 2>&1 || log_warn "fail2ban sshd jail 暂未进入运行状态，请稍后用 fail2ban-client status sshd 检查。"
    fi

    display_success "SSH 加固已完成" "新连接命令: ssh -p $new_port root@<PVE-IP>；请立即新开终端验证后再关闭当前会话。"
}
