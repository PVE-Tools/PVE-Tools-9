#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

host_network_build_bridge_block() {
    local iface_name="$1"
    local ports="$2"
    local vlan_aware="$3"
    local mtu="$4"
    local ipv4_cfg="$5"
    local ipv6_cfg="$6"
    local v4_method v4_addr v4_gw v4_extra
    local v6_method v6_addr v6_gw v6_extra
    IFS='|' read -r v4_method v4_addr v4_gw v4_extra <<< "$ipv4_cfg"
    IFS='|' read -r v6_method v6_addr v6_gw v6_extra <<< "$ipv6_cfg"

    [[ "$v4_method" == "none" ]] && v4_method="manual"
    printf 'auto %s\n' "$iface_name"
    printf 'iface %s inet %s\n' "$iface_name" "$v4_method"
    printf '    bridge-ports %s\n' "${ports:-none}"
    printf '    bridge-stp off\n'
    printf '    bridge-fd 0\n'
    [[ "$vlan_aware" == "yes" || "$vlan_aware" == "YES" ]] && printf '    bridge-vlan-aware yes\n'
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
host_network_create_bridge() {
    host_network_show_current_overview
    local default_name bridge_name ports vlan_aware mtu ipv4_cfg ipv6_cfg tmp block
    default_name="$(host_network_guess_next_name vmbr)"
    read -p "请输入桥接名称 [$default_name]: " bridge_name
    bridge_name="${bridge_name:-$default_name}"
    host_network_validate_iface_name "$bridge_name" || {
        display_error "桥接名称不合法: $bridge_name" "接口名需为 1-15 位，且仅允许字母、数字、._:-。"
        return 1
    }
    if host_network_get_all_interface_names | grep -qx "$bridge_name"; then
        display_error "接口已存在: $bridge_name"
        return 1
    fi

    echo -e "${CYAN}可作为 bridge-ports 的接口（可输入多个，以空格分隔；留空表示 none）：${NC}"
    host_network_get_all_interface_names | sed 's/^/  - /'
    read -p "bridge-ports [none]: " ports
    ports="${ports:-none}"
    if [[ "$ports" != "none" ]]; then
        host_network_validate_member_list "$ports" "$bridge_name" "bridge-ports" || return 1
    fi

    read -p "是否启用 VLAN Aware？(yes/no) [yes]: " vlan_aware
    vlan_aware="${vlan_aware:-yes}"
    case "$vlan_aware" in
        yes|YES|no|NO) ;;
        *)
            display_error "VLAN Aware 仅支持 yes/no"
            return 1
            ;;
    esac

    read -p "MTU（留空保持默认）: " mtu
    host_network_validate_mtu "$mtu" || return 1
    echo "$UI_DIVIDER"
    ipv4_cfg="$(host_network_collect_family_config inet create)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 create)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    block="$(host_network_build_bridge_block "$bridge_name" "$ports" "$vlan_aware" "$mtu" "$ipv4_cfg" "$ipv6_cfg")"
    host_network_remove_iface_from_candidate "$tmp" "$bridge_name"
    host_network_append_text_to_candidate "$tmp" "# PVE-TOOLS HOST IFACE BEGIN $bridge_name
$block
# PVE-TOOLS HOST IFACE END $bridge_name"
    host_network_commit_candidate "$tmp" "创建桥接 $bridge_name" "将直接改写宿主机网桥配置，错误的桥接成员口、地址或网关会导致宿主机失联。" "SSH/WebUI、集群网络、VM 出口网络都可能受到影响。" "请确认控制台可用、bridge-ports 和网关正确，并已准备回滚。"
    rm -f "$tmp"
}
host_network_delete_bridge() {
    local bridge_name
    bridge_name="$(host_network_select_bridge_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bridge_name" ]] || return 1

    if grep -Eq "(bridge-ports|bond-slaves|vlan-raw-device)[[:space:]].*\b${bridge_name}\b" "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null; then
        display_error "检测到其他接口仍依赖 $bridge_name" "请先删除依赖它的 VLAN、bond 或 bridge 关系后再试。"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    host_network_remove_iface_from_candidate "$tmp" "$bridge_name"
    host_network_commit_candidate "$tmp" "删除桥接 $bridge_name" "删除桥接会切断与该 bridge 绑定的宿主机与 VM 网络配置。" "如果该 bridge 承载管理口或生产流量，宿主机会立即失联。" "请确认管理流量不走该桥接，且相关 VM 已迁移或停机。"
    rm -f "$tmp"
}
host_network_bridge_menu() {
    while true; do
        clear
        show_menu_header "桥接管理"
        host_network_show_risk_banner
        echo -e "${CYAN}当前 bridge：${NC}"
        if host_network_get_configured_bridges | awk 'NF{print "  - "$0}'; then :; fi
        echo "$UI_DIVIDER"
        show_menu_option "1" "列出当前网卡与桥接"
        show_menu_option "2" "创建桥接"
        show_menu_option "3" "删除桥接"
        show_menu_option "4" "MAC 地址绑定管理（防网卡顺序变化）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_create_bridge ;;
            3) host_network_delete_bridge ;;
            4) host_network_mac_binding_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
