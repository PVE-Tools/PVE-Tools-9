#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

remove_swap() {
    log_step "准备释放 Swap 空间给系统使用"
    log_warn "注意：删除 Swap 后请确保内存充足！"
    
    if ! confirm_high_risk_action \
        "删除 Swap 分区并扩展 root 文件系统" \
        "删除 /dev/pve/swap 逻辑卷，可能导致内存不足场景下系统不稳定。" \
        "将执行 swapoff、lvremove、lvextend、resize2fs，不可逆。" \
        "请确保内存充足（建议 >= 8GB），并已备份重要数据。" \
        "CONFIRM"; then
        log_info "好的，操作已取消"
        return
    fi
    
    # 检查 swap 是否存在
    if ! lvdisplay /dev/pve/swap &> /dev/null; then
        log_warn "没有找到 swap 分区，可能已经删除过了"
        return
    fi
    
    log_info "正在关闭 Swap..."
    swapoff /dev/mapper/pve-swap
    
    log_info "正在修改启动配置..."
    backup_file "/etc/fstab"
    sed -i 's|^/dev/pve/swap|# /dev/pve/swap|g' /etc/fstab
    
    log_info "正在删除 swap 分区..."
    lvremove -f /dev/pve/swap
    
    log_info "正在扩展系统分区..."
    lvextend -l +100%FREE /dev/mapper/pve-root
    
    log_info "正在扩展文件系统..."
    resize2fs /dev/mapper/pve-root
    
    log_success "Swap 删除完成！系统空间更宽裕了"
}

# 更新系统
