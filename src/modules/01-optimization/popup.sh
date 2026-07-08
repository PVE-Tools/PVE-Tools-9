#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

remove_subscription_popup() {
    block_non_pve9_destructive "删除订阅弹窗" || return 1
    log_step "正在消除那个烦人的订阅弹窗"
    
    local js_file="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
    if [[ -f "$js_file" ]]; then
        backup_file "$js_file"
        
        # 修复逻辑：
        # 新版 PVE 的 proxmoxlib.js 在 Ext.Msg.show 调用前有大量换行和空格
        # 原有的 sed 正则 "Ext.Msg.show\(\{\s+title" 可能因为换行符匹配失败
        # 新方案：直接将判断条件中的 !== 'active' 改为 == 'active'，从逻辑上短路
        # 匹配模式：res.data.status.toLowerCase() !== 'active'
        # 这种方式比替换 Ext.Msg.show 更稳定，且代码侵入性更小

        if grep -q "res.data.status.toLowerCase() !== 'active'" "$js_file"; then
             sed -i "s/res.data.status.toLowerCase() !== 'active'/res.data.status.toLowerCase() == 'active'/g" "$js_file"
             log_success "策略A生效：修改了判断逻辑"
        elif grep -q "Ext.Msg.show({" "$js_file"; then
             # 备用方案：如果找不到特定判断逻辑，尝试旧方法的宽泛匹配，但增强兼容性
             # 使用 perl 替代 sed 以更好地支持多行匹配
             perl -i -0777 -pe "s/(Ext\.Msg\.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" "$js_file"
             log_success "策略B生效：屏蔽了弹窗函数"
        else
             log_error "未找到匹配的代码片段，可能文件版本已更新"
             return 1
        fi

        systemctl restart pveproxy.service
        log_success "完美！再也不会有烦人的弹窗啦"
    else
        log_warn "咦？没找到弹窗文件，可能已经被处理过了"
    fi
}
reinstall_pve_webui_packages() {
    log_step "正在重新安装官方 Web UI 相关软件包"
    if apt-get install --reinstall -y pve-manager proxmox-widget-toolkit; then
        systemctl restart pveproxy.service
        log_success "官方 Web UI 文件已恢复"
        return 0
    fi

    log_error "重新安装失败，请检查软件源或网络后重试：apt-get install --reinstall -y pve-manager proxmox-widget-toolkit"
    return 1
}

# 恢复 proxmoxlib.js 文件
restore_proxmoxlib() {
    log_step "准备恢复官方 Web UI 文件"
    log_warn "此操作会重新安装 pve-manager 和 proxmox-widget-toolkit，并覆盖当前前端补丁"

    if ! confirm_action "确定要恢复官方 Web UI 文件吗？"; then
        return
    fi

    reinstall_pve_webui_packages
}

# 合并 local 与 local-lvm
