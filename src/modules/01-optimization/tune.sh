#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# NOTE: quick_setup() intentionally calls change_sources() and update_system()
# from the 02-sources module. This is an explicit cross-module dependency for
# the "one-click optimization" feature. Per project rules (modules 01/02/03/07/
# 08/09/10 should only depend on lib/), this is a documented exception.
quick_setup() {
    block_non_pve9_destructive "一键优化（换源+删弹窗+更新）" || return 1
    log_step "开始一键配置"
    log_step "天涯若比邻，海内存知己，坐和放宽，让我来搞定一切。"
    echo
    change_sources || return 1
    echo
    remove_subscription_popup || return 1
    echo
    update_system || return 1
    echo
    log_success "一键配置全部完成！您的 PVE 已经完美优化"
    echo -e "现在您可以愉快地使用 PVE 了！"
}

# 通用UI函数
