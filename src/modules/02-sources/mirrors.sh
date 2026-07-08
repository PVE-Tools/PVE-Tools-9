#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

change_sources() {
    block_non_pve9_destructive "更换软件源" || return 1
    log_step "开始为您的 PVE 换上飞速源"

    if ! mirror_selection_complete; then
        select_mirror || return 1
    fi

    local debian_mirror="${MIRROR_DEBIAN_URIS[$MIRROR_SELECTED_DEBIAN]}"
    local debian_security_mirror="${MIRROR_SECURITY_URIS[$MIRROR_SELECTED_SECURITY]}"
    local pve_mirror="${MIRROR_PVE_URIS[$MIRROR_SELECTED_PVE]}"
    local ceph_mirror="${MIRROR_CEPH_URIS[$MIRROR_SELECTED_CEPH]}"
    local ct_mirror="${MIRROR_CT_URIS[$MIRROR_SELECTED_CT]}"

    [[ -z "$debian_mirror" ]] && debian_mirror="https://deb.debian.org/debian"
    [[ -z "$debian_security_mirror" ]] && debian_security_mirror="https://security.debian.org/debian-security"
    [[ -z "$pve_mirror" ]] && pve_mirror="http://download.proxmox.com/debian/pve"
    [[ -z "$ceph_mirror" ]] && ceph_mirror="http://download.proxmox.com/debian/ceph-squid"
    [[ -z "$ct_mirror" ]] && ct_mirror="http://download.proxmox.com"

    log_info "镜像源配置:"
    log_info "  Debian:    $debian_mirror"
    log_info "  Security:  $debian_security_mirror"
    log_info "  PVE:       $pve_mirror"
    log_info "  Ceph:      $ceph_mirror"
    log_info "  CT 模板:   $ct_mirror"
    
    # 1. 更换 Debian 软件源 (DEB822 格式)
    log_info "正在配置 Debian 镜像源..."
    backup_file "/etc/apt/sources.list.d/debian.sources"
    
    cat > /etc/apt/sources.list.d/debian.sources << EOF
Types: deb
URIs: $debian_mirror
Suites: trixie trixie-updates trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
# Types: deb-src
# URIs: $debian_mirror
# Suites: trixie trixie-updates trixie-backports
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
Types: deb
URIs: $debian_security_mirror
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb-src
# URIs: $debian_security_mirror
# Suites: trixie-security
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    
    # 2. 注释企业源
    log_info "正在关闭企业源（我们用免费版就够啦）..."
    if [[ -f "/etc/apt/sources.list.d/pve-enterprise.sources" ]]; then
        backup_file "/etc/apt/sources.list.d/pve-enterprise.sources"
        sed -i 's/^Types:/#Types:/g' /etc/apt/sources.list.d/pve-enterprise.sources
        sed -i 's/^URIs:/#URIs:/g' /etc/apt/sources.list.d/pve-enterprise.sources
        sed -i 's/^Suites:/#Suites:/g' /etc/apt/sources.list.d/pve-enterprise.sources
        sed -i 's/^Components:/#Components:/g' /etc/apt/sources.list.d/pve-enterprise.sources
        sed -i 's/^Signed-By:/#Signed-By:/g' /etc/apt/sources.list.d/pve-enterprise.sources
    fi
    
    # 3. 更换 Ceph 源
    log_info "正在配置 Ceph 镜像源..."
    if [[ -f "/etc/apt/sources.list.d/ceph.sources" ]]; then
        backup_file "/etc/apt/sources.list.d/ceph.sources"
        cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: $ceph_mirror
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    fi
    
    # 4. 添加无订阅源
    log_info "正在添加免费版专用源..."
    cat > /etc/apt/sources.list.d/pve-no-subscription.sources << EOF
Types: deb
URIs: $pve_mirror
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    # 5. 更换 CT 模板源
    log_info "正在加速 CT 模板下载..."
    if [[ -f "/usr/share/perl5/PVE/APLInfo.pm" ]]; then
        backup_file "/usr/share/perl5/PVE/APLInfo.pm"
        local known_ct_uri
        for known_ct_uri in "${MIRROR_CT_URIS[@]}"; do
            [[ -n "$known_ct_uri" && "$known_ct_uri" != "http://download.proxmox.com" ]] || continue
            sed -i "s|$known_ct_uri|http://download.proxmox.com|g" /usr/share/perl5/PVE/APLInfo.pm
        done
        sed -i "s|http://download.proxmox.com|$ct_mirror|g" /usr/share/perl5/PVE/APLInfo.pm
    fi
    
    log_success "软件源配置已完成"
}

# 删除订阅弹窗
