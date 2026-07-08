#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

host_network_show_risk_banner() {
    echo -e "${RED}${UI_DIVIDER}${NC}"
    echo -e "${RED}高风险提示：以下功能会直接改写宿主机网络、防火墙和 IPv6 行为。${NC}"
    echo -e "${YELLOW}请仅在控制台或带外管理可用、已确认维护窗口、已准备回滚方案时继续。${NC}"
    echo -e "${YELLOW}错误的 bridge / bond / VLAN / 路由 / 防火墙规则可能导致 SSH 与 WebUI 断连。${NC}"
    echo -e "${RED}${UI_DIVIDER}${NC}"
}
host_network_ensure_interfaces_file() {
    if [[ ! -f "$HOST_NETWORK_INTERFACES_FILE" ]]; then
        cat > "$HOST_NETWORK_INTERFACES_FILE" <<'EOF_INTERFACES'
auto lo
iface lo inet loopback
EOF_INTERFACES
    fi
}
host_network_get_all_interface_names() {
    host_network_ensure_interfaces_file
    {
        awk '/^iface[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null
        ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1
    } | awk 'NF && $1 != "lo"' | sort -u
}
host_network_get_configured_bridges() {
    host_network_ensure_interfaces_file
    awk '/^iface[[:space:]]+vmbr[0-9]+[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | sort -u
}
host_network_get_configured_vlans() {
    host_network_ensure_interfaces_file
    awk '/^iface[[:space:]]+[A-Za-z0-9_.:-]+\.[0-9]+[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | sort -u
}
host_network_get_configured_bonds() {
    host_network_ensure_interfaces_file
    awk '/^iface[[:space:]]+bond[0-9]+[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | sort -u
}
host_network_guess_next_name() {
    local prefix="$1"
    local idx=0
    while :; do
        if ! host_network_get_all_interface_names | grep -qx "${prefix}${idx}"; then
            echo "${prefix}${idx}"
            return 0
        fi
        idx=$((idx + 1))
    done
}
host_network_validate_iface_name() {
    local name="$1"
    [[ -n "$name" && ${#name} -le 15 && "$name" =~ ^[A-Za-z0-9_.:-]+$ ]]
}
host_network_validate_mtu() {
    local mtu="$1"
    [[ -z "$mtu" ]] && return 0
    if [[ ! "$mtu" =~ ^[0-9]+$ || "$mtu" -lt 576 || "$mtu" -gt 9216 ]]; then
        display_error "MTU 不合法: $mtu" "请输入 576-9216 之间的整数，或留空保持默认。"
        return 1
    fi
}
host_network_get_iface_mac() {
    local iface="$1"
    local mac
    mac="$(cat "/sys/class/net/${iface}/address" 2>/dev/null || true)"
    [[ "$mac" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] && echo "$mac" || echo ""
}
host_network_get_physical_ifaces_with_mac() {
    local iface mac
    for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | sort -u); do
        [[ "$iface" == "lo" ]] && continue
        # 跳过 bridge、bond、vlan 等虚拟接口
        [[ -f "/sys/class/net/${iface}/device/vendor" ]] || continue
        mac="$(host_network_get_iface_mac "$iface")"
        [[ -n "$mac" ]] || continue
        printf '%s|%s\n' "$iface" "$mac"
    done
}
host_network_validate_mac() {
    local mac="$1"
    [[ "$mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]
}
host_network_mac_to_iface() {
    local target_mac="$1"
    target_mac="$(echo "$target_mac" | tr '[:upper:]' '[:lower:]')"
    local iface mac
    for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | sort -u); do
        [[ "$iface" == "lo" ]] && continue
        mac="$(host_network_get_iface_mac "$iface")"
        [[ "$(echo "$mac" | tr '[:upper:]' '[:lower:]')" == "$target_mac" ]] && { echo "$iface"; return 0; }
    done
    return 1
}
host_network_validate_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    awk -F'.' '{for(i=1;i<=4;i++) if($i < 0 || $i > 255) exit 1; exit 0}' <<< "$ip"
}
host_network_validate_ipv4_cidr() {
    local value="$1"
    local ip="${value%/*}"
    local prefix="${value##*/}"
    [[ "$value" == */* ]] || return 1
    host_network_validate_ipv4 "$ip" || return 1
    [[ "$prefix" =~ ^[0-9]+$ && "$prefix" -ge 0 && "$prefix" -le 32 ]]
}
host_network_validate_ipv6() {
    local ip="$1"
    [[ "$ip" == *:* ]] || return 1
    [[ "$ip" =~ ^[0-9A-Fa-f:]+(%[A-Za-z0-9_.-]+)?$ ]]
}
host_network_validate_ipv6_cidr() {
    local value="$1"
    local ip="${value%/*}"
    local prefix="${value##*/}"
    [[ "$value" == */* ]] || return 1
    host_network_validate_ipv6 "$ip" || return 1
    [[ "$prefix" =~ ^[0-9]+$ && "$prefix" -ge 0 && "$prefix" -le 128 ]]
}
host_network_validate_static_address() {
    local family="$1"
    local address="$2"
    case "$family" in
        inet) host_network_validate_ipv4_cidr "$address" ;;
        inet6) host_network_validate_ipv6_cidr "$address" ;;
        *) return 1 ;;
    esac
}
host_network_validate_gateway() {
    local family="$1"
    local gateway="$2"
    [[ -z "$gateway" ]] && return 0
    case "$family" in
        inet) host_network_validate_ipv4 "$gateway" ;;
        inet6) host_network_validate_ipv6 "$gateway" ;;
        *) return 1 ;;
    esac
}
host_network_iface_exists() {
    local iface_name="$1"
    host_network_get_all_interface_names | grep -qx "$iface_name"
}
host_network_interface_has_master_dependency() {
    local iface_name="$1"
    awk -v iface_name="$iface_name" '
        /^[[:space:]]*(bridge-ports|bond-slaves)[[:space:]]+/ {
            for (i=2; i<=NF; i++) {
                if ($i == iface_name) {
                    print $0
                    exit
                }
            }
        }
    ' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | grep -q .
}
host_network_validate_member_list() {
    local members_text="$1"
    local owner_name="$2"
    local relation_label="$3"
    local -A seen=()
    local member count=0

    while IFS= read -r member; do
        [[ -n "$member" ]] || continue
        host_network_validate_iface_name "$member" || {
            display_error "$relation_label 中包含非法接口名: $member"
            return 1
        }
        [[ "$member" != "$owner_name" ]] || {
            display_error "$relation_label 不能引用自身接口: $owner_name"
            return 1
        }
        if [[ -n "${seen[$member]:-}" ]]; then
            display_error "$relation_label 中存在重复成员: $member"
            return 1
        fi
        seen[$member]=1
        host_network_iface_exists "$member" || {
            display_error "接口不存在: $member" "请先确认该接口已经存在于宿主机链路或配置中。"
            return 1
        }
        if host_network_interface_has_master_dependency "$member"; then
            display_error "接口已被其他 bridge/bond 使用: $member" "请先解除现有从属关系，再重新编排宿主机网络。"
            return 1
        fi
        count=$((count + 1))
    done < <(printf '%s\n' "$members_text" | tr ' ' '\n' | awk 'NF')

    if (( count == 0 )); then
        display_error "$relation_label 不能为空"
        return 1
    fi
}
host_network_select_from_text() {
    local title="$1"
    local items_text="$2"
    mapfile -t items < <(printf '%s\n' "$items_text" | awk 'NF')
    if (( ${#items[@]} == 0 )); then
        return 1
    fi

    echo -e "${CYAN}${title}${NC}" >&2
    local i=1
    for item in "${items[@]}"; do
        printf '  [%d] %s\n' "$i" "$item" >&2
        i=$((i + 1))
    done
    echo "$UI_DIVIDER" >&2

    local pick
    read -p "请选择序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#items[@]} )); then
        return 1
    fi
    printf '%s\n' "${items[$((pick - 1))]}"
}
host_network_select_interface_name() {
    host_network_select_from_text "可用接口：" "$(host_network_get_all_interface_names)"
}
host_network_select_bridge_name() {
    host_network_select_from_text "已配置桥接：" "$(host_network_get_configured_bridges)"
}
host_network_select_bond_name() {
    host_network_select_from_text "已配置 Bond：" "$(host_network_get_configured_bonds)"
}
host_network_select_vlan_name() {
    host_network_select_from_text "已配置 VLAN 子接口：" "$(host_network_get_configured_vlans)"
}
host_network_show_current_overview() {
    clear
    show_menu_header "宿主机网络概览"
    echo -e "${CYAN}运行时链路：${NC}"
    ip -brief link 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}运行时地址：${NC}"
    ip -brief addr 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}默认路由：${NC}"
    ip route 2>/dev/null | sed 's/^/  /' || true
    ip -6 route 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}当前配置中的 bridge / bond / VLAN：${NC}"
    awk '
        /^iface[[:space:]]+/ {
            name=$2
            fam=$3
            method=$4
            if (name ~ /^vmbr[0-9]+$/ || name ~ /^bond[0-9]+$/ || name ~ /\.[0-9]+$/) {
                printf "  %s (%s %s)\n", name, fam, method
            }
        }
    ' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null || true
    echo "$UI_DIVIDER"
}
host_network_collect_family_config() {
    local family="$1"
    local phase="${2:-create}"
    local choice method address gateway extra

    if [[ "$family" == "inet" ]]; then
        if [[ "$phase" == "update" ]]; then
            echo "  [1] 保持当前 IPv4" >&2
            echo "  [2] 静态 IPv4" >&2
            echo "  [3] DHCPv4" >&2
            read -p "请选择 IPv4 模式 [1-3]: " choice
            case "$choice" in
                1|"") echo "keep|||"; return 0 ;;
                2) method="static" ;;
                3) method="dhcp" ;;
                *) return 1 ;;
            esac
        else
            echo "  [1] 静态 IPv4" >&2
            echo "  [2] DHCPv4" >&2
            echo "  [3] 不配置 IPv4" >&2
            read -p "请选择 IPv4 模式 [1-3]: " choice
            case "$choice" in
                1) method="static" ;;
                2) method="dhcp" ;;
                3|"") echo "none|||"; return 0 ;;
                *) return 1 ;;
            esac
        fi
    else
        if [[ "$phase" == "update" ]]; then
            echo "  [1] 保持当前 IPv6" >&2
            echo "  [2] 静态 IPv6" >&2
            echo "  [3] DHCPv6" >&2
            echo "  [4] SLAAC" >&2
            echo "  [5] 移除 IPv6 stanza" >&2
            read -p "请选择 IPv6 模式 [1-5]: " choice
            case "$choice" in
                1|"") echo "keep|||"; return 0 ;;
                2) method="static" ;;
                3) method="dhcp" ;;
                4) method="auto"; extra="accept-ra 2" ;;
                5) echo "remove|||"; return 0 ;;
                *) return 1 ;;
            esac
        else
            echo "  [1] 静态 IPv6" >&2
            echo "  [2] DHCPv6" >&2
            echo "  [3] SLAAC" >&2
            echo "  [4] 不配置 IPv6" >&2
            read -p "请选择 IPv6 模式 [1-4]: " choice
            case "$choice" in
                1) method="static" ;;
                2) method="dhcp" ;;
                3) method="auto"; extra="accept-ra 2" ;;
                4|"") echo "none|||"; return 0 ;;
                *) return 1 ;;
            esac
        fi
    fi

    if [[ "$method" == "static" ]]; then
        if [[ "$family" == "inet" ]]; then
            read -p "请输入静态 IPv4/CIDR（示例 192.168.10.2/24）: " address
        else
            read -p "请输入静态 IPv6/CIDR（示例 2001:db8::2/64）: " address
        fi
        [[ -n "$address" ]] || return 1
        host_network_validate_static_address "$family" "$address" || {
            display_error "静态地址格式无效: $address"
            return 1
        }
        read -p "请输入网关（留空跳过）: " gateway
        host_network_validate_gateway "$family" "$gateway" || {
            display_error "网关格式无效: $gateway"
            return 1
        }
    fi

    printf '%s|%s|%s|%s\n' "$method" "$address" "$gateway" "$extra"
}
host_network_extract_family_stanza() {
    local file_path="$1"
    local iface_name="$2"
    local family="$3"
    awk -v iface_name="$iface_name" -v family="$family" '
        BEGIN { capture=0 }
        {
            if (capture) {
                if ($0 !~ /^[[:space:]]/ && $0 ~ /^(iface|auto|allow-)/) {
                    exit
                }
                print
                next
            }
            if ($0 ~ ("^iface[[:space:]]+" iface_name "[[:space:]]+" family "([[:space:]]+|$)")) {
                capture=1
                print
            }
        }
    ' "$file_path"
}
host_network_collect_preserved_family_options() {
    local file_path="$1"
    local iface_name="$2"
    local family="$3"
    host_network_extract_family_stanza "$file_path" "$iface_name" "$family" | awk '
        NR == 1 { next }
        /^[[:space:]]+/ {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^(address|gateway|netmask|broadcast|pointopoint|accept-ra|dns-nameservers|dns-search)([[:space:]]|$)/) next
            if (line ~ /MASQUERADE/) next
            if (line ~ /net\.ipv6\.conf\.all\.forwarding/) next
            print line
        }
    '
}
host_network_remove_iface_family_from_candidate() {
    local file_path="$1"
    local iface_name="$2"
    local family="$3"
    local tmp
    tmp=$(mktemp)
    awk -v iface_name="$iface_name" -v family="$family" '
        BEGIN { skip=0 }
        {
            if (skip) {
                if ($0 !~ /^[[:space:]]/ && $0 !~ /^$/) {
                    skip=0
                } else {
                    next
                }
            }
            if ($0 ~ ("^iface[[:space:]]+" iface_name "[[:space:]]+" family "([[:space:]]+|$)")) {
                skip=1
                next
            }
            print
        }
    ' "$file_path" > "$tmp"
    mv "$tmp" "$file_path"
}
host_network_remove_iface_from_candidate() {
    local file_path="$1"
    local iface_name="$2"
    local tmp
    tmp=$(mktemp)
    awk -v iface_name="$iface_name" '
        BEGIN { skip=0 }
        function rebuild_line(line,   n, i, parts, out, kept) {
            n=split(line, parts, /[[:space:]]+/)
            out=parts[1]
            kept=0
            for (i=2; i<=n; i++) {
                if (parts[i] == iface_name || parts[i] == "") continue
                out=out " " parts[i]
                kept=1
            }
            if (kept) print out
        }
        {
            if (skip) {
                if ($0 !~ /^[[:space:]]/ && $0 !~ /^$/) {
                    skip=0
                } else {
                    next
                }
            }
            if ($0 ~ ("^# PVE-TOOLS HOST IFACE (BEGIN|END) " iface_name "$")) next
            if ($0 ~ /^(auto|allow-[^[:space:]]+)/) {
                if ($0 ~ ("(^|[[:space:]])" iface_name "([[:space:]]|$)")) {
                    rebuild_line($0)
                    next
                }
            }
            if ($0 ~ ("^iface[[:space:]]+" iface_name "[[:space:]]+(inet|inet6)([[:space:]]+|$)")) {
                skip=1
                next
            }
            print
        }
    ' "$file_path" > "$tmp"
    mv "$tmp" "$file_path"
}
host_network_ensure_auto_line_in_candidate() {
    local file_path="$1"
    local iface_name="$2"
    if ! grep -Eq "^(auto|allow-[^[:space:]]+)[[:space:]].*\b${iface_name}\b" "$file_path"; then
        printf '\nauto %s\n' "$iface_name" >> "$file_path"
    fi
}
host_network_append_text_to_candidate() {
    local file_path="$1"
    local text="$2"
    printf '\n%s\n' "$text" >> "$file_path"
}
host_network_build_family_stanza() {
    local iface_name="$1"
    local family="$2"
    local cfg="$3"
    local preserved_text="$4"
    local method address gateway extra
    IFS='|' read -r method address gateway extra <<< "$cfg"

    [[ "$method" == "remove" ]] && return 0
    [[ "$method" == "keep" ]] && return 0

    printf 'iface %s %s %s\n' "$iface_name" "$family" "$method"
    if [[ -n "$preserved_text" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf '    %s\n' "$line"
        done <<< "$preserved_text"
    fi
    [[ -n "$address" ]] && printf '    address %s\n' "$address"
    [[ -n "$gateway" ]] && printf '    gateway %s\n' "$gateway"
    [[ -n "$extra" ]] && printf '    %s\n' "$extra"
}
host_network_commit_candidate() {
    local candidate_file="$1"
    local action_desc="$2"
    local risk_desc="$3"
    local impact_desc="$4"
    local backup_desc="$5"
    local backup_path=""

    mkdir -p "$(dirname "$HOST_NETWORK_INTERFACES_STAGED_FILE")" >/dev/null 2>&1 || true
    cp "$candidate_file" "$HOST_NETWORK_INTERFACES_STAGED_FILE"

    clear
    show_menu_header "宿主机网络变更预览"
    echo -e "${YELLOW}动作:${NC} $action_desc"
    echo -e "${YELLOW}已写入 staged:${NC} $HOST_NETWORK_INTERFACES_STAGED_FILE"
    echo "$UI_DIVIDER"
    diff -u "$HOST_NETWORK_INTERFACES_FILE" "$candidate_file" 2>/dev/null | sed 's/^/  /' || true
    echo "$UI_DIVIDER"

    local stage_only
    read -p "是否只写入 staged 文件而不立即应用？(yes/no) [yes]: " stage_only
    stage_only="${stage_only:-yes}"
    if [[ "$stage_only" == "yes" || "$stage_only" == "YES" ]]; then
        display_success "候选网络配置已写入 staged 文件" "建议先在控制台或带外环境审阅后，再使用 pvenetcommit / ifreload 正式切换。"
        return 0
    fi

    if ! confirm_high_risk_action "$action_desc" "$risk_desc" "$impact_desc" "$backup_desc" "APPLY-NET"; then
        return 0
    fi

    backup_file "$HOST_NETWORK_INTERFACES_FILE" backup_path >/dev/null 2>&1 || true

    if command -v pvenetcommit >/dev/null 2>&1; then
        if pvenetcommit >/dev/null 2>&1; then
            display_success "网络配置已通过 pvenetcommit 提交" "如 SSH 断连，请通过控制台确认新链路已生效。"
            return 0
        fi
        log_warn "pvenetcommit 执行失败，准备回退到显式文件切换流程。"
    fi

    if ! command -v ifreload >/dev/null 2>&1; then
        display_error "当前环境缺少 ifreload，已拒绝直接覆盖正式网络配置" "请保留 staged 文件，并在控制台中使用 pvenetcommit 或人工审核后再应用。"
        return 1
    fi

    cp "$candidate_file" "$HOST_NETWORK_INTERFACES_FILE"
    if ifreload -a >/dev/null 2>&1; then
        display_success "网络配置已应用" "如当前会话断连，请通过控制台确认 bridge / bond / VLAN 和路由状态。"
        return 0
    fi

    if [[ -n "$backup_path" && -f "$backup_path" ]]; then
        log_warn "新网络配置应用失败，正在尝试自动恢复备份。"
        cp "$backup_path" "$HOST_NETWORK_INTERFACES_FILE"
        if ifreload -a >/dev/null 2>&1; then
            display_error "网络配置应用失败，已自动回滚" "请审阅 $HOST_NETWORK_INTERFACES_STAGED_FILE 与备份 $backup_path 后再重试。"
            return 1
        fi
        display_error "网络配置应用失败，且自动回滚未能重新加载" "请立即通过控制台检查 $HOST_NETWORK_INTERFACES_FILE、$HOST_NETWORK_INTERFACES_STAGED_FILE 与备份 $backup_path。"
        return 1
    fi

    display_error "网络配置应用失败" "未获取到可用备份，需立即通过控制台检查 $HOST_NETWORK_INTERFACES_FILE。"
    return 1
}
