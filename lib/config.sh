#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# 版本信息
CURRENT_VERSION="10.1.0"
BUILD_NICKNAME="Evanescia"
VERSION_FILE_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/VERSION"
UPDATE_FILE_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/UPDATE"
PVE_TOOLS_SCRIPT_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh"
PVE_VERSION_DETECTED=""
PVE_MAJOR_VERSION=""
RISK_ACK_BYPASS=false


# 镜像源注册表（并行数组，索引一一对应）
# 展示顺序即推荐顺序：官方源 -> 商业云 -> 骨干高校 -> 其他高校/地区源。
# 新增镜像: 在每个数组末尾追加一个元素即可。
MIRROR_NAMES=()
MIRROR_IDS=()
MIRROR_DEBIAN_URIS=()
MIRROR_SECURITY_URIS=()
MIRROR_PVE_URIS=()
MIRROR_CEPH_URIS=()
MIRROR_CT_URIS=()

MIRROR_NAMES+=("官方源 (Debian/Proxmox)")
MIRROR_IDS+=("official")
MIRROR_DEBIAN_URIS+=("https://deb.debian.org/debian")
MIRROR_SECURITY_URIS+=("https://security.debian.org/debian-security")
MIRROR_PVE_URIS+=("http://download.proxmox.com/debian/pve")
MIRROR_CEPH_URIS+=("http://download.proxmox.com/debian/ceph-squid")
MIRROR_CT_URIS+=("http://download.proxmox.com")

