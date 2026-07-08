#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

manage_vm_schedule() {
    while true; do
        clear
        show_menu_header "虚拟机/容器定时开关机"
        echo -e "${YELLOW}当前配置的任务：${NC}"
        if [ -f "/etc/cron.d/pve-tools-schedule" ]; then
            grep -E "^[^#]" /etc/cron.d/pve-tools-schedule | sed 's/root \/usr\/sbin\///g'
        else
            echo "  暂无定时任务"
        fi
        echo -e "${UI_DIVIDER}"
        
        echo -e "${BLUE}可用虚拟机 (QM):${NC}"
        qm list 2>/dev/null | awk 'NR>1 {printf "  ID: %-8s Name: %-20s Status: %s\n", $1, $2, $3}' || echo "  未发现虚拟机"
        echo -e "${BLUE}可用容器 (PCT):${NC}"
        pct list 2>/dev/null | awk 'NR>1 {printf "  ID: %-8s Name: %-20s Status: %s\n", $1, $4, $2}' || echo "  未发现容器"
        echo -e "${UI_DIVIDER}"
        
        read -p "请输入要操作的 ID (返回请输入 0): " target_id
        target_id=${target_id:-0}
        if [[ "$target_id" == "0" ]]; then
            return
        fi

        local cmd=""
        if qm status "$target_id" >/dev/null 2>&1; then
            cmd="qm"
        elif pct status "$target_id" >/dev/null 2>&1; then
            cmd="pct"
        else
            log_error "无效的 ID: $target_id"
            pause_function
            continue
        fi

        echo -e "${CYAN}正在配置 $cmd $target_id${NC}"
        show_menu_option "1" "设置/修改定时任务"
        show_menu_option "2" "删除定时任务"
        show_menu_option "0" "取消"
        read -p "请选择操作 [0-2]: " sub_choice
        
        case $sub_choice in
            1)
                read -p "请输入开机时间 (格式 HH:MM, 如 07:00, 直接回车跳过): " start_time
                read -p "请输入关机时间 (格式 HH:MM, 如 00:00, 直接回车跳过): " stop_time
                
                local cron_content=""
                if [[ -n "$start_time" ]]; then
                    if [[ "$start_time" =~ ^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
                        local hour=${BASH_REMATCH[1]}
                        local min=${BASH_REMATCH[2]}
                        min=$((10#$min))
                        hour=$((10#$hour))
                        cron_content+="$min $hour * * * root /usr/sbin/$cmd start $target_id >/dev/null 2>&1\n"
                    else
                        log_error "开机时间格式错误: $start_time"
                    fi
                fi
                
                if [[ -n "$stop_time" ]]; then
                    if [[ "$stop_time" =~ ^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
                        local hour=${BASH_REMATCH[1]}
                        local min=${BASH_REMATCH[2]}
                        min=$((10#$min))
                        hour=$((10#$hour))
                        cron_content+="$min $hour * * * root /usr/sbin/$cmd stop $target_id >/dev/null 2>&1"
                    else
                        log_error "关机时间格式错误: $stop_time"
                    fi
                fi
                
                if [[ -n "$cron_content" ]]; then
                    apply_block "/etc/cron.d/pve-tools-schedule" "SCHEDULE_$target_id" "$(echo -e "$cron_content")"
                    log_success "ID $target_id 的定时任务已更新"
                    systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null
                else
                    log_warn "未设置任何有效时间，操作取消"
                fi
                ;;
            2)
                remove_block "/etc/cron.d/pve-tools-schedule" "SCHEDULE_$target_id"
                log_success "ID $target_id 的定时任务已删除"
                systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null
                ;;
            0)
                continue
                ;;
            *)
                log_error "无效选择"
                ;;
        esac
        pause_function
    done
}
