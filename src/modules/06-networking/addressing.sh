#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

host_network_configure_interface_addressing() {
    local iface_name ipv4_cfg ipv6_cfg tmp preserved block method
    iface_name="$(host_network_select_interface_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$iface_name" ]] || return 1

    echo -e "${CYAN}为接口 $iface_name 更新地址模式：${NC}"
    ipv4_cfg="$(host_network_collect_family_config inet update)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 update)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"

    IFS='|' read -r method _ <<< "$ipv4_cfg"
    if [[ "$method" != "keep" ]]; then
        preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$iface_name" inet)"
        host_network_remove_iface_family_from_candidate "$tmp" "$iface_name" inet
        if [[ "$method" != "remove" ]]; then
            host_network_ensure_auto_line_in_candidate "$tmp" "$iface_name"
            block="$(host_network_build_family_stanza "$iface_name" inet "$ipv4_cfg" "$preserved")"
            host_network_append_text_to_candidate "$tmp" "$block"
        fi
    fi

    IFS='|' read -r method _ <<< "$ipv6_cfg"
    if [[ "$method" != "keep" ]]; then
        preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$iface_name" inet6)"
        host_network_remove_iface_family_from_candidate "$tmp" "$iface_name" inet6
        if [[ "$method" != "remove" ]]; then
            host_network_ensure_auto_line_in_candidate "$tmp" "$iface_name"
            block="$(host_network_build_family_stanza "$iface_name" inet6 "$ipv6_cfg" "$preserved")"
            host_network_append_text_to_candidate "$tmp" "$block"
        fi
    fi

    host_network_commit_candidate "$tmp" "更新接口 $iface_name 的 IPv4/IPv6 地址模式" "会直接改写宿主机接口地址、网关和 RA/DHCP 行为。" "管理面 IP、默认路由和业务地址可能立即切换。" "请确认新的地址、网关、前缀和维护窗口都已校对。"
    rm -f "$tmp"
}