MIRROR_NAMES+=("阿里云 (公网限速/私网不限速)")
MIRROR_IDS+=("aliyun")
MIRROR_DEBIAN_URIS+=("https://mirrors.aliyun.com/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.aliyun.com/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("腾讯云 (公网限速/VPC不限速)")
MIRROR_IDS+=("tencent")
MIRROR_DEBIAN_URIS+=("https://mirrors.cloud.tencent.com/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.cloud.tencent.com/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("华为云 (公网限速/私网不限速)")
MIRROR_IDS+=("huaweicloud")
MIRROR_DEBIAN_URIS+=("https://mirrors.huaweicloud.com/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.huaweicloud.com/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("网易 163 (限速单线程)")
MIRROR_IDS+=("netease163")
MIRROR_DEBIAN_URIS+=("http://mirrors.163.com/debian")
MIRROR_SECURITY_URIS+=("http://mirrors.163.com/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("清华大学 (TUNA)")
MIRROR_IDS+=("tuna")
MIRROR_DEBIAN_URIS+=("https://mirrors.tuna.tsinghua.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.tuna.tsinghua.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("https://mirrors.tuna.tsinghua.edu.cn/proxmox")

MIRROR_NAMES+=("中科大 (USTC)")
MIRROR_IDS+=("ustc")
MIRROR_DEBIAN_URIS+=("https://mirrors.ustc.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.ustc.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.ustc.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirrors.ustc.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("https://mirrors.ustc.edu.cn/proxmox")

MIRROR_NAMES+=("北京大学 (PKU)")
MIRROR_IDS+=("pku")
MIRROR_DEBIAN_URIS+=("https://mirrors.pku.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.pku.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("上海交大致远 (SJTUG-Zhiyuan)")
MIRROR_IDS+=("sjtug-zhiyuan")
MIRROR_DEBIAN_URIS+=("https://mirrors.sjtug.sjtu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.sjtug.sjtu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("上海交大思源 (SJTUG-Siyuan)")
MIRROR_IDS+=("sjtug-siyuan")
MIRROR_DEBIAN_URIS+=("https://mirror.sjtu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirror.sjtu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("华中科技大学 (HUST)")
MIRROR_IDS+=("hust")
MIRROR_DEBIAN_URIS+=("https://mirrors.hust.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.hust.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("西安交通大学 (XJTU)")
MIRROR_IDS+=("xjtu")
MIRROR_DEBIAN_URIS+=("https://mirrors.xjtu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.xjtu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("南京大学 (NJUNJU)")
MIRROR_IDS+=("njunju")
MIRROR_DEBIAN_URIS+=("https://mirrors.nju.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.nju.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.nju.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirrors.nju.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("浙江大学 (ZJU)")
MIRROR_IDS+=("zju")
MIRROR_DEBIAN_URIS+=("https://mirrors.zju.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.zju.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.zju.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirrors.zju.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("https://mirrors.zju.edu.cn/proxmox")

MIRROR_NAMES+=("北京外国语大学 (BFSU)")
MIRROR_IDS+=("bfsu")
MIRROR_DEBIAN_URIS+=("https://mirrors.bfsu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.bfsu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.bfsu.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirrors.bfsu.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("兰州大学 (LZUOSS)")
MIRROR_IDS+=("lzuoss")
MIRROR_DEBIAN_URIS+=("https://mirror.lzu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirror.lzu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirror.lzu.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirror.lzu.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("山东大学 (SDU)")
MIRROR_IDS+=("sdu")
MIRROR_DEBIAN_URIS+=("https://mirrors.sdu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.sdu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.sdu.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("https://mirrors.sdu.edu.cn/proxmox/debian/ceph-squid")
MIRROR_CT_URIS+=("https://mirrors.sdu.edu.cn/proxmox")

MIRROR_NAMES+=("南阳理工学院 (NYIST)")
MIRROR_IDS+=("nyist")
MIRROR_DEBIAN_URIS+=("https://mirror.nyist.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirror.nyist.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirror.nyist.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("重庆大学 (CQU)")
MIRROR_IDS+=("cqu")
MIRROR_DEBIAN_URIS+=("https://mirrors.cqu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.cqu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.cqu.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("河南省教育科研网 (HERNET)")
MIRROR_IDS+=("hernet")
MIRROR_DEBIAN_URIS+=("https://mirrors.ha.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.ha.edu.cn/debian-security")
MIRROR_PVE_URIS+=("https://mirrors.ha.edu.cn/proxmox/debian/pve")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("南方科技大学 (SUSTech)")
MIRROR_IDS+=("sustech")
MIRROR_DEBIAN_URIS+=("https://mirrors.sustech.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.sustech.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("吉林大学 (JLU)")
MIRROR_IDS+=("jlu")
MIRROR_DEBIAN_URIS+=("https://mirrors.jlu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.jlu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("南京工业大学 (NJTech)")
MIRROR_IDS+=("njtech")
MIRROR_DEBIAN_URIS+=("https://mirrors.njtech.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.njtech.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_NAMES+=("西北农林科技大学 (NWAFU)")
MIRROR_IDS+=("nwafu")
MIRROR_DEBIAN_URIS+=("https://mirrors.nwafu.edu.cn/debian")
MIRROR_SECURITY_URIS+=("https://mirrors.nwafu.edu.cn/debian-security")
MIRROR_PVE_URIS+=("")
MIRROR_CEPH_URIS+=("")
MIRROR_CT_URIS+=("")

MIRROR_SELECTED_DEBIAN=-1
MIRROR_SELECTED_SECURITY=-1
MIRROR_SELECTED_PVE=-1
MIRROR_SELECTED_CEPH=-1
MIRROR_SELECTED_CT=-1

# 自动更新网络检测配置
CF_TRACE_URL="https://www.cloudflare.com/cdn-cgi/trace"
GITHUB_MIRROR_PREFIX="https://ghfast.top/"
USE_MIRROR_FOR_UPDATE=0
USER_COUNTRY_CODE=""
NETWORK_MODE="auto"
IS_OFFLINE_MODE=0
HITOKOTO_API_URL="https://v1.hitokoto.cn/?encode=json"
SESSION_TIP=""
PVE_KVM_ROM_DIR="/usr/share/kvm"

# 快速虚拟机下载脚本配置
FASTPVE_INSTALLER_URL="https://raw.githubusercontent.com/kspeeder/fastpve/main/fastpve-install.sh"
FASTPVE_PROJECT_URL="https://github.com/kspeeder/fastpve"
THIRD_PARTY_MODULES_TREE_API_MAIN_URL="https://api.github.com/repos/PVE-Tools/PVE-Tools-9/git/trees/main?recursive=1"
THIRD_PARTY_MODULES_TREE_API_MASTER_URL="https://api.github.com/repos/PVE-Tools/PVE-Tools-9/git/trees/master?recursive=1"
THIRD_PARTY_MODULES_RAW_BASE_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/Modules"
COOLERCONTROL_PROJECT_URL="https://gitlab.com/coolercontrol/coolercontrol"
COOLERCONTROL_DOCS_URL="https://docs.coolercontrol.org/getting-started.html"
COOLERCONTROL_DEB_SETUP_URL="https://dl.cloudsmith.io/public/coolercontrol/coolercontrol/setup.deb.sh"
NVIDIA_ASSETS_BASE_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/Modules/NVIDIA"
NVIDIA_VGPU_UNLOCK_SO_URL="${NVIDIA_ASSETS_BASE_URL}/libvgpu_unlock_rs.so"
VM_CONFIG_EXPORT_DIR="/var/lib/pve-tools/vm-config-exports"
VM_BACKUP_CRON_FILE="/etc/cron.d/pve-tools-vm-backup"
VM_DEFAULT_CLOUDINIT_BRIDGE="vmbr0"
HOST_NETWORK_INTERFACES_FILE="/etc/network/interfaces"
HOST_NETWORK_INTERFACES_STAGED_FILE="/etc/network/interfaces.new"
HOST_NETWORK_EXPORT_DIR="/var/lib/pve-tools/network-firewall-exports"
PVE_CLUSTER_FIREWALL_FILE="/etc/pve/firewall/cluster.fw"
