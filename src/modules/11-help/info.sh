#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# 加 Q 群水群（闲聊交流为主，技术问题不保证有解答）
help_show_qq_group() {
    clear
    show_menu_header "加 Q 群水群"

    echo "  欢迎加入 PVE-Tools QQ 水群，与大家交流 PVE 玩法与踩坑经验。"
    echo
    echo "  QQ 群号: ${CYAN}1031976463${NC}"
    echo
    echo -e "${YELLOW}提示:${NC} 本群以闲聊交流为主，技术问题不保证有解答；需要技术支持请前往付费咨询。"
    echo "${UI_DIVIDER}"
}

# 加聊天社区咨询（Telegram 群，与 QQ 水群相互独立）
help_show_telegram_group() {
    clear
    show_menu_header "加聊天社区咨询"

    echo "  欢迎加入 PVE-Tools Telegram 聊天社区，与全球用户交流使用心得。"
    echo
    echo "  Telegram 群: ${CYAN}https://t.me/pvetools233${NC}"
    echo
    echo -e "${YELLOW}提示:${NC} 本社区与 QQ 水群相互独立；技术问题不保证有解答，需要技术支持请前往付费咨询。"
    echo "${UI_DIVIDER}"
}

# 加作者付费咨询（不提供免费技术支持，赞助入口一并展示）
help_show_paid_consult() {
    clear
    show_menu_header "加作者付费咨询"

    echo "  写脚本、维护项目需要时间和精力，这也是作者的饭碗。本工具免费开源，"
    echo "  但一般不提供免费的技术支持和免费解答方案，感谢理解～"
    echo
    echo -e "  ${RED}紧急情况 / 深度排查 / 谈合作：${NC}"
    echo "    QQ:       1520942621"
    echo "    微信:     kilomaple2024"
    echo "    Telegram: https://t.me/pvetools_bot"
    echo "    邮件:     contact@ciriu.com"
    echo
    echo "  想赞助作者：去官网支持一下，或直接加联系方式给作者转钱，感谢投喂！"
    echo "    官网支持页: ${CYAN}https://pve.ciriu.com/support${NC}"
    echo "${UI_DIVIDER}"
}
