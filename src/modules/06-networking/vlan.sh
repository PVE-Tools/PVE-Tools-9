#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

host_network_build_vlan_block() {
    local iface_name="$1"
    local raw_dev="$2"
    local mtu="$3"
    local ipv4_cfg="$4"
    local ipv6_cfg="$5"
    local v4_method v4_addr v4_gw v4_extra
    local v6_method v6_addr v6_gw v6_extra
    IFS='|' read -r v4_method v4_addr v4_gw v4_extra <<< "$ipv4_cfg"
    IFS='|' read -r v6_method v6_addr v6_gw v6_extra <<< "$ipv6_cfg"

    [[ "$v4_method" == "none" ]] && v4_method="manual"
    printf 'auto %s\n' "$iface_name"
    printf 'iface %s inet %s\n' "$iface_name" "$v4_method"
    printf '    vlan-raw-device %s\n' "$raw_dev"
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
host_network_create_vlan() {
    local raw_dev vlan_id iface_name mtu ipv4_cfg ipv6_cfg tmp block
    raw_dev="$(host_network_select_interface_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$raw_dev" ]] || return 1

    host_network_iface_exists "$raw_dev" || {
        display_error "上联接口不存在: $raw_dev"
        return 1
    }

    read -p "请输入 VLAN ID: " vlan_id
    [[ "$vlan_id" =~ ^[0-9]+$ && "$vlan_id" -ge 1 && "$vlan_id" -le 4094 ]] || {
        display_error "VLAN ID 不合法: $vlan_id" "请输入 1-4094 之间的整数。"
        return 1
    }
    iface_name="${raw_dev}.${vlan_id}"
    read -p "请输入 VLAN 子接口名称 [$iface_name]: " iface_name
    iface_name="${iface_name:-${raw_dev}.${vlan_id}}"
    host_network_validate_iface_name "$iface_name" || {
        display_error "接口名称不合法: $iface_name" "接口名需为 1-15 位，且仅允许字母、数字、._:-。"
        return 1
    }
    if host_network_get_all_interface_names | grep -qx "$iface_name"; then
        display_error "接口已存在: $iface_name"
        return 1
    fi
    read -p "MTU（留空保持默认）: " mtu
    host_network_validate_mtu "$mtu" || return 1
    echo "$UI_DIVIDER"
    ipv4_cfg="$(host_network_collect_family_config inet create)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 create)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    block="$(host_network_build_vlan_block "$iface_name" "$raw_dev" "$mtu" "$ipv4_cfg" "$ipv6_cfg")"
    host_network_remove_iface_from_candidate "$tmp" "$iface_name"
    host_network_append_text_to_candidate "$tmp" "# PVE-TOOLS HOST IFACE BEGIN $iface_name
$block
# PVE-TOOLS HOST IFACE END $iface_name"
    host_network_commit_candidate "$tmp" "创建 VLAN 子接口 $iface_name" "VLAN 子接口会改写宿主机链路与上联 VLAN 规划。" "VLAN ID、上联接口或网关错误时，相关业务与管理流量会中断。" "请确认上联交换机配置、VLAN ID、地址规划和控制台回滚路径。"
    rm -f "$tmp"
}
host_network_delete_vlan() {
    local iface_name
    iface_name="$(host_network_select_vlan_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$iface_name" ]] || return 1

    if grep -Eq "(bridge-ports|bond-slaves|vlan-raw-device)[[:space:]].*\b${iface_name}\b" "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null; then
        display_error "检测到其他接口仍依赖 $iface_name" "请先删除依赖关系后再试。"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    host_network_remove_iface_from_candidate "$tmp" "$iface_name"
    host_network_commit_candidate "$tmp" "删除 VLAN 子接口 $iface_name" "删除 VLAN 子接口会中断承载在该 VLAN 上的宿主机和 VM 网络。" "业务中断、管理口断连和路由丢失都可能立即发生。" "请先确认该 VLAN 不再承担管理面或生产流量。"
    rm -f "$tmp"
}
host_network_vlan_menu() {
    while true; do
        clear
        show_menu_header "VLAN 子接口管理"
        host_network_show_risk_banner
        echo -e "${CYAN}当前 VLAN 子接口：${NC}"
        if host_network_get_configured_vlans | awk 'NF{print "  - "$0}'; then :; fi
        echo "$UI_DIVIDER"
        show_menu_option "1" "列出 VLAN 子接口"
        show_menu_option "2" "创建 VLAN 子接口"
        show_menu_option "3" "删除 VLAN 子接口"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_create_vlan ;;
            3) host_network_delete_vlan ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
