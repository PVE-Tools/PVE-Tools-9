#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

third_party_community_scripts_info() {
    clear
    show_menu_header "Community Scripts"

    echo "  这里推荐一个由社区维护的庞大脚本集合，覆盖 Proxmox 安装、容器/虚拟机模版、监控等各种高级玩法。"
    echo
    echo "  项目主页: https://community-scripts.github.io/ProxmoxVE/"
    echo "  GitHub 仓库: https://github.com/community-scripts/ProxmoxVE"
    echo
    echo -e "${RED}重要提示:${NC} 该工具集完全由第三方维护，与 PVE-Tools 项目无关。"
    echo "  如果脚本运行出现问题，请直接前往上述项目反馈。"
    echo
    echo "  使用建议："
    echo "    - 全站为英文界面，可配合浏览器或翻译软件使用。"
    echo "    - 网站中包含大量脚本和功能说明，建议按需阅读说明后再执行。"
    echo "    - 执行任何第三方脚本前，请务必备份关键配置并了解潜在风险。"
    echo "${UI_DIVIDER}"
}
#---------第三方工具集合-----------
