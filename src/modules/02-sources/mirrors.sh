#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# 换源过程中的失败统一上报：标明失败环节，并提示已产生的部分修改与备份位置。
# 参数: $1=失败环节描述（建议包含目标文件路径）
sources_write_error() {
    log_error "换源失败: $1"
    log_error "已写入的软件源不会自动回滚；请核对 /var/backups/pve-tools/ 中的备份后恢复，勿继续更新系统。"
}

# 按已选镜像重写 APT 源并禁用企业源；写入前沿用逐文件备份。
# 返回：0=完成；1=失败；2=用户取消，未写入配置。
# 任一备份、配置写入或 CT 模板替换失败即返回 1；此前已完成的文件保持已改写状态，
# 不承诺原子回滚，错误信息会指出失败环节。
change_sources() {
    block_non_pve9_destructive "更换软件源" || return 1
    log_step "开始为您的 PVE 换上飞速源"

    if ! mirror_selection_complete; then
        select_mirror || return $?
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

    if ! confirm_action "按以上配置重写 APT 源文件（debian/ceph/pve-no-subscription 等）"; then
        return 2
    fi

    # 1. 更换 Debian 软件源 (DEB822 格式)
    log_info "正在配置 Debian 镜像源..."
    # 仅对已存在的文件备份；backup_file 对不存在的文件返回 1，不能与备份失败混为一谈。
    if [[ -f "/etc/apt/sources.list.d/debian.sources" ]] \
        && ! backup_file "/etc/apt/sources.list.d/debian.sources"; then
        sources_write_error "备份 /etc/apt/sources.list.d/debian.sources 失败"
        return 1
    fi
    if ! cat > /etc/apt/sources.list.d/debian.sources << EOF
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
    then
        sources_write_error "写入 /etc/apt/sources.list.d/debian.sources 失败"
        return 1
    fi

    # 2. 注释企业源
    log_info "正在关闭企业源（我们用免费版就够啦）..."
    if [[ -f "/etc/apt/sources.list.d/pve-enterprise.sources" ]]; then
        if ! backup_file "/etc/apt/sources.list.d/pve-enterprise.sources"; then
            sources_write_error "备份 /etc/apt/sources.list.d/pve-enterprise.sources 失败"
            return 1
        fi
        # 注释整个 deb822 段，避免遗漏 Enabled 等字段形成缺少 Types 的残缺段。
        # 仅保留首列 # 注释；缩进的 # 行也加前缀，保留原文并保证重复执行幂等。
        if ! sed -i '/^#/!s/^/#/' /etc/apt/sources.list.d/pve-enterprise.sources; then
            sources_write_error "注释 /etc/apt/sources.list.d/pve-enterprise.sources 失败"
            return 1
        fi
    fi

    # 3. 更换 Ceph 源
    log_info "正在配置 Ceph 镜像源..."
    if [[ -f "/etc/apt/sources.list.d/ceph.sources" ]]; then
        if ! backup_file "/etc/apt/sources.list.d/ceph.sources"; then
            sources_write_error "备份 /etc/apt/sources.list.d/ceph.sources 失败"
            return 1
        fi
        if ! cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: $ceph_mirror
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
        then
            sources_write_error "写入 /etc/apt/sources.list.d/ceph.sources 失败"
            return 1
        fi
    fi

    # 4. 添加无订阅源
    log_info "正在添加免费版专用源..."
    if ! cat > /etc/apt/sources.list.d/pve-no-subscription.sources << EOF
Types: deb
URIs: $pve_mirror
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    then
        sources_write_error "写入 /etc/apt/sources.list.d/pve-no-subscription.sources 失败"
        return 1
    fi

    # 5. 更换 CT 模板源
    log_info "正在加速 CT 模板下载..."
    if [[ -f "/usr/share/perl5/PVE/APLInfo.pm" ]]; then
        if ! backup_file "/usr/share/perl5/PVE/APLInfo.pm"; then
            sources_write_error "备份 /usr/share/perl5/PVE/APLInfo.pm 失败"
            return 1
        fi
        local known_ct_uri
        for known_ct_uri in "${MIRROR_CT_URIS[@]}"; do
            [[ -n "$known_ct_uri" && "$known_ct_uri" != "http://download.proxmox.com" ]] || continue
            if ! sed -i "s|$known_ct_uri|http://download.proxmox.com|g" /usr/share/perl5/PVE/APLInfo.pm; then
                sources_write_error "重写 /usr/share/perl5/PVE/APLInfo.pm 的 CT 模板地址失败"
                return 1
            fi
        done
        if ! sed -i "s|http://download.proxmox.com|$ct_mirror|g" /usr/share/perl5/PVE/APLInfo.pm; then
            sources_write_error "写入 /usr/share/perl5/PVE/APLInfo.pm 的 CT 模板地址失败"
            return 1
        fi
    fi

    log_success "软件源配置已完成"
}

# 删除订阅弹窗