#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

security_report_item() {
    local level="$1"
    local title="$2"
    local detail="$3"
    local advice="$4"
    local color="$GREEN"

    case "$level" in
        高) color="$RED"; SECURITY_HIGH_COUNT=$((SECURITY_HIGH_COUNT + 1)) ;;
        中) color="$YELLOW"; SECURITY_MEDIUM_COUNT=$((SECURITY_MEDIUM_COUNT + 1)) ;;
        低) color="$CYAN"; SECURITY_LOW_COUNT=$((SECURITY_LOW_COUNT + 1)) ;;
    esac

    echo -e "${color}[${level}]${NC} ${title}"
    echo "  状态: $detail"
    echo "  建议: $advice"
    echo
}
security_pve_firewall_enabled() {
    local file="$1"

    [[ -f "$file" ]] || return 1
    awk '
        /^\[OPTIONS\]/ { in_options = 1; next }
        /^\[/ { in_options = 0 }
        in_options && $1 == "enable:" && $2 == "1" { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$file"
}
security_list_public_listeners() {
    if ! command -v ss >/dev/null 2>&1; then
        return 0
    fi

    ss -ltn 2>/dev/null | awk 'NR>1 {
        addr=$4
        n=split(addr, parts, ":")
        port=parts[n]
        if (addr ~ /^0\.0\.0\.0:/ || addr ~ /^\[::\]:/ || addr ~ /^\*:/ || addr ~ /^:::/) {
            print port "|" addr
        }
    }' | sort -u
}
security_risk_check() {
    local ssh_port password_auth empty_passwords fail2ban_state cluster_fw node_fw dangerous_ports upgradable uid0_extra loose_files

    SECURITY_HIGH_COUNT=0
    SECURITY_MEDIUM_COUNT=0
    SECURITY_LOW_COUNT=0

    clear
    show_menu_header "安全风险检查"
    echo -e "${YELLOW}本功能只读取配置和状态，不修改系统。${NC}"
    echo "$UI_DIVIDER"

    ssh_port="$(security_sshd_effective_option port)"
    ssh_port="${ssh_port:-unknown}"
    password_auth="$(security_sshd_effective_option passwordauthentication)"
    password_auth="${password_auth:-unknown}"
    if [[ "$ssh_port" == "22" ]]; then
        security_report_item "中" "SSH 使用默认端口 22" "当前端口: $ssh_port" "可进入本菜单的 SSH 一键加固，改为高位端口并同步防火墙规则。"
    else
        security_report_item "低" "SSH 端口检查" "当前端口: $ssh_port" "保持资产台账和防火墙规则同步。"
    fi

    if [[ "$password_auth" == "yes" ]]; then
        security_report_item "高" "SSH 允许密码登录" "PasswordAuthentication: yes" "确认密钥登录可用后，使用 SSH 一键加固禁用密码登录。"
    else
        security_report_item "低" "SSH 密码登录检查" "PasswordAuthentication: $password_auth" "定期检查 authorized_keys 和账号权限。"
    fi

    fail2ban_state="$(systemctl is-active fail2ban 2>/dev/null || echo inactive)"
    if [[ "$fail2ban_state" != "active" ]]; then
        security_report_item "中" "fail2ban 未运行" "状态: $fail2ban_state" "安装并启用 fail2ban，至少保护 sshd jail。"
    else
        security_report_item "低" "fail2ban 状态" "状态: active" "可用 fail2ban-client status sshd 复查封禁策略。"
    fi

    if security_pve_firewall_enabled "$PVE_CLUSTER_FIREWALL_FILE"; then
        cluster_fw="enabled"
    else
        cluster_fw="disabled"
    fi
    node_fw="/etc/pve/nodes/$(hostname)/host.fw"
    if security_pve_firewall_enabled "$node_fw"; then
        node_fw="enabled"
    else
        node_fw="disabled"
    fi
    if [[ "$cluster_fw" != "enabled" || "$node_fw" != "enabled" ]]; then
        security_report_item "中" "PVE 防火墙未完全启用" "datacenter=$cluster_fw, node=$node_fw" "进入宿主机网络与防火墙菜单，审查规则后启用数据中心和节点防火墙。"
    else
        security_report_item "低" "PVE 防火墙状态" "datacenter=enabled, node=enabled" "继续保持规则最小开放。"
    fi

    dangerous_ports="$(security_list_public_listeners | awk -F'|' '$1 ~ /^(21|23|25|111|139|445|3306|5432|6379|9200|9300)$/ || ($1 >= 5900 && $1 <= 5999) {print $0}')"
    if [[ -n "$dangerous_ports" ]]; then
        security_report_item "中" "检测到常见高风险端口对外监听" "$(echo "$dangerous_ports" | tr '\n' ' ')" "确认是否确需暴露；不需要时关闭服务或用防火墙限制来源。"
    else
        security_report_item "低" "服务暴露检查" "未发现常见高风险端口对外监听" "仍建议人工审查 ss -ltnup 输出。"
    fi

    upgradable="$(apt list --upgradable 2>/dev/null | awk 'NR>1 {print}' | head -n 10)"
    if [[ -n "$upgradable" ]]; then
        security_report_item "中" "存在待升级软件包" "$(echo "$upgradable" | wc -l) 个以上待升级条目（仅展示前 10 个）" "在维护窗口执行 apt update && apt upgrade，并重启到新内核后复查。"
        echo "$upgradable" | sed 's/^/    /'
        echo
    else
        security_report_item "低" "系统更新检查" "当前 apt 缓存未显示待升级包" "该检查不主动刷新 apt 缓存；建议定期运行 apt update。"
    fi

    empty_passwords="$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null | tr '\n' ' ')"
    uid0_extra="$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd 2>/dev/null | tr '\n' ' ')"
    if [[ -n "$empty_passwords" || -n "$uid0_extra" ]]; then
        security_report_item "高" "账户风险" "空密码账户: ${empty_passwords:-无}; 额外 UID0: ${uid0_extra:-无}" "立即锁定异常账户或设置强密码，并审查 /etc/passwd 与 /etc/shadow。"
    else
        security_report_item "低" "账户风险检查" "未发现空密码账户或额外 UID 0 账户" "继续保持最小账号集。"
    fi

    loose_files=""
    for file in /etc/ssh/sshd_config /etc/shadow /etc/pve/storage.cfg "$PVE_CLUSTER_FIREWALL_FILE"; do
        [[ -e "$file" ]] || continue
        if [[ -w "$file" && ! -O "$file" ]]; then
            loose_files+="$file(当前用户可写但非属主) "
        fi
        if find "$file" -maxdepth 0 -perm /022 2>/dev/null | grep -q .; then
            loose_files+="$file(组/其他可写) "
        fi
    done
    if [[ -n "$loose_files" ]]; then
        security_report_item "高" "关键配置文件权限过宽" "$loose_files" "恢复 root/系统默认属主和最小写权限，避免普通用户改写关键配置。"
    else
        security_report_item "低" "关键文件权限检查" "未发现组/其他可写的关键配置文件" "后续变更后继续复查。"
    fi

    echo "$UI_DIVIDER"
    echo -e "${CYAN}汇总:${NC} 高风险 $SECURITY_HIGH_COUNT / 中风险 $SECURITY_MEDIUM_COUNT / 低风险 $SECURITY_LOW_COUNT"
    echo -e "${YELLOW}提示:${NC} 该报告不会自动修复系统；需要改配置时请从对应菜单进入并确认风险。"
}
