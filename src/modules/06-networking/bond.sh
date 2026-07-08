#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

host_network_build_bond_block() {
    local iface_name="$1"
    local slaves="$2"
    local mode="$3"
    local mtu="$4"
    local ipv4_cfg="$5"
    local ipv6_cfg="$6"
    local mode_name=""
    local v4_method v4_addr v4_gw v4_extra
    local v6_method v6_addr v6_gw v6_extra
    IFS='|' read -r v4_method v4_addr v4_gw v4_extra <<< "$ipv4_cfg"
    IFS='|' read -r v6_method v6_addr v6_gw v6_extra <<< "$ipv6_cfg"

    case "$mode" in
        0) mode_name="balance-rr" ;;
        1) mode_name="active-backup" ;;
        4) mode_name="802.3ad" ;;
        6) mode_name="balance-alb" ;;
        *) return 1 ;;
    esac

    [[ "$v4_method" == "none" ]] && v4_method="manual"
    printf 'auto %s\n' "$iface_name"
    printf 'iface %s inet %s\n' "$iface_name" "$v4_method"
    printf '    bond-slaves %s\n' "$slaves"
    printf '    bond-mode %s\n' "$mode_name"
    printf '    bond-miimon 100\n'
    [[ "$mode_name" == "802.3ad" ]] && printf '    bond-xmit-hash-policy layer2+3\n    bond-lacp-rate fast\n'
    [[ -n "$mtu" ]] && printf '    mtu %s\n' "$mtu"
    [[ "$v4_method" == "static" && -n "$v4_addr" ]] && printf '    address %s\n' "$v4_addr"
    [[ "$v4_method" == "static" && -n "$v4_gw" ]] && printf '    gateway %s\n' "$v4_gw"

    if [[ "$v6_method" != "none" ]]; then
        printf '\niface %s inet6 %s\n' "$iface_name" "$v6_method"
        [[ -n "$v6_addr" ]] && printf '    address %s\n' "$v6_addr"
        [[ -n "$v6_gw" ]] && printf '    gateway %s\n' "$v6_gw"
        [[ -n "$v6_extra" ]] && printf '    %s\n' "$v6_extra"
    fi
}
host_network_create_bond() {
    local default_name bond_name slaves mode mtu ipv4_cfg ipv6_cfg tmp block
    default_name="$(host_network_guess_next_name bond)"
    read -p "请输入 Bond 名称 [$default_name]: " bond_name
    bond_name="${bond_name:-$default_name}"
    host_network_validate_iface_name "$bond_name" || {
        display_error "Bond 名称不合法: $bond_name" "接口名需为 1-15 位，且仅允许字母、数字、._:-。"
        return 1
    }
    if host_network_get_all_interface_names | grep -qx "$bond_name"; then
        display_error "接口已存在: $bond_name"
        return 1
    fi
    echo -e "${CYAN}可加入 Bond 的接口（输入多个，以空格分隔）：${NC}"
    host_network_get_all_interface_names | sed 's/^/  - /'
    read -p "bond-slaves: " slaves
    host_network_validate_member_list "$slaves" "$bond_name" "bond-slaves" || return 1

    echo "  [0] mode 0  = balance-rr"
    echo "  [1] mode 1  = active-backup"
    echo "  [4] mode 4  = 802.3ad"
    echo "  [6] mode 6  = balance-alb"
    read -p "请选择 Bond 模式 [0/1/4/6]: " mode
    [[ "$mode" =~ ^(0|1|4|6)$ ]] || {
        display_error "仅支持 Bond 模式 0/1/4/6"
        return 1
    }
    read -p "MTU（留空保持默认）: " mtu
    host_network_validate_mtu "$mtu" || return 1
    echo "$UI_DIVIDER"
    ipv4_cfg="$(host_network_collect_family_config inet create)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 create)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    block="$(host_network_build_bond_block "$bond_name" "$slaves" "$mode" "$mtu" "$ipv4_cfg" "$ipv6_cfg")"
    host_network_remove_iface_from_candidate "$tmp" "$bond_name"
    host_network_append_text_to_candidate "$tmp" "# PVE-TOOLS HOST IFACE BEGIN $bond_name
$block
# PVE-TOOLS HOST IFACE END $bond_name"
    host_network_commit_candidate "$tmp" "创建 Bond $bond_name" "Bond 会重组宿主机上联链路，错误的成员口或模式会导致管理面和业务流量异常。" "交换机 LACP/静态聚合不匹配时，链路可能抖动、黑洞或单向丢包。" "请确认交换机侧聚合模式、成员口、MTU 与回滚路径已经准备好。"
    rm -f "$tmp"
}
host_network_delete_bond() {
    local bond_name
    bond_name="$(host_network_select_bond_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bond_name" ]] || return 1

    if grep -Eq "(bridge-ports|bond-slaves|vlan-raw-device)[[:space:]].*\b${bond_name}\b" "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null; then
        display_error "检测到其他接口仍依赖 $bond_name" "请先解除 bridge、VLAN 或其他依赖后再删除。"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    host_network_remove_iface_from_candidate "$tmp" "$bond_name"
    host_network_commit_candidate "$tmp" "删除 Bond $bond_name" "删除 Bond 会让其上的 bridge、VLAN、地址和上联聚合失效。" "生产网络、存储网络、集群心跳都可能立即受影响。" "请确认已迁移上层依赖，并通过控制台执行。"
    rm -f "$tmp"
}
host_network_bond_menu() {
    while true; do
        clear
        show_menu_header "Bond 管理"
        host_network_show_risk_banner
        echo -e "${CYAN}当前 Bond：${NC}"
        if host_network_get_configured_bonds | awk 'NF{print "  - "$0}'; then :; fi
        echo "$UI_DIVIDER"
        show_menu_option "1" "列出 Bond"
        show_menu_option "2" "创建 Bond"
        show_menu_option "3" "删除 Bond"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_create_bond ;;
            3) host_network_delete_bond ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
