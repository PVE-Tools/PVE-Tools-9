#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

show_system_info() {
    log_step "为您展示系统运行状况"
    echo
    echo "${UI_BORDER}"
    echo -e "  ${H1}系统信息概览${NC}"
    echo "${UI_DIVIDER}"
    echo -e "  ${PRIMARY}PVE 版本:${NC} $(pveversion | head -n1)"
    echo -e "  ${PRIMARY}内核版本:${NC} $(uname -r)"
    echo -e "  ${PRIMARY}CPU 信息:${NC} $(lscpu | grep 'Model name' | sed 's/Model name:[ \t]*//')"
    echo -e "  ${PRIMARY}CPU 核心:${NC} $(nproc) 核心"
    echo -e "  ${PRIMARY}系统架构:${NC} $(dpkg --print-architecture)"
    echo -e "  ${PRIMARY}系统启动:${NC} $(uptime -p | sed 's/up //')"
    echo -e "  ${PRIMARY}引导类型:${NC} $(if [ -d /sys/firmware/efi ]; then echo UEFI; else echo BIOS; fi)"
    echo -e "  ${PRIMARY}系统负载:${NC} $(uptime | awk -F'load average:' '{print $2}')"
    echo -e "  ${PRIMARY}内存使用:${NC} $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo -e "  ${PRIMARY}磁盘使用:${NC}"
    df -h | grep -E '^/dev/' | awk '{print "    "$1" "$3"/"$2" ("$5")"}'
    echo -e "  ${PRIMARY}网络接口:${NC}"
    ip -br addr show | awk '{print "    "$1" "$3}'
    echo -e "  ${PRIMARY}当前时间:${NC} $(date)"
    echo "${UI_FOOTER}"
}

# 主菜单
