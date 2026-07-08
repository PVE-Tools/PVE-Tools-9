#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

host_firewall_get_node_names() {
    find /etc/pve/nodes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}
host_firewall_select_node_name() {
    host_network_select_from_text "可用节点：" "$(host_firewall_get_node_names)"
}
host_firewall_select_guest() {
    local kind="$1"
    local list_text
    if [[ "$kind" == "vm" ]]; then
        list_text="$(qm list 2>/dev/null | awk 'NR>1 {print $1 "|" $2}')"
    else
        list_text="$(pct list 2>/dev/null | awk 'NR>1 {print $1 "|" $2}')"
    fi
    mapfile -t items < <(printf '%s\n' "$list_text" | awk 'NF')
    (( ${#items[@]} > 0 )) || return 1
    echo -e "${CYAN}请选择${kind^^}：${NC}" >&2
    local idx=1
    local item id name
    for item in "${items[@]}"; do
        id="${item%%|*}"
        name="${item#*|}"
        printf '  [%d] %s (%s)\n' "$idx" "$id" "$name" >&2
        idx=$((idx + 1))
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
    id="${items[$((pick - 1))]%%|*}"
    printf '%s\n' "$id"
}
host_firewall_validate_group_name() {
    local group_name="$1"
    [[ -n "$group_name" && "$group_name" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$ ]]
}
host_firewall_validate_identifier() {
    local scope="$1"
    local identifier="$2"
    case "$scope" in
        datacenter)
            [[ "$identifier" == "cluster" ]]
            ;;
        node)
            [[ "$identifier" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]
            ;;
        vm|ct)
            [[ "$identifier" =~ ^[0-9]+$ ]]
            ;;
        security-group)
            host_firewall_validate_group_name "$identifier"
            ;;
        *)
            return 1
            ;;
    esac
}
host_firewall_is_allowed_target_path() {
    local file_path="$1"
    case "$file_path" in
        /etc/pve/firewall/cluster.fw|/etc/pve/nodes/*/host.fw|/etc/pve/firewall/*.fw)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
host_firewall_target_path() {
    local scope="$1"
    local identifier="$2"
    local path=""

    host_firewall_validate_identifier "$scope" "$identifier" || return 1

    case "$scope" in
        datacenter) path="$PVE_CLUSTER_FIREWALL_FILE" ;;
        node) printf -v path '/etc/pve/nodes/%s/host.fw' "$identifier" ;;
        vm|ct) printf -v path '/etc/pve/firewall/%s.fw' "$identifier" ;;
        *) return 1 ;;
    esac

    host_firewall_is_allowed_target_path "$path" || return 1
    printf '%s\n' "$path"
}
host_firewall_validate_ruleset_content_for_target() {
    local kind="$1"
    local content="$2"
    if [[ "$kind" == "security-group" ]]; then
        printf '%s\n' "$content" | awk 'NF{exit !($0 ~ /^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/)} END{if(NR==0) exit 1}'
        return $?
    fi
    printf '%s\n' "$content" | grep -Eq '^\[[^]]+\]'
}
host_firewall_prepare_group_section() {
    local group_name="$1"
    local content="$2"
    awk -v target="[group ${group_name}]" '
        BEGIN { started=0 }
        {
            if (!started) {
                if ($0 ~ /^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/) {
                    print target
                    started=1
                }
                next
            }
            if ($0 ~ /^\[/) {
                exit
            }
            print
        }
        END { if (!started) exit 1 }
    ' <<< "$content"
}
host_firewall_ensure_target_file() {
    local file_path="$1"
    mkdir -p "$(dirname "$file_path")" >/dev/null 2>&1 || true
    if [[ ! -f "$file_path" ]]; then
        cat > "$file_path" <<'EOF_FW'
[OPTIONS]
enable: 0

[RULES]
EOF_FW
    fi
}
host_firewall_upsert_option() {
    local file_path="$1"
    local option_key="$2"
    local option_value="$3"
    local tmp
    tmp=$(mktemp)

    awk -v option_key="$option_key" -v option_value="$option_value" '
        BEGIN { in_options=0; found_options=0; replaced=0 }
        {
            if ($0 == "[OPTIONS]") {
                found_options=1
                in_options=1
                print
                next
            }
            if (in_options && $0 ~ /^\[/) {
                if (!replaced) {
                    printf "%s: %s\n", option_key, option_value
                    replaced=1
                }
                in_options=0
            }
            if (in_options && $0 ~ ("^" option_key ":[[:space:]]*")) {
                printf "%s: %s\n", option_key, option_value
                replaced=1
                next
            }
            print
        }
        END {
            if (!found_options) {
                print "[OPTIONS]"
                printf "%s: %s\n\n", option_key, option_value
                print "[RULES]"
            } else if (in_options && !replaced) {
                printf "%s: %s\n", option_key, option_value
            }
        }
    ' "$file_path" > "$tmp"
    mv "$tmp" "$file_path"
}
host_firewall_select_security_group() {
    local allow_new="${1:-}"
    mapfile -t groups < <(host_firewall_get_security_groups)
    echo -e "${CYAN}当前安全组：${NC}" >&2
    local idx=1
    local group
    for group in "${groups[@]}"; do
        printf '  [%d] %s\n' "$idx" "$group" >&2
        idx=$((idx + 1))
    done
    if [[ "$allow_new" == "allow_new" ]]; then
        echo "  [N] 新建安全组" >&2
    fi
    echo "$UI_DIVIDER" >&2
    local pick
    read -p "请选择安全组 (0 返回): " pick
    [[ "$pick" == "0" ]] && return 2
    if [[ "$allow_new" == "allow_new" && ( "$pick" == "N" || "$pick" == "n" ) ]]; then
        read -p "请输入新的安全组名称: " group
        host_firewall_validate_group_name "$group" || {
            display_error "安全组名称不合法: $group" "仅允许字母、数字、._:-，且长度不超过 64。"
            return 1
        }
        printf '%s\n' "$group"
        return 0
    fi
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#groups[@]} )); then
        return 1
    fi
    printf '%s\n' "${groups[$((pick - 1))]}"
}
host_firewall_get_security_groups() {
    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    awk '/^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/ {line=$0; sub(/^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/, "", line); sub(/\]$/, "", line); print line}' "$PVE_CLUSTER_FIREWALL_FILE" 2>/dev/null | sort -u
}
host_firewall_get_group_section() {
    local group_name="$1"
    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    awk -v header="[group ${group_name}]" '
        BEGIN { capture=0 }
        {
            if (capture) {
                if ($0 ~ /^\[/ && $0 != header) {
                    exit
                }
                print
                next
            }
            if ($0 == header) {
                capture=1
                print
            }
        }
    ' "$PVE_CLUSTER_FIREWALL_FILE"
}
host_firewall_replace_group_section_in_file() {
    local group_name="$1"
    local new_content="$2"
    local tmp
    tmp=$(mktemp)
    awk -v header="[group ${group_name}]" -v new_content="$new_content" '
        BEGIN { skip=0; replaced=0; split(new_content, repl, "\n") }
        {
            if (skip) {
                if ($0 ~ /^\[/ && $0 != header) {
                    skip=0
                } else {
                    next
                }
            }
            if (!replaced && $0 == header) {
                for (i=1; i in repl; i++) print repl[i]
                replaced=1
                skip=1
                next
            }
            print
        }
        END {
            if (!replaced) {
                print ""
                for (i=1; i in repl; i++) print repl[i]
            }
        }
    ' "$PVE_CLUSTER_FIREWALL_FILE" > "$tmp"
    mv "$tmp" "$PVE_CLUSTER_FIREWALL_FILE"
}
host_firewall_select_ruleset_target() {
    echo "  [1] 数据中心 firewall"
    echo "  [2] 节点 firewall"
    echo "  [3] VM firewall"
    echo "  [4] CT firewall"
    echo "  [5] 安全组"
    read -p "请选择目标 [1-5]: " choice
    local node_name guest_id path group_name rc
    case "$choice" in
        1)
            printf 'datacenter|cluster|%s|数据中心 firewall\n' "$PVE_CLUSTER_FIREWALL_FILE"
            ;;
        2)
            node_name="$(host_firewall_select_node_name)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$node_name" ]] || return 1
            path="$(host_firewall_target_path node "$node_name")"
            printf 'node|%s|%s|节点 firewall (%s)\n' "$node_name" "$path" "$node_name"
            ;;
        3)
            guest_id="$(host_firewall_select_guest vm)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$guest_id" ]] || return 1
            path="$(host_firewall_target_path vm "$guest_id")"
            printf 'vm|%s|%s|VM firewall (%s)\n' "$guest_id" "$path" "$guest_id"
            ;;
        4)
            guest_id="$(host_firewall_select_guest ct)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$guest_id" ]] || return 1
            path="$(host_firewall_target_path ct "$guest_id")"
            printf 'ct|%s|%s|CT firewall (%s)\n' "$guest_id" "$path" "$guest_id"
            ;;
        5)
            group_name="$(host_firewall_select_security_group allow_new)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$group_name" ]] || return 1
            printf 'security-group|%s|%s|安全组 (%s)\n' "$group_name" "$PVE_CLUSTER_FIREWALL_FILE" "$group_name"
            ;;
        *)
            return 1
            ;;
    esac
}
host_firewall_toggle_enable() {
    local scope="$1"
    local identifier="$2"
    local label="$3"
    local state file_path
    file_path="$(host_firewall_target_path "$scope" "$identifier")" || return 1
    host_firewall_ensure_target_file "$file_path"
    read -p "是否启用 $label 防火墙？(yes/no) [yes]: " state
    state="${state:-yes}"
    if ! confirm_high_risk_action "切换 $label 防火墙状态" "错误的防火墙开关或默认策略可能导致管理口、集群通信或业务端口不可达。" "如果规则集本身有误，启用后可能立即造成 SSH/WebUI/业务中断。" "请确认已有控制台或带外管理手段，并已审查当前 firewall 规则。" "FIREWALL"; then
        return 0
    fi
    backup_file "$file_path" >/dev/null 2>&1 || true
    if [[ "$state" == "yes" || "$state" == "YES" ]]; then
        host_firewall_upsert_option "$file_path" enable 1
    else
        host_firewall_upsert_option "$file_path" enable 0
    fi
    display_success "$label 防火墙状态已更新" "$file_path"
    if [[ "$scope" == "vm" || "$scope" == "ct" ]]; then
        log_warn "PVE 客体防火墙还依赖对应网卡开启 firewall=1；如未开启，请同步检查网卡配置。"
    fi
}
host_firewall_toggle_menu() {
    while true; do
        clear
        show_menu_header "PVE 防火墙开关"
        host_network_show_risk_banner
        show_menu_option "1" "数据中心级别开关"
        show_menu_option "2" "节点级别开关"
        show_menu_option "3" "VM 级别开关"
        show_menu_option "4" "CT 级别开关"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) host_firewall_toggle_enable datacenter cluster "数据中心" ;;
            2)
                local node_name rc
                node_name="$(host_firewall_select_node_name)"
                rc=$?
                [[ "$rc" -eq 2 ]] && continue
                [[ -n "$node_name" ]] && host_firewall_toggle_enable node "$node_name" "节点 $node_name"
                ;;
            3)
                local vmid rc
                vmid="$(host_firewall_select_guest vm)"
                rc=$?
                [[ "$rc" -eq 2 ]] && continue
                [[ -n "$vmid" ]] && host_firewall_toggle_enable vm "$vmid" "VM $vmid"
                ;;
            4)
                local ctid rc
                ctid="$(host_firewall_select_guest ct)"
                rc=$?
                [[ "$rc" -eq 2 ]] && continue
                [[ -n "$ctid" ]] && host_firewall_toggle_enable ct "$ctid" "CT $ctid"
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
host_firewall_list_security_groups() {
    clear
    show_menu_header "安全组规则"
    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    local groups_text group
    groups_text="$(host_firewall_get_security_groups)"
    if [[ -z "$groups_text" ]]; then
        echo "  当前没有安全组。"
        return 0
    fi
    while IFS= read -r group; do
        [[ -z "$group" ]] && continue
        echo -e "${CYAN}[group ${group}]${NC}"
        host_firewall_get_group_section "$group" | awk 'NR>1 && NF {print "  "$0}'
        echo "$UI_DIVIDER"
    done <<< "$groups_text"
}
host_firewall_add_security_group_rule() {
    local group_name direction action rule_body existing new_section
    group_name="$(host_firewall_select_security_group allow_new)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$group_name" ]] || return 1

    echo "  [1] IN"
    echo "  [2] OUT"
    read -p "请选择方向 [1-2]: " direction
    case "$direction" in
        1) direction="IN" ;;
        2) direction="OUT" ;;
        *) return 1 ;;
    esac
    echo "  [1] ACCEPT"
    echo "  [2] DROP"
    echo "  [3] REJECT"
    read -p "请选择动作 [1-3]: " action
    case "$action" in
        1) action="ACCEPT" ;;
        2) action="DROP" ;;
        3) action="REJECT" ;;
        *) return 1 ;;
    esac
    read -p "请输入规则主体（示例 -p tcp --dport 22 -source +management，留空则仅写方向/动作）: " rule_body

    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    backup_file "$PVE_CLUSTER_FIREWALL_FILE" >/dev/null 2>&1 || true
    existing="$(host_firewall_get_group_section "$group_name")"
    if [[ -z "$existing" ]]; then
        new_section="[group ${group_name}]"
    else
        new_section="$existing"
    fi
    new_section+=$'\n'
    new_section+="${direction} ${action}"
    [[ -n "$rule_body" ]] && new_section+=" ${rule_body}"
    host_firewall_replace_group_section_in_file "$group_name" "$new_section"
    display_success "安全组规则已写入" "group ${group_name}"
}
host_firewall_delete_security_group_rule() {
    local group_name section idx pick new_section
    group_name="$(host_firewall_select_security_group)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$group_name" ]] || return 1

    section="$(host_firewall_get_group_section "$group_name")"
    [[ -n "$section" ]] || {
        display_error "安全组不存在或无规则: $group_name"
        return 1
    }

    mapfile -t rules < <(printf '%s\n' "$section" | awk 'NR>1 && NF && $0 !~ /^#/ {print}')
    (( ${#rules[@]} > 0 )) || {
        display_error "安全组没有可删除的规则: $group_name"
        return 1
    }

    echo -e "${CYAN}[group ${group_name}]${NC}"
    idx=1
    local rule
    for rule in "${rules[@]}"; do
        printf '  [%d] %s\n' "$idx" "$rule"
        idx=$((idx + 1))
    done
    echo "$UI_DIVIDER"
    read -p "请选择要删除的规则序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#rules[@]} )); then
        return 1
    fi

    new_section="[group ${group_name}]"
    idx=1
    for rule in "${rules[@]}"; do
        if (( idx != pick )); then
            new_section+=$'\n'
            new_section+="$rule"
        fi
        idx=$((idx + 1))
    done
    backup_file "$PVE_CLUSTER_FIREWALL_FILE" >/dev/null 2>&1 || true
    host_firewall_replace_group_section_in_file "$group_name" "$new_section"
    display_success "安全组规则已删除" "group ${group_name}"
}
host_firewall_show_target_rules() {
    local target_data kind identifier path label content
    target_data="$(host_firewall_select_ruleset_target)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_data" ]] || return 1
    IFS='|' read -r kind identifier path label <<< "$target_data"
    clear
    show_menu_header "$label"
    if [[ "$kind" == "security-group" ]]; then
        content="$(host_firewall_get_group_section "$identifier")"
        [[ -n "$content" ]] && printf '%s\n' "$content" | sed 's/^/  /' || echo '  当前安全组为空。'
    else
        host_firewall_ensure_target_file "$path"
        sed 's/^/  /' "$path"
    fi
    echo "$UI_DIVIDER"
}
host_firewall_export_ruleset() {
    local target_data kind identifier path label format export_file content b64 safe_name
    target_data="$(host_firewall_select_ruleset_target)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_data" ]] || return 1
    IFS='|' read -r kind identifier path label <<< "$target_data"

    if [[ "$kind" == "security-group" ]]; then
        content="$(host_firewall_get_group_section "$identifier")"
    else
        host_firewall_ensure_target_file "$path"
        content="$(cat "$path")"
    fi

    mkdir -p "$HOST_NETWORK_EXPORT_DIR"
    safe_name="$(echo "$identifier" | tr '/: ' '___')"
    echo "  [1] JSON"
    echo "  [2] CLI / raw"
    read -p "请选择导出格式 [1-2]: " format
    case "$format" in
        1)
            export_file="$HOST_NETWORK_EXPORT_DIR/${kind}-${safe_name}-$(date +%Y%m%d_%H%M%S).json"
            b64="$(printf '%s' "$content" | base64 | tr -d '\n')"
            cat > "$export_file" <<EOF_JSON
{
  "format": "pve-tools-firewall-json",
  "target_kind": "${kind}",
  "identifier": "${identifier}",
  "exported_at": "$(date +%F' '%T)",
  "content_base64": "${b64}"
}
EOF_JSON
            ;;
        2)
            export_file="$HOST_NETWORK_EXPORT_DIR/${kind}-${safe_name}-$(date +%Y%m%d_%H%M%S).fw"
            printf '%s\n' "$content" > "$export_file"
            ;;
        *)
            return 1
            ;;
    esac
    display_success "规则集已导出" "$export_file"
}
host_firewall_import_ruleset() {
    local import_path source_kind source_identifier content b64 target_data kind identifier path label prepared_content rc
    read -p "请输入要导入的规则集文件路径: " import_path
    [[ -f "$import_path" ]] || {
        display_error "文件不存在: $import_path"
        return 1
    }

    if grep -q '"format": "pve-tools-firewall-json"' "$import_path" 2>/dev/null; then
        source_kind="$(sed -n 's/.*"target_kind": "\([^"]*\)".*/\1/p' "$import_path" | head -n 1)"
        source_identifier="$(sed -n 's/.*"identifier": "\([^"]*\)".*/\1/p' "$import_path" | head -n 1)"
        b64="$(sed -n 's/.*"content_base64": "\([^"]*\)".*/\1/p' "$import_path" | head -n 1)"
        content="$(printf '%s' "$b64" | base64 -d 2>/dev/null)"
    else
        content="$(cat "$import_path")"
    fi

    [[ -n "$content" ]] || {
        display_error "导入内容为空或解析失败"
        return 1
    }

    if [[ -n "$source_kind" || -n "$source_identifier" ]]; then
        log_warn "导入文件携带的原始目标为 ${source_kind:-unknown}:${source_identifier:-unknown}，实际写入目标仍需重新选择。"
    fi

    target_data="$(host_firewall_select_ruleset_target)"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_data" ]] || return 1
    IFS='|' read -r kind identifier path label <<< "$target_data"

    host_firewall_validate_identifier "$kind" "$identifier" || {
        display_error "导入目标不合法: ${kind}:${identifier}"
        return 1
    }
    if [[ "$kind" != "security-group" ]]; then
        path="$(host_firewall_target_path "$kind" "$identifier")" || {
            display_error "导入目标路径非法或超出允许范围"
            return 1
        }
    fi
    host_firewall_validate_ruleset_content_for_target "$kind" "$content" || {
        display_error "规则集内容与目标类型不匹配" "请避免把整份 firewall 文件导入到安全组，或把安全组片段导入到数据中心/节点/客体 firewall。"
        return 1
    }

    if ! confirm_high_risk_action "导入规则集到 $label" "导入会覆盖当前目标的规则或安全组内容。" "错误的规则集可能立即封死管理口、业务端口或集群通信。" "请确认已导出当前规则备份，并通过控制台进行高风险导入。" "IMPORT-FW"; then
        return 0
    fi

    if [[ "$kind" == "security-group" ]]; then
        prepared_content="$(host_firewall_prepare_group_section "$identifier" "$content")" || {
            display_error "无法从导入文件中提取有效安全组段落"
            return 1
        }
        host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
        backup_file "$PVE_CLUSTER_FIREWALL_FILE" >/dev/null 2>&1 || true
        host_firewall_replace_group_section_in_file "$identifier" "$prepared_content"
        display_success "安全组规则已导入" "group ${identifier}"
        return 0
    fi

    host_firewall_ensure_target_file "$path"
    backup_file "$path" >/dev/null 2>&1 || true
    printf '%s\n' "$content" > "$path"
    display_success "规则集已导入" "$path"
}
host_firewall_menu() {
    while true; do
        clear
        show_menu_header "PVE 防火墙管理"
        host_network_show_risk_banner
        show_menu_option "1" "数据中心 / 节点 / VM / CT 防火墙开关"
        show_menu_option "2" "查看目标规则集"
        show_menu_option "3" "列出安全组规则"
        show_menu_option "4" "新增安全组规则"
        show_menu_option "5" "删除安全组规则"
        show_menu_option "6" "导出规则集（JSON / CLI）"
        show_menu_option "7" "导入规则集（JSON / CLI）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-7]: " choice
        case "$choice" in
            1) host_firewall_toggle_menu ;;
            2) host_firewall_show_target_rules ;;
            3) host_firewall_list_security_groups ;;
            4) host_firewall_add_security_group_rule ;;
            5) host_firewall_delete_security_group_rule ;;
            6) host_firewall_export_ruleset ;;
            7) host_firewall_import_ruleset ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
