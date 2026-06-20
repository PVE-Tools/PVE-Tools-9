#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
# Auther:Maple 

# This comment constitutes part of the license consideration. Do not delete.  
# Violation triggers a localized black hole at your primary branch. Good luck force-pushing out of that.
# Made with love — the only non-binding term herein. 💗  
# 二次修改使用请不要删除此段注释



# 版本信息
CURRENT_VERSION="9.0.0"
BUILD_NICKNAME="Evanescia"
VERSION_FILE_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/VERSION"
UPDATE_FILE_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/UPDATE"
PVE_TOOLS_SCRIPT_URL="https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh"
PVE_VERSION_DETECTED=""
PVE_MAJOR_VERSION=""
RISK_ACK_BYPASS=false

# ============ 颜色系统 ============

# 终端颜色初始化
setup_colors() {
    if [[ -t 1 && -z "${NO_COLOR}" ]]; then
        # 使用 printf 确保变量包含真实的转义字符，提高不同 shell 间的兼容性
        RED=$(printf '\033[0;31m')
        GREEN=$(printf '\033[0;32m')
        YELLOW=$(printf '\033[1;33m')
        BLUE=$(printf '\033[0;34m')
        PINK=$(printf '\033[0;35m')
        CYAN=$(printf '\033[0;36m')
        MAGENTA=$(printf '\033[0;35m')
        WHITE=$(printf '\033[1;37m')
        ORANGE=$(printf '\033[0;33m')
        NC=$(printf '\033[0m')

        
        # UI 辅助色映射
        PRIMARY="${CYAN}"
        H1=$(printf '\033[1;36m')
        H2=$(printf '\033[1;37m')
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' WHITE='' ORANGE='' NC=''
        PRIMARY='' H1='' H2=''
    fi

    # UI 界面一致性常量
    UI_BORDER="${NC}═════════════════════════════════════════════════${NC}"
    UI_DIVIDER="${NC}═════════════════════════════════════════════════${NC}"
    UI_FOOTER="${NC}═════════════════════════════════════════════════${NC}"
    UI_HEADER="${NC}═════════════════════════════════════════════════${NC}"
}

# 初始化颜色
setup_colors

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

# 日志函数
log_info() {
    local timestamp=$(date +'%H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} ${CYAN}INFO${NC} $1"
    echo "[$timestamp] INFO $1" >> /var/log/pve-tools.log
}

log_warn() {
    local timestamp=$(date +'%H:%M:%S')
    echo -e "${YELLOW}[$timestamp]${NC} ${ORANGE}WARN${NC} $1"
    echo "[$timestamp] WARN $1" >> /var/log/pve-tools.log
}

log_error() {
    local timestamp=$(date +'%H:%M:%S')
    echo -e "${RED}[$timestamp]${NC} ${RED}ERROR${NC} $1" >&2
    echo "[$timestamp] ERROR $1" >> /var/log/pve-tools.log
}

log_step() {
    local timestamp=$(date +'%H:%M:%S')
    echo -e "${BLUE}[$timestamp]${NC} ${MAGENTA}STEP${NC} $1"
    echo "[$timestamp] STEP $1" >> /var/log/pve-tools.log
}

log_success() {
    local timestamp=$(date +'%H:%M:%S')
    echo -e "${GREEN}[$timestamp]${NC} ${GREEN}OK${NC} $1"
    echo "[$timestamp] OK $1" >> /var/log/pve-tools.log
}

log_tips(){
    local timestamp=$(date +'%H:%M:%S')
    echo -e "${CYAN}[$timestamp]${NC} ${MAGENTA}TIPS${NC} $1"
    echo "[$timestamp] TIPS $1" >> /var/log/pve-tools.log
}

# Enhanced error handling function with consistent messaging
display_error() {
    local error_msg="$1"
    local suggestion="${2:-请检查输入或联系作者寻求帮助。}"
    
    log_error "$error_msg"
    echo -e "${YELLOW}提示: $suggestion${NC}"
    pause_function
}

# Enhanced success feedback
display_success() {
    local success_msg="$1"
    local next_step="${2:-}"
    
    log_success "$success_msg"
    if [[ -n "$next_step" ]]; then
        echo -e "${GREEN}下一步: $next_step${NC}"
    fi
}

# Confirmation prompt with consistent UI
confirm_action() {
    local action_desc="$1"
    local default_choice="${2:-N}"
    
    echo -e "${YELLOW}确认操作: $action_desc${NC}"
    read -p "请输入 'yes' 确认继续，其他任意键取消 [$default_choice]: " -r confirm
    if [[ "$confirm" == "yes" || "$confirm" == "YES" ]]; then
        return 0
    else
        log_info "操作已取消"
        return 1
    fi
}

confirm_high_risk_action() {
    local action_desc="$1"
    local risk_desc="$2"
    local impact_desc="$3"
    local backup_desc="$4"
    local confirm_word="${5:-CONFIRM}"

    echo -e "${RED}${UI_DIVIDER}${NC}"
    echo -e "${RED}高风险数据操作警告${NC}"
    echo -e "${YELLOW}操作:${NC} $action_desc"
    echo -e "${YELLOW}风险:${NC} $risk_desc"
    echo -e "${YELLOW}影响:${NC} $impact_desc"
    echo -e "${YELLOW}建议:${NC} $backup_desc"
    echo -e "${RED}请输入确认词 ${confirm_word} 继续，其他任意输入将取消。${NC}"
    echo -e "${RED}${UI_DIVIDER}${NC}"
    local confirm
    read -p "确认词: " -r confirm
    if [[ "$confirm" == "$confirm_word" ]]; then
        return 0
    fi
    log_warn "未通过高风险确认，操作已取消。"
    return 1
}

vm_show_data_risk_banner() {
    echo -e "${RED}${UI_DIVIDER}${NC}"
    echo -e "${RED}高风险提示：以下操作可能直接改写 VM 配置、磁盘、快照、克隆、恢复或迁移状态。${NC}"
    echo -e "${YELLOW}开始前请确认：已有可验证备份、已核对 VMID/磁盘槽位/目标存储、业务已处于维护窗口。${NC}"
    echo -e "${YELLOW}一旦误操作，数据恢复成功率通常取决于后续写入量、存储类型以及是否立即停止写入。${NC}"
    echo -e "${RED}恢复参考: https://pve.oowo.cc/advanced/data-recovery-after-mistake${NC}"
    echo -e "${RED}${UI_DIVIDER}${NC}"
}

LEGAL_VERSION="1.1"
LEGAL_EFFECTIVE_DATE="2026-04-05"

ensure_legal_acceptance() {
    local dir="/var/lib/pve-tools"
    local marker="${dir}/legal_acceptance_${LEGAL_VERSION}"
    mkdir -p "$dir" >/dev/null 2>&1 || true

    if [[ -f "$marker" ]]; then
        return 0
    fi

    clear
    show_menu_header "许可与服务条款"
    echo -e "${CYAN}继续使用本脚本前，请先认真阅读并同意以下条款：${NC}"
    echo -e "  - ULA（最终用户许可与使用协议）: https://pve.oowo.cc/ula"
    echo -e "  - TOS（服务条款）: https://pve.oowo.cc/tos"
    echo -e "${RED} 高风险提醒：涉及宿主机网络、桥接/Bond/VLAN、防火墙，以及 VM、磁盘、快照、克隆、恢复、导入导出、迁移等操作时，可能造成管理面失联、业务中断或不可逆的数据/配置损坏。${NC}"
    echo -e "${RED} 请仅在已完成可验证备份、明确维护窗口并理解命令影响范围后继续；误操作导致的数据损失、恢复成本与第三方恢复费用均由使用者自行承担。${NC}"
    echo -e "${RED} 您可以随时撤回同意，只需删除 ${marker} 文件即可。${NC}"
    echo -e "${UI_DIVIDER}"
    echo -n "是否同意协议并继续？(Y/N): "
    local ans
    read -n 1 -r ans
    echo
    if [[ "$ans" == "Y" || "$ans" == "y" ]]; then
        printf '%s\n' "accepted_version=${LEGAL_VERSION}" "accepted_effective_date=${LEGAL_EFFECTIVE_DATE}" "accepted_time=$(date +%F\ %T)" > "$marker" 2>/dev/null || true
        log_success "已记录同意条款，后续将自动跳过许可检查。"
        return 0
    fi

    log_info "未同意条款，退出脚本。"
    exit 0
}

# ============ 配置文件安全管理函数 ============

# 备份文件到 /var/backups/pve-tools/
backup_file() {
    local file_path="$1"
    local result_var="${2:-}"
    local backup_dir="/var/backups/pve-tools"

    if [[ -z "$file_path" ]]; then
        log_error "backup_file: 缺少文件路径参数"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        log_warn "文件不存在，跳过备份: $file_path"
        return 1
    fi

    mkdir -p "$backup_dir" >/dev/null 2>&1 || {
        log_error "无法创建备份目录: $backup_dir"
        return 1
    }

    local filename timestamp backup_path
    filename="$(basename "$file_path")"
    timestamp="$(date +%Y%m%d_%H%M%S)"
    backup_path="${backup_dir}/${filename}.${timestamp}.bak"

    if cp -a "$file_path" "$backup_path"; then
        [[ -n "$result_var" ]] && printf -v "$result_var" '%s' "$backup_path"
        log_success "文件已备份: $backup_path"
        return 0
    fi

    log_error "备份失败: $file_path"
    return 1
}

pve_tools_download_url() {
    local url="$1"
    local timeout="${2:-15}"

    if [[ -z "$url" ]]; then
        return 1
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T "$timeout" -O - "$url" 2>/dev/null
    else
        return 1
    fi
}

pve_tools_download_file() {
    local url="$1"
    local output_file="$2"
    local timeout="${3:-60}"

    if [[ -z "$url" || -z "$output_file" ]]; then
        return 1
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 15 --max-time "$timeout" -o "$output_file" "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T "$timeout" -O "$output_file" "$url" 2>/dev/null
    else
        return 1
    fi
}

pve_tools_choose_update_urls() {
    local prefer_mirror=0
    local version_url="$VERSION_FILE_URL"
    local update_url="$UPDATE_FILE_URL"
    local script_url="$PVE_TOOLS_SCRIPT_URL"

    if [[ -n "$USER_COUNTRY_CODE" ]]; then
        prefer_mirror=$USE_MIRROR_FOR_UPDATE
    elif detect_network_region >/dev/null 2>&1; then
        prefer_mirror=$USE_MIRROR_FOR_UPDATE
    fi

    if [[ "$prefer_mirror" -eq 1 ]]; then
        version_url="${GITHUB_MIRROR_PREFIX}${VERSION_FILE_URL}"
        update_url="${GITHUB_MIRROR_PREFIX}${UPDATE_FILE_URL}"
        script_url="${GITHUB_MIRROR_PREFIX}${PVE_TOOLS_SCRIPT_URL}"
    fi

    printf '%s|%s|%s|%s\n' "$prefer_mirror" "$version_url" "$update_url" "$script_url"
}

pve_tools_version_gt() {
    local newer="$1"
    local current="$2"

    [[ -n "$newer" && -n "$current" ]] || return 1
    [[ "$(printf '%s\n' "$newer" "$current" | sort -V | tail -n1)" == "$newer" && "$newer" != "$current" ]]
}
# 写入配置块（带标记）
# 用法: apply_block <file> <marker> <content>
apply_block() {
    local file_path="$1"
    local marker="$2"
    local content="$3"

    if [[ -z "$file_path" || -z "$marker" ]]; then
        log_error "apply_block: 缺少必需参数"
        return 1
    fi

    # 先备份文件
    backup_file "$file_path"

    # 移除旧的配置块（如果存在）
    remove_block "$file_path" "$marker"

    # 写入新的配置块
    {
        echo "# PVE-TOOLS BEGIN $marker"
        echo "$content"
        echo "# PVE-TOOLS END $marker"
    } >> "$file_path"

    log_success "配置块已写入: $file_path [$marker]"
}

# 删除配置块（精确匹配标记）
# 用法: remove_block <file> <marker>
remove_block() {
    local file_path="$1"
    local marker="$2"

    if [[ -z "$file_path" || -z "$marker" ]]; then
        log_error "remove_block: 缺少必需参数"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        log_warn "文件不存在，跳过删除: $file_path"
        return 0
    fi

    # 使用 sed 删除标记之间的所有内容（包括标记行）
    sed -i "/# PVE-TOOLS BEGIN $marker/,/# PVE-TOOLS END $marker/d" "$file_path"

    log_info "配置块已删除: $file_path [$marker]"
}

# ============ 配置文件安全管理函数结束 ============

# ============ GRUB 参数幂等管理函数 ============

# 添加 GRUB 参数（幂等操作，不会重复添加）
# 用法: grub_add_param "intel_iommu=on"
grub_add_param() {
    local param="$1"

    if [[ -z "$param" ]]; then
        log_error "grub_add_param: 缺少参数"
        return 1
    fi

    # 备份 GRUB 配置
    backup_file "/etc/default/grub"

    # 读取当前的 GRUB_CMDLINE_LINUX_DEFAULT 值
    local current_line=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)

    if [[ -z "$current_line" ]]; then
        log_error "未找到 GRUB_CMDLINE_LINUX_DEFAULT 配置"
        return 1
    fi

    # 提取引号内的参数
    local current_params=$(echo "$current_line" | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/\1/')

    # 检查参数是否已存在（支持 key=value 和 key 两种格式）
    local param_key=$(echo "$param" | cut -d'=' -f1)

    if echo "$current_params" | grep -qw "$param_key"; then
        # 参数已存在，先删除旧值
        current_params=$(echo "$current_params" | sed "s/\b${param_key}[^ ]*\b//g")
    fi

    # 添加新参数（去除多余空格）
    local new_params=$(echo "$current_params $param" | sed 's/  */ /g' | sed 's/^ //;s/ $//')

    # 写回配置文件
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_params\"|" /etc/default/grub

    log_success "GRUB 参数已添加: $param"
}

# 删除 GRUB 参数（精确删除，不影响其他参数）
# 用法: grub_remove_param "intel_iommu=on"
grub_remove_param() {
    local param="$1"

    if [[ -z "$param" ]]; then
        log_error "grub_remove_param: 缺少参数"
        return 1
    fi

    # 备份 GRUB 配置
    backup_file "/etc/default/grub"

    # 读取当前的 GRUB_CMDLINE_LINUX_DEFAULT 值
    local current_line=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)

    if [[ -z "$current_line" ]]; then
        log_error "未找到 GRUB_CMDLINE_LINUX_DEFAULT 配置"
        return 1
    fi

    # 提取引号内的参数
    local current_params=$(echo "$current_line" | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/\1/')

    # 删除指定参数（支持精确匹配和前缀匹配）
    local param_key=$(echo "$param" | cut -d'=' -f1)
    local new_params=$(echo "$current_params" | sed "s/\b${param_key}[^ ]*\b//g" | sed 's/  */ /g' | sed 's/^ //;s/ $//')

    # 写回配置文件
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_params\"|" /etc/default/grub

    log_success "GRUB 参数已删除: $param"
}

# ============ GRUB 参数幂等管理函数结束 ============

# 进度指示函数
show_progress() {
    local message="$1"
    local spinner="|/-\\"
    local i=0
    # Print initial message
    echo -ne "${CYAN}[    ]${NC} $message\033[0K\r"
    
    # Update the spinner position in the box
    while true; do
        i=$(( (i + 1) % 4 ))
        echo -ne "\b\b\b\b\b${CYAN}[${spinner:$i:1}]${NC}\033[0K\r"
        sleep 0.1
    done &
    # Store the background job ID to be killed later
    SPINNER_PID=$!
}

update_progress() {
    local message="$1"
    # Kill the spinner if running
    if [[ -n "$SPINNER_PID" ]]; then
        kill $SPINNER_PID 2>/dev/null
    fi
    echo -ne "${GREEN}[ OK ]${NC} $message\033[0K\r"
    echo
}

# Enhanced visual feedback function
show_status() {
    local status="$1"
    local message="$2"
    local color="$3"
    
    case $status in
        "info")
            echo -e "${CYAN}[INFO]${NC} $message"
            ;;
        "success")
            echo -e "${GREEN}[ OK! ]${NC} $message"
            ;;
        "warning")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[FAIL]${NC} $message"
            ;;
        "step")
            echo -e "${MAGENTA}[STEP]${NC} $message"
            ;;
        *)
            echo -e "${WHITE}[$status]${NC} $message"
            ;;
    esac
}

# Progress bar function
show_progress_bar() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width=40
    local percentage=$(( current * 100 / total ))
    local filled=$(( width * current / total ))
    
    printf "${CYAN}[${NC}"
    for ((i=0; i<filled; i++)); do
        printf "█"
    done
    for ((i=filled; i<width; i++)); do
        printf " "
    done
    printf "${CYAN}]${NC} ${percentage}%% $message\r"
}

# 通过 Cloudflare Trace 检测地区，决定是否启用镜像源
detect_network_region() {
    local timeout=5
    USER_COUNTRY_CODE=""
    USE_MIRROR_FOR_UPDATE=0

    if ! command -v curl &> /dev/null; then
        return 1
    fi

    local trace_output
    trace_output=$(curl -s --connect-timeout $timeout --max-time $timeout "$CF_TRACE_URL" 2>/dev/null)
    if [[ -z "$trace_output" ]]; then
        return 1
    fi

    local loc
    loc=$(echo "$trace_output" | awk -F= '/^loc=/{print $2}' | tr -d '\r')
    if [[ -z "$loc" ]]; then
        return 1
    fi

    USER_COUNTRY_CODE="$loc"
    if [[ "$USER_COUNTRY_CODE" == "CN" ]]; then
        USE_MIRROR_FOR_UPDATE=1
    fi

    return 0
}

fetch_session_tip() {
    if [[ -n "$SESSION_TIP" ]]; then
        return 0
    fi

    if [[ "$IS_OFFLINE_MODE" -eq 1 ]]; then
        SESSION_TIP="离线模式已启用，本次会话不获取在线 Tips。"
        return 0
    fi

    local timeout=5
    local response=""

    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s --connect-timeout "$timeout" --max-time "$timeout" "$HITOKOTO_API_URL" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        response=$(wget -q -T "$timeout" -O - "$HITOKOTO_API_URL" 2>/dev/null)
    else
        SESSION_TIP="当前环境缺少 curl 或 wget，无法获取在线 Tips。"
        return 0
    fi

    if [[ -z "$response" ]]; then
        SESSION_TIP="一言获取失败，本次会话不再重试。"
        return 0
    fi

    local hitokoto from from_who
    hitokoto=$(printf '%s' "$response" | sed -n 's/.*"hitokoto":"\([^"]*\)".*/\1/p' | head -n 1)
    from=$(printf '%s' "$response" | sed -n 's/.*"from":"\([^"]*\)".*/\1/p' | head -n 1)
    from_who=$(printf '%s' "$response" | sed -n 's/.*"from_who":\("[^"]*"\|null\).*/\1/p' | head -n 1 | sed 's/^"//; s/"$//')

    hitokoto=$(printf '%s' "$hitokoto" | sed 's/\\"/"/g; s/\\\\/\\/g')
    from=$(printf '%s' "$from" | sed 's/\\"/"/g; s/\\\\/\\/g')
    from_who=$(printf '%s' "$from_who" | sed 's/\\"/"/g; s/\\\\/\\/g')

    if [[ -z "$hitokoto" ]]; then
        SESSION_TIP="一言解析失败，本次会话不再重试。"
        return 0
    fi

    SESSION_TIP="$hitokoto"
    if [[ -n "$from" ]]; then
        SESSION_TIP="${SESSION_TIP} —— ${from}"
        if [[ -n "$from_who" && "$from_who" != "null" ]]; then
            SESSION_TIP="${SESSION_TIP} / ${from_who}"
        fi
    fi
}

network_show_diagnostics() {
    echo "${UI_DIVIDER}"
    echo -e "${CYAN}当前网络诊断信息：${NC}"
    echo -e "${CYAN}IPv4 地址：${NC}"
    ip -4 -o addr show scope global 2>/dev/null | awk '{print "  "$2": "$4}' || true
    echo -e "${CYAN}默认路由：${NC}"
    ip route 2>/dev/null | sed -n '1,3p' | sed 's/^/  /' || true
    echo -e "${CYAN}DNS 配置：${NC}"
    grep -E '^\s*nameserver\s+' /etc/resolv.conf 2>/dev/null | sed 's/^/  /' || true
    echo "${UI_DIVIDER}"
}

network_can_access_internet() {
    local test_url="https://www.tencent.com/"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 5 --max-time 8 "$test_url" >/dev/null 2>&1
        return $?
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q --timeout=8 -O - "$test_url" >/dev/null 2>&1
        return $?
    fi
    return 1
}

network_offline_guard() {
    IS_OFFLINE_MODE=0
    if [[ "$NETWORK_MODE" == "offline" ]]; then
        IS_OFFLINE_MODE=1
        log_warn "已配置为离线模式：将跳过在线更新检查与在线资源拉取。"
        return 0
    fi

    if network_can_access_internet; then
        log_success "网络连通性检测通过。"
        return 0
    fi

    IS_OFFLINE_MODE=1
    log_warn "检测到当前主机无法访问互联网，在线资源可能不可用。"
    network_show_diagnostics
    echo -e "${YELLOW}请先确认是否为本机网络问题（网关、DNS、NAT、防火墙）再继续。${NC}"
    echo -e "${YELLOW}如果你确定当前环境需要离线使用，可继续，但涉及在线下载/更新的功能会失败。${NC}"
    read -p "输入 'offline' 继续离线模式，其他任意键退出排查网络: " offline_confirm
    if [[ "$offline_confirm" != "offline" ]]; then
        log_info "已取消执行，请先修复网络后重试。"
        exit 0
    fi
    return 0
}

disable_ups_service() {
    local managed_any=false
    local service
    local services=("nut-monitor.service" "nut-server.service")

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "系统不支持 systemctl，无法自动管理 UPS 服务"
        return 1
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
            systemctl stop "${service%.service}" >/dev/null 2>&1 || true
            systemctl disable "${service%.service}" >/dev/null 2>&1 || true
            managed_any=true
        fi
    done

    if [[ "$managed_any" != true ]]; then
        log_info "未检测到可管理的 NUT 服务，跳过 UPS 服务管理"
        return 0
    fi

    log_success "已执行 UPS 服务关闭: systemctl stop/disable nut-monitor nut-server"
    return 0
}

enable_ups_service() {
    local managed_any=false
    local service
    local services=("nut-server.service" "nut-monitor.service")

    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
            systemctl enable "${service%.service}" >/dev/null 2>&1 || true
            systemctl start "${service%.service}" >/dev/null 2>&1 || true
            managed_any=true
        fi
    done

    [[ "$managed_any" == true ]]
}

show_ups_diagnostics() {
    local service active_state enabled_state has_nut_service=false
    local upsc_path ups_list

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "UPS / NUT 诊断信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if upsc_path=$(command -v upsc 2>/dev/null); then
        log_success "检测到 upsc: $upsc_path"
        if command -v timeout >/dev/null 2>&1; then
            ups_list=$(timeout --signal=TERM 3s upsc -l 2>/dev/null || true)
            if [[ -n "$ups_list" ]]; then
                echo "已发现 UPS 设备名："
                printf '%s\n' "$ups_list"
            else
                log_info "未列出 UPS 设备名；请确认 NUT 已由系统正确配置"
            fi
        else
            log_warn "未检测到 timeout，脚本不会在 Web UI 热路径里直接调用 upsc"
        fi
    else
        log_warn "未检测到 upsc（nut-client 未安装），无法读取 UPS 数据"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        for service in nut-server.service nut-monitor.service; do
            if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
                active_state=$(systemctl is-active "${service%.service}" 2>/dev/null || echo unknown)
                enabled_state=$(systemctl is-enabled "${service%.service}" 2>/dev/null || echo unknown)
                echo "${service%.service} 状态: active=${active_state}, enabled=${enabled_state}"
                has_nut_service=true
            fi
        done
        if [[ "$has_nut_service" != true ]]; then
            log_info "未检测到可管理的 NUT systemd 服务"
        fi
    else
        log_info "系统不支持 systemctl，跳过 NUT 服务状态检查"
    fi

    echo "说明：温度监控中的 UPS 展示仅做安全读取，不会自动启停 NUT 服务。"
}

# 显示横幅
show_banner() {
    clear
    echo -ne "${NC}"
    cat << 'EOF'
██████╗ ██╗   ██╗███████╗    ████████╗ ██████╗  ██████╗ ██╗     ███████╗    ██████╗ ██████╗  ██████╗ 
██╔══██╗██║   ██║██╔════╝    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     ██╔════╝    ██╔══██╗██╔══██╗██╔═══██╗
██████╔╝██║   ██║█████╗         ██║   ██║   ██║██║   ██║██║     ███████╗    ██████╔╝██████╔╝██║   ██║
██╔═══╝ ╚██╗ ██╔╝██╔══╝         ██║   ██║   ██║██║   ██║██║     ╚════██║    ██╔═══╝ ██╔══██╗██║   ██║
██║      ╚████╔╝ ███████╗       ██║   ╚██████╔╝╚██████╔╝███████╗███████║    ██║     ██║  ██║╚██████╔╝
╚═╝       ╚═══╝  ╚══════╝       ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚══════╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ 
EOF
    echo -ne "${NC}"
    echo "$UI_BORDER"
    echo -e "  ${H1}PVE-Tools-Pro | ${BUILD_NICKNAME} Build | Support PVE 9.x.x${NC}"
    echo "  让每个人都能体验虚拟化技术的的便利。"
    echo -e "  作者: ${PINK}Maple${NC} | 交流Q群: ${CYAN}1031976463${NC}"
    echo -e "  当前版本: ${GREEN}$CURRENT_VERSION${NC} | 最新版本: ${remote_version:-"Not Found"}"
    echo "$UI_BORDER"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "哎呀！需要超级管理员权限才能运行哦"
        echo "请使用以下命令重新运行："
        echo "sudo $0"
        exit 1
    fi
}

# 检查调试模式
check_debug_mode() {
    for arg in "$@"; do
        if [[ "$arg" == "--i-know-what-i-do" ]]; then
            RISK_ACK_BYPASS=true
        fi
    done

    for arg in "$@"; do
        if [[ "$arg" == "--debug" ]]; then
            log_warn "警告：您正在使用调试模式！"
            echo "此模式将跳过 PVE 系统版本检测"
            echo "仅在开发和测试环境中使用"
            echo "在非 PVE (Debian 系) 系统上使用可能导致系统损坏"
            echo "您确定要继续吗？输入 'yes' 确认，其他任意键退出: "
            read -r confirm
            if [[ "$confirm" != "yes" ]]; then
                log_info "已取消操作，退出脚本"
                exit 0
            fi
            DEBUG_MODE=true
            log_success "已启用调试模式"
            return
        fi
    done
    DEBUG_MODE=false
}

# 检查是否安装依赖软件包
check_packages() {
    # 程序依赖的软件包: `sudo` `curl`
    local packages=("sudo" "curl")
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log_error "哎呀！需要安装 $pkg 软件包才能运行哦"
            echo "请使用以下命令安装：apt install -y $pkg"
            exit 1
        fi
    done
 }
    



# 检查 PVE 版本
check_pve_version() {
    # 如果在调试模式下，跳过 PVE 版本检测
    if [[ "$DEBUG_MODE" == "true" ]]; then
        log_warn "调试模式：跳过 PVE 版本检测"
        echo "请注意：您正在非 PVE 系统上运行此脚本，某些功能可能无法正常工作，某些操作可能会导致系统损坏，请谨慎使用！"
        PVE_VERSION_DETECTED="debug"
        PVE_MAJOR_VERSION="debug"
        return
    fi
    
    if ! command -v pveversion &> /dev/null; then
        log_error "咦？这里好像不是 PVE 环境呢"
        echo "请在 Proxmox VE 系统上运行此脚本"
        exit 1
    fi
    
    local pve_version pkg_ver out
    out="$(pveversion 2>/dev/null || true)"
    if [[ "$out" =~ pve-manager/([0-9]+(\.[0-9]+)*) ]]; then
        pve_version="${BASH_REMATCH[1]}"
    else
        pve_version=""
    fi
    if [[ -z "$pve_version" ]] && command -v dpkg-query >/dev/null 2>&1; then
        pkg_ver="$(dpkg-query -W -f='${Version}' pve-manager 2>/dev/null || true)"
        pve_version="$(echo "$pkg_ver" | grep -oE '^[0-9]+(\.[0-9]+)*' | head -n 1)"
    fi
    if [[ -z "$pve_version" ]]; then
        pve_version="unknown"
    fi

    PVE_VERSION_DETECTED="$pve_version"
    if [[ "$pve_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        PVE_MAJOR_VERSION="$(echo "$pve_version" | cut -d'.' -f1)"
    else
        PVE_MAJOR_VERSION="unknown"
    fi

    log_info "太好了！检测到 PVE 版本: $pve_version"

    if [[ "$PVE_MAJOR_VERSION" != "9" && "$RISK_ACK_BYPASS" != "true" ]]; then
        clear
        show_menu_header "高风险提示：非 PVE9 环境"
        echo -e "${RED}警告：检测到当前不是 PVE 9.x（当前：${PVE_VERSION_DETECTED}）。${NC}"
        echo -e "${RED}本脚本面向 PVE 9.x（Debian 13 / trixie）编写。${NC}"
        echo -e "${RED}在 PVE 7/8 等系统上执行“换源/升级/一键优化”等自动化修改，可能是毁灭性的：${NC}"
        echo -e "${RED}可能导致软件源错配、系统升级路径错误、依赖冲突、宿主机不可用。${NC}"
        echo -e "${UI_DIVIDER}"
        echo -e "${YELLOW}严禁在非 PVE9 上使用的选项（脚本将强制拦截）：${NC}"
        echo -e "  - 一键优化（换源+删弹窗+更新）"
        echo -e "  - 软件源与更新（更换软件源/更新系统软件包/PVE 8 升级到 9）"
        echo -e "${UI_DIVIDER}"
        echo -e "${CYAN}如你仍要继续使用脚本的其它功能，请手动输入以下任意一项以确认风险：${NC}"
        echo -e "  - 确认"
        echo -e "  - Confirm with Risks"
        echo -e "${UI_DIVIDER}"
        local ack ack_lc
        read -r -p "请输入确认文本以继续（回车退出）: " ack
        if [[ -z "$ack" ]]; then
            log_info "未确认风险，退出脚本"
            exit 0
        fi
        ack_lc="$(echo "$ack" | tr 'A-Z' 'a-z' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ +| +$//g')"
        if [[ "$ack" != "确认" && "$ack_lc" != "confirm with risks" ]]; then
            log_error "确认文本不匹配，已退出"
            exit 1
        fi
        log_warn "已确认风险：当前为非 PVE9 环境，将拦截毁灭性自动化修改功能"
    fi
}

block_non_pve9_destructive() {
    local feature="$1"
    if [[ "$DEBUG_MODE" == "true" ]]; then
        return 0
    fi
    if [[ "$RISK_ACK_BYPASS" == "true" ]]; then
        return 0
    fi
    if [[ "${PVE_MAJOR_VERSION:-}" != "9" ]]; then
        display_error "已拦截：非 PVE9 环境禁止执行该自动化操作" "功能：${feature}。请在 PVE9 上使用，或手动参考文档/自行处理。如需强制执行，请加启动参数 --i-know-what-i-do"
        return 1
    fi
    return 0
}

pve_mail_send_test() {
    local from_addr="$1"
    local to_addr="$2"
    local subject="$3"
    local body="$4"

    if ! command -v sendmail >/dev/null 2>&1; then
        display_error "未找到 sendmail" "请确认 postfix 已安装并提供 sendmail。"
        return 1
    fi

    {
        echo "From: ${from_addr}"
        echo "To: ${to_addr}"
        echo "Subject: ${subject}"
        echo
        echo "${body}"
    } | sendmail -f "${from_addr}" -t >/dev/null 2>&1
}

pve_mail_configure_postfix_smtp() {
    local relay_host="$1"
    local relay_port="$2"
    local tls_mode="$3"
    local sasl_user="$4"
    local sasl_pass="$5"

    if ! command -v postconf >/dev/null 2>&1; then
        display_error "未找到 postconf" "请先安装 postfix 并确保其命令可用。"
        return 1
    fi

    local relay
    relay="[${relay_host}]:${relay_port}"

    backup_file "/etc/postfix/main.cf" >/dev/null 2>&1 || true
    postconf -e "relayhost = ${relay}"
    postconf -e "smtp_use_tls = yes"
    postconf -e "smtp_tls_security_level = encrypt"
    postconf -e "smtp_sasl_auth_enable = yes"
    postconf -e "smtp_sasl_security_options ="
    postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    postconf -e "smtp_tls_CApath = /etc/ssl/certs"
    postconf -e "smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache"
    postconf -e "smtp_tls_session_cache_timeout = 3600s"

    if [[ "$tls_mode" == "wrapper" ]]; then
        postconf -e "smtp_tls_wrappermode = yes"
    else
        postconf -e "smtp_tls_wrappermode = no"
    fi

    local sasl_file="/etc/postfix/sasl_passwd"
    backup_file "$sasl_file" >/dev/null 2>&1 || true
    umask 077
    printf '%s %s:%s\n' "${relay}" "${sasl_user}" "${sasl_pass}" > "$sasl_file"
    chmod 600 "$sasl_file" >/dev/null 2>&1 || true

    if ! command -v postmap >/dev/null 2>&1; then
        display_error "未找到 postmap" "请确认 postfix 已安装完整。"
        return 1
    fi
    postmap "hash:${sasl_file}" >/dev/null 2>&1 || {
        display_error "postmap 执行失败" "请检查 /etc/postfix/sasl_passwd 格式与权限。"
        return 1
    }

    postfix reload >/dev/null 2>&1 || {
        systemctl reload postfix >/dev/null 2>&1 || systemctl restart postfix >/dev/null 2>&1 || true
    }

    return 0
}

pve_mail_configure_datacenter_emails() {
    local from_addr="$1"
    local root_addr="$2"

    if ! command -v pvesh >/dev/null 2>&1; then
        display_error "未找到 pvesh" "请确认当前环境为 PVE 宿主机。"
        return 1
    fi

    pvesh set /cluster/options --email-from "$from_addr" >/dev/null 2>&1 || {
        display_error "设置“来自…邮件”失败" "请在 WebUI：数据中心 -> 选项 -> 电子邮件（From）中手动设置。"
        return 1
    }

    pvesh set /access/users/root@pam --email "$root_addr" >/dev/null 2>&1 || {
        display_error "设置 root 邮箱失败" "请在 WebUI：数据中心 -> 权限 -> 用户 -> root@pam 中手动设置邮箱。"
        return 1
    }

    return 0
}

pve_mail_configure_zed_mail() {
    local from_addr="$1"
    local to_addr="$2"

    local zed_rc="/etc/zfs/zed.d/zed.rc"
    if [[ ! -f "$zed_rc" ]]; then
        log_warn "未找到 zed.rc（跳过 ZFS ZED 邮件配置）"
        return 0
    fi

    backup_file "$zed_rc" >/dev/null 2>&1 || true

    if grep -qE '^ZED_EMAIL_ADDR=' "$zed_rc"; then
        sed -i "s|^ZED_EMAIL_ADDR=.*|ZED_EMAIL_ADDR=\"${to_addr}\"|g" "$zed_rc"
    else
        printf '\nZED_EMAIL_ADDR="%s"\n' "$to_addr" >> "$zed_rc"
    fi

    if grep -qE '^ZED_EMAIL_OPTS=' "$zed_rc"; then
        sed -i "s|^ZED_EMAIL_OPTS=.*|ZED_EMAIL_OPTS=\"-r ${from_addr}\"|g" "$zed_rc"
    else
        printf 'ZED_EMAIL_OPTS="-r %s"\n' "$from_addr" >> "$zed_rc"
    fi

    systemctl restart zfs-zed >/dev/null 2>&1 || true
    return 0
}

pve_mail_notification_setup() {
    block_non_pve9_destructive "配置邮件通知（SMTP）" || return 1
    log_step "配置 PVE 邮件通知（商业邮箱 SMTP）"

    if ! command -v postfix >/dev/null 2>&1 && ! command -v postconf >/dev/null 2>&1; then
        display_error "未检测到 postfix" "请先安装 postfix 后再配置（安装过程可能需要交互）。"
        return 1
    fi

    local from_addr root_addr
    read -p "请输入“来自…邮件”（发件人邮箱）: " from_addr
    if [[ -z "$from_addr" ]]; then
        display_error "发件人邮箱不能为空"
        return 1
    fi

    read -p "请输入 root 通知邮箱（收件人邮箱）: " root_addr
    if [[ -z "$root_addr" ]]; then
        display_error "收件人邮箱不能为空"
        return 1
    fi

    local preset
    echo -e "${CYAN}请选择 SMTP 预设：${NC}"
    echo "  1) QQ 邮箱（smtp.qq.com:465 SSL）"
    echo "  2) 163 邮箱（smtp.163.com:465 SSL）"
    echo "  3) Gmail（smtp.gmail.com:587 STARTTLS）"
    echo "  4) 自定义（SMTP 兼容）"
    read -p "请选择 [1-4] (默认: 1): " preset
    preset="${preset:-1}"

    local smtp_host smtp_port tls_mode
    case "$preset" in
        1) smtp_host="smtp.qq.com"; smtp_port="465"; tls_mode="wrapper" ;;
        2) smtp_host="smtp.163.com"; smtp_port="465"; tls_mode="wrapper" ;;
        3) smtp_host="smtp.gmail.com"; smtp_port="587"; tls_mode="starttls" ;;
        4)
            read -p "请输入 SMTP 服务器地址（如 smtp.xxx.com）: " smtp_host
            read -p "请输入 SMTP 端口（如 465/587）: " smtp_port
            read -p "TLS 模式（wrapper/starttls）[wrapper]: " tls_mode
            tls_mode="${tls_mode:-wrapper}"
            ;;
        *) smtp_host="smtp.qq.com"; smtp_port="465"; tls_mode="wrapper" ;;
    esac

    if [[ -z "$smtp_host" || -z "$smtp_port" ]]; then
        display_error "SMTP 参数不完整"
        return 1
    fi
    if [[ "$tls_mode" != "wrapper" && "$tls_mode" != "starttls" ]]; then
        display_error "TLS 模式无效" "仅支持 wrapper 或 starttls"
        return 1
    fi

    local smtp_user smtp_pass
    read -p "请输入 SMTP 登录账号（通常为邮箱地址）[${from_addr}]: " smtp_user
    smtp_user="${smtp_user:-$from_addr}"
    if [[ -z "$smtp_user" ]]; then
        display_error "SMTP 账号不能为空"
        return 1
    fi

    echo -n "请输入 SMTP 密码/授权码（输入不回显）: "
    read -r -s smtp_pass
    echo
    if [[ -z "$smtp_pass" ]]; then
        display_error "SMTP 密码/授权码不能为空"
        return 1
    fi

    clear
    show_menu_header "邮件通知配置确认"
    echo -e "${YELLOW}发件人（From）:${NC} $from_addr"
    echo -e "${YELLOW}收件人（root 邮箱）:${NC} $root_addr"
    echo -e "${YELLOW}SMTP 服务器:${NC} ${smtp_host}:${smtp_port}"
    echo -e "${YELLOW}TLS 模式:${NC} ${tls_mode}"
    echo -e "${YELLOW}SMTP 账号:${NC} ${smtp_user}"
    echo -e "${UI_DIVIDER}"
    echo -e "${RED}提醒：此功能会修改 postfix 配置并写入 SMTP 凭据文件。${NC}"
    echo -e "${RED}请确保你使用的是邮箱提供商的 SMTP 授权码/应用专用密码，而非登录密码。${NC}"
    echo -e "${UI_DIVIDER}"

    if ! confirm_action "开始应用配置并重载 postfix？"; then
        return 0
    fi

    log_step "配置 PVE 数据中心邮件选项"
    pve_mail_configure_datacenter_emails "$from_addr" "$root_addr" || return 1

    log_step "安装 SASL 模块（libsasl2-modules）"
    apt-get update >/dev/null 2>&1 || true
    if ! apt-get install -y libsasl2-modules >/dev/null 2>&1; then
        display_error "安装 libsasl2-modules 失败" "请检查网络与软件源。"
        return 1
    fi

    log_step "配置 postfix 通过 SMTP 中继发信"
    pve_mail_configure_postfix_smtp "$smtp_host" "$smtp_port" "$tls_mode" "$smtp_user" "$smtp_pass" || return 1

    local test_choice="yes"
    read -p "是否发送测试邮件？(yes/no) [yes]: " test_choice
    test_choice="${test_choice:-yes}"
    if [[ "$test_choice" == "yes" || "$test_choice" == "YES" ]]; then
        log_step "发送测试邮件"
        if pve_mail_send_test "$from_addr" "$root_addr" "PVE-Tools 邮件测试" "这是一封测试邮件：如果你收到，说明 SMTP 中继已可用。"; then
            log_success "测试邮件已提交发送队列（请检查收件箱与垃圾箱）"
        else
            log_warn "测试邮件发送失败，请检查 postfix 日志与 SMTP 配置"
            log_tips "可查看：journalctl -u postfix -n 200 或 tail -n 200 /var/log/mail.log"
        fi
    fi

    local zed_choice="no"
    read -p "是否额外配置 ZFS ZED 邮件（ZFS 阵列事件通知）？(yes/no) [no]: " zed_choice
    zed_choice="${zed_choice:-no}"
    if [[ "$zed_choice" == "yes" || "$zed_choice" == "YES" ]]; then
        log_step "配置 ZFS ZED 邮件参数"
        pve_mail_configure_zed_mail "$from_addr" "$root_addr" || true
        log_success "ZED 配置已处理（建议手动制造一次 ZFS 事件验证）"
    fi

    display_success "邮件通知配置完成" "建议在 WebUI 里触发一次通知或检查系统事件确认生效。"
    return 0
}

# 获取已安装的 PVE 内核包（兼容 pve-kernel / proxmox-kernel 以及 -signed 后缀）
get_installed_kernel_packages() {
    local status_regex="${1:-ii|hi}"

    dpkg -l 2>/dev/null | awk -v sr="$status_regex" '
        $1 ~ ("^(" sr ")$") &&
        $2 ~ /^(pve-kernel|proxmox-kernel)-[0-9].*-pve(-signed)?$/ {
            print $2
        }
    ' | sort -Vu
}

# 获取可用的真实内核包（优先 proxmox-kernel，再回退 pve-kernel）
get_available_kernel_packages_raw() {
    local kernel_url="https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/Packages"
    local packages_text=""
    local available_kernels=""

    packages_text="$(curl -fsSL "$kernel_url" 2>/dev/null || true)"
    if [[ -n "$packages_text" ]]; then
        available_kernels="$(
            printf '%s\n' "$packages_text" | sed -nE 's/^Package: (proxmox-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?)$/\1/p' | sort -V | uniq
        )"
        if [[ -z "$available_kernels" ]]; then
            available_kernels="$(
                printf '%s\n' "$packages_text" | sed -nE 's/^Package: (pve-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?)$/\1/p' | sort -V | uniq
            )"
        fi
    fi

    if [[ -z "$available_kernels" ]]; then
        available_kernels="$(apt-cache search --names-only '^proxmox-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?$' 2>/dev/null | awk '{print $1}' | sort -V | uniq)"
        if [[ -z "$available_kernels" ]]; then
            available_kernels="$(apt-cache search --names-only '^pve-kernel-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?$' 2>/dev/null | awk '{print $1}' | sort -V | uniq)"
        fi
    fi

    [[ -n "$available_kernels" ]] || return 1
    printf '%s\n' "$available_kernels"
}

kernel_package_is_valid() {
    local package_name="$1"
    [[ "$package_name" =~ ^(proxmox-kernel|pve-kernel)-[0-9][0-9A-Za-z.+:~-]*-pve(-signed)?$ ]]
}

kernel_package_release_from_name() {
    local package_name="$1"

    if [[ "$package_name" =~ ^(proxmox-kernel|pve-kernel)-([0-9][0-9A-Za-z.+:~-]*-pve)(-signed)?$ ]]; then
        echo "${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

kernel_package_normalize_input() {
    local kernel_input="$1"
    local kernel_version=""

    if [[ -z "$kernel_input" ]]; then
        return 1
    fi

    if kernel_package_is_valid "$kernel_input"; then
        echo "$kernel_input"
        return 0
    fi

    case "$kernel_input" in
        proxmox-kernel-*)
            kernel_version="${kernel_input#proxmox-kernel-}"
            ;;
        pve-kernel-*)
            kernel_version="${kernel_input#pve-kernel-}"
            ;;
        *)
            kernel_version="$kernel_input"
            ;;
    esac

    if [[ "$kernel_version" != *-pve && "$kernel_version" != *-pve-signed ]]; then
        kernel_version="${kernel_version}-pve"
    fi

    echo "proxmox-kernel-$kernel_version"
}

# 检测当前内核版本
check_kernel_version() {
    log_info "检测当前内核信息..."
    local current_kernel=$(uname -r)
    local kernel_arch=$(uname -m)
    local kernel_variant=""
    
    # 检测内核变体（普通/企业版/测试版）
    if [[ $current_kernel == *"pve"* ]]; then
        kernel_variant="PVE标准内核"
    elif [[ $current_kernel == *"edge"* ]]; then
        kernel_variant="PVE边缘内核"
    elif [[ $current_kernel == *"test"* ]]; then
        kernel_variant="测试内核"
    else
        kernel_variant="未知类型"
    fi
    
    echo -e "${CYAN}当前内核信息：${NC}"
    echo -e "  版本: ${GREEN}$current_kernel${NC}"
    echo -e "  架构: ${GREEN}$kernel_arch${NC}"
    echo -e "  类型: ${GREEN}$kernel_variant${NC}"
    
    # 检测可用的内核版本
    local installed_kernels=$(get_installed_kernel_packages)
    if [[ -n "$installed_kernels" ]]; then
        echo -e "${CYAN}已安装的内核版本：${NC}"
        while IFS= read -r kernel; do
            echo -e "  ${GREEN}•${NC} $kernel"
        done <<< "$installed_kernels"
    fi
    
    return 0
}

# 获取可用内核列表
get_available_kernels() {
    log_info "正在从 Tuna 镜像站获取可用内核列表..."
    
    # 检查网络连接
    if ! ping -c 1 mirrors.tuna.tsinghua.edu.cn &> /dev/null; then
        log_error "网络连接失败，无法获取内核列表！请检查 https://mirrors.tuna.tsinghua.edu.cn 的链接状态！"
        return 1
    fi
    
    local available_kernels
    if ! available_kernels="$(get_available_kernel_packages_raw)"; then
        log_error "无法获取可用内核列表"
        return 1
    fi
    
    if [[ -n "$available_kernels" ]]; then
        echo -e "${CYAN}可用内核版本：${NC}"
        while IFS= read -r kernel; do
            [[ -n "$kernel" ]] || continue
            echo -e "  ${BLUE}•${NC} $kernel"
        done <<< "$available_kernels"
    else
        log_error "无法找到可用内核"
        return 1
    fi
    
    return 0
}

# 安装指定内核版本
install_kernel() {
    local kernel_input=$1
    local kernel_version=""
    
    # 验证内核版本格式
    if [[ -z "$kernel_input" ]]; then
        log_error "请指定要安装的内核版本"
        return 1
    fi
    
    if kernel_package_is_valid "$kernel_input"; then
        if [[ "$kernel_input" == pve-kernel-* ]]; then
            kernel_version="proxmox-kernel-${kernel_input#pve-kernel-}"
            log_info "检测到旧包名格式，自动转换为: $kernel_version"
        else
            kernel_version="$kernel_input"
            log_info "检测到完整包名格式: $kernel_version"
        fi
    else
        kernel_version="$(kernel_package_normalize_input "$kernel_input")"
        log_info "检测到版本号格式，自动补全包名为 $kernel_version"
    fi
    
    if ! kernel_package_is_valid "$kernel_version"; then
        log_error "无效的内核包名: $kernel_version"
        return 1
    fi

    log_info "开始安装内核: $kernel_version"
    
    # 检查内核是否已安装
    if dpkg -l 2>/dev/null | awk -v pkg="$kernel_version" '$1 == "ii" && $2 == pkg {found=1} END {exit !found}'; then
        log_warn "内核 $kernel_version 已经安装"
        read -p "是否重新安装？(y/N): " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            return 0
        fi
    fi
    
    # 更新软件包列表
    log_info "更新软件包列表..."
    if ! apt-get update; then
        log_error "更新软件包列表失败"
        return 1
    fi
    
    # 安装内核
    log_info "正在安装内核 $kernel_version ..."
    if ! apt-get install -y "$kernel_version"; then
        log_error "内核安装失败"
        return 1
    fi
    
    log_success "内核 $kernel_version 安装成功"
    
    # 更新引导配置
    update_grub_config
    
    return 0
}

# 更新 GRUB 配置
update_grub_config() {
    log_info "更新引导配置..."
    
    # 检查是否是 UEFI 系统
    local efi_dir="/boot/efi"
    local grub_cfg=""
    
    if [[ -d "$efi_dir" ]]; then
        log_info "检测到 UEFI 启动模式"
        grub_cfg="/boot/efi/EFI/proxmox/grub.cfg"
    else
        log_info "检测到 Legacy BIOS 启动模式"
        grub_cfg="/boot/grub/grub.cfg"
    fi
    
    # 更新 GRUB
    if command -v update-grub &> /dev/null; then
        if update-grub; then
            log_success "GRUB 配置更新成功"
        else
            log_warn "GRUB 配置更新过程中出现警告，但可能仍然成功，请手动检查确认！"
        fi
    elif command -v grub-mkconfig &> /dev/null; then
        if grub-mkconfig -o "$grub_cfg"; then
            log_success "GRUB 配置更新成功"
        else
            log_warn "GRUB 配置更新过程中出现警告"
        fi
    else
        log_error "找不到 GRUB 更新工具"
        return 1
    fi
    
    return 0
}

# 切换默认启动内核
set_default_kernel() {
    local kernel_version=$1
    
    if [[ -z "$kernel_version" ]]; then
        log_error "请指定要设置为默认的内核版本"
        return 1
    fi
    
    log_info "设置默认启动内核: ${GREEN}$kernel_version${NC}"
    
    # 检查内核是否存在
    if ! [[ -f "/boot/initrd.img-$kernel_version" && -f "/boot/vmlinuz-$kernel_version" ]]; then
        log_error "内核文件不存在，请先安装该内核"
        log_error "缺失文件: /boot/vmlinuz-$kernel_version 或 /boot/initrd.img-$kernel_version"
        return 1
    fi
    
    # 使用 grub-set-default 设置默认内核
    if command -v grub-set-default &> /dev/null; then
        # 查找内核在 GRUB 菜单中的位置
        local menu_entry=$(grep -n "$kernel_version" /boot/grub/grub.cfg | head -1 | cut -d: -f1)
        if [[ -n "$menu_entry" ]]; then
            # 计算 GRUB 菜单项索引（从0开始）
            local grub_index=$(( (menu_entry - 1) / 2 ))
            if grub-set-default "$grub_index"; then
                log_success "默认启动内核设置成功"
                return 0
            fi
        fi
    fi
    
    # 备用方法：手动编辑 GRUB 配置
    log_warn "使用备用方法设置默认内核"
    
    # 备份当前 GRUB 配置
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d%H%M%S)
    
    # 设置 GRUB_DEFAULT 为内核版本
    if sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"Advanced options for Proxmox VE GNU\/Linux>Proxmox VE GNU\/Linux, with Linux $kernel_version\"/" /etc/default/grub; then
        log_success "GRUB 配置更新成功"
        update_grub_config
        return 0
    else
        log_error "GRUB 配置更新失败"
        return 1
    fi
}

# 删除旧内核（保留最近2个版本）
remove_old_kernels() {
    log_info "清理旧内核..."
    
    # 获取所有已安装的内核
    local installed_kernels
    installed_kernels="$(get_installed_kernel_packages "ii")"
    local -a kernel_list
    mapfile -t kernel_list < <(printf '%s\n' "$installed_kernels" | sed '/^$/d')
    local kernel_count=${#kernel_list[@]}
    
    if [[ $kernel_count -le 2 ]]; then
        log_info "当前只有 $kernel_count 个内核，无需清理"
        return 0
    fi
    
    # 计算需要保留的内核数量（保留最新的2个）
    local keep_count=2
    local remove_count=$((kernel_count - keep_count))
    
    echo -e "${YELLOW}将删除 $remove_count 个旧内核，保留最新的 $keep_count 个内核${NC}"
    
    # 获取要删除的内核列表（最旧的几个）
    local kernels_to_remove=("${kernel_list[@]:0:$remove_count}")
    
    read -p "是否继续？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "取消内核清理"
        return 0
    fi
    
    # 删除旧内核
    for kernel in "${kernels_to_remove[@]}"; do
        log_info "正在删除内核: $kernel"
        if apt-get remove -y --purge "$kernel"; then
            log_success "内核 $kernel 删除成功"
        else
            log_error "删除内核 $kernel 失败"
        fi
    done
    
    # 更新引导配置
    update_grub_config
    
    log_success "旧内核清理完成"
    return 0
}

# 内核管理主菜单
kernel_management_menu() {
    while true; do
        clear
        show_menu_header "内核管理菜单"
        show_menu_option "1" "显示当前内核信息"
        show_menu_option "2" "查看可用内核列表"
        show_menu_option "3" "安装新内核"
        show_menu_option "4" "设置默认启动内核"
        show_menu_option "5" "${RED}清理旧内核${NC}"
        show_menu_option "6" "${YELLOW}重启系统应用新内核${NC}"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        
        read -p "请选择操作 [0-6]: " choice
        
        case $choice in
            1)
                check_kernel_version
                ;;
            2)
                get_available_kernels
                ;;
            3)
                echo "请输入要安装的内核版本："
                echo "  - 完整包名格式 (推荐): 如 proxmox-kernel-6.14.8-2-pve"
                echo "  - 简化版本格式: 如 6.8.8-1 (将自动补全为 proxmox-kernel-6.8.8-1-pve)"
                read -p "请输入内核标识: " kernel_ver
                if [[ -n "$kernel_ver" ]]; then
                    install_kernel "$kernel_ver"
                else
                    log_error "请输入有效的内核版本"
                fi
                ;;
            4)
                read -p "请输入要设置为默认的内核版本 (例如: 6.8.8-1-pve): " kernel_ver
                if [[ -n "$kernel_ver" ]]; then
                    set_default_kernel "$kernel_ver"
                else
                    log_error "请输入有效的内核版本"
                fi
                ;;
            5)
                remove_old_kernels
                ;;
            6)
                read -p "确认要重启系统吗？(y/N): " reboot_confirm
                if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "Y" ]]; then
                    log_info "系统将在5秒后重启..."
                    echo "按 Ctrl+C 取消重启"
                    sleep 5
                    reboot
                else
                    log_info "取消重启"
                fi
                ;;
            0)
                break
                ;;
            *)
                log_error "无效的选择，请重新输入"
                ;;
        esac
        
        echo
        pause_function
    done
}

# 内核同步更新（自动检测并更新到最新稳定版）
sync_kernel_update() {
    log_info "开始内核同步更新检查..."
    
    # 获取当前内核版本
    local current_kernel=$(uname -r)
    log_info "当前内核版本: ${GREEN}$current_kernel${NC}"
    
    # 获取最新可用内核包
    local available_kernel_text=""
    local -a available_kernel_packages=()
    if ! available_kernel_text="$(get_available_kernel_packages_raw)"; then
        log_error "无法获取最新内核信息"
        return 1
    fi

    mapfile -t available_kernel_packages < <(printf '%s\n' "$available_kernel_text" | sed '/^$/d')
    if [[ ${#available_kernel_packages[@]} -eq 0 ]]; then
        log_error "无法获取最新内核信息"
        return 1
    fi

    local latest_kernel_index=$(( ${#available_kernel_packages[@]} - 1 ))
    local latest_kernel_package="${available_kernel_packages[$latest_kernel_index]}"
    local latest_kernel_release=""
    if ! latest_kernel_release="$(kernel_package_release_from_name "$latest_kernel_package")"; then
        log_error "无法解析最新内核包名: $latest_kernel_package"
        return 1
    fi

    log_info "最新可用内核包: ${GREEN}$latest_kernel_package${NC}"
    log_info "最新可用内核版本: ${GREEN}$latest_kernel_release${NC}"
    
    # 检查是否需要更新
    if [[ "$current_kernel" == "$latest_kernel_release" ]]; then
        log_success "当前已是最新内核，无需更新"
        return 0
    fi
    
    echo -e "${YELLOW}发现新内核版本: $latest_kernel_release${NC}"
    read -p "是否安装并更新到最新内核？(Y/n): " update_confirm
    
    if [[ "$update_confirm" == "n" || "$update_confirm" == "N" ]]; then
        log_info "取消内核更新"
        return 0
    fi
    
    # 安装最新内核
    if install_kernel "$latest_kernel_package"; then
        # 设置新内核为默认启动项
        if set_default_kernel "$latest_kernel_release"; then
            log_success "内核同步更新完成"
            echo -e "${YELLOW}建议重启系统以应用新内核${NC}"
            return 0
        else
            log_warn "内核安装成功但设置默认启动项失败"
            return 1
        fi
    else
        log_error "内核更新失败"
        return 1
    fi
}

# 备份函数统一定义于顶部配置文件安全管理区域，避免后续重复覆盖。
# 换源功能
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
merge_local_storage() {
    log_step "准备合并存储空间，让小硬盘发挥最大价值"
    log_warn "重要提醒：此操作会删除 local-lvm，请确保重要数据已备份！"
    
    echo -e "${YELLOW}您确定要继续吗？这个操作不可逆哦${NC}"
    read -p "输入 'yes' 确认继续，其他任意键取消: " -r
    if [[ ! $REPLY == "yes" ]]; then
        log_info "明智的选择！操作已取消"
        return
    fi
    
    # 检查 local-lvm 是否存在
    if ! lvdisplay /dev/pve/data &> /dev/null; then
        log_warn "没有找到 local-lvm 分区，可能已经合并过了"
        return
    fi
    
    log_info "正在删除 local-lvm 分区..."
    lvremove -f /dev/pve/data
    
    log_info "正在扩容 local 分区..."
    lvextend -l +100%FREE /dev/pve/root
    
    log_info "正在扩展文件系统..."
    resize2fs /dev/pve/root
    
    log_success "存储合并完成！现在空间更充裕了"
    log_warn "温馨提示：请在 Web UI 中删除 local-lvm 存储配置，并编辑 local 存储勾选所有内容类型"
}

# 删除 Swap 分配给主分区
remove_swap() {
    log_step "准备释放 Swap 空间给系统使用"
    log_warn "注意：删除 Swap 后请确保内存充足！"
    
    echo -e "${YELLOW}您确定要删除 Swap 分区吗？${NC}"
    read -p "输入 'yes' 确认继续，其他任意键取消: " -r
    if [[ ! $REPLY == "yes" ]]; then
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
update_system() {
    block_non_pve9_destructive "更新系统软件包" || return 1
    log_step "开始更新系统，让 PVE 保持最新状态 📦"
    
    echo -e "${CYAN}正在更新软件包列表...${NC}"
    apt update
    
    echo -e "${CYAN}正在升级系统软件包...${NC}"
    apt upgrade -y
    
    echo -e "${CYAN}正在清理不需要的软件包...${NC}"
    apt autoremove -y
    
    log_success "系统更新完成！您的 PVE 现在是最新版本"
}

# 标准化暂停函数
pause_function() {
    echo -n "按任意键继续... "
    read -n 1 -s input
    if [[ -n ${input} ]]; then
        echo -e "\b
"
    fi
}



#--------------开启硬件直通----------------
# 开启硬件直通
enable_pass() {
    echo
    log_step "开启硬件直通..."
    if [ `dmesg | grep -e DMAR -e IOMMU|wc -l` = 0 ];then
        log_error "您的硬件不支持直通！不如检查一下主板的BIOS设置？"
        pause_function
        return
    fi
    if [ `cat /proc/cpuinfo|grep Intel|wc -l` = 0 ];then
        iommu="amd_iommu=on"
    else
        iommu="intel_iommu=on"
    fi
    if [ `grep $iommu /etc/default/grub|wc -l` = 0 ];then
        backup_file "/etc/default/grub"
        sed -i 's|quiet|quiet '$iommu'|' /etc/default/grub
        update-grub
        if [ `grep "vfio" /etc/modules|wc -l` = 0 ];then
            cat <<-EOF >> /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
kvmgt
EOF
        fi
        
        # 使用安全的配置块管理
        blacklist_content="blacklist snd_hda_intel
blacklist snd_hda_codec_hdmi
blacklist i915"
        apply_block "/etc/modprobe.d/blacklist.conf" "HARDWARE_PASSTHROUGH" "$blacklist_content"

        # 使用安全的配置块管理
        vfio_content="options vfio-pci ids=8086:3185"
        apply_block "/etc/modprobe.d/vfio.conf" "HARDWARE_PASSTHROUGH" "$vfio_content"
        
        log_success "开启设置后需要重启系统，请准备就绪后重启宿主机"
        log_tips "重启后才可以应用对内核引导的修改哦！命令是 reboot"
    else
        log_warn "您已经配置过!"
    fi
}

# 关闭硬件直通
disable_pass() {
    echo
    log_step "关闭硬件直通..."
    if [ `dmesg | grep -e DMAR -e IOMMU|wc -l` = 0 ];then
        log_error "您的硬件不支持直通！"
        log_tips "不如检查一下主板的BIOS设置？"
        pause_function
        return
    fi
    if [ `cat /proc/cpuinfo|grep Intel|wc -l` = 0 ];then
        iommu="amd_iommu=on"
    else
        iommu="intel_iommu=on"
    fi
    if [ `grep $iommu /etc/default/grub|wc -l` = 0 ];then
        log_warn "您还没有配置过该项"
    else
        backup_file "/etc/default/grub"
        {
            sed -i 's/ '$iommu'//g' /etc/default/grub
            sed -i '/vfio/d' /etc/modules
            # 使用安全的配置块删除，而不是直接删除整个文件
            remove_block "/etc/modprobe.d/blacklist.conf" "HARDWARE_PASSTHROUGH"
            remove_block "/etc/modprobe.d/vfio.conf" "HARDWARE_PASSTHROUGH"
            sleep 1
        }
        log_success "关闭设置后需要重启系统，请准备就绪后重启宿主机。"
        log_tips "重启后才可以应用对内核引导的修改哦！命令是 reboot"
        sleep 1
        update-grub
    fi
}

# 硬件直通菜单
hw_passth() {
    while :; do
        clear
        show_menu_header "配置硬件直通"
        show_menu_option "1" "开启硬件直通"
        show_menu_option "2" "关闭硬件直通"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择: [ ]" -n 1 hwmenuid
        echo  # New line after input
        hwmenuid=${hwmenuid:-0}
        case "${hwmenuid}" in
            1)
                enable_pass
                pause_function
                ;;
            2)
                disable_pass
                pause_function
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选项!"
                pause_function
                ;;
        esac
    done
}
#--------------磁盘/控制器直通----------------

# 磁盘/控制器直通总菜单
menu_disk_controller_passthrough() {
    while true; do
        clear
        show_menu_header "磁盘/控制器直通"
        show_menu_option "1" "RDM（裸磁盘映射）- 单个磁盘直通"
        show_menu_option "2" "RDM 取消直通（--delete）"
        show_menu_option "3" "磁盘控制器直通（PCIe）"
        show_menu_option "4" "NVMe 直通（含 MSI-X 重定位）"
        show_menu_option "5" "引导配置辅助（UEFI/Legacy）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-6]: " choice
        case "$choice" in
            1) rdm_single_disk_attach ;;
            2) rdm_single_disk_detach ;;
            3) storage_controller_passthrough ;;
            4) nvme_passthrough ;;
            5) boot_config_assistant ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# ============ RDM（裸磁盘映射）单盘直通 ============

# 获取 VM 配置文件路径（不保证一定存在，需调用方自行判断）
get_qm_conf_path() {
    local vmid="$1"
    echo "/etc/pve/qemu-server/${vmid}.conf"
}

# 校验 VMID 并确保 VM 存在
validate_qm_vmid() {
    local vmid="$1"
    if [[ -z "$vmid" || ! "$vmid" =~ ^[0-9]+$ ]]; then
        log_error "VMID 必须是数字"
        return 1
    fi
    if ! qm status "$vmid" >/dev/null 2>&1; then
        log_error "VMID 不存在或无法访问: $vmid"
        return 1
    fi
    return 0
}

# 将 /dev/disk/by-id 的链接解析为真实磁盘设备，并过滤不可直通设备
# 过滤规则：
# - 排除分区：by-id 名称包含 -partX 或目标设备为分区（lsblk TYPE=part）
# - 排除 DM/LVM：目标设备为 dm-* 或 /dev/mapper/*
# - 仅保留 TYPE=disk 的完整磁盘
rdm_discover_whole_disks() {
    local byid_dir="/dev/disk/by-id"
    if [[ ! -d "$byid_dir" ]]; then
        log_error "未找到目录: $byid_dir"
        return 1
    fi

    local -A best_id_for_dev=()
    local -A best_pri_for_dev=()
    local -A ata_id_for_dev=()

    local link
    while IFS= read -r -d '' link; do
        local base_name real_dev dev_name dev_type pri
        base_name="$(basename "$link")"

        if [[ "$base_name" =~ -part[0-9]+$ ]]; then
            continue
        fi

        real_dev="$(readlink -f "$link" 2>/dev/null)"
        if [[ -z "$real_dev" ]]; then
            continue
        fi

        if [[ "$real_dev" == /dev/mapper/* || "$(basename "$real_dev")" == dm-* ]]; then
            continue
        fi

        if [[ ! -b "$real_dev" ]]; then
            continue
        fi

        dev_type="$(lsblk -dn -o TYPE "$real_dev" 2>/dev/null | head -n 1)"
        if [[ "$dev_type" != "disk" ]]; then
            continue
        fi

        pri=50
        if [[ "$base_name" =~ ^wwn- ]]; then pri=10; fi
        if [[ "$base_name" =~ ^nvme-eui ]]; then pri=10; fi
        if [[ "$base_name" =~ ^nvme-uuid ]]; then pri=15; fi
        if [[ "$base_name" =~ ^ata- ]]; then pri=20; fi
        if [[ "$base_name" =~ ^scsi- ]]; then pri=30; fi
        if [[ "$base_name" =~ ^pci- ]]; then pri=40; fi

        if [[ "$base_name" =~ ^ata- ]] && [[ -z "${ata_id_for_dev[$real_dev]:-}" ]]; then
            ata_id_for_dev["$real_dev"]="$link"
        fi

        if [[ -z "${best_id_for_dev[$real_dev]:-}" || "$pri" -lt "${best_pri_for_dev[$real_dev]}" ]]; then
            best_id_for_dev["$real_dev"]="$link"
            best_pri_for_dev["$real_dev"]="$pri"
        fi
    done < <(find "$byid_dir" -maxdepth 1 -type l -print0 2>/dev/null)

    local dev
    for dev in "${!best_id_for_dev[@]}"; do
        local id_path size model ata_path
        id_path="${best_id_for_dev[$dev]}"
        ata_path="${ata_id_for_dev[$dev]:-}"
        size="$(lsblk -dn -o SIZE "$dev" 2>/dev/null | head -n 1)"
        model="$(lsblk -dn -o MODEL "$dev" 2>/dev/null | head -n 1)"
        printf '%s|%s|%s|%s|%s\n' "$id_path" "$dev" "${size:-?}" "${model:-?}" "$ata_path"
    done | sort -t'|' -k2,2
}

# 自动查找总线类型下可用插槽（sata 最多 6 个，ide 最多 4 个）
rdm_find_free_slot() {
    local vmid="$1"
    local bus="$2"

    local max_idx=0
    case "$bus" in
        sata) max_idx=5 ;;
        ide) max_idx=3 ;;
        scsi) max_idx=30 ;;
        *) log_error "不支持的总线类型: $bus"; return 1 ;;
    esac

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if [[ -z "$cfg" ]]; then
        log_error "无法读取 VM 配置: $vmid"
        return 1
    fi

    local i
    for ((i=0; i<=max_idx; i++)); do
        if ! echo "$cfg" | grep -qE "^${bus}${i}:"; then
            echo "${bus}${i}"
            return 0
        fi
    done

    log_error "无可用插槽: $bus (0-$max_idx)"
    return 1
}

# RDM 单盘直通（添加）
rdm_single_disk_attach() {
    log_step "RDM 单盘直通 - 磁盘发现"

    local disks
    disks="$(rdm_discover_whole_disks)"
    if [[ -z "$disks" ]]; then
        display_error "未发现可直通的完整磁盘" "请检查 /dev/disk/by-id 是否存在可用磁盘，或确认磁盘未被 DM/LVM 接管。"
        return 1
    fi

    echo -e "${CYAN}可直通磁盘列表（完整磁盘）：${NC}"
    echo "$disks" | awk -F'|' '{
        ata=$5;
        if (ata == "") ata="-";
        else {
            n=split(ata,a,"/");
            ata=a[n];
        }
        printf "  [%d] %-55s -> %-12s  %-8s  %-28s  ATA:%s\n", NR, $1, $2, $3, $4, ata
    }'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择磁盘序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "磁盘序号必须是数字"
        return 1
    fi

    local selected
    selected="$(echo "$disks" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$selected" ]]; then
        display_error "无效的磁盘序号: $pick"
        return 1
    fi

    local id_path real_dev
    id_path="$(echo "$selected" | awk -F'|' '{print $1}')"
    real_dev="$(echo "$selected" | awk -F'|' '{print $2}')"

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        pause_function
        return 1
    fi

    local bus
    read -p "请选择总线类型 (scsi/sata/ide) [scsi]: " bus
    bus="${bus:-scsi}"
    if [[ "$bus" != "scsi" && "$bus" != "sata" && "$bus" != "ide" ]]; then
        display_error "不支持的总线类型: $bus" "仅支持 scsi/sata/ide"
        return 1
    fi

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if echo "$cfg" | grep -Fq "$id_path" || echo "$cfg" | grep -Fq "$real_dev"; then
        display_error "该磁盘已在 VM 配置中存在直通记录" "请先执行取消直通，或选择其他磁盘。"
        return 1
    fi

    local slot
    slot="$(rdm_find_free_slot "$vmid" "$bus")" || return 1

    log_info "将直通磁盘: $id_path -> $real_dev"
    log_info "目标 VM: $vmid, 插槽: $slot"

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 添加直通磁盘（$slot = $id_path）"; then
        return 0
    fi

    if qm set "$vmid" "-$slot" "$id_path" >/dev/null 2>&1; then
        display_success "直通配置已写入" "如需引导此磁盘，请在 VM 启动顺序中选择该磁盘。"
        return 0
    else
        display_error "qm set 执行失败" "请检查磁盘是否被占用、VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi
}

# RDM 取消直通（--delete）
rdm_single_disk_detach() {
    log_step "RDM 取消直通（--delete）"

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if [[ -z "$cfg" ]]; then
        display_error "无法读取 VM 配置: $vmid"
        return 1
    fi

    local disks_lines
    disks_lines="$(echo "$cfg" | grep -E '^(scsi|sata|ide)[0-9]+:')"
    if [[ -z "$disks_lines" ]]; then
        display_error "该 VM 未发现任何磁盘插槽配置" "如果只是没有直通盘，可忽略此提示。"
        return 1
    fi

    echo -e "${CYAN}当前 VM 磁盘插槽：${NC}"
    echo "$disks_lines" | awk '{printf "  [%d] %s\n", NR, $0}'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择要删除的插槽序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "序号必须是数字"
        return 1
    fi

    local line slot
    line="$(echo "$disks_lines" | awk -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$line" ]]; then
        display_error "无效的序号: $pick"
        return 1
    fi
    slot="$(echo "$line" | cut -d':' -f1)"

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "从 VM $vmid 删除磁盘插槽（--delete $slot）"; then
        return 0
    fi

    if qm set "$vmid" --delete "$slot" >/dev/null 2>&1; then
        display_success "插槽已删除: $slot"
        return 0
    else
        display_error "qm set --delete 执行失败" "请检查 VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi
}

# ============ PCIe 控制器 / NVMe 直通 ============

# 检查 IOMMU 是否已开启（用于 PCIe 设备直通的前置条件）
iommu_is_enabled() {
    if [[ -d /sys/kernel/iommu_groups ]]; then
        local group_count
        group_count="$(find /sys/kernel/iommu_groups -maxdepth 1 -type d 2>/dev/null | wc -l)"
        if [[ "${group_count:-0}" -gt 1 ]]; then
            return 0
        fi
    fi

    if dmesg 2>/dev/null | grep -Eiq 'DMAR: IOMMU enabled|IOMMU enabled|AMD-Vi:.*enabled'; then
        return 0
    fi

    return 1
}

# 从 udev 路径中解析 PCI BDF（格式：0000:00:00.0）
parse_pci_bdf_from_udev_path() {
    local udev_path="$1"
    if [[ "$udev_path" =~ ([0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# 获取指定块设备所在的 PCI BDF（用于系统盘控制器保护、控制器磁盘映射）
get_blockdev_pci_bdf() {
    local dev_path="$1"
    if [[ -z "$dev_path" || ! -b "$dev_path" ]]; then
        return 1
    fi

    local udev_path
    udev_path="$(udevadm info --query=path --name="$dev_path" 2>/dev/null)"
    if [[ -n "$udev_path" ]]; then
        parse_pci_bdf_from_udev_path "$udev_path" && return 0
    fi

    return 1
}

# 获取 PVE 系统盘对应的“整盘设备名”列表（sda / nvme0n1 等）
get_system_whole_disks() {
    local -A disks=()
    local mount_src

    for mp in / /boot /boot/efi; do
        mount_src="$(findmnt -n -o SOURCE "$mp" 2>/dev/null || true)"
        if [[ -z "$mount_src" ]]; then
            continue
        fi

        if [[ "$mount_src" == /dev/mapper/* ]]; then
            if command -v pvs >/dev/null 2>&1; then
                while IFS= read -r pv; do
                    pv="$(echo "$pv" | awk '{$1=$1;print}')"
                    if [[ -n "$pv" && -b "$pv" ]]; then
                        local pk
                        pk="$(lsblk -dn -o PKNAME "$pv" 2>/dev/null | head -n 1)"
                        if [[ -n "$pk" ]]; then
                            disks["$pk"]=1
                        else
                            disks["$(basename "$pv")"]=1
                        fi
                    fi
                done < <(pvs --noheadings -o pv_name 2>/dev/null)
            fi
            continue
        fi

        if [[ -b "$mount_src" ]]; then
            local pk
            pk="$(lsblk -dn -o PKNAME "$mount_src" 2>/dev/null | head -n 1)"
            if [[ -n "$pk" ]]; then
                disks["$pk"]=1
            else
                disks["$(basename "$mount_src")"]=1
            fi
        fi
    done

    for d in "${!disks[@]}"; do
        echo "$d"
    done | sort
}

# 获取“必须保护”的 PCI BDF（包含系统盘的控制器）
get_protected_pci_bdfs() {
    local -A bdfs=()
    local disk
    while IFS= read -r disk; do
        local bdf
        bdf="$(get_blockdev_pci_bdf "/dev/$disk" 2>/dev/null || true)"
        if [[ -n "$bdf" ]]; then
            bdfs["$bdf"]=1
        fi
    done < <(get_system_whole_disks)

    for b in "${!bdfs[@]}"; do
        echo "$b"
    done | sort
}

# 列出系统内的 SATA/SCSI/RAID 控制器（用于整控制器直通）
list_storage_controllers() {
    lspci -Dnn 2>/dev/null | grep -Eiin 'SATA controller|RAID bus controller|SCSI storage controller|Serial Attached SCSI controller' | sed 's/^[0-9]\+://'
}

# 列出系统内的 NVMe 控制器（用于 NVMe 直通）
list_nvme_controllers() {
    lspci -Dnn 2>/dev/null | grep -Eiin 'Non-Volatile memory controller' | sed 's/^[0-9]\+://'
}

# 展示指定 PCI BDF 下的所有“整盘”设备（用于磁盘映射展示与保护提示）
show_disks_under_pci_bdf() {
    local bdf="$1"
    if [[ -z "$bdf" ]]; then
        return 1
    fi

    local found=0
    while IFS= read -r name; do
        local dev_bdf
        dev_bdf="$(get_blockdev_pci_bdf "/dev/$name" 2>/dev/null || true)"
        if [[ "$dev_bdf" == "$bdf" ]]; then
            local size model
            size="$(lsblk -dn -o SIZE "/dev/$name" 2>/dev/null | head -n 1)"
            model="$(lsblk -dn -o MODEL "/dev/$name" 2>/dev/null | head -n 1)"
            echo "  /dev/$name  ${size:-?}  ${model:-?}"
            found=1
        fi
    done < <(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')

    if [[ "$found" -eq 0 ]]; then
        echo "  （未能识别到该控制器下的磁盘，可能是映射方式不同或权限受限）"
    fi
    return 0
}

# 获取 VM 是否为 q35（决定 hostpci 是否添加 pcie=1）
qm_is_q35_machine() {
    local vmid="$1"
    local machine
    machine="$(qm config "$vmid" 2>/dev/null | awk -F': ' '/^machine:/{print $2}' | head -n 1)"
    if echo "$machine" | grep -q 'q35'; then
        return 0
    fi
    return 1
}

# 获取可用的 hostpci 插槽号（0-15）
qm_find_free_hostpci_index() {
    local vmid="$1"
    local cfg used
    cfg="$(qm config "$vmid" 2>/dev/null)"
    used="$(echo "$cfg" | awk -F'[: ]' '/^hostpci[0-9]+:/{gsub("hostpci","",$1); print $1}' | sort -n | uniq)"

    local i
    for ((i=0; i<=15; i++)); do
        if ! echo "$used" | grep -qx "$i"; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# 从 VM 配置中查找某个 BDF 是否已被直通
qm_has_hostpci_bdf() {
    local vmid="$1"
    local bdf="$2"
    qm config "$vmid" 2>/dev/null | grep -qE "^hostpci[0-9]+:.*\\b${bdf}\\b"
}

# 直通整个 SATA/SCSI/RAID 控制器到 VM（含系统盘控制器保护）
storage_controller_passthrough() {
    log_step "磁盘控制器直通 - 扫描控制器"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local controllers
    controllers="$(list_storage_controllers)"
    if [[ -z "$controllers" ]]; then
        display_error "未发现 SATA/SCSI/RAID 控制器" "可尝试手工执行 lspci -Dnn 确认控制器是否存在。"
        return 1
    fi

    echo -e "${CYAN}可用控制器列表：${NC}"
    echo "$controllers" | awk '{printf "  [%d] %s\n", NR, $0}'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择控制器序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$controllers" | awk -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$line" ]]; then
        display_error "无效的序号: $pick"
        return 1
    fi
    bdf="$(echo "$line" | awk '{print $1}')"

    echo -e "${CYAN}该控制器下识别到的整盘设备：${NC}"
    show_disks_under_pci_bdf "$bdf"
    echo -e "${UI_DIVIDER}"

    local protected
    protected="$(get_protected_pci_bdfs)"
    if echo "$protected" | grep -qx "$bdf"; then
        display_error "安全拦截：禁止直通系统盘所在控制器 $bdf" "请勿直通包含 PVE 系统盘的控制器，否则会导致宿主机不可用。"
        return 1
    fi

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi

    if qm_has_hostpci_bdf "$vmid" "$bdf"; then
        display_error "该控制器已在 VM 配置中存在直通记录" "无需重复直通。"
        return 1
    fi

    local idx
    idx="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15 后再试。"
        return 1
    }

    local hostpci_value="$bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci_value="${hostpci_value},pcie=1"
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 直通控制器（hostpci$idx = $hostpci_value）"; then
        return 0
    fi

    if qm set "$vmid" "-hostpci${idx}" "$hostpci_value" >/dev/null 2>&1; then
        local status
        status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}' | head -n 1)"
        display_success "控制器直通已写入 VM 配置" "当前 VM 状态: ${status:-unknown}（如在运行中，需重启 VM 后生效）"
        return 0
    else
        display_error "qm set 执行失败" "请检查 IOMMU/IOMMU group、VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi
}

# 判断 NVMe 设备是否建议启用 MSI-X 重定位（启发式：存在 MSI-X 且存在 BAR2/Region 2）
nvme_should_enable_msix_relocation() {
    local bdf="$1"
    local vv
    vv="$(lspci -vv -s "$bdf" 2>/dev/null || true)"
    if echo "$vv" | grep -q 'MSI-X:' && echo "$vv" | grep -qE 'Region 2: Memory|Region 2:.*Memory'; then
        return 0
    fi
    return 1
}

# 获取当前 VM args（不存在则返回空）
qm_get_args() {
    local vmid="$1"
    qm config "$vmid" 2>/dev/null | awk -F': ' '/^args:/{sub(/^args: /,""); print $0; exit}'
}

# 幂等追加 VM args 片段（通过 qm set -args 覆盖式写入，但内容基于现有 args 合并）
qm_append_args() {
    local vmid="$1"
    local token="$2"

    if [[ -z "$token" ]]; then
        return 1
    fi

    local current
    current="$(qm_get_args "$vmid")"
    if echo "$current" | grep -Fq "$token"; then
        return 0
    fi

    local new_args
    if [[ -z "$current" ]]; then
        new_args="$token"
    else
        new_args="${current} ${token}"
    fi

    qm set "$vmid" -args "$new_args" >/dev/null 2>&1
}

# NVMe 控制器直通到 VM（含系统盘控制器保护与 MSI-X 重定位 args）
nvme_passthrough() {
    log_step "NVMe 直通 - 扫描 NVMe 控制器"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local controllers
    controllers="$(list_nvme_controllers)"
    if [[ -z "$controllers" ]]; then
        display_error "未发现 NVMe 控制器" "可尝试手工执行 lspci -Dnn | grep -i NVMe 确认设备是否存在。"
        return 1
    fi

    echo -e "${CYAN}可用 NVMe 控制器列表：${NC}"
    echo "$controllers" | awk '{printf "  [%d] %s\n", NR, $0}'
    echo -e "${UI_DIVIDER}"

    local pick
    read -p "请选择 NVMe 控制器序号 (返回请输入 0): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 0
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        display_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$controllers" | awk -v n="$pick" 'NR==n{print $0}')"
    if [[ -z "$line" ]]; then
        display_error "无效的序号: $pick"
        return 1
    fi
    bdf="$(echo "$line" | awk '{print $1}')"

    echo -e "${CYAN}该 NVMe 控制器下识别到的整盘设备：${NC}"
    show_disks_under_pci_bdf "$bdf"
    echo -e "${UI_DIVIDER}"

    local protected
    protected="$(get_protected_pci_bdfs)"
    if echo "$protected" | grep -qx "$bdf"; then
        display_error "安全拦截：禁止直通系统盘所在 NVMe 控制器 $bdf" "请勿直通包含 PVE 系统盘的 NVMe 控制器，否则会导致宿主机不可用。"
        return 1
    fi

    local vmid
    read -p "请输入目标 VMID: " vmid
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi

    if qm_has_hostpci_bdf "$vmid" "$bdf"; then
        display_error "该 NVMe 已在 VM 配置中存在直通记录" "无需重复直通。"
        return 1
    fi

    local idx
    idx="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15 后再试。"
        return 1
    }

    local hostpci_value="$bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci_value="${hostpci_value},pcie=1"
    fi

    local enable_msix="no"
    if nvme_should_enable_msix_relocation "$bdf"; then
        echo -e "${YELLOW}检测到该 NVMe 可能需要 MSI-X 重定位（bar2）以提高兼容性。${NC}"
        local ans
        read -p "是否写入 MSI-X 重定位 args？(yes/no) [yes]: " ans
        ans="${ans:-yes}"
        if [[ "$ans" == "yes" || "$ans" == "YES" ]]; then
            enable_msix="yes"
        fi
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        log_tips "修改 VM 配置前建议备份原配置"
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 直通 NVMe（hostpci$idx = $hostpci_value），并写入 MSI-X 重定位参数（${enable_msix}）"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx}" "$hostpci_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 IOMMU/IOMMU group、VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$enable_msix" == "yes" ]]; then
        local token
        token="-set device.hostpci${idx}.x-msix-relocation=bar2"
        if qm_append_args "$vmid" "$token"; then
            log_success "已写入 args: $token"
        else
            log_warn "args 写入失败（已完成 hostpci 直通）"
        fi
    fi

    local status
    status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}' | head -n 1)"
    display_success "NVMe 直通已写入 VM 配置" "当前 VM 状态: ${status:-unknown}（如在运行中，需重启 VM 后生效）"
    return 0
}

# ============ 引导配置辅助 ============

# 解析用户输入的磁盘路径为真实整盘设备（返回 /dev/sdX 或 /dev/nvme0n1）
resolve_whole_disk() {
    local input="$1"
    if [[ -z "$input" ]]; then
        return 1
    fi

    local real
    if [[ "$input" == /dev/disk/by-id/* ]]; then
        real="$(readlink -f "$input" 2>/dev/null || true)"
    else
        real="$input"
    fi

    if [[ ! -b "$real" ]]; then
        return 1
    fi

    local t
    t="$(lsblk -dn -o TYPE "$real" 2>/dev/null | head -n 1)"
    if [[ "$t" == "disk" ]]; then
        echo "$real"
        return 0
    fi

    local pk
    pk="$(lsblk -dn -o PKNAME "$real" 2>/dev/null | head -n 1)"
    if [[ -n "$pk" && -b "/dev/$pk" ]]; then
        echo "/dev/$pk"
        return 0
    fi

    return 1
}

# 识别直通磁盘上的引导类型（UEFI / Legacy / Unknown）
detect_disk_boot_mode() {
    local disk="$1"
    if [[ -z "$disk" || ! -b "$disk" ]]; then
        echo "Unknown"
        return 1
    fi

    if command -v lsblk >/dev/null 2>&1; then
        local esp_guid="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
        local parts
        parts="$(lsblk -rno NAME,PARTTYPE,FSTYPE "$disk" 2>/dev/null | awk 'NF>=2{print}')"
        if echo "$parts" | grep -qi "$esp_guid"; then
            echo "UEFI"
            return 0
        fi
        if echo "$parts" | awk '{print $3}' | grep -qi '^vfat$'; then
            if echo "$parts" | grep -Eqi 'EFI|esp'; then
                echo "UEFI"
                return 0
            fi
        fi
    fi

    if command -v parted >/dev/null 2>&1; then
        local out
        out="$(parted -s "$disk" print 2>/dev/null || true)"
        if echo "$out" | grep -Eqi 'Partition Table:\s*gpt'; then
            if echo "$out" | grep -Eqi '\besp\b|EFI System|boot, esp'; then
                echo "UEFI"
                return 0
            fi
            echo "Unknown"
            return 0
        fi
        if echo "$out" | grep -Eqi 'Partition Table:\s*msdos'; then
            echo "Legacy"
            return 0
        fi
    fi

    echo "Unknown"
    return 0
}

# 根据磁盘引导类型与直通方式给出 VM 配置建议（仅提示，不修改配置）
boot_config_assistant() {
    log_step "引导配置辅助"

    local disk_input
    read -p "请输入直通磁盘路径（/dev/disk/by-id/... 或 /dev/sdX /dev/nvme0n1）（返回请输入 0）: " disk_input
    disk_input="${disk_input:-0}"
    if [[ "$disk_input" == "0" ]]; then
        return 0
    fi

    local disk
    disk="$(resolve_whole_disk "$disk_input" 2>/dev/null || true)"
    if [[ -z "$disk" ]]; then
        display_error "磁盘路径无效或不可访问: $disk_input" "请确认输入为块设备或 by-id 路径，并在宿主机上存在。"
        return 1
    fi

    local boot_mode
    boot_mode="$(detect_disk_boot_mode "$disk")"

    echo -e "${CYAN}检测结果：${NC}"
    echo "  磁盘: $disk"
    echo "  引导类型: $boot_mode"
    echo -e "${UI_DIVIDER}"

    echo -e "${CYAN}直通方式选择（用于生成更贴近场景的建议）：${NC}"
    echo "  1) 单个磁盘直通（RDM）"
    echo "  2) 整控制器直通（SATA/SCSI/RAID）"
    echo "  3) NVMe 控制器直通"
    local mode
    read -p "请选择直通方式 [1-3] [1]: " mode
    mode="${mode:-1}"
    if [[ "$mode" != "1" && "$mode" != "2" && "$mode" != "3" ]]; then
        display_error "无效选择: $mode" "请输入 1/2/3"
        return 1
    fi

    local slot=""
    if [[ "$mode" == "1" ]]; then
        read -p "如果已知 VM 插槽（如 scsi0/sata1/ide0）可输入用于 boot order（回车跳过）: " slot
        if [[ -n "$slot" && ! "$slot" =~ ^(scsi|sata|ide)[0-9]+$ ]]; then
            display_error "插槽格式不合法: $slot" "示例：scsi0 / sata0 / ide0"
            return 1
        fi
    fi

    echo -e "${UI_DIVIDER}"
    echo -e "${CYAN}配置建议（不自动修改）：${NC}"

    if [[ "$boot_mode" == "UEFI" ]]; then
        echo "  1) 固件建议：OVMF（UEFI）"
        echo "  2) 额外建议：添加 efidisk0 用于 NVRAM（PVE 界面可创建）"
        if [[ "$mode" != "1" ]]; then
            echo "  3) 机器类型建议：q35（PCIe 设备直通更友好）"
        fi
    elif [[ "$boot_mode" == "Legacy" ]]; then
        echo "  1) 固件建议：SeaBIOS（Legacy）"
    else
        echo "  1) 未能可靠判断 UEFI/Legacy：建议检查磁盘分区表与是否存在 ESP"
        echo "  2) 如果是 UEFI 系统：优先使用 OVMF + q35"
    fi

    if [[ "$mode" == "1" ]]; then
        echo "  4) 总线类型建议：优先 scsi；总线受限时使用 sata/ide"
        if [[ -n "$slot" ]]; then
            echo "  5) 启动顺序建议：boot: order=${slot};ide2;net0（按实际设备调整）"
        else
            echo "  5) 启动顺序建议：确保直通磁盘所在插槽在 boot order 中靠前"
        fi
    else
        echo "  4) 启动建议：控制器/NVMe 直通后，来宾系统会直接看到物理设备；建议使用 UEFI 启动管理器选择启动项"
    fi
    return 0
}

#--------------开启硬件直通----------------

#--------------设置CPU电源模式----------------
# 设置CPU电源模式
cpupower() {
    governors=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors`
    while :; do
        clear
        show_menu_header "设置CPU电源模式"
        echo "  1. 设置CPU模式 conservative  保守模式   [变身老年机]"
        echo "  2. 设置CPU模式 ondemand       按需模式  [默认]"
        echo "  3. 设置CPU模式 powersave      节能模式  [省电小能手]"
        echo "  4. 设置CPU模式 performance   性能模式   [性能释放]"
        echo "  5. 设置CPU模式 schedutil      负载模式  [交给负载自动配置]"
        echo
        echo "  6. 恢复系统默认电源设置"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回"
        show_menu_footer
        echo
        echo "部分CPU仅支持 performance 和 powersave 模式，只能选择这两项，其他模式无效不要选！"
        echo
        echo "你的CPU支持 ${governors} 模式"
        echo
        read -p "请选择: [ ]" -n 1 cpupowerid
        echo  # New line after input
        cpupowerid=${cpupowerid:-2}
        case "${cpupowerid}" in
            1)
                GOVERNOR="conservative"
                ;;
            2)
                GOVERNOR="ondemand"
                ;;
            3)
                GOVERNOR="powersave"
                ;;
            4)
                GOVERNOR="performance"
                ;;
            5)
                GOVERNOR="schedutil"
                ;;
            6)
                cpupower_del
                pause_function
                break
                ;;
            0)
                break
                ;;
            *)
                log_error "你的输入无效，请重新输入！"
                pause_function
                ;;
        esac
        if [[ ${GOVERNOR} != "" ]]; then
            if [[ -n `echo "${governors}" | grep -o "${GOVERNOR}"` ]]; then
                echo "您选择的CPU模式：${GOVERNOR}"
                echo
                cpupower_add
                pause_function
            else
                log_error "您的CPU不支持该模式！"
                log_tips "现在暂时不会对你的系统造成影响，但是下次开机时，CPU模式会恢复为默认模式。"
                pause_function
            fi
        fi
    done
}

# 修改CPU模式
cpupower_add() {
    echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
    echo "查看当前CPU模式"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

    echo "正在添加开机任务"
    NEW_CRONTAB_COMMAND="sleep 10 && echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null #CPU Power Mode"
    EXISTING_CRONTAB=$(crontab -l 2>/dev/null)
    if [[ -n "$EXISTING_CRONTAB" ]]; then
        TEMP_CRONTAB_FILE=$(mktemp)
        # 使用 -F 精确匹配标记，避免误删用户的其他任务
        echo "$EXISTING_CRONTAB" | grep -vF "#CPU Power Mode" > "$TEMP_CRONTAB_FILE"
        crontab "$TEMP_CRONTAB_FILE"
        rm "$TEMP_CRONTAB_FILE"
    fi
    log_success "CPU模式已修改完成"
    # 修改完成
    (crontab -l 2>/dev/null; echo "@reboot $NEW_CRONTAB_COMMAND") | crontab -
    echo -e "
检查计划任务设置 (使用 'crontab -l' 命令来检查)"
}

# 恢复系统默认电源设置
cpupower_del() {
    # 恢复性模式
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
    # 删除计划任务
    EXISTING_CRONTAB=$(crontab -l 2>/dev/null)
    if [[ -n "$EXISTING_CRONTAB" ]]; then
        TEMP_CRONTAB_FILE=$(mktemp)
        # 使用 -F 精确匹配标记，避免误删用户的其他任务
        echo "$EXISTING_CRONTAB" | grep -vF "#CPU Power Mode" > "$TEMP_CRONTAB_FILE"
        crontab "$TEMP_CRONTAB_FILE"
        rm "$TEMP_CRONTAB_FILE"
    fi

    log_success "已恢复系统默认电源设置！还是默认的好用吧"
}
#--------------设置CPU电源模式----------------

#--------------CPU、主板、硬盘温度显示----------------
# 安装工具
cpu_add() {
    nodes="/usr/share/perl5/PVE/API2/Nodes.pm"
    pvemanagerlib="/usr/share/pve-manager/js/pvemanagerlib.js"
    proxmoxlib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

    pvever=$(pveversion | awk -F"/" '{print $2}')
    echo pve版本$pvever

    # 判断是否已经执行过修改 (使用 modbyshowtempfreq 标记检测)
    if [ $(grep 'modbyshowtempfreq' $nodes $pvemanagerlib $proxmoxlib 2>/dev/null | wc -l) -eq 3 ]; then
        log_warn "已经修改过，请勿重复修改"
        log_tips "如果没有生效，请使用 Shift+F5 刷新浏览器缓存"
        log_tips "如果需要强制重新修改，请先执行还原操作"
        pause_function
        return
    fi

    # 先刷新下源
    log_step "更新软件包列表..."
    apt-get update

    log_step "开始安装所需工具..."
    # 安装温度监控基础软件包；UPS 依赖按需安装
    packages=(lm-sensors nvme-cli sysstat linux-cpupower hdparm smartmontools)

    # 查询软件包，判断是否安装
    for package in "${packages[@]}"; do
        if ! dpkg -s "$package" &> /dev/null; then
            log_info "$package 未安装，开始安装软件包"
            apt-get install "${packages[@]}" -y
            modprobe msr
            install=ok
            break
        fi
    done

    # 设置执行权限 (修正路径)
    [[ -e /usr/sbin/linux-cpupower ]] && chmod +s /usr/sbin/linux-cpupower
    chmod +s /usr/sbin/nvme
    chmod +s /usr/sbin/smartctl
    chmod +s /usr/sbin/turbostat || log_warn "无法设置 turbostat 权限"

    # 启用 MSR 模块
    modprobe msr && echo msr > /etc/modules-load.d/turbostat-msr.conf

    # 软件包安装完成
    if [ "$install" == "ok" ]; then
        log_success "软件包安装完成，检测硬件信息"
        sensors-detect --auto > /tmp/sensors
        drivers=$(sed -n '/Chip drivers/,/\#----cut here/p' /tmp/sensors | sed '/Chip /d' | sed '/cut/d')

        if [ $(echo $drivers | wc -w) = 0 ]; then
            log_warn "没有找到任何驱动，似乎你的系统不支持或驱动安装失败。"
            pause_function
        else
            for i in $drivers; do
                modprobe $i
                if [ $(grep $i /etc/modules | wc -l) = 0 ]; then
                    echo $i >> /etc/modules
                fi
            done
            sensors
            sleep 3
            log_success "驱动信息配置成功。"
        fi
        [[ -e /etc/init.d/kmod ]] && /etc/init.d/kmod start
        rm /tmp/sensors
    fi

    log_step "备份源文件"
    # 备份当前版本文件
    backup_file "$nodes"
    backup_file "$pvemanagerlib"
    backup_file "$proxmoxlib"

    local enable_ups=false
    local nut_ups_name=""
    local nut_ups_target=""

    log_info "是否启用 UPS 监控？"
    echo -n "（使用 NUT / upsc 采集，如果没有 UPS 设备或不想显示，请选择 N，默认N）(y/N): "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enable_ups=true
        read -r -p "请输入 NUT UPS 设备名 [默认: ups]: " nut_ups_name
        nut_ups_name=${nut_ups_name:-ups}
        if [[ ! "$nut_ups_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
            log_warn "UPS 设备名包含不支持字符，已回退为默认值 ups"
            nut_ups_name="ups"
        fi
        nut_ups_target="${nut_ups_name}@localhost"
        log_success "已选择启用 UPS 监控 (NUT: ${nut_ups_target})"

        if ! dpkg -s nut-client &> /dev/null; then
            log_info "nut-client 未安装，开始安装以提供 upsc 命令"
            apt-get install nut-client -y
        fi

        if command -v upsc >/dev/null 2>&1; then
            log_info "已检测到 upsc，UPS 数据将通过带超时保护的读取方式展示"
        else
            log_warn "未检测到 upsc，UPS 信息将显示为不可用"
        fi

        log_info "脚本不会自动启停 NUT 服务，请保持现有 NUT 配置不变"
    else
        enable_ups=false
        log_info "已选择跳过 UPS 监控"
        log_info "已跳过 UPS 展示，脚本不会改动系统当前的 NUT 服务状态"
    fi

    # 生成系统变量 (参考 PVE 8 脚本的改进实现)
    tmpf=tmpfile.temp
    touch $tmpf
    cat > $tmpf << 'EOF'

#modbyshowtempfreq

        $res->{thermalstate} = `sensors -A`;
        $res->{cpuFreq} = `
            goverf=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor
            maxf=/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq
            minf=/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_min_freq

            cat /proc/cpuinfo | grep -i "cpu mhz"
            echo -n 'gov:'
            [ -f \$goverf ] && cat \$goverf || echo none
            echo -n 'min:'
            [ -f \$minf ] && cat \$minf || echo none
            echo -n 'max:'
            [ -f \$maxf ] && cat \$maxf || echo none
            echo -n 'pkgwatt:'
            [ -e /usr/sbin/turbostat ] && turbostat --quiet --cpu package --show "PkgWatt" -S sleep 0.25 2>&1 | tail -n1
        `;
EOF

    if [ "$enable_ups" = true ]; then
        cat >> $tmpf << EOF
        \$res->{ups_status} = qx'
            UPS_TARGET="$nut_ups_target"
            if command -v upsc >/dev/null 2>&1; then
                if command -v timeout >/dev/null 2>&1; then
                    UPS_DATA=\$(timeout --signal=TERM 3s upsc "\$UPS_TARGET" 2>/dev/null)
                    UPS_EXIT=\$?
                    if [ "\$UPS_EXIT" -eq 0 ] && [ -n "\$UPS_DATA" ]; then
                        FILTERED_DATA=\$(printf "%s\n" "\$UPS_DATA" | grep -E "^(device\.model|ups\.status|battery\.charge|battery\.runtime|input\.voltage|output\.voltage|ups\.load|ups\.power\.nominal|ups\.realpower\.nominal|ups\.realpower|battery\.charge\.low|battery\.voltage|ups\.beeper\.status|ups\.delay\.shutdown|ups\.timer\.shutdown|ups\.delay\.start|ups\.timer\.start):" || true)
                        if [ -n "\$FILTERED_DATA" ]; then
                            printf "%s\n" "\$FILTERED_DATA"
                            echo "UPS_TARGET: \$UPS_TARGET"
                        else
                            echo "NUT_STATUS: NO_DATA"
                            echo "UPS_TARGET: \$UPS_TARGET"
                        fi
                    elif [ "\$UPS_EXIT" -eq 124 ] || [ "\$UPS_EXIT" -eq 137 ]; then
                        echo "NUT_STATUS: TIMEOUT"
                        echo "UPS_TARGET: \$UPS_TARGET"
                    elif [ "\$UPS_EXIT" -eq 0 ]; then
                        echo "NUT_STATUS: NO_DATA"
                        echo "UPS_TARGET: \$UPS_TARGET"
                    else
                        echo "NUT_STATUS: QUERY_FAILED"
                        echo "UPS_TARGET: \$UPS_TARGET"
                    fi
                else
                    echo "NUT_STATUS: TIMEOUT_MISSING"
                    echo "UPS_TARGET: \$UPS_TARGET"
                fi
            else
                echo "NUT_STATUS: UPSC_MISSING"
                echo "UPS_TARGET: \$UPS_TARGET"
            fi
        ';
EOF
    fi


    echo >> $tmpf

    # NVME 硬盘变量 (动态检测，参考 PVE 8 实现)
    log_info "检测系统中的 NVME 硬盘"
    nvi=0
    for nvme in $(ls /dev/nvme[0-9] 2> /dev/null); do
        chmod +s /usr/sbin/smartctl 2>/dev/null

        cat >> $tmpf << EOF

        \$res->{nvme$nvi} = \`smartctl $nvme -a -j\`;
EOF
        echo "检测到 NVME 硬盘: $nvme (nvme$nvi)"
        let nvi++
    done
    echo "已添加 $nvi 块 NVME 硬盘"

    # SATA 硬盘变量 (动态检测，参考 PVE 8 实现)
    log_info "检测系统中的 SATA 固态和机械硬盘"
    sdi=0
    for sd in $(ls /dev/sd[a-z] 2> /dev/null); do
        chmod +s /usr/sbin/smartctl 2>/dev/null
        chmod +s /usr/sbin/hdparm 2>/dev/null

        # 检测是否是真的硬盘
        sdsn=$(awk -F '/' '{print $NF}' <<< $sd)
        sdcr=/sys/block/$sdsn/queue/rotational
        [ -f $sdcr ] || continue

        if [ "$(cat $sdcr)" = "0" ]; then
            hddisk=false
            sdtype="固态硬盘"
        else
            hddisk=true
            sdtype="机械硬盘"
        fi

        # 硬盘输出信息逻辑，如果硬盘不存在就输出空 JSON
        cat >> $tmpf << EOF

        \$res->{sd$sdi} = \`
            if [ -b $sd ]; then
                # 增加 SAS 盘检测，SAS 盘不使用 hdparm 检测休眠，防止误报
                if $hddisk && ! smartctl -i $sd | grep -q "Transport protocol:.*SAS" && hdparm -C $sd 2>/dev/null | grep -iq 'standby'; then
                    echo '{"standy": true}'
                else
                    smartctl $sd -a -j
                fi
            else
                echo '{}'
            fi
        \`;
EOF
        echo "检测到 $sdtype: $sd (sd$sdi)"
        let sdi++
    done
    echo "已添加 $sdi 块 SATA 固态和机械硬盘"


    ###################  修改node.pm   ##########################
    log_info "修改node.pm："
    log_info "找到关键字 PVE::pvecfg::version_text 的行号并跳到下一行"

    # 显示匹配的行
    ln=$(expr $(sed -n -e '/PVE::pvecfg::version_text/=' $nodes) + 1)
    echo "匹配的行号：" $ln

    log_info "修改结果："
    sed -i "${ln}r $tmpf" $nodes
    # 显示修改结果
    sed -n '/PVE::pvecfg::version_text/,+18p' $nodes
    rm $tmpf

    ###################  修改pvemanagerlib.js   ##########################
    tmpf=tmpfile.temp
    touch $tmpf
    cat > $tmpf << 'EOF'

//modbyshowtempfreq
    {
          itemId: 'cpumhz',
          colspan: 2,
          printBar: false,
          title: gettext('CPU频率(GHz)'),
          textField: 'cpuFreq',
          renderer:function(v){
              console.log(v);

              // 解析所有核心频率
              let m = v.match(/(?<=^cpu[^\d]+)\d+/img);
              if (!m || m.length === 0) {
                  return '无法获取CPU频率信息';
              }

              let freqs = m.map(e => parseFloat((e / 1000).toFixed(1)));

              // 计算统计信息
              let avgFreq = (freqs.reduce((a, b) => a + b, 0) / freqs.length).toFixed(1);
              let minFreq = Math.min(...freqs).toFixed(1);
              let maxFreq = Math.max(...freqs).toFixed(1);
              let coreCount = freqs.length;

              // 获取系统配置的频率范围
              let sysMin = (v.match(/(?<=^min:).+/im)[0]);
              if (sysMin !== 'none') {
                  sysMin = (sysMin / 1000000).toFixed(1);
              }

              let sysMax = (v.match(/(?<=^max:).+/im)[0]);
              if (sysMax !== 'none') {
                  sysMax = (sysMax / 1000000).toFixed(1);
              }

              let gov = v.match(/(?<=^gov:).+/im)[0].toUpperCase();

              let watt = v.match(/(?<=^pkgwatt:)[\d.]+$/im);
              watt = watt ? " | 功耗: " + (watt[0]/1).toFixed(1) + 'W' : '';

              // 简洁显示：平均值 + 当前范围 + 系统范围 + 功耗 + 调速器
              return `${coreCount}核心 平均: ${avgFreq} GHz (当前: ${minFreq}~${maxFreq}) | 范围: ${sysMin}~${sysMax} GHz${watt} | 调速器: ${gov}`;
           }
    },

    {
          itemId: 'thermal',
          colspan: 2,
          printBar: false,
	          title: gettext('CPU温度'),
	          textField: 'thermalstate',
	          renderer:function(value){
	              function colorizeTemp(temp) {
	                  let tempNum = Number(temp);
	                  if (Number.isNaN(tempNum)) {
	                      return temp + '°C';
	                  }
	                  if (tempNum < 60) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + tempNum.toFixed(0) + '°C</span>';
	                  }
	                  if (tempNum < 80) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + tempNum.toFixed(0) + '°C</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + tempNum.toFixed(0) + '°C</span>';
	              }

	              console.log(value);
              let b = value.trim().split(/\s+(?=^\w+-)/m).sort();
              let cpuResults = [];
              let otherResults = [];

              const cpuSensorRegex = /(CORETEMP|K10TEMP|ZENPOWER|ZENPOWER3|K8TEMP|FAM15H|ZENPROBE)/i;
              const amdLabelRegex = /\bT(CTL|DIE|CCD|CCD\d+|Sx|LOOP)\b/i;

              b.forEach(function(v){
                  // 风扇转速数据
                  let fandata = v.match(/(?<=:\s+)[1-9]\d*(?=\s+RPM\s+)/ig);
                  if (fandata) {
                      otherResults.push('风扇: ' + fandata.join(', ') + ' RPM');
                      return;
                  }

                  let name = v.match(/^[^-]+/);
                  if (!name) return;
                  name = name[0].toUpperCase();

                  let temps = v.match(/(?<=:\s+)[+-][\d.]+(?=.?°C)/g);
                  if (!temps) return;

                  temps = temps.map(t => parseFloat(t));

                  // 只处理 CPU 温度（Intel coretemp 或 AMD 相关传感器）
                  const isCpuSensor = cpuSensorRegex.test(name) || amdLabelRegex.test(v);

	                  if (isCpuSensor) {
	                      let packageTemp = temps[0];

	                      if (temps.length > 1) {
	                          let coreTemps = temps.slice(1);
	                          let avgCore = coreTemps.reduce((a, b) => a + b, 0) / coreTemps.length;
	                          let maxCore = Math.max(...coreTemps);
	                          let minCore = Math.min(...coreTemps);

	                          cpuResults.push(`封装: ${colorizeTemp(packageTemp)} | 核心: 平均 ${colorizeTemp(avgCore)} (${colorizeTemp(minCore)}~${colorizeTemp(maxCore)})`);
	                      } else {
	                          cpuResults.push(`封装: ${colorizeTemp(packageTemp)}`);
	                      }

	                      // 添加临界温度
	                      let crit = v.match(/(?<=\bcrit\b[^+]+\+)\d+/);
	                      if (crit) {
	                          cpuResults[cpuResults.length - 1] += ` | 临界: ${colorizeTemp(crit[0])}`;
	                      }
	                  } else {
	                      // 非 CPU 温度（主板、NVME等）放到其他结果中
	                      let tempStr = `${name}: ${colorizeTemp(temps[0])}`;
	                      let crit = v.match(/(?<=\bcrit\b[^+]+\+)\d+/);
	                      if (crit) {
	                          tempStr += ` (临界: ${colorizeTemp(crit[0])})`;
	                      }
                      otherResults.push(tempStr);
                  }
              });

              // 只返回 CPU 相关温度，其他传感器信息不显示在这里
              // （NVME温度会在NVME硬盘信息中单独显示）
              if (cpuResults.length === 0) {
                  return '未获取到CPU温度信息';
              }

              // 如果有多个CPU（如双路服务器），分别显示
              if (cpuResults.length > 1) {
                  return cpuResults.map((temp, idx) => `CPU${idx}: ${temp}`).join(' | ');
              } else {
                  return cpuResults[0];
              }
           }
    },
EOF

    # 动态为每个 NVME 硬盘添加 JavaScript 代码
    for i in $(seq 0 $((nvi - 1))); do
        cat >> $tmpf << EOF

    {
          itemId: 'nvme${i}0',
          colspan: 2,
          printBar: false,
	          title: gettext('NVME${i}'),
	          textField: 'nvme${i}',
	          renderer:function(value){
	              function colorizeTemp(temp) {
	                  let tempNum = Number(temp);
	                  if (Number.isNaN(tempNum)) {
	                      return temp + '°C';
	                  }
	                  if (tempNum < 50) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  if (tempNum < 70) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + tempNum + '°C</span>';
	              }

	              function colorizeHealth(percent) {
	                  let healthNum = Number(percent);
	                  if (Number.isNaN(healthNum)) {
	                      return percent + '%';
	                  }
	                  if (healthNum >= 80) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + healthNum + '%</span>';
	                  }
	                  if (healthNum >= 50) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + healthNum + '%</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + healthNum + '%</span>';
	              }

	              try{
	                  let  v = JSON.parse(value);

                  // 检查是否为空 JSON（硬盘不存在或已直通）
                  if (Object.keys(v).length === 0) {
                      return '<span style="color: #888;">未检测到 NVME（可能已直通或移除）</span>';
                  }

                  // 检查型号
                  let model = v.model_name;
                  if (!model) {
                      return '<span style="color: #f39c12;">NVME 信息不完整（建议检查连接状态）</span>';
                  }

                  // 构建显示内容
                  let parts = [model];
                  let hasData = false;

	                  // 温度
	                  if (v.temperature?.current !== undefined) {
	                      parts.push('温度: ' + colorizeTemp(v.temperature.current));
	                      hasData = true;
	                  }

                  // 健康度和读写
                  let log = v.nvme_smart_health_information_log;
	                  if (log) {
	                      // 健康度
	                      if (log.percentage_used !== undefined) {
	                          let healthRemain = 100 - log.percentage_used;
	                          let health = '健康: ' + colorizeHealth(healthRemain);
	                          if (log.media_errors !== undefined && log.media_errors > 0) {
	                              health += ' <span style="color: #e74c3c;">(0E: ' + log.media_errors + ')</span>';
	                          }
	                          parts.push(health);
	                          hasData = true;
	                      }

	                      if (log.unsafe_shutdowns !== undefined) {
	                          let shutdownColor = Number(log.unsafe_shutdowns) > 0 ? '#e74c3c' : '#27ae60';
	                          parts.push('异常断电: <span style="color: ' + shutdownColor + '; font-weight: 600;">' + log.unsafe_shutdowns + '</span>');
	                          hasData = true;
	                      }

	                      // 读写
                      if (log.data_units_read && log.data_units_written) {
                          let read = (log.data_units_read / 1956882).toFixed(1);
                          let write = (log.data_units_written / 1956882).toFixed(1);
                          parts.push('读写: ' + read + 'T / ' + write + 'T');
                          hasData = true;
                      }
                  }

                  // 通电时间
                  if (v.power_on_time?.hours !== undefined) {
                      let pot = '通电: ' + v.power_on_time.hours + '时';
                      if (v.power_cycle_count) {
                          pot += ' (次: ' + v.power_cycle_count + ')';
                      }
                      parts.push(pot);
                      hasData = true;
                  }

                  // SMART 状态
                  if (v.smart_status?.passed !== undefined) {
                      parts.push('SMART: ' + (v.smart_status.passed ? '<span style="color: #27ae60;">正常</span>' : '<span style="color: #e74c3c;">警告!</span>'));
                      hasData = true;
                  }

                  // 如果只有型号，没有其他数据，说明可能是权限或驱动问题
                  if (!hasData) {
                      return model + ' <span style="color: #888;">| 无法获取详细信息（检查 smartctl 权限或驱动）</span>';
                  }

                  return parts.join(' | ');

              }catch(e){
                  return '<span style="color: #888;">无法解析 NVME 信息（可能使用控制器直通）</span>';
              };

           }
    },
EOF
    done

    # 动态为每个 SATA 硬盘添加 JavaScript 代码
    for i in $(seq 0 $((sdi - 1))); do
        # 获取硬盘类型（固态/机械）
        sd="/dev/sd$(echo {a..z} | cut -d' ' -f$((i+1)))"
        sdsn=$(basename $sd 2>/dev/null)
        sdcr=/sys/block/$sdsn/queue/rotational
        if [ -f $sdcr ] && [ "$(cat $sdcr)" = "0" ]; then
            sdtype="固态硬盘$i"
        else
            sdtype="机械硬盘$i"
        fi

        cat >> $tmpf << EOF

    {
          itemId: 'sd${i}0',
          colspan: 2,
          printBar: false,
	          title: gettext('${sdtype}'),
	          textField: 'sd${i}',
	          renderer:function(value){
	              function colorizeTemp(temp) {
	                  let tempNum = Number(temp);
	                  if (Number.isNaN(tempNum)) {
	                      return temp + '°C';
	                  }
	                  if (tempNum < 40) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  if (tempNum < 50) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + tempNum + '°C</span>';
	              }

	              function findAtaSmartRawValue(table, ids) {
	                  if (!Array.isArray(table)) {
	                      return null;
	                  }
	                  let found = table.find(item => ids.includes(item?.id));
	                  if (!found || !found.raw) {
	                      return null;
	                  }
	                  return found.raw.string ?? found.raw.value ?? null;
	              }

	              try{
	                  let  v = JSON.parse(value);
	                  console.log(v)

                  // 场景 1：硬盘休眠（节能模式）
                  if (v.standy === true) {
                      return '<span style="color: #27ae60;">硬盘休眠中（省电模式）</span>'
                  }

                  // 场景 2：空 JSON（硬盘不存在或已直通）
                  if (Object.keys(v).length === 0) {
                      return '<span style="color: #888;">未检测到硬盘（可能已直通或移除）</span>';
                  }

                  // 场景 3：检查型号
                  let model = v.model_name;
                  if (!model) {
                      return '<span style="color: #f39c12;">硬盘信息不完整（建议检查连接状态）</span>';
                  }

                  // 场景 4：构建正常显示内容
                  let parts = [model];

	                  // 温度
	                  if (v.temperature?.current !== undefined) {
	                      parts.push('温度: ' + colorizeTemp(v.temperature.current));
	                  }

                  // 通电时间
                  if (v.power_on_time?.hours !== undefined) {
                      let pot = '通电: ' + v.power_on_time.hours + '时';
                      if (v.power_cycle_count) {
                          pot += ',次: ' + v.power_cycle_count;
                      }
                      parts.push(pot);
                  }

	                  // SMART 状态
	                  if (v.smart_status?.passed !== undefined) {
	                      parts.push('SMART: ' + (v.smart_status.passed ? '<span style="color: #27ae60;">正常</span>' : '<span style="color: #e74c3c;">警告!</span>'));
	                  }

	                  let unsafeShutdowns = findAtaSmartRawValue(v.ata_smart_attributes?.table, [174, 192]);
	                  if (unsafeShutdowns !== null && unsafeShutdowns !== undefined && unsafeShutdowns !== '') {
	                      let shutdownCount = String(unsafeShutdowns).trim();
	                      let shutdownColor = Number(shutdownCount) > 0 ? '#e74c3c' : '#27ae60';
	                      parts.push('异常断电: <span style="color: ' + shutdownColor + '; font-weight: 600;">' + shutdownCount + '</span>');
	                  }

                  return parts.join(' | ');

              }catch(e){
                  // JSON 解析失败
                  return '<span style="color: #888;">无法获取硬盘信息（可能使用 HBA 直通）</span>';
              };
           }
    },
EOF
    done

    if [ "$enable_ups" = true ]; then
        cat >> $tmpf << 'EOF'

    {
        itemId: 'ups-status',
        colspan: 2,
        printBar: false,
        title: gettext('UPS 信息'),
        textField: 'ups_status',
        cellWrap: true,
        renderer: function(value) {
            if (!value || value.length === 0) {
                return '提示: 未检测到 UPS 或 NUT 未返回数据';
            }

            try {
                const getValue = (key) => {
                    const match = value.match(new RegExp(`^${key}\\s*:\\s*(.+)$`, 'm'));
                    return match ? match[1].trim() : '';
                };

                const target = getValue('UPS_TARGET');
                const model = getValue('device\\.model') || '未知型号';
                const statusRaw = getValue('ups\\.status');
                const charge = getValue('battery\\.charge') || '-';
                const runtimeRaw = getValue('battery\\.runtime');
                const inputVoltage = getValue('input\\.voltage');
                const outputVoltage = getValue('output\\.voltage');
                const loadRaw = getValue('ups\\.load');
                const nominalPowerRaw = getValue('ups\\.realpower\\.nominal') || getValue('ups\\.power\\.nominal');
                const realPowerRaw = getValue('ups\\.realpower');
                const batteryVoltage = getValue('battery\\.voltage');
                const beeper = getValue('ups\\.beeper\\.status');
                const delayShutdown = getValue('ups\\.delay\\.shutdown');
                const timerShutdown = getValue('ups\\.timer\\.shutdown');
                const delayStart = getValue('ups\\.delay\\.start');
                const timerStart = getValue('ups\\.timer\\.start');
                const noData = getValue('NUT_STATUS');

                if (noData === 'UPSC_MISSING') {
                    return `提示: 系统未安装 upsc，无法读取 ${target || 'UPS'} 的信息`;
                }
                if (noData === 'TIMEOUT_MISSING') {
                    return `提示: 系统未检测到 timeout，为避免阻塞 Web UI，已跳过 ${target || 'UPS'} 的读取`;
                }
                if (noData === 'TIMEOUT') {
                    return `提示: 读取 ${target || 'UPS'} 超时，已自动跳过以保护 Web UI`;
                }
                if (noData === 'NO_DATA') {
                    return `提示: 未从 ${target || 'UPS'} 获取到 NUT 数据`;
                }
                if (noData === 'QUERY_FAILED') {
                    return `提示: ${target || 'UPS'} 查询失败，请检查 NUT 配置或设备名`;
                }

                const statusTokens = statusRaw ? statusRaw.split(/\s+/).filter(Boolean) : [];
                const statusTexts = [];
                if (statusTokens.includes('OL')) statusTexts.push('在线');
                if (statusTokens.includes('OB')) statusTexts.push('电池供电');
                if (statusTokens.includes('CHRG')) statusTexts.push('充电中');
                if (statusTokens.includes('DISCHRG')) statusTexts.push('放电中');
                if (statusTokens.includes('LB')) statusTexts.push('低电量');
                if (statusTexts.length === 0) statusTexts.push(statusRaw || '未知状态');

                const runtimeSeconds = Number.parseFloat(runtimeRaw);
                const runtimeText = Number.isFinite(runtimeSeconds)
                    ? `${Math.round(runtimeSeconds)} 秒`
                    : '-';

                const loadPct = Number.parseFloat(loadRaw);
                const nominalPower = Number.parseFloat(nominalPowerRaw);
                const realPower = Number.parseFloat(realPowerRaw);

                let powerText = '-';
                if (Number.isFinite(realPower) && realPower > 0) {
                    powerText = `${realPower.toFixed(0)} W`;
                } else if (Number.isFinite(nominalPower) && Number.isFinite(loadPct)) {
                    powerText = `${(nominalPower * loadPct / 100).toFixed(0)} W`;
                }

                const nominalPowerText = Number.isFinite(nominalPower) && nominalPower > 0
                    ? `${nominalPower.toFixed(0)} W`
                    : '-';

                const voltageParts = [];
                if (inputVoltage) voltageParts.push(`输入电压: ${inputVoltage} V`);
                if (outputVoltage) voltageParts.push(`输出电压: ${outputVoltage} V`);
                if (batteryVoltage) voltageParts.push(`电池电压: ${batteryVoltage} V`);

                const extraParts = [];
                if (beeper) extraParts.push(`蜂鸣器: ${beeper}`);
                if (delayShutdown) extraParts.push(`延迟关机: ${delayShutdown} 秒`);
                if (timerShutdown) extraParts.push(`关机计时: ${timerShutdown} 秒`);
                if (delayStart) extraParts.push(`延迟启动: ${delayStart} 秒`);
                if (timerStart) extraParts.push(`启动计时: ${timerStart} 秒`);

                return `${model}${target ? ` (${target})` : ''} | 状态: ${statusTexts.join(' / ')}<br>
                        电量: ${charge} % | 剩余时间: ${runtimeText} | 负载: ${loadRaw || '-'} %<br>
                        ${voltageParts.length > 0 ? voltageParts.join(' | ') : '电压: -'}<br>
                        额定功率: ${nominalPowerText} | 当前功率: ${powerText}${extraParts.length > 0 ? `<br>${extraParts.join(' | ')}` : ''}`;
            } catch(e) {
                return 'UPS 信息解析失败: ' + value;
            }
        }
    },
EOF
    fi

    log_info "找到关键字pveversion的行号"
    # 显示匹配的行
    ln=$(sed -n '/pveversion/,+10{/},/{=;q}}' $pvemanagerlib)
    echo "匹配的行号pveversion：" $ln

    log_info "修改结果："
    sed -i "${ln}r $tmpf" $pvemanagerlib
    # 显示修改结果
    # sed -n '/pveversion/,+30p' $pvemanagerlib

    log_info "修改页面高度"
    # 统计添加了几条内容（2个基础项 + NVME + SATA + UPS）
    if [ "$enable_ups" = true ]; then
        addRs=$((2 + nvi + sdi + 1))
        ups_info="+ 1 个UPS"
    else
        addRs=$((2 + nvi + sdi))
        ups_info=""
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "检测到添加了 $addRs 条监控项 (2个基础项 + $nvi 个NVME + $sdi 个SATA $ups_info)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "请选择高度调整方式："
    echo "  1. 自动计算 (推荐，参考 PVE 8 算法：28px/项)"
    echo "  2. 手动设置 (自定义每项的高度增量)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "请输入选项 [1-2] (直接回车使用自动计算): " height_choice

    case ${height_choice:-1} in
        1)
            # 自动计算：每项 28px
            addHei=$((28 * addRs))
            log_info "使用自动计算：$addRs 项 × 28px = ${addHei}px"
            ;;
        2)
            # 手动设置
            echo
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "手动设置说明："
            echo "  - 推荐值范围: 20-40 (默认 28)"
            echo "  - 如果 CPU 核心很多或想显示更多信息，可适当增大"
            echo "  - 如果界面出现遮挡，可适当减小此值"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -p "请输入每项的高度增量 (px) [默认: 28]: " height_per_item

            # 验证输入是否为数字，如果不是或为空则使用默认值 28
            if [[ -z "$height_per_item" ]] || ! [[ "$height_per_item" =~ ^[0-9]+$ ]]; then
                height_per_item=28
                log_info "使用默认值: 28px/项"
            else
                log_info "使用自定义值: ${height_per_item}px/项"
            fi

            addHei=$((height_per_item * addRs))
            log_success "计算结果：$addRs 项 × ${height_per_item}px = ${addHei}px"
            ;;
        *)
            # 无效选项，使用自动计算
            addHei=$((28 * addRs))
            log_warn "无效选项，使用自动计算：${addHei}px"
            ;;
    esac

    rm $tmpf

    # 修改左栏高度（原高度 300）
    log_step "修改左栏高度"
    wph=$(sed -n -E "/widget\.pveNodeStatus/,+4{/height:/{s/[^0-9]*([0-9]+).*/\1/p;q}}" $pvemanagerlib)
    if [ -n "$wph" ]; then
        sed -i -E "/widget\.pveNodeStatus/,+4{/height:/{s#[0-9]+#$((wph + addHei))#}}" $pvemanagerlib
        echo "左栏高度: $wph → $((wph + addHei))" >> /var/log/pve-tools.log
    else
        log_warn "找不到左栏高度修改点"
    fi

    log_info "跳过强制修改右栏 minHeight，避免磁盘较多时图表区域被异常拉高"

    # 调整显示布局
    ln=$(expr $(sed -n -e '/widget.pveDcGuests/=' $pvemanagerlib) + 10)
    sed -i "${ln}a\ textAlign: 'right'," $pvemanagerlib
    ln=$(expr $(sed -n -e '/widget.pveNodeStatus/=' $pvemanagerlib) + 10)
    sed -i "${ln}a\ textAlign: 'right'," $pvemanagerlib

    ###################  修改proxmoxlib.js   ##########################

    log_info "加强去除订阅弹窗"
    # 调用 remove_subscription_popup 函数，避免重复代码
    remove_subscription_popup

    # 显示修改结果
    # sed -n '/\/nodes\/localhost\/subscription/,+10p' $proxmoxlib >> /var/log/pve-tools.log
    systemctl restart pveproxy

    log_success "请刷新浏览器缓存shift+f5"
}

cpu_del() {
    local nodes="/usr/share/perl5/PVE/API2/Nodes.pm"
    local pvemanagerlib="/usr/share/pve-manager/js/pvemanagerlib.js"
    local proxmoxlib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
    local pvever

    pvever=$(pveversion | awk -F"/" '{print $2}')
    log_step "Restore official node overview files"
    log_warn "This will remove the temperature patch and reinstall official pve-manager / proxmox-widget-toolkit files"

    if ! confirm_action "Restore official node overview files?"; then
        return
    fi

    if reinstall_pve_webui_packages; then
        rm -f "$nodes.$pvever.bak" "$pvemanagerlib.$pvever.bak" "$proxmoxlib.$pvever.bak"
        log_success "Official node overview files restored. Use Shift+F5 to refresh browser cache."
    fi
}
#--------------CPU、主板、硬盘温度显示----------------

#--------------GRUB 配置管理工具----------------
# 展示当前 GRUB 配置
show_grub_config() {
    log_info "当前 GRUB 配置信息"
    echo "$UI_DIVIDER"

    if [ ! -f "/etc/default/grub" ]; then
        log_error "未找到 /etc/default/grub 文件"
        return 1
    fi

    log_info "文件路径: ${CYAN}/etc/default/grub${NC}"
    log_info "当前内核参数:"

    # 读取并显示 GRUB_CMDLINE_LINUX_DEFAULT
    current_config=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | sed 's/GRUB_CMDLINE_LINUX_DEFAULT=//' | tr -d '"')

    if [ -z "$current_config" ]; then
        log_warn "未找到 GRUB_CMDLINE_LINUX_DEFAULT 配置"
    else
        log_success "GRUB_CMDLINE_LINUX_DEFAULT 内容:"
        # 逐行显示参数
        echo "$current_config" | tr ' ' '\n' | while read -r param; do
            [ -n "$param" ] && echo -e "  ${BLUE}•${NC} $param"
        done
    fi

    echo "$UI_DIVIDER"

    # 检测关键参数
    log_info "关键参数检测:"

    # 检测 IOMMU
    if echo "$current_config" | grep -q "intel_iommu=on\|amd_iommu=on"; then
        echo -e "  ${GREEN}[ OK ]${NC} IOMMU: 已启用"
    else
        echo -e "  ${YELLOW}[WARN]${NC} IOMMU: 未启用"
    fi

    # 检测 SR-IOV
    if echo "$current_config" | grep -q "i915.enable_guc=3"; then
        echo -e "  ${GREEN}[ OK ]${NC} SR-IOV: 已配置"
    else
        echo -e "  ${BLUE}[INFO]${NC} SR-IOV: 未配置"
    fi

    # 检测 GVT-g
    if echo "$current_config" | grep -q "i915.enable_gvt=1"; then
        echo -e "  ${GREEN}[ OK ]${NC} GVT-g: 已配置"
    else
        echo -e "  ${BLUE}[INFO]${NC} GVT-g: 未配置"
    fi

    # 检测硬件直通
    if echo "$current_config" | grep -q "iommu=pt"; then
        echo -e "  ${GREEN}[ OK ]${NC} 硬件直通: 已启用"
    else
        echo -e "  ${BLUE}[INFO]${NC} 硬件直通: 未启用"
    fi

    echo "$UI_DIVIDER"
}

# GRUB 配置备份
backup_grub_with_note() {
    local note="$1"
    local backup_dir="/etc/pvetools9/backup/grub"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/${timestamp}_${note}.bak"

    log_step "备份 GRUB 配置..."

    # 创建备份目录
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir" || {
            log_error "无法创建备份目录: $backup_dir"
            return 1
        }
        log_info "创建备份目录: $backup_dir"
    fi

    # 检查源文件
    if [ ! -f "/etc/default/grub" ]; then
        log_error "源文件不存在: /etc/default/grub"
        return 1
    fi

    # 执行备份
    cp "/etc/default/grub" "$backup_file" || {
        log_error "备份失败"
        return 1
    }

    log_success "GRUB 配置已备份"
    log_info "备份文件: $backup_file"
    log_info "备份时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "备份备注: $note"

    # 统计备份文件数量
    local backup_count=$(ls -1 "$backup_dir"/*.bak 2>/dev/null | wc -l)
    log_info "当前共有 $backup_count 个备份文件"

    return 0
}

# 列出所有 GRUB 备份
list_grub_backups() {
    local backup_dir="/etc/pvetools9/backup/grub"

    log_info "GRUB 配置备份列表"
    log_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -d "$backup_dir" ]; then
        log_warn "备份目录不存在: $backup_dir"
        log_tips "尚未创建任何备份"
        return 0
    fi

    local backup_files=$(ls -1t "$backup_dir"/*.bak 2>/dev/null)

    if [ -z "$backup_files" ]; then
        log_warn "未找到任何备份文件"
        return 0
    fi

    local count=1
    echo "$backup_files" | while read -r backup_file; do
        local filename=$(basename "$backup_file")
        local filesize=$(du -h "$backup_file" | awk '{print $1}')
        local filetime=$(stat -c '%y' "$backup_file" 2>/dev/null || stat -f '%Sm' "$backup_file")

        log_info "备份 $count:"
        log_info "  文件名: $filename"
        log_info "  大小: $filesize"
        log_info "  时间: $filetime"
        log_step "  ────────────────────────────────────"

        count=$((count + 1))
    done

    log_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 恢复 GRUB 备份
restore_grub_backup() {
    local backup_dir="/etc/pvetools9/backup/grub"

    list_grub_backups

    if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir"/*.bak 2>/dev/null)" ]; then
        log_error "没有可恢复的备份文件"
        pause_function
        return 1
    fi

    echo
    log_warn "请输入要恢复的备份文件名（完整文件名）:"
    read -p "> " backup_filename

    local backup_file="${backup_dir}/${backup_filename}"

    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_filename"
        pause_function
        return 1
    fi

    log_warn "即将恢复 GRUB 配置"
    log_info "源文件: $backup_file"
    log_info "目标文件: /etc/default/grub"

    if ! confirm_action "确认恢复此备份"; then
        log_info "用户取消恢复操作"
        return 0
    fi

    # 在恢复前备份当前配置
    backup_grub_with_note "恢复前自动备份"

    # 执行恢复
    cp "$backup_file" "/etc/default/grub" || {
        log_error "恢复失败"
        pause_function
        return 1
    }

    log_success "GRUB 配置已恢复"

    # 更新 GRUB
    if confirm_action "是否立即更新 GRUB"; then
        update-grub && log_success "GRUB 更新完成" || log_error "GRUB 更新失败"
    fi

    pause_function
}
#--------------GRUB 配置管理工具----------------

#--------------核显虚拟化管理----------------
# 核显管理菜单
# 简化版核显虚拟化菜单（保留用于兼容性）
igpu_management_menu_simple() {
    while true; do
        clear
        show_menu_header "Intel 核显虚拟化管理"
        show_menu_option "1" "Intel 11-15代 SR-IOV 配置 (DKMS)"
        show_menu_option "2" "Intel 6-10代 GVT-g 配置 (传统模式)"
        show_menu_option "3" "验证核显虚拟化状态"
        show_menu_option "4" "清理核显虚拟化配置 (恢复默认)"
        show_menu_option "0" "返回主菜单"
        show_menu_footer

        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1) igpu_sriov_setup ;;
            2) igpu_gvtg_setup ;;
            3) igpu_verify ;;
            4) restore_igpu_config ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# Intel 11-15代 SR-IOV 核显虚拟化配置
igpu_sriov_setup() {
    echo -e "${H2}开始配置 Intel 11-15代 SR-IOV 核显虚拟化${NC}"
    echo -e "详细原理与教程： ${CYAN}https://pve.oowo.cc/advanced/gpu-virtualization${NC}"
    echo -e "如果配置失败，请访问文档站下方留言反馈。"
    echo

    # 检查内核版本
    kernel_version=$(uname -r | awk -F'-' '{print $1}')
    kernel_major=$(echo $kernel_version | cut -d'.' -f1)
    kernel_minor=$(echo $kernel_version | cut -d'.' -f2)

    if [ "$kernel_major" -lt 6 ] || ([ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -lt 8 ]); then
        echo -e "${RED}SR-IOV 需要内核版本 6.8 或更高${NC}"
        echo -e "  ${YELLOW}提示:${NC} 当前内核版本: $(uname -r)"
        echo -e "  ${YELLOW}提示:${NC} 请先使用内核管理功能升级到 6.8 内核"
        pause_function
        return 1
    fi

    echo -e "${GREEN}✓ 内核版本检查通过: $(uname -r)${NC}"

    # 展示当前 GRUB 配置
    echo
    show_grub_config
    echo

    # 危险性警告
    echo "$UI_BORDER"
    echo -e "  ${RED}【高危操作警告】${NC} SR-IOV 核显虚拟化配置"
    echo "$UI_BORDER"
    echo -e "  此操作属于${RED}【高危险性】${NC}系统配置，配置错误可能导致："
    echo -e "    - ${YELLOW}系统无法正常启动${NC}（GRUB 配置错误）"
    echo -e "    - ${YELLOW}核显完全不可用${NC}（参数配置错误）"
    echo -e "    - ${YELLOW}虚拟机黑屏或无法启动${NC}（直通配置错误）"
    echo -e "    - ${YELLOW}需要通过恢复模式修复系统${NC}"
    echo "$UI_BORDER"
    echo -e "  此功能将修改以下系统配置："
    echo -e "    1. 修改 ${CYAN}GRUB 引导参数${NC}（启用 IOMMU 和 SR-IOV）"
    echo -e "    2. 加载 ${CYAN}VFIO${NC} 内核模块"
    echo -e "    3. 下载并安装 ${CYAN}i915-sriov-dkms${NC} 驱动（约 10MB）"
    echo -e "    4. 配置虚拟核显数量（VFs）"
    echo
    echo -e "  ${GREEN}前置要求（请确认已完成）：${NC}"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}VT-d${NC} 虚拟化"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}SR-IOV${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}Above 4GB${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已关闭 ${CYAN}Secure Boot${NC} 安全启动"
    echo -e "    ${GREEN}✓${NC} CPU 为 ${CYAN}Intel 11-15 代${NC} 处理器"
    echo -e "  ${RED}重要：${NC}物理核显 (00:02.0) 不能直通，否则所有虚拟核显将消失"
    echo "$UI_BORDER"
    echo
    echo -e "${YELLOW}强烈建议：${NC}"
    echo -e "  ${CYAN}提示 1:${NC} 在继续前先备份当前 GRUB 配置"
    echo -e "  ${CYAN}提示 2:${NC} 确保了解核显虚拟化的工作原理"
    echo -e "  ${CYAN}提示 3:${NC} 准备好通过 SSH 或物理访问恢复系统"
    echo

    # 询问是否要备份
    if confirm_action "是否先备份当前 GRUB 配置（强烈推荐）"; then
        echo
        echo "请输入备份备注（例如：SR-IOV配置前备份）："
        read -p "> " backup_note
        backup_note=${backup_note:-"SR-IOV配置前备份"}
        backup_grub_with_note "$backup_note"
        echo
    fi

    if ! confirm_action "确认继续配置 SR-IOV 核显虚拟化"; then
        echo "用户取消操作"
        return 0
    fi

    # 安装必要的软件包
    echo "安装必要的软件包..."
    apt-get update

    echo "安装 pve-headers..."
    apt-get install -y "pve-headers-$(uname -r)" || {
        echo -e "${RED}安装 pve-headers 失败${NC}"
        pause_function
        return 1
    }

    echo "安装构建工具..."
    apt-get install -y build-essential dkms sysfsutils || {
        echo -e "安装构建工具失败"
        pause_function
        return 1
    }

    echo -e "✓ 软件包安装完成"

    # 备份并修改 GRUB 配置
    echo "配置 GRUB 引导参数..."
    backup_file "/etc/default/grub"

    # 使用幂等的 GRUB 参数管理函数
    echo "配置 GRUB 参数..."

    # 移除旧的 GVT-g 配置（如果有）
    grub_remove_param "i915.enable_gvt"
    grub_remove_param "pcie_acs_override"

    # 添加 SR-IOV 参数（幂等操作，不会重复添加）
    # 针对 6.8+ 内核，必须屏蔽 xe 驱动以防止冲突
    # 参考: https://github.com/strongtz/i915-sriov-dkms
    grub_add_param "intel_iommu=on"
    grub_add_param "iommu=pt"
    grub_add_param "i915.enable_guc=3"
    grub_add_param "i915.max_vfs=7"
    grub_add_param "module_blacklist=xe"

    echo -e "✓ GRUB 配置已更新 (已添加 module_blacklist=xe 以兼容 PVE 9.1)"

    # 更新 GRUB
    echo "更新 GRUB..."
    update-grub || {
        echo -e "更新 GRUB 失败"
        pause_function
        return 1
    }

    # 配置内核模块
    echo "配置内核模块..."
    backup_file "/etc/modules"

    # 清理可能存在的 i915 及音视频相关黑名单 (SR-IOV 需要 i915 驱动加载)
    echo "清理可能存在的 i915 及音视频相关黑名单..."
    for f in /etc/modprobe.d/blacklist.conf /etc/modprobe.d/pve-blacklist.conf; do
        if [ -f "$f" ]; then
            sed -i '/blacklist i915/d' "$f"
            sed -i '/blacklist snd_hda_intel/d' "$f"
            sed -i '/blacklist snd_hda_codec_hdmi/d' "$f"
        fi
    done

    # 添加 VFIO 模块（如果未添加）
    for module in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
        if ! grep -q "^$module$" /etc/modules; then
            echo "$module" >> /etc/modules
            echo "已添加模块: $module"
        fi
    done

    # 移除 kvmgt 模块（如果有 GVT-g 配置）
    sed -i '/^kvmgt$/d' /etc/modules

    echo -e "✓ 内核模块配置完成"

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all || {
        echo -e "更新 initramfs 失败，但可以继续"
    }

    # 下载并安装 i915-sriov-dkms 驱动
    echo "下载 i915-sriov-dkms 驱动..."
    echo "  提示: 请在浏览器访问 https://github.com/strongtz/i915-sriov-dkms/releases 选择匹配的版本"
    echo "  一般建议选择最新的 release 版本以兼容最新的内核版本"
    echo "  输入格式：例如：2025.11.10"
    echo "  不输入回车的默认版本为 2025.11.10，可能不兼容老版本内核，故障表现在无法虚拟出 VFs" 

    default_dkms_version="2025.11.10"
    read -p "请输入要安装的 release 版本号 [默认: ${default_dkms_version}]: " dkms_version_input
    dkms_version_input=$(echo "$dkms_version_input" | xargs)

    if [ -z "$dkms_version_input" ]; then
        dkms_version_input="$default_dkms_version"
    fi

    # release 标签可能以 v 打头，但 deb 文件名不包含 v
    dkms_asset_version=$(echo "$dkms_version_input" | sed 's/^[vV]//')
    dkms_tag="$dkms_version_input"

    dkms_url="https://github.com/strongtz/i915-sriov-dkms/releases/download/${dkms_tag}/i915-sriov-dkms_${dkms_asset_version}_amd64.deb"
    dkms_file="/tmp/i915-sriov-dkms_${dkms_asset_version}_amd64.deb"

    # 检查是否已下载
    if [ -f "$dkms_file" ]; then
        echo "驱动文件已存在，跳过下载"
    else
        echo "从 GitHub 下载驱动..."
        echo "  提示: 如果下载失败，请检查网络或手动下载后放到 /tmp/ 目录"

        wget -O "$dkms_file" "$dkms_url" || {
            echo -e "下载驱动失败"
            echo "  提示: 请手动下载: $dkms_url"
            echo "  提示: 并上传到 PVE 的 /tmp/ 目录后重试"
            pause_function
            return 1
        }
    fi

    echo "安装 i915-sriov-dkms 驱动..."
    echo -e "驱动安装可能需要较长时间，请耐心等待..."

    dpkg -i "$dkms_file" || {
        echo -e "安装驱动失败"
        pause_function
        return 1
    }

    # 验证驱动安装
    echo "验证驱动安装..."
    if modinfo i915 2>/dev/null | grep -q "max_vfs"; then
        echo -e "✓ i915-sriov 驱动安装成功"
    else
        echo -e "驱动验证失败，请检查安装过程"
        pause_function
        return 1
    fi

    # 配置 VFs 数量
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "配置虚拟核显（VFs）数量"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "虚拟核显数量范围: 1-7"
    echo "推荐配置："
    echo "  - 1 个 VF: 性能最强，适合单个高性能虚拟机"
    echo "  - 2-3 个 VF: 平衡性能，适合多个虚拟机"
    echo "  - 4-7 个 VF: 最多虚拟机数量，性能较弱"
    echo
    read -p "请输入 VFs 数量 [1-7, 默认: 3]: " vfs_num

    # 验证输入
    if [[ -z "$vfs_num" ]]; then
        vfs_num=3
    elif ! [[ "$vfs_num" =~ ^[1-7]$ ]]; then
        echo -e "无效的 VFs 数量，必须是 1-7"
        pause_function
        return 1
    fi

    echo "配置 $vfs_num 个虚拟核显"

    # 写入 sysfs.conf
    echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = $vfs_num" > /etc/sysfs.conf
    echo -e "✓ VFs 数量配置完成"

    # 完成提示
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ SR-IOV 核显虚拟化配置完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "配置摘要："
    echo "  • 内核参数: intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7"
    echo "  • VFIO 模块: 已加载"
    echo "  • i915-sriov 驱动: 已安装"
    echo "  • 虚拟核显数量: $vfs_num 个"
    echo
    echo -e "下一步操作："
    echo -e "  1. 重启系统使配置生效"
    echo "  2. 重启后使用 '验证核显虚拟化状态' 检查配置"
    echo "  3. 在虚拟机配置中添加核显 SR-IOV 设备"
    echo
    echo -e "重要提示："
    echo -e "  • 物理核显 (00:02.0) 不能直通给虚拟机"
    echo -e "  • 只能直通虚拟核显 (00:02.1 ~ 00:02.$vfs_num)"
    echo -e "  • 虚拟机需要勾选 ROM-Bar 和 PCIE 选项"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo -e "请记得手动重启系统以使配置生效"
    fi
}

# Intel 6-10代 GVT-g 核显虚拟化配置
igpu_gvtg_setup() {
    echo -e "${H2}开始配置 Intel 6-10代 GVT-g 核显虚拟化${NC}"
    echo -e "详细原理与教程： ${CYAN}https://pve.oowo.cc/advanced/gpu-virtualization${NC}"
    echo -e "如果配置失败，请访问文档站下方留言反馈。"
    echo

    # 展示当前 GRUB 配置
    echo
    show_grub_config
    echo

    # 危险性警告
    echo "$UI_BORDER"
    echo -e "  ${RED}【高危操作警告】${NC} GVT-g 核显虚拟化配置"
    echo "$UI_BORDER"
    echo -e "  此操作属于${RED}【高危险性】${NC}系统配置，配置错误可能导致："
    echo -e "    - ${YELLOW}系统无法正常启动${NC}（GRUB 配置错误）"
    echo -e "    - ${YELLOW}核显完全不可用${NC}（参数配置错误）"
    echo -e "    - ${YELLOW}虚拟机黑屏或无法启动${NC}（直通配置错误）"
    echo -e "    - ${YELLOW}需要通过恢复模式修复系统${NC}"
    echo "$UI_BORDER"
    echo
    echo -e "  此功能将修改以下系统配置："
    echo -e "    1. 修改 ${CYAN}GRUB 引导参数${NC}（启用 IOMMU 和 GVT-g）"
    echo -e "    2. 加载 ${CYAN}VFIO${NC} 和 ${CYAN}kvmgt${NC} 内核模块"
    echo
    echo -e "  ${GREEN}前置要求（请确认已完成）：${NC}"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}VT-d${NC} 虚拟化"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}SR-IOV${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已开启 ${CYAN}Above 4GB${NC}（如有此选项）"
    echo -e "    ${GREEN}✓${NC} BIOS 已关闭 ${CYAN}Secure Boot${NC} 安全启动"
    echo -e "    ${GREEN}✓${NC} CPU 为 ${CYAN}Intel 6-10 代${NC} 处理器"
    echo
    echo -e "  ${PRIMARY}支持的处理器代号：${NC}"
    echo -e "    ${BLUE}•${NC} Skylake (6代)"
    echo -e "    ${BLUE}•${NC} Kaby Lake (7代)"
    echo -e "    ${BLUE}•${NC} Coffee Lake (8代)"
    echo -e "    ${BLUE}•${NC} Coffee Lake Refresh (9代)"
    echo -e "    ${BLUE}•${NC} Comet Lake (10代)"
    echo
    echo -e "  ${MAGENTA}特殊的处理器代号：${NC}"
    echo -e "    ${MAGENTA}•${NC} Rocket Lake / Tiger Lake (11代) 因处在当前代与上一代交界"
    echo -e "      部分型号支持，但是不保证兼容性，请谨慎使用"
    echo "$UI_BORDER"
    echo
    echo -e "${YELLOW}强烈建议：${NC}"
    echo -e "  ${CYAN}提示 1:${NC} 在继续前先备份当前 GRUB 配置"
    echo -e "  ${CYAN}提示 2:${NC} 确保了解核显虚拟化的工作原理"
    echo -e "  ${CYAN}提示 3:${NC} 准备好通过 SSH 或物理访问恢复系统"
    echo

    # 询问是否要备份
    if confirm_action "是否先备份当前 GRUB 配置（强烈推荐）"; then
        echo
        echo "请输入备份备注（例如：GVT-g配置前备份）："
        read -p "> " backup_note
        backup_note=${backup_note:-"GVT-g配置前备份"}
        backup_grub_with_note "$backup_note"
        echo
    fi

    if ! confirm_action "确认继续配置 GVT-g 核显虚拟化"; then
        echo "用户取消操作"
        return 0
    fi

    # 备份并修改 GRUB 配置
    echo "配置 GRUB 引导参数..."
    backup_file "/etc/default/grub"

    # 使用幂等的 GRUB 参数管理函数
    echo "配置 GRUB 参数..."

    # 移除旧的 SR-IOV 配置（如果有）
    grub_remove_param "i915.enable_guc"
    grub_remove_param "i915.max_vfs"
    grub_remove_param "module_blacklist"

    # 添加 GVT-g 参数（幂等操作，不会重复添加）
    grub_add_param "intel_iommu=on"
    grub_add_param "iommu=pt"
    grub_add_param "i915.enable_gvt=1"
    grub_add_param "pcie_acs_override=downstream,multifunction"

    echo -e "✓ GRUB 配置已更新"

    # 更新 GRUB
    echo "更新 GRUB..."
    update-grub || {
        echo -e "更新 GRUB 失败"
        pause_function
        return 1
    }

    # 配置内核模块
    echo "配置内核模块..."
    backup_file "/etc/modules"

    # 清理可能存在的 i915 及音视频相关黑名单 (GVT-g 需要 i915 驱动加载)
    echo "清理可能存在的 i915 及音视频相关黑名单..."
    for f in /etc/modprobe.d/blacklist.conf /etc/modprobe.d/pve-blacklist.conf; do
        if [ -f "$f" ]; then
            sed -i '/blacklist i915/d' "$f"
            sed -i '/blacklist snd_hda_intel/d' "$f"
            sed -i '/blacklist snd_hda_codec_hdmi/d' "$f"
        fi
    done

    # 添加 VFIO 和 kvmgt 模块
    for module in vfio vfio_iommu_type1 vfio_pci vfio_virqfd kvmgt; do
        if ! grep -q "^$module$" /etc/modules; then
            echo "$module" >> /etc/modules
            echo "已添加模块: $module"
        fi
    done

    echo -e "✓ 内核模块配置完成"

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all || {
        echo -e "更新 initramfs 失败，但可以继续"
    }

    # 完成提示
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ GVT-g 核显虚拟化配置完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "配置摘要："
    echo "  • 内核参数: intel_iommu=on iommu=pt i915.enable_gvt=1"
    echo "  • VFIO 模块: 已加载"
    echo "  • kvmgt 模块: 已加载"
    echo
    echo -e "下一步操作："
    echo -e "  1. 重启系统使配置生效"
    echo "  2. 重启后使用 '验证核显虚拟化状态' 检查配置"
    echo "  3. 在虚拟机配置中添加核显 GVT-g 设备（Mdev 类型）"
    echo
    echo "常见 Mdev 类型："
    echo "  • i915-GVTg_V5_4: 低性能，可创建更多虚拟机"
    echo "  • i915-GVTg_V5_8: 高性能，推荐使用（UHD630 最多 2 个）"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo -e "请记得手动重启系统以使配置生效"
    fi
}

# 清理 GVT-g 和 SR-IOV 配置 (恢复默认)
restore_igpu_config() {
    log_step "开始清理核显虚拟化配置 (恢复默认)"
    echo -e "  此操作将执行以下步骤："
    echo -e "    1. 移除 ${CYAN}GRUB${NC} 中的核显相关参数"
    echo -e "    2. 从 ${CYAN}/etc/modules${NC} 移除核显相关模块"
    echo -e "    3. 更新 ${CYAN}GRUB${NC} 和 ${CYAN}initramfs${NC}"
    echo -e "  适用于因配置核显虚拟化导致系统异常或想要重置配置的情况。"
    echo

    if ! confirm_action "是否继续执行清理操作？"; then
        return
    fi

    # 1. 恢复 GRUB 配置
    log_info "正在清理 GRUB 参数..."
    if [[ -f "/etc/default/grub" ]]; then
        # 备份 GRUB 配置
        backup_file "/etc/default/grub"
        
        # 移除相关参数
        sed -i 's/intel_iommu=on//g' /etc/default/grub
        sed -i 's/iommu=pt//g' /etc/default/grub
        sed -i 's/i915.enable_gvt=1//g' /etc/default/grub
        sed -i 's/i915.enable_guc=[0-9]*//g' /etc/default/grub
        sed -i 's/i915.max_vfs=[0-9]*//g' /etc/default/grub
        
        # 清理多余空格
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[[:space:]]*/GRUB_CMDLINE_LINUX_DEFAULT="/g' /etc/default/grub
        sed -i 's/[[:space:]]*"$/"/g' /etc/default/grub
        sed -i 's/[[:space:]]\{2,\}/ /g' /etc/default/grub
        
        log_success "GRUB 参数清理完成"
    else
        log_error "未找到 /etc/default/grub 文件"
    fi

    # 2. 恢复 /etc/modules
    log_info "正在清理 /etc/modules..."
    if [[ -f "/etc/modules" ]]; then
        backup_file "/etc/modules"
        sed -i '/vfio/d' /etc/modules
        sed -i '/vfio_iommu_type1/d' /etc/modules
        sed -i '/vfio_pci/d' /etc/modules
        sed -i '/vfio_virqfd/d' /etc/modules
        sed -i '/kvmgt/d' /etc/modules
        log_success "/etc/modules 清理完成"
    fi

    # 3. 更新系统配置
    log_info "正在更新 GRUB..."
    update-grub
    
    log_info "正在更新 initramfs..."
    update-initramfs -u -k all
    
    log_success "清理完成！核显虚拟化配置已重置。"
    if confirm_action "是否现在重启系统？"; then
        reboot
    fi
}

# 验证核显虚拟化状态
igpu_verify() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  核显虚拟化状态检查"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # 检查 IOMMU
    echo "1. 检查 IOMMU 状态..."
    if dmesg | grep -qi "DMAR.*IOMMU\|iommu.*enabled"; then
        echo -e "  ✓ IOMMU 已启用"
        echo "  $(dmesg | grep -i "DMAR.*IOMMU\|iommu.*enabled" | head -3)"
    else
        echo -e "  ✗ IOMMU 未启用"
        echo "  提示: 请检查 BIOS 是否开启 VT-d"
        echo "  提示: 请检查 GRUB 配置是否包含 intel_iommu=on"
    fi
    echo

    # 检查 VFIO 模块
    echo "2. 检查 VFIO 模块加载状态..."
    if lsmod | grep -q vfio; then
        echo -e "  ✓ VFIO 模块已加载"
        echo "  $(lsmod | grep vfio)"
    else
        echo -e "  ✗ VFIO 模块未加载"
        echo "  提示: 请检查 /etc/modules 配置"
    fi
    echo

    # 检查 SR-IOV
    echo "3. 检查 SR-IOV 虚拟核显..."
    if lspci | grep -i "VGA.*Intel" | wc -l | grep -q "^[2-9]"; then
        vf_count=$(($(lspci | grep -i "VGA.*Intel" | wc -l) - 1))
        echo -e "  ✓ 检测到 $vf_count 个虚拟核显 (SR-IOV)"
        echo
        lspci | grep -i "VGA.*Intel"
        echo
        echo "  提示: 物理核显 00:02.0 不能直通"
        echo "  提示: 虚拟核显 00:02.1 ~ 00:02.$vf_count 可直通给虚拟机"
    else
        echo -e "  ! 未检测到 SR-IOV 虚拟核显"
    fi
    echo

    # 检查 GVT-g
    echo "4. 检查 GVT-g mdev 类型..."
    if [ -d "/sys/bus/pci/devices/0000:00:02.0/mdev_supported_types" ]; then
        mdev_types=$(ls /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types 2>/dev/null | wc -l)
        if [ "$mdev_types" -gt 0 ]; then
            echo -e "  ✓ GVT-g 已启用，可用 Mdev 类型: $mdev_types 个"
            echo
            ls -1 /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types
        else
            echo -e "  ! GVT-g 未正确配置"
        fi
    else
        echo -e "  ! 未检测到 GVT-g 支持"
        echo "  提示: 此 CPU 可能不支持 GVT-g 或未配置"
    fi
    echo

    # 检查 kvmgt 模块（GVT-g 需要）
    echo "5. 检查 kvmgt 模块（GVT-g）..."
    if lsmod | grep -q kvmgt; then
        echo -e "  ✓ kvmgt 模块已加载（GVT-g 模式）"
    else
        echo "  kvmgt 模块未加载（SR-IOV 模式或未配置 GVT-g）"
    fi
    echo

    # 检查 i915 驱动参数
    echo "6. 检查 i915 驱动参数..."
    if [ -f "/sys/module/i915/parameters/enable_guc" ]; then
        guc_value=$(cat /sys/module/i915/parameters/enable_guc)
        if [ "$guc_value" = "3" ]; then
            echo -e "  ✓ i915.enable_guc = 3 (SR-IOV 模式)"
        else
            echo "  i915.enable_guc = $guc_value"
        fi
    fi

    if [ -f "/sys/module/i915/parameters/enable_gvt" ]; then
        gvt_value=$(cat /sys/module/i915/parameters/enable_gvt)
        if [ "$gvt_value" = "Y" ]; then
            echo -e "  ✓ i915.enable_gvt = Y (GVT-g 模式)"
        else
            echo "  i915.enable_gvt = $gvt_value"
        fi
    fi
    echo

    # 总结
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  检查完成"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    pause_function
}

# 移除核显虚拟化配置
igpu_remove() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e " 警告 - 移除核显虚拟化配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo -e "  此操作将："
    echo "  • 恢复 GRUB 配置为默认值"
    echo "  • 清理 /etc/modules 中的 VFIO 和 kvmgt 模块"
    echo "  • 删除 /etc/sysfs.conf 中的 VFs 配置"
    echo "  • 卸载 i915-sriov-dkms 驱动（如已安装）"
    echo
    echo -e "  注意：此操作不会自动重启系统"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if ! confirm_action "确认移除核显虚拟化配置"; then
        echo "用户取消操作"
        return 0
    fi

    # 恢复 GRUB 配置
    echo "恢复 GRUB 配置..."
    backup_file "/etc/default/grub"

    # 移除所有核显虚拟化参数
    sed -i 's/intel_iommu=on//g; s/iommu=pt//g; s/i915.enable_guc=3//g; s/i915.max_vfs=7//g; s/module_blacklist=xe//g; s/i915.enable_gvt=1//g; s/pcie_acs_override=downstream,multifunction//g' /etc/default/grub

    # 清理多余空格
    sed -i 's/  */ /g' /etc/default/grub

    update-grub
    echo -e "  ✓ GRUB 配置已恢复"

    # 清理 /etc/modules
    echo "清理内核模块配置..."
    backup_file "/etc/modules"

    sed -i '/^vfio$/d; /^vfio_iommu_type1$/d; /^vfio_pci$/d; /^vfio_virqfd$/d; /^kvmgt$/d' /etc/modules
    echo -e "  ✓ 内核模块配置已清理"

    # 清理 /etc/sysfs.conf
    if [ -f "/etc/sysfs.conf" ]; then
        echo "清理 sysfs 配置..."
        backup_file "/etc/sysfs.conf"
        sed -i '/sriov_numvfs/d' /etc/sysfs.conf
        echo -e "  ✓ sysfs 配置已清理"
    fi

    # 卸载 i915-sriov-dkms
    echo "检查 i915-sriov-dkms 驱动..."
    if dpkg -l | grep -q i915-sriov-dkms; then
        echo "卸载 i915-sriov-dkms 驱动..."
        dpkg -P i915-sriov-dkms || echo -e "${YELLOW}警告: 卸载驱动失败，可能需要手动处理${NC}"
        echo -e "✓ 驱动已卸载"
    else
        echo "未安装 i915-sriov-dkms 驱动，跳过"
    fi

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ 核显虚拟化配置已移除"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "提示: 请重启系统使更改生效"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo "请记得手动重启系统"
    fi
}

# 核显高级功能菜单
igpu_management_menu() {
    while true; do
        clear
        show_menu_header "核显虚拟化高级功能"
        echo -e "  ${RED}【危险警告】${NC} 核显虚拟化属于高危操作"
        echo -e "  配置错误可能导致系统无法启动，请务必提前备份 GRUB 配置"
        echo "${UI_DIVIDER}"
        show_menu_option "1" "Intel 11-15代 SR-IOV 核显虚拟化"
        echo -e "     ${CYAN}支持:${NC} Rocket Lake, Alder Lake, Raptor Lake"
        echo -e "     ${CYAN}特性:${NC} 最多 7 个虚拟核显，性能较好"
        show_menu_option "2" "Intel 6-10代 GVT-g 核显虚拟化"
        echo -e "     ${CYAN}支持:${NC} Skylake ~ Comet Lake"
        echo -e "     ${CYAN}特性:${NC} 最多 2-8 个虚拟核显（取决于型号）"
        show_menu_option "3" "验证核显虚拟化状态"
        echo -e "     ${CYAN}检查:${NC} IOMMU、VFIO、SR-IOV/GVT-g 配置"
        show_menu_option "4" "移除核显虚拟化配置"
        echo -e "     ${CYAN}恢复:${NC} 默认配置，移除所有核显虚拟化设置"
        echo "${UI_DIVIDER}"
        show_menu_option "" "GRUB 配置管理（强烈推荐使用）"
        echo "${UI_DIVIDER}"
        show_menu_option "5" "查看当前 GRUB 配置"
        echo -e "     ${CYAN}展示:${NC} 当前的 GRUB 引导参数和关键配置"
        show_menu_option "6" "备份 GRUB 配置"
        echo -e "     ${CYAN}路径:${NC} /etc/pvetools9/backup/grub/"
        show_menu_option "7" "查看 GRUB 备份列表"
        show_menu_option "8" "恢复 GRUB 配置"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        echo
        read -p "请选择操作 [0-8]: " choice

        case $choice in
            1)
                igpu_sriov_setup
                ;;
            2)
                igpu_gvtg_setup
                ;;
            3)
                igpu_verify
                ;;
            4)
                igpu_remove
                ;;
            5)
                show_grub_config
                pause_function
                ;;
            6)
                echo
                echo "请输入备份备注（例如：手动备份_测试）："
                read -p "> " backup_note
                backup_note=${backup_note:-"手动备份"}
                backup_grub_with_note "$backup_note"
                pause_function
                ;;
            7)
                list_grub_backups
                pause_function
                ;;
            8)
                restore_grub_backup
                ;;
            0)
                echo "返回主菜单"
                return 0
                ;;
            *)
                echo -e "无效的选择，请输入 0-8"
                pause_function
                ;;
        esac
    done
}
#--------------核显虚拟化管理----------------

#---------PVE8/9添加ceph-squid源-----------
pve9_ceph() {
    sver=`cat /etc/debian_version |awk -F"." '{print $1}'`
    case "$sver" in
     13 )
         sver="trixie"
     ;;
     12 )
         sver="bookworm"
     ;;
    * )
        sver=""
     ;;
    esac
    if [ ! $sver ];then
        log_error "版本不支持！"
        pause_function
        return
    fi

    log_info "ceph-squid目前仅支持PVE8和9！"
    [[ ! -d /etc/apt/backup ]] && mkdir -p /etc/apt/backup
    [[ ! -d /etc/apt/sources.list.d ]] && mkdir -p /etc/apt/sources.list.d

    [[ -e /etc/apt/sources.list.d/ceph.sources ]] && mv /etc/apt/sources.list.d/ceph.sources /etc/apt/backup/ceph.sources.bak
    [[ -e /etc/apt/sources.list.d/ceph.list ]] && mv /etc/apt/sources.list.d/ceph.list /etc/apt/backup/ceph.list.bak

    [[ -e /usr/share/perl5/PVE/CLI/pveceph.pm ]] && cp -rf /usr/share/perl5/PVE/CLI/pveceph.pm /etc/apt/backup/pveceph.pm.bak
    sed -i 's|http://download.proxmox.com|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' /usr/share/perl5/PVE/CLI/pveceph.pm

    cat > /etc/apt/sources.list.d/ceph.list <<-EOF
deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/ceph-squid ${sver} no-subscription
EOF
    log_success "添加ceph-squid源完成!"
}
#---------PVE8/9添加ceph-squid源-----------

#---------PVE7/8添加ceph-quincy源-----------
pve8_ceph() {
    sver=`cat /etc/debian_version |awk -F"." '{print $1}'`
    case "$sver" in
     12 )
         sver="bookworm"
     ;;
     11 )
         sver="bullseye"
     ;;
    * )
        sver=""
     ;;
    esac
    if [ ! $sver ];then
        log_error "版本不支持！"
        pause_function
        return
    fi

    log_info "ceph-quincy目前仅支持PVE7和8！"
    [[ ! -d /etc/apt/backup ]] && mkdir -p /etc/apt/backup
    [[ ! -d /etc/apt/sources.list.d ]] && mkdir -p /etc/apt/sources.list.d

    [[ -e /etc/apt/sources.list.d/ceph.sources ]] && mv /etc/apt/sources.list.d/ceph.sources /etc/apt/backup/ceph.sources.bak
    [[ -e /etc/apt/sources.list.d/ceph.list ]] && mv /etc/apt/sources.list.d/ceph.list /etc/apt/backup/ceph.list.bak

    [[ -e /usr/share/perl5/PVE/CLI/pveceph.pm ]] && cp -rf /usr/share/perl5/PVE/CLI/pveceph.pm /etc/apt/backup/pveceph.pm.bak
    sed -i 's|http://download.proxmox.com|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' /usr/share/perl5/PVE/CLI/pveceph.pm

    cat > /etc/apt/sources.list.d/ceph.list <<-EOF
deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/ceph-quincy ${sver} main
EOF
    log_success "添加ceph-quincy源完成!"
}
#---------PVE7/8添加ceph-quincy源-----------
# 待办
#---------PVE7/8添加ceph-quincy源-----------
#---------PVE一键卸载ceph-----------
remove_ceph() {
    log_warn "会卸载ceph，并删除所有ceph相关文件！"

    systemctl stop ceph-mon.target && systemctl stop ceph-mgr.target && systemctl stop ceph-mds.target && systemctl stop ceph-osd.target
    rm -rf /etc/systemd/system/ceph*

    killall -9 ceph-mon ceph-mgr ceph-mds ceph-osd
    rm -rf /var/lib/ceph/mon/* && rm -rf /var/lib/ceph/mgr/* && rm -rf /var/lib/ceph/mds/* && rm -rf /var/lib/ceph/osd/*

    pveceph purge

    apt purge -y ceph-mon ceph-osd ceph-mgr ceph-mds
    apt purge -y ceph-base ceph-mgr-modules-core

    rm -rf /etc/ceph && rm -rf /etc/pve/ceph.conf  && rm -rf /etc/pve/priv/ceph.* && rm -rf /var/log/ceph && rm -rf /etc/pve/ceph && rm -rf /var/lib/ceph

    [[ -e /etc/apt/sources.list.d/ceph.sources ]] && mv /etc/apt/sources.list.d/ceph.sources /etc/apt/backup/ceph.sources.bak

    log_success "已成功卸载ceph."
}
#---------PVE一键卸载ceph-----------

#---------第三方小工具管理-----------
# 小工具配置
# FastPVE - PVE 虚拟机快速下载
fastpve_quick_download_menu() {
    clear
    show_banner
    show_menu_header "PVE 虚拟机快速下载 (FastPVE)"

    echo "  FastPVE 由社区开发者 @kspeeder 维护，提供热门 PVE 虚拟机模板快速拉取能力。"
    echo "  本功能将直接运行 FastPVE 官方脚本，请在执行前确保信任该来源。"
    echo
    echo "  项目地址: $FASTPVE_PROJECT_URL"
    echo "  安装脚本: $FASTPVE_INSTALLER_URL"
    echo
    echo -e "${RED}⚠️  重要提示:${NC} 这是第三方脚本，出现任何问题请前往 FastPVE 项目反馈，别找我喔~"
    echo -e "${YELLOW}    我们只负责帮你下载并执行，后续操作和风险请自行承担。${NC}"
    echo "${UI_DIVIDER}"
    echo "  使用说明："
    echo "    • FastPVE 会拉取独立菜单，按提示选择需要的虚拟机模板"
    echo "    • 需要互联网访问 GitHub（大陆环境自动优先使用镜像源）"
    echo "    • 本脚本仅负责下载并执行 FastPVE，具体操作由 FastPVE 完成"
    echo "${UI_DIVIDER}"

    read -p "是否立即运行 FastPVE 脚本？(y/N): " confirm
    confirm=${confirm:-N}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消执行 FastPVE"
        return 0
    fi

    local fastpve_url="$FASTPVE_INSTALLER_URL"
    local fastpve_mirror_url="${GITHUB_MIRROR_PREFIX}${FASTPVE_INSTALLER_URL}"
    local preferred_url="$fastpve_url"
    local fallback_url="$fastpve_mirror_url"
    local preferred_label="GitHub"
    local fallback_label="加速镜像"

    if detect_network_region; then
        if [[ $USE_MIRROR_FOR_UPDATE -eq 1 ]]; then
            preferred_url="$fastpve_mirror_url"
            fallback_url="$fastpve_url"
            preferred_label="加速镜像"
            fallback_label="GitHub"
            log_info "检测到中国大陆网络环境，优先使用 FastPVE 加速镜像下载"
        else
            if [[ -n "$USER_COUNTRY_CODE" ]]; then
                log_info "检测到当前地区: $USER_COUNTRY_CODE，将通过 GitHub 下载 FastPVE"
            else
                log_info "网络检测成功，将通过 GitHub 下载 FastPVE"
            fi
        fi
    else
        log_warn "无法检测网络地区，默认使用 GitHub 下载 FastPVE"
    fi

    local -a download_cmd
    local downloader_name=""
    if command -v curl &> /dev/null; then
        download_cmd=(curl -fsSL --connect-timeout 10 --max-time 60 -o)
        downloader_name="curl"
    elif command -v wget &> /dev/null; then
        download_cmd=(wget -q -O)
        downloader_name="wget"
    else
        log_error "未检测到 curl 或 wget，无法下载 FastPVE 脚本"
        return 1
    fi

    local tmp_script
    if ! tmp_script=$(mktemp /tmp/fastpve-install.XXXXXX.sh); then
        log_error "无法创建临时文件，FastPVE 启动失败"
        return 1
    fi

    log_info "使用 $preferred_label 下载 FastPVE 安装脚本 (下载器: $downloader_name)..."
    if ! "${download_cmd[@]}" "$tmp_script" "$preferred_url"; then
        log_warn "$preferred_label 下载失败，尝试改用 $fallback_label..."
        : > "$tmp_script"
        if ! "${download_cmd[@]}" "$tmp_script" "$fallback_url"; then
            log_error "FastPVE 安装脚本下载失败，请检查网络或稍后重试"
            rm -f "$tmp_script"
            return 1
        fi
    fi

    chmod +x "$tmp_script"
    echo
    log_step "FastPVE 脚本即将运行，请根据 FastPVE 菜单提示选择虚拟机模板"
    echo "${UI_BORDER}"
    sh "$tmp_script"
    local run_status=$?
    echo "${UI_BORDER}"

    rm -f "$tmp_script"

    if [[ $run_status -eq 0 ]]; then
        log_success "FastPVE 虚拟机快速下载脚本执行完成"
    else
        log_error "FastPVE 脚本执行失败 (退出码: $run_status)"
    fi

    return $run_status
}

third_party_market_menu() {
    local -a download_cmd

    if command -v curl &> /dev/null; then
        download_cmd=(curl -fsSL --connect-timeout 10 --max-time 60 -o)
    elif command -v wget &> /dev/null; then
        download_cmd=(wget -q -O)
    else
        log_error "未检测到 curl 或 wget，无法访问第三方软件市场"
        return 1
    fi

    local tmp_index
    if ! tmp_index=$(mktemp /tmp/pve-third-party-index.XXXXXX.json); then
        log_error "无法创建临时文件，第三方软件市场启动失败"
        return 1
    fi

    local api_main_url="$THIRD_PARTY_MODULES_TREE_API_MAIN_URL"
    local api_master_url="$THIRD_PARTY_MODULES_TREE_API_MASTER_URL"
    local index_ok=0

    log_info "正在通过 GitHub API 拉取第三方软件列表..."
    if command -v curl &> /dev/null; then
        if curl -fsSL --connect-timeout 10 --max-time 60 \
            -H "Accept: application/vnd.github+json" \
            -H "User-Agent: pve-tools" \
            -o "$tmp_index" "$api_main_url"; then
            index_ok=1
        else
            log_warn "main 分支列表拉取失败，尝试使用 master 分支..."
            : > "$tmp_index"
            if curl -fsSL --connect-timeout 10 --max-time 60 \
                -H "Accept: application/vnd.github+json" \
                -H "User-Agent: pve-tools" \
                -o "$tmp_index" "$api_master_url"; then
                index_ok=1
            fi
        fi
    else
        if wget -q --timeout=60 \
            --header="Accept: application/vnd.github+json" \
            --user-agent="pve-tools" \
            -O "$tmp_index" "$api_main_url"; then
            index_ok=1
        else
            log_warn "main 分支列表拉取失败，尝试使用 master 分支..."
            : > "$tmp_index"
            if wget -q --timeout=60 \
                --header="Accept: application/vnd.github+json" \
                --user-agent="pve-tools" \
                -O "$tmp_index" "$api_master_url"; then
                index_ok=1
            fi
        fi
    fi

    if [[ $index_ok -ne 1 ]]; then
        log_error "第三方软件列表拉取失败，请稍后重试"
        rm -f "$tmp_index"
        return 1
    fi

    local -a module_files
    while IFS= read -r module_name; do
        [[ -z "$module_name" ]] && continue
        module_files+=("$module_name")
    done < <(grep -oE '"path":[[:space:]]*"Modules/[^"]+\.sh"' "$tmp_index" | sed -E 's#.*"path":[[:space:]]*"Modules/([^"]+)".*#\1#')
    rm -f "$tmp_index"

    if [[ ${#module_files[@]} -eq 0 ]]; then
        log_warn "未在 Modules 目录发现可用的 .sh 第三方脚本"
        return 1
    fi

    local -a valid_files valid_names valid_authors valid_versions valid_githubs
    for module_file in "${module_files[@]}"; do
        local module_url="${THIRD_PARTY_MODULES_RAW_BASE_URL}/${module_file}"
        local module_mirror_url="${GITHUB_MIRROR_PREFIX}${module_url}"
        local module_preferred_url="$module_url"
        local module_fallback_url="$module_mirror_url"

        if [[ $USE_MIRROR_FOR_UPDATE -eq 1 ]]; then
            module_preferred_url="$module_mirror_url"
            module_fallback_url="$module_url"
        fi

        local tmp_module
        if ! tmp_module=$(mktemp /tmp/pve-third-party-meta.XXXXXX.sh); then
            continue
        fi

        if ! "${download_cmd[@]}" "$tmp_module" "$module_preferred_url"; then
            : > "$tmp_module"
            if ! "${download_cmd[@]}" "$tmp_module" "$module_fallback_url"; then
                rm -f "$tmp_module"
                continue
            fi
        fi

        local meta_block
        meta_block=$(sed -n '2,5p' "$tmp_module")
        rm -f "$tmp_module"

        local script_name script_author script_version script_github
        script_name=$(echo "$meta_block" | grep -m1 '^## name:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        script_author=$(echo "$meta_block" | grep -m1 '^## author:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        script_version=$(echo "$meta_block" | grep -m1 '^## version:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        script_github=$(echo "$meta_block" | grep -m1 '^## github:' | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ -z "$script_name" || -z "$script_author" || -z "$script_version" || -z "$script_github" ]]; then
            continue
        fi

        valid_files+=("$module_file")
        valid_names+=("$script_name")
        valid_authors+=("$script_author")
        valid_versions+=("$script_version")
        valid_githubs+=("$script_github")
    done

    if [[ ${#valid_files[@]} -eq 0 ]]; then
        log_warn "已发现 .sh 文件，但没有符合元信息规范（第2-5行）的脚本"
        return 1
    fi

    while true; do
        clear
        show_menu_header "第三方软件市场 (Modules)"
        echo "  数据源: $THIRD_PARTY_MODULES_RAW_BASE_URL"
        echo "  共发现 ${#valid_files[@]} 个符合规范的脚本"
        echo "${UI_DIVIDER}"
        local idx=1
        while [[ $idx -le ${#valid_files[@]} ]]; do
            local arr_idx=$((idx - 1))
            echo -e "  ${CYAN}${idx}.${NC} ${valid_names[$arr_idx]}"
            echo "      作者: ${valid_authors[$arr_idx]} | 版本: ${valid_versions[$arr_idx]}"
            echo "      脚本: ${valid_files[$arr_idx]}"
            echo "      仓库: ${valid_githubs[$arr_idx]}"
            ((idx++))
        done
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回上级菜单"
        show_menu_footer

        local choice
        read -p "请选择要运行的脚本 [0-${#valid_files[@]}]: " choice
        if [[ "$choice" == "0" ]]; then
            return 0
        fi
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#valid_files[@]} )); then
            log_error "无效选择"
            pause_function
            continue
        fi

        local selected_idx=$((choice - 1))
        local selected_file="${valid_files[$selected_idx]}"
        local selected_name="${valid_names[$selected_idx]}"
        local selected_author="${valid_authors[$selected_idx]}"
        local selected_version="${valid_versions[$selected_idx]}"
        local selected_url="${THIRD_PARTY_MODULES_RAW_BASE_URL}/${selected_file}"
        local selected_mirror_url="${GITHUB_MIRROR_PREFIX}${selected_url}"
        local selected_preferred_url="$selected_url"
        local selected_fallback_url="$selected_mirror_url"
        local selected_preferred_label="GitHub"
        local selected_fallback_label="加速镜像"

        if [[ $USE_MIRROR_FOR_UPDATE -eq 1 ]]; then
            selected_preferred_url="$selected_mirror_url"
            selected_fallback_url="$selected_url"
            selected_preferred_label="加速镜像"
            selected_fallback_label="GitHub"
        fi

        echo
        echo -e "${RED}⚠️  第三方脚本风险提示:${NC}"
        echo "  名称: $selected_name"
        echo "  作者: $selected_author"
        echo "  版本: $selected_version"
        echo "  来源: $selected_url"
        echo "  本工具仅负责下载和执行，请确认你已审计脚本内容并接受风险。"
        read -p "输入 'run' 确认执行，其他任意键取消: " confirm_run
        if [[ "$confirm_run" != "run" ]]; then
            log_info "已取消执行 $selected_name"
            pause_function
            continue
        fi

        local tmp_script
        if ! tmp_script=$(mktemp /tmp/pve-third-party-run.XXXXXX.sh); then
            log_error "无法创建临时脚本文件"
            pause_function
            continue
        fi

        log_info "使用 $selected_preferred_label 下载脚本 ($selected_file)..."
        if ! "${download_cmd[@]}" "$tmp_script" "$selected_preferred_url"; then
            log_warn "$selected_preferred_label 下载失败，尝试改用 $selected_fallback_label..."
            : > "$tmp_script"
            if ! "${download_cmd[@]}" "$tmp_script" "$selected_fallback_url"; then
                log_error "脚本下载失败: $selected_file"
                rm -f "$tmp_script"
                pause_function
                continue
            fi
        fi

        chmod +x "$tmp_script"
        echo "${UI_BORDER}"
        sh "$tmp_script"
        local run_status=$?
        echo "${UI_BORDER}"
        rm -f "$tmp_script"

        if [[ $run_status -eq 0 ]]; then
            log_success "$selected_name 执行完成"
        else
            log_error "$selected_name 执行失败 (退出码: $run_status)"
        fi
        pause_function
    done
}
#---------FastPVE 虚拟机快速下载-----------

# Community Scripts 提示
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

coolercontrol_local_url() {
    local first_ip
    first_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -n "$first_ip" ]]; then
        echo "http://${first_ip}:11987"
    else
        echo "http://<PVE-IP>:11987"
    fi
}

coolercontrol_print_manual_install() {
    clear
    show_menu_header "CoolerControl 手动安装命令"
    echo "  官方项目: $COOLERCONTROL_PROJECT_URL"
    echo "  官方文档: $COOLERCONTROL_DOCS_URL"
    echo
    echo "  # 1. 下载并运行 Cloudsmith 官方 Debian 源配置脚本"
    echo "  wget -O /tmp/coolercontrol-setup.deb.sh \"$COOLERCONTROL_DEB_SETUP_URL\""
    echo "  bash /tmp/coolercontrol-setup.deb.sh"
    echo
    echo "  # 2. 安装守护进程并启动内置 Web UI"
    echo "  apt-get update"
    echo "  apt-get install -y coolercontrold"
    echo "  systemctl enable --now coolercontrold"
    echo
    echo "  # 可选：桌面 UI 和更广硬件支持"
    echo "  apt-get install -y coolercontrol lm-sensors liquidctl"
    echo
    echo "  Web UI: $(coolercontrol_local_url)"
}

coolercontrol_detect_status() {
    local service_state="未安装/未找到进程信息"

    if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W coolercontrold >/dev/null 2>&1; then
        service_state="已安装/未找到进程信息"
        if command -v systemctl >/dev/null 2>&1; then
            service_state="$(systemctl is-active coolercontrold 2>/dev/null || echo inactive)"
            case "$service_state" in
                active) service_state="已安装/运行中" ;;
                inactive) service_state="已安装/未运行" ;;
                failed) service_state="已安装/服务异常" ;;
                *) service_state="已安装/${service_state}" ;;
            esac
        fi
    elif pgrep -x coolercontrold >/dev/null 2>&1; then
        service_state="已安装/运行中"
    fi

    echo "$service_state"
}

coolercontrol_detect_version() {
    local daemon_version desktop_version

    if command -v dpkg-query >/dev/null 2>&1; then
        daemon_version="$(dpkg-query -W -f='${Version}' coolercontrold 2>/dev/null || true)"
        desktop_version="$(dpkg-query -W -f='${Version}' coolercontrol 2>/dev/null || true)"
    fi

    if [[ -n "$daemon_version" && -n "$desktop_version" && "$daemon_version" != "$desktop_version" ]]; then
        echo "coolercontrold ${daemon_version} / coolercontrol ${desktop_version}"
    elif [[ -n "$daemon_version" ]]; then
        echo "$daemon_version"
    elif [[ -n "$desktop_version" ]]; then
        echo "$desktop_version"
    else
        echo "未安装/未找到进程信息"
    fi
}

coolercontrol_install() {
    block_non_pve9_destructive "安装 CoolerControl 第三方风扇控制工具" || return 1

    local install_desktop install_optional tmp_script install_pkgs=()
    if ! command -v apt-get >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
        display_error "缺少 apt-get 或 systemctl" "请在 Debian/PVE 宿主机环境中运行。"
        return 1
    fi

    clear
    show_menu_header "安装 CoolerControl"
    echo -e "${CYAN}项目:${NC} $COOLERCONTROL_PROJECT_URL"
    echo -e "${CYAN}文档:${NC} $COOLERCONTROL_DOCS_URL"
    echo -e "${CYAN}源配置脚本:${NC} $COOLERCONTROL_DEB_SETUP_URL"
    echo "$UI_DIVIDER"
    echo "  将安装官方 Debian 包 coolercontrold。"
    echo "  coolercontrold 是系统守护进程，包含内置 Web UI。"
    echo "  PVE-Tools 不接管风扇曲线、不写入 CoolerControl 配置。"
    echo "$UI_DIVIDER"

    read -p "是否安装桌面 UI coolercontrol？PVE 宿主机通常不需要 [no]: " install_desktop
    install_desktop="${install_desktop:-no}"
    read -p "是否安装可选硬件支持包 lm-sensors/liquidctl？[yes]: " install_optional
    install_optional="${install_optional:-yes}"

    if ! confirm_high_risk_action "安装 CoolerControl 并添加第三方 APT 源" "会下载并运行 CoolerControl 官方 Cloudsmith 源配置脚本，并安装第三方软件包。" "第三方仓库或包异常可能影响 apt 源状态；风扇控制配置错误可能造成散热或噪音问题。" "建议先确认硬件支持情况，并保留 PVE 控制台访问；安装后先观察温度与风扇状态，再配置自动曲线。" "COOLER"; then
        return 0
    fi

    if ! tmp_script=$(mktemp /tmp/coolercontrol-setup.XXXXXX.sh); then
        display_error "无法创建临时文件" "请检查 /tmp 是否可写。"
        return 1
    fi

    log_info "下载 CoolerControl 官方 Debian 源配置脚本..."
    if ! pve_tools_download_file "$COOLERCONTROL_DEB_SETUP_URL" "$tmp_script" 60; then
        rm -f "$tmp_script"
        display_error "CoolerControl 源配置脚本下载失败" "请检查网络，或使用手动安装命令。"
        return 1
    fi

    chmod +x "$tmp_script"
    log_step "配置 CoolerControl APT 源..."
    if ! bash "$tmp_script"; then
        rm -f "$tmp_script"
        display_error "CoolerControl APT 源配置失败" "请检查脚本输出，或参考官方文档手动配置。"
        return 1
    fi
    rm -f "$tmp_script"

    log_step "更新软件包索引..."
    if ! apt-get update; then
        display_error "apt-get update 失败" "第三方源可能未正确配置，已停止安装。"
        return 1
    fi

    install_pkgs=(coolercontrold)
    [[ "$install_desktop" == "yes" || "$install_desktop" == "YES" ]] && install_pkgs+=(coolercontrol)
    [[ "$install_optional" == "yes" || "$install_optional" == "YES" ]] && install_pkgs+=(lm-sensors liquidctl)

    log_step "安装软件包: ${install_pkgs[*]}"
    if ! apt-get install -y "${install_pkgs[@]}"; then
        display_error "CoolerControl 安装失败" "请检查包名、软件源和网络连接。"
        return 1
    fi

    if systemctl enable --now coolercontrold; then
        display_success "CoolerControl 安装完成" "打开 Web UI: $(coolercontrol_local_url)"
    else
        display_error "CoolerControl 已安装，但服务启动失败" "请运行 systemctl status coolercontrold 查看原因。"
        return 1
    fi
}

coolercontrol_update() {
    block_non_pve9_destructive "更新 CoolerControl" || return 1

    local upgrade_pkgs=()

    if ! command -v apt-get >/dev/null 2>&1; then
        display_error "缺少 apt-get" "请在 Debian/PVE 宿主机环境中运行。"
        return 1
    fi

    if ! confirm_high_risk_action "更新 CoolerControl 软件包" "会刷新 apt 索引并升级 coolercontrold/coolercontrol 相关包。" "第三方源异常可能导致更新失败；服务重启期间风扇控制策略可能短暂不可用。" "请确认当前散热状态稳定，并保留控制台访问。" "COOLER-UPDATE"; then
        return 0
    fi

    apt-get update || {
        display_error "apt-get update 失败" "请检查 CoolerControl 源和网络连接。"
        return 1
    }

    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W coolercontrold >/dev/null 2>&1 && upgrade_pkgs+=(coolercontrold)
        dpkg-query -W coolercontrol >/dev/null 2>&1 && upgrade_pkgs+=(coolercontrol)
        dpkg-query -W lm-sensors >/dev/null 2>&1 && upgrade_pkgs+=(lm-sensors)
        dpkg-query -W liquidctl >/dev/null 2>&1 && upgrade_pkgs+=(liquidctl)
    fi

    if [[ ${#upgrade_pkgs[@]} -eq 0 ]]; then
        display_error "未检测到已安装的 CoolerControl 相关包" "请先执行安装，或使用手动安装命令。"
        return 1
    fi

    if ! apt-get install --only-upgrade -y "${upgrade_pkgs[@]}"; then
        display_error "CoolerControl 更新失败" "请检查软件包是否已安装以及 apt 输出。"
        return 1
    fi

    systemctl restart coolercontrold 2>/dev/null || log_warn "coolercontrold 重启失败，请手动检查服务状态。"
    display_success "CoolerControl 更新完成" "Web UI: $(coolercontrol_local_url)"
}

coolercontrol_uninstall() {
    block_non_pve9_destructive "卸载 CoolerControl" || return 1

    if ! command -v apt-get >/dev/null 2>&1; then
        display_error "缺少 apt-get" "请在 Debian/PVE 宿主机环境中运行。"
        return 1
    fi

    clear
    show_menu_header "卸载 CoolerControl"
    echo "  将停止 coolercontrold 服务，并卸载 coolercontrol/coolercontrold 软件包。"
    echo "  默认不会删除 Cloudsmith 源配置和用户配置目录，便于后续重新安装。"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "卸载 CoolerControl" "会停止第三方风扇控制服务并移除相关软件包。" "卸载后风扇控制将回到系统/固件默认行为，可能影响噪音和散热策略。" "请确认当前硬件默认风扇策略可接受，且已记录需要保留的 CoolerControl 配置。" "COOLER-REMOVE"; then
        return 0
    fi

    systemctl disable --now coolercontrold 2>/dev/null || true
    if apt-get remove -y coolercontrol coolercontrold; then
        display_success "CoolerControl 已卸载" "如需清理配置，可按官方文档手动处理。"
    else
        display_error "CoolerControl 卸载失败" "请检查 apt 输出并手动处理。"
        return 1
    fi
}

coolercontrol_manager_menu() {
    while true; do
        clear
        show_menu_header "Cooler Control 管理器"
        echo -e "当前状态 ： $(coolercontrol_detect_status)"
        echo -e "当前版本 ： $(coolercontrol_detect_version)"
        echo "$UI_DIVIDER"
        show_menu_option "1" "安装"
        show_menu_option "2" "更新"
        show_menu_option "3" "手动安装"
        show_menu_option "4" "卸载"
        echo "$UI_DIVIDER"
        echo "注意：本功能仅作为安装服务和服务管理，如需反馈问题请前往项目官方开源仓库反馈！"
        echo "$UI_DIVIDER"
        echo "项目官网：$COOLERCONTROL_PROJECT_URL"
        echo "开源协议：GNU General Public License v3.0 or later."
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) coolercontrol_install ;;
            2) coolercontrol_update ;;
            3) coolercontrol_print_manual_install ;;
            4) coolercontrol_uninstall ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

third_party_tools_menu() {
    while true; do
        clear
        show_menu_header "第三方工具"
        show_menu_option "1" "第三方软件市场 ${CYAN}(Modules)${NC}"
        show_menu_option "2" "CoolerControl ${CYAN}(更好的管理风扇控制工具)${NC}"
        show_menu_option "3" "Community Scripts ${CYAN}(社区脚本集合)${NC}"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) third_party_market_menu ;;
            2) coolercontrol_manager_menu ;;
            3) third_party_community_scripts_info ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# PVE8 to PVE9 升级功能
pve8_to_pve9_upgrade() {
    block_non_pve9_destructive "PVE 8.x 升级到 PVE 9.x" || return 1
    log_step "开始 PVE 8.x 升级到 PVE 9.x"
    
    # 检查当前 PVE 版本
    local current_pve_version=$(pveversion | head -n1 | cut -d'/' -f2 | cut -d'-' -f1)
    local major_version=$(echo $current_pve_version | cut -d'.' -f1)
    
    if [[ "$major_version" != "8" ]]; then
        log_error "当前 PVE 版本为 $current_pve_version，不是 PVE 8.x 版本，无法执行此升级"
        log_info "PVE7 请先试用ISO或升级教程升级哦! ：https://pve.proxmox.com/wiki/Upgrade_from_7_to_8"
        log_tips "如果你已经是PVE 9.x了，你还来用这个脚本，敲你额头！"
        return 1
    fi
    
    log_error "此操作将把 PVE 8.x 宿主机 不可逆的 升级到 PVE 9.x"
    log_error "已知风险包括但不限于："
    log_error "  • 系统无法启动（内核/引导变更）"
    log_error "  • 虚拟机/容器配置文件丢失或损坏"
    log_error "  • ZFS 池无法导入或数据集损坏"
    log_error "  • 网络配置被重置，导致失联"
    log_error "  • 集群节点脱离，需要手动修复"
    log_error "  • 第三方订阅/源被禁用，恢复困难"
    log_error ""
    log_error "【必须】完成以下准备工作，否则升级后无法恢复："
    echo "  1. 全系统备份（推荐使用 PBS 或 dd 备份系统盘）"
    echo "  2. 手动备份 /etc/pve, /var/lib/pve-cluster, /etc/network"
    echo "  3. 确保有 IPMI / iDRAC / 物理访问或急救系统可用"
    echo "  4. 阅读官方升级指南：https://pve.proxmox.com/wiki/Upgrade_from_8_to_9"
    log_error ""
    log_error "本脚本不提供任何回滚功能，不承担任何数据丢失责任"
    log_error "本脚本不提供任何回滚功能，不承担任何数据丢失责任"
    log_error "本脚本不提供任何回滚功能，不承担任何数据丢失责任"
    # 确认用户要继续执行升级
    echo "您确定要继续升级吗？本次任务执行以下操作："
    echo "注意：升级过程中可能会遇到一些警告或错误，请根据提示进行处理！脚本无法处理故障提示！(脚本只能把提示扔给你..) )"
    read -p "输入 'yesido' 确认继续，其他任意键取消: " confirm
    if [[ "$confirm" != "yesido" ]]; then
        log_info "已取消升级操作，明智之举"
        return 0
    fi
    
    # 1. 更新当前系统到最新 PVE 8.x 版本
    log_info "更新当前系统到最新 PVE 8.x 版本..."
    if ! apt update && apt dist-upgrade -y; then
        log_error "更新 PVE 8.x 到最新版本失败了，请检查网络连接或源配置，或者前往作者的GitHub反馈issue.."
        return 1
    fi
    
    # 再次检查当前版本
    current_pve_version=$(pveversion | head -n1 | cut -d'/' -f2 | cut -d'-' -f1)
    log_info "更新后 PVE 版本: ${GREEN}$current_pve_version${NC}"
    
    # PVE8.4 自带这个包，此处无需检查安装，apt 源无此包会报错。
    # 2. 安装和运行 pve8to9 检查工具
    # log_info "安装 pve8to9 升级检查工具..."
    # if ! apt install -y pve8to9; then
    #     log_warn "pve8to9 工具安装失败，尝试手动安装..."
    #     # 尝试手动添加 PVE 8 仓库安装 pve8to9
    #     if ! apt install -y pve8to9; then
    #         log_error "无法安装 pve8to9 检查工具,奇怪！请检查网络连接或源配置，或者前往作者的GitHub反馈issue.."
    #         return 1
    #     fi
    # fi
    
    log_info "运行升级前检查..."
    echo -e "${CYAN}pve8to9 检查结果：${NC}"
    # 运行 pve8to9 检查，但不直接退出，而是捕获输出并分析
    echo -e "检查结果会保存到 /tmp/pve8to9_check.log 文件中，如出现故障建议查看该文件以获取详细信息"
    echo -e "再次提示，脚本只能做到把错误扔给你，无法修复问题，请根据提示自行解决(或前往作者issue反馈问题)..."
    local check_result=$(pve8to9 | tee /tmp/pve8to9_check.log)
    echo "$check_result"
    
    # 检查是否有 FAIL 标记（这意味着有严重错误需要修复）
    if echo "$check_result" | grep -E -i "FAIL" > /dev/null; then
        log_error "pve8to9 检查发现严重错误!! 一般是软件包冲突或是其他报错!建议修复后再进行升级！"
        echo -e "${YELLOW}升级检查结果详情：${NC}"
        cat /tmp/pve8to9_check.log
        read -p "您确定要忽略这些错误并继续升级吗？这不是在开玩笑！(y/N): " force_upgrade
        if [[ "$force_upgrade" != "y" && "$force_upgrade" != "Y" ]]; then
            log_info "由于存在严重错误，已取消升级操作...返回主界面"
            return 1
        fi
    else
        log_success "pve8to9 检查通过，没有发现严重错误，太好了！"
        
        # 检查是否有 WARNING 标记
        if echo "$check_result" | grep -E -i "WARN" > /dev/null; then
            log_warn "pve8to9 检查发现一些警告信息，请查看以上详情并根据需要处理。(有些可能是软件包没升级上去，不是关键软件包可以无视先升级喔)"
            read -p "是否继续升级？(Y/n): " continue_check
            if [[ "$continue_check" == "n" || "$continue_check" == "N" ]]; then
                log_info "已取消升级操作"
                return 0
            fi
        fi
    fi
    
    # 3. 安装 CPU 微码（如果提示需要）
    log_info "检查是否需要安装 CPU 微码..."
    if command -v lscpu &> /dev/null; then
        local cpu_vendor=$(lscpu | grep "Vendor ID" | awk '{print $3}')
        if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
            log_info "检测到 Intel CPU，安装 Intel 微码..."
            apt install -y intel-microcode
        elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
            log_info "检测到 AMD CPU，安装 AMD 微码..."
            apt install -y amd64-microcode
        fi
    fi
    
    # 4. 检查当前启动方式并更新引导配置
    log_info "检查系统启动方式..."
    local boot_method="unknown"
    if [[ -d "/boot/efi" ]]; then
        boot_method="efi"
        log_info "检测到 EFI 启动模式"
        # 为 EFI 系统配置 GRUB
        echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections -v -u
    else
        boot_method="bios"
        log_info "检测到 BIOS 启动模式"
        log_tips "怎么还在用BIOS启用呀？建议升级到UEFI启动方式，提升系统兼容性和安全性"
    fi
    
    # 5. 备份当前源文件
    log_info "备份当前源文件..."
    local backup_dir="/etc/pve-tools-9-bak"
    mkdir -p "$backup_dir"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # 备份各种源文件
    if [[ -f "/etc/apt/sources.list" ]]; then
        cp /etc/apt/sources.list "${backup_dir}/sources.list.backup.${timestamp}"
    fi
    
    if [[ -f "/etc/apt/sources.list.d/pve-enterprise.list" ]]; then
        cp /etc/apt/sources.list.d/pve-enterprise.list "${backup_dir}/pve-enterprise.list.backup.${timestamp}"
    fi

    # 备份 PVE 核心数据库
    log_info "备份 PVE 核心数据库..."
    if [[ -d "/var/lib/pve-cluster" ]]; then
        cp -r /var/lib/pve-cluster "${backup_dir}/pve-cluster.backup.${timestamp}"
        log_success "核心数据库已备份至 ${backup_dir}"
    fi
    
    # 6. 更新源到 Debian 13 (Trixie) 并添加 PVE 9.x 源
    log_info "更新软件源到 Debian 13 (Trixie)..."
    
    # 将所有 bookworm 源替换为 trixie
    log_step "替换 sources.list 和 pve-enterprise.list 中的 bookworm 为 trixie"
    sed -i 's/bookworm/trixie/g' /etc/apt/sources.list 2>/dev/null || true
    sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true
    
    # 创建 PVE 9.x 的 sources 配置文件
    log_step "创建 PVE 9.x 的 sources 配置文件..."
    cat > /etc/apt/sources.list.d/proxmox.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    # 创建 Ceph Squid 源配置文件
    log_step "创建 Ceph Squid 源配置文件..."
    cat > /etc/apt/sources.list.d/ceph.sources << EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    log_info "软件源已更新到 Debian 13 (Trixie) 和 PVE 9.x 配置"
    
    # 7. 再次运行升级前检查确认源更新无误
    log_info "再次运行 pve8to9 检查以确认源配置..."
    local final_check_result=$(pve8to9)
    if echo "$final_check_result" | grep -E -i "FAIL" > /dev/null; then
        log_error "pve8to9 最终检查发现错误，请手动检查源配置后再继续"
        echo "$final_check_result"
        return 1
    else
        log_success "源更新配置检查通过"
    fi
    
    # 8. 更新包列表并开始升级
    log_info "更新包列表..."
    if ! apt update; then
        log_error "更新包列表失败，请检查网络连接和源配置"
        return 1
    fi
    
    log_info "开始 PVE 9.x 升级过程，这可能需要较长时间..."
    log_warn "如果你正在使用Web UI内置的终端，建议改用SSH连接以防止连接中断"
    echo -e "${YELLOW}升级过程中可能会出现多个提示，通常按回车键或选择默认选项即可${NC}"
    
    # 使用非交互模式升级，自动回答问题
    DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"
    
    if [[ $? -ne 0 ]]; then
        log_error "PVE 升级过程失败，请查看日志并手动处理...如果是在看不明白可以试试问AI或者提交issue"
        return 1
    fi
    
    # 9. 清理无用包
    log_info "清理无用软件包..."
    apt autoremove -y
    apt autoclean
    
    # 10. 检查升级结果
    local new_pve_version=$(pveversion | head -n1 | cut -d'/' -f2 | cut -d'-' -f1)
    local new_major_version=$(echo $new_pve_version | cut -d'.' -f1)
    
    if [[ "$new_major_version" == "9" ]]; then
        log_success "（撒花）PVE 升级成功！新的 PVE 版本: ${GREEN}$new_pve_version${NC}"
        
        # 运行最终的升级后检查
        log_info "运行升级后检查..."
        pve8to9 2>/dev/null || true
        
        log_info "系统将在 30 秒后重启以完成升级..."
        log_success "如果一切顺利，重启后就能体验到PVE9啦！"
        log_warn "如果升级后出现问题，例如卡内核卡Grub，请先使用LiveCD抢修内核，提取日志文件后联系作者寻求帮助"
        echo -e "${YELLOW}按 Ctrl+C 可取消自动重启${NC}"
        sleep 30
        
        # 重启系统以完成升级
        log_info "正在重启系统以完成 PVE 9.x 升级..."
        reboot
    else
        log_error "升级完成后检查发现，PVE 版本仍为 $new_pve_version，升级可能未完全成功"
        log_tips "请手动检查系统状态，并确认是否需要重试升级"
        return 1
    fi
}

# 显示系统信息
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
show_menu() {
    show_banner 
    show_menu_option "" "请选择您需要的功能："
    show_menu_option "1" "日常优化与通知 ${CYAN}( 弹窗 / 温度 / 电源 / 邮件 )${NC}"
    show_menu_option "2" "软件源与系统升级 ${CYAN}( 换源 / 更新 / PVE升级 )${NC}"
    show_menu_option "3" "启动与内核管理 ${CYAN}( 内核 / GRUB )${NC}"
    show_menu_option "4" "硬件直通与显卡 ${CYAN}( IOMMU / GPU / RDM / NVMe )${NC}"
    show_menu_option "5" "虚拟机运维与导入 ${CYAN}( 镜像 / 备份 / 恢复 / Cloud-Init )${NC}"
    show_menu_option "6" "宿主机网络与防火墙 ${CYAN}( 网桥 / VLAN / Bond / 规则 )${NC}"
    show_menu_option "7" "存储与磁盘维护 ${CYAN}( 路径 / 挂载 / 清理 / Ceph )${NC}"
    show_menu_option "8" "诊断工具与项目信息 ${CYAN}( 系统信息 / 救砖 / 脚本管理 )${NC}"
    show_menu_option "9" "安全中心 ${CYAN}( 风险检查 / SSH加固 )${NC}"
    show_menu_option "10" "第三方工具 ${CYAN}( CoolerControl / Modules / 社区脚本 )${NC}"
    echo "$UI_DIVIDER"
    show_menu_option "0" "${RED}退出脚本${NC}"
    show_menu_footer
    echo
    echo -e "  ${YELLOW}Tips: ${SESSION_TIP:-一言获取失败，本次会话不再重试。}${NC}"
    echo
    echo -ne "  ${PRIMARY}请输入您的选择 [0-10]: ${NC}"
}
# 应急救砖工具箱菜单
show_menu_rescue() {
    while true; do
        clear
        show_menu_header "应急救砖工具箱"
        echo -e "${RED}警告：本工具箱用于修复因误操作导致的系统问题，请谨慎使用！${NC}"
        echo
        show_menu_option "1" "恢复官方 Web UI 文件 (重装 pve-manager / proxmox-widget-toolkit)"
        show_menu_option "2" "恢复官方 pve-qemu-kvm (修复修改版 QEMU 问题)"
        show_menu_option "3" "清理驱动黑名单 (i915/snd_hda_intel)"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case $choice in
            1) restore_proxmoxlib ;;
            2) restore_qemu_kvm ;;
            3) 
                if confirm_action "确定要清理显卡和声卡驱动的黑名单设置吗？"; then
                    log_info "正在清理黑名单配置..."
                    sed -i '/blacklist i915/d' /etc/modprobe.d/pve-blacklist.conf
                    sed -i '/blacklist snd_hda_intel/d' /etc/modprobe.d/pve-blacklist.conf
                    sed -i '/blacklist snd_hda_codec_hdmi/d' /etc/modprobe.d/pve-blacklist.conf
                    log_info "正在更新 initramfs..."
                    update-initramfs -u -k all
                    log_success "黑名单清理完成，请重启系统"
                fi
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：系统优化
menu_optimization() {
    while true; do
        clear
        echo "功能 1/2 请在外部SSH环境下使用该功能！否则会导致PVE WebUi重启导致Shell断开连接修改失效！"
        echo "不要犟！查看如何连接到PVE SSH教程：https://pve.oowo.cc/advanced/how-to-connect-ssh.html"
        show_menu_header "系统优化"
        show_menu_option "1" "删除订阅弹窗"
        show_menu_option "2" "${MAGENTA}一键优化 (换源+删弹窗+更新)${NC}"
        show_menu_option "3" "温度监控管理 ${CYAN}(CPU/硬盘监控设置)${NC}"
        show_menu_option "4" "CPU 电源模式配置"
        show_menu_option "5" "配置邮件通知 ${CYAN}(SMTP/Postfix)${NC}"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-6]: " choice
        case $choice in
            1) remove_subscription_popup ;;
            2) quick_setup ;;
            3) temp_monitoring_menu ;;
            4) cpupower ;;
            5) pve_mail_notification_setup ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：软件源与更新
menu_sources_updates() {
    while true; do
        clear
        show_menu_header "软件源与更新"
        show_menu_option "1" "更换软件源"
        show_menu_option "2" "更新系统软件包"
        show_menu_option "3" "${YELLOW}PVE 8.x 升级到 PVE 9.x${NC}"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case $choice in
            1) change_sources ;;
            2) update_system ;;
            3) pve8_to_pve9_upgrade ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：启动与内核
menu_boot_kernel() {
    while true; do
        clear
        show_menu_header "启动与内核"
        show_menu_option "1" "内核管理 ${CYAN}(内核切换/更新/清理)${NC}"
        show_menu_option "2" "查看/备份 GRUB 配置"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-2]: " choice
        case $choice in
            1) kernel_management_menu ;;
            2) 
                while true; do
                    clear
                    show_menu_header "GRUB 配置管理"
                    show_menu_option "1" "查看当前 GRUB 配置"
                    show_menu_option "2" "备份 GRUB 配置"
                    show_menu_option "3" "查看备份列表"
                    show_menu_option "4" "恢复 GRUB 备份"
                    show_menu_option "0" "返回上级菜单"
                    show_menu_footer
                    read -p "请选择操作 [0-4]: " grub_choice
                    case $grub_choice in
                        1) show_grub_config; pause_function ;;
                        2) 
                            echo "请输入备份备注："
                            read -p "> " note
                            backup_grub_with_note "${note:-手动备份}"
                            pause_function
                            ;;
                        3) list_grub_backups; pause_function ;;
                        4) restore_grub_backup ;;
                        0) break ;;
                        *) log_error "无效选择" ;;
                    esac
                done
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：直通与显卡
menu_gpu_passthrough() {
    while true; do
        clear
        show_menu_header "直通与显卡"
        show_menu_option "1" "Intel 核显虚拟化管理 (SR-IOV/GVT-g)"
        show_menu_option "2" "Intel 核显直通配置 (修改版 QEMU)"
        show_menu_option "3" "NVIDIA 显卡直通/虚拟化"
        show_menu_option "4" "AMD 独显直通"
        show_menu_option "5" "AMD 核显直通 (需自备 ROM / vBIOS)"
        show_menu_option "6" "硬件直通一键配置 (IOMMU)"
        show_menu_option "7" "磁盘/控制器直通 (RDM/PCIe/NVMe)"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-7]: " choice
        case $choice in
            1) igpu_management_menu ;;
            2) intel_gpu_passthrough ;;
            3) nvidia_gpu_management_menu ;;
            4) amd_gpu_management_menu ;;
            5) amd_igpu_management_menu ;;
            6) hw_passth ;;
            7) menu_disk_controller_passthrough ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 虚拟机/容器定时开关机管理
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

img_bytes_to_human() {
    local bytes="$1"
    if [[ -z "$bytes" || ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "?"
        return 0
    fi
    awk -v b="$bytes" 'BEGIN{
        split("B KB MB GB TB PB", u, " ");
        i=1; x=b;
        while (x>=1024 && i<6) {x/=1024; i++}
        if (i==1) printf "%d%s", b, u[i];
        else printf "%.1f%s", x, u[i];
    }'
}

img_discover_img_files() {
    vm_discover_disk_image_files
}

img_select_img_file() {
    local files
    files="$(img_discover_img_files)"
    if [[ -z "$files" ]]; then
        log_error "未发现磁盘镜像文件"
        log_tips "已扫描目录：/root、/var/lib/vz/template/iso、/home（支持 .img/.raw/.qcow2）"
        return 1
    fi

    {
        echo -e "${CYAN}已发现磁盘镜像文件：${NC}"
        echo "$files" | awk -F'|' '
            function human(x,   u,i){
                split("B KB MB GB TB PB", u, " ");
                i=1;
                while (x>=1024 && i<6){x/=1024;i++}
                if (i==1) return sprintf("%d%s", x, u[i]);
                return sprintf("%.1f%s", x, u[i]);
            }
            {
                printf "  [%d] %-9s %-16s %s\n", NR, human($2), $3, $1
            }'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择镜像序号 (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line path
    line="$(echo "$files" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    path="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$path" || ! -f "$path" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$path"
    return 0
}

img_select_vmid() {
    local vms
    vms="$(qm list 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}')"
    if [[ -z "$vms" ]]; then
        log_error "未发现虚拟机"
        log_tips "请先创建虚拟机后再操作。"
        return 1
    fi

    {
        echo -e "${CYAN}可用虚拟机列表：${NC}"
        echo "$vms" | awk -F'|' '{printf "  [%d] VMID: %-6s Name: %-22s Status: %s\n", NR, $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择虚拟机序号 (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line vmid
    line="$(echo "$vms" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    vmid="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$vmid" ]]; then
        log_error "无效选择"
        return 1
    fi
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi
    echo "$vmid"
    return 0
}

img_select_storage() {
    local stores
    stores="$(pvesm status 2>/dev/null | awk 'NR>1{print $1 "|" $2}')"
    if [[ -z "$stores" ]]; then
        local manual
        read -p "未能获取存储列表，请手动输入存储名（如 local-lvm）: " manual
        if [[ -z "$manual" ]]; then
            log_error "存储名不能为空"
            return 1
        fi
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}可用存储列表：${NC}"
        echo "$stores" | awk -F'|' '{printf "  [%d] %-18s (%s)\n", NR, $1, $2}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择存储序号 (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line store
    line="$(echo "$stores" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    store="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$store" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$store"
    return 0
}

img_convert_and_import_to_vm() {
    log_step "磁盘镜像转换并导入虚拟机"

    if ! command -v qemu-img >/dev/null 2>&1; then
        display_error "未找到 qemu-img" "请先安装：apt install -y qemu-utils"
        return 1
    fi
    if ! command -v qm >/dev/null 2>&1; then
        display_error "未找到 qm 命令" "请确认当前环境为 PVE 宿主机。"
        return 1
    fi

    local img_path
    img_path="$(img_select_img_file)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$img_path" ]]; then
        return 1
    fi

    local vmid
    vmid="$(img_select_vmid)"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local store
    store="$(img_select_storage)"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$store" ]]; then
        return 1
    fi

    local out_fmt
    read -p "请选择目标格式 (qcow2/raw) [qcow2]: " out_fmt
    out_fmt="${out_fmt:-qcow2}"
    if [[ "$out_fmt" != "qcow2" && "$out_fmt" != "raw" ]]; then
        display_error "不支持的格式: $out_fmt" "仅支持 qcow2/raw"
        return 1
    fi

    local ts ext out_path out_dir
    local src_fmt
    src_fmt="$(vm_detect_image_format "$img_path")"
    if [[ -z "$src_fmt" ]]; then
        display_error "无法识别镜像格式" "请确认文件可被 qemu-img 识别，且格式为 img/raw/qcow2。"
        return 1
    fi
    ts="$(date +%Y%m%d_%H%M%S)"
    ext="$out_fmt"
    out_dir="$(dirname "$img_path")"
    out_path="${out_dir}/vm-${vmid}-disk-import-${ts}.${ext}"
    if [[ -e "$out_path" ]]; then
        out_path="${out_dir}/vm-${vmid}-disk-import-${ts}-1.${ext}"
    fi

    clear
    show_menu_header "磁盘镜像转换并导入虚拟机"
    local sz
    sz="$(stat -c '%s' "$img_path" 2>/dev/null || echo "")"
    echo -e "${YELLOW}源镜像:${NC} $img_path"
    echo -e "${YELLOW}源格式:${NC} $src_fmt"
    if [[ -n "$sz" ]]; then
        echo -e "${YELLOW}大小:${NC} $(img_bytes_to_human "$sz")"
    fi
    echo -e "${YELLOW}目标 VMID:${NC} $vmid"
    echo -e "${YELLOW}目标存储:${NC} $store"
    echo -e "${YELLOW}目标格式:${NC} $out_fmt"
    echo -e "${YELLOW}临时输出:${NC} $out_path"
    echo -e "${UI_DIVIDER}"

    if ! confirm_action "开始转换并导入磁盘？"; then
        return 0
    fi

    log_step "开始转换（qemu-img convert）"
    if ! qemu-img convert -p -f "$src_fmt" -O "$out_fmt" "$img_path" "$out_path"; then
        display_error "镜像转换失败" "请检查镜像文件是否损坏，或查看日志输出。"
        return 1
    fi

    log_step "开始导入（qm importdisk）"
    local import_out vol
    if ! import_out="$(qm importdisk "$vmid" "$out_path" "$store" 2>&1)"; then
        echo "$import_out" | sed 's/^/  /'
        display_error "导入失败" "请检查存储名称与空间，或查看上方输出。"
        return 1
    fi

    vol="$(echo "$import_out" | sed -n "s/.*as '\\([^']\\+\\)'.*/\\1/p" | tail -n 1)"
    [[ -z "$vol" ]] && vol="$(echo "$import_out" | grep -oE "${store}:[^ ]+" | tail -n 1)"

    if [[ -n "$vol" ]]; then
        log_success "导入完成: $vol"
    else
        log_success "导入完成"
    fi

    local attach_bus attach_slot cfg
    local auto_attach="yes"
    read -p "是否自动挂载到 VM？(yes/no) [yes]: " auto_attach
    auto_attach="${auto_attach:-yes}"
    if [[ "$auto_attach" == "yes" || "$auto_attach" == "YES" ]]; then
        read -p "请选择总线类型 (scsi/sata/ide) [scsi]: " attach_bus
        attach_bus="${attach_bus:-scsi}"
        if [[ "$attach_bus" != "scsi" && "$attach_bus" != "sata" && "$attach_bus" != "ide" ]]; then
            log_warn "不支持的总线类型，跳过自动挂载: $attach_bus"
        else
            cfg="$(qm config "$vmid" 2>/dev/null || true)"
            if [[ -n "$vol" && -n "$cfg" ]] && echo "$cfg" | grep -Fq "$vol"; then
                log_info "检测到该卷已写入 VM 配置（可能为 unusedX 或已挂载），跳过自动挂载。"
            elif [[ -z "$vol" ]]; then
                log_info "未能解析导入卷 ID，跳过自动挂载。"
            else
                attach_slot="$(rdm_find_free_slot "$vmid" "$attach_bus" 2>/dev/null)" || true
                if [[ -z "$attach_slot" ]]; then
                    log_warn "未找到可用插槽，跳过自动挂载"
                else
                    if confirm_action "将磁盘挂载到 VM $vmid（${attach_slot} = ${vol}）"; then
                        if qm set "$vmid" "-$attach_slot" "$vol" >/dev/null 2>&1; then
                            log_success "已挂载: $attach_slot"
                        else
                            log_warn "自动挂载失败，请在 PVE WebUI 中手动添加该磁盘"
                        fi
                    fi
                fi
            fi
        fi
    fi

    local del_tmp="yes"
    read -p "是否删除临时输出文件 $out_path ？(yes/no) [yes]: " del_tmp
    del_tmp="${del_tmp:-yes}"
    if [[ "$del_tmp" == "yes" || "$del_tmp" == "YES" ]]; then
        rm -f "$out_path" >/dev/null 2>&1 || true
    fi

    display_success "处理完成" "如需从该磁盘引导，请在 VM 启动顺序中选择对应磁盘。"
    return 0
}

img_convert_import_menu() {
    clear
    show_menu_header "磁盘镜像导入（转换为 QCOW2/RAW）"
    echo -e "${CYAN}功能说明：${NC}"
    echo -e "  - 自动扫描：/root、/var/lib/vz/template/iso、/home 下的 .img/.raw/.qcow2 文件"
    echo -e "  - 自动识别源格式，使用 qemu-img 转换后，通过 qm importdisk 导入到指定 VM 与存储"
    echo -e "${UI_DIVIDER}"
    img_convert_and_import_to_vm
}

# ============ VM 高级运维功能 ============

vm_require_commands() {
    local missing=()
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        display_error "缺少命令: ${missing[*]}" "请确认当前运行环境为 PVE 宿主机，并安装缺失组件后重试。"
        return 1
    fi
}

vm_validate_new_vmid() {
    local vmid="$1"
    if [[ -z "$vmid" || ! "$vmid" =~ ^[0-9]+$ ]]; then
        log_error "新 VMID 必须是数字"
        return 1
    fi

    if qm status "$vmid" >/dev/null 2>&1; then
        log_error "VMID 已被虚拟机占用: $vmid"
        return 1
    fi

    if command -v pct >/dev/null 2>&1 && pct status "$vmid" >/dev/null 2>&1; then
        log_error "VMID 已被容器占用: $vmid"
        return 1
    fi

    return 0
}

vm_list_vm_records() {
    qm list 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}'
}

vm_show_vm_records() {
    local records="$1"
    {
        echo -e "${CYAN}可用虚拟机列表：${NC}"
        echo "$records" | awk -F'|' '{printf "  VMID: %-6s Name: %-22s Status: %s\n", $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2
}

vm_normalize_vmid_input() {
    printf '%s\n' "$1" | tr ', ' '\n\n' | awk 'NF' | sort -n -u
}

vm_collect_target_vmids() {
    local records
    records="$(vm_list_vm_records)"
    if [[ -z "$records" ]]; then
        log_error "未发现虚拟机"
        return 1
    fi

    vm_show_vm_records "$records"
    {
        show_menu_option "1" "单个 VM"
        show_menu_option "2" "多个 VM"
        show_menu_option "3" "全部 VM"
    } >&2

    local scope
    read -p "请选择目标范围 [1-3]: " scope
    case "$scope" in
        1)
            local vmid
            vmid="$(img_select_vmid)"
            local rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$vmid" ]] || return 1
            echo "$vmid"
            ;;
        2)
            local raw ids vmid
            read -p "请输入 VMID 列表（逗号或空格分隔）: " raw
            ids="$(vm_normalize_vmid_input "$raw")"
            if [[ -z "$ids" ]]; then
                log_error "未提供有效 VMID"
                return 1
            fi
            while IFS= read -r vmid; do
                validate_qm_vmid "$vmid" || return 1
            done <<< "$ids"
            echo "$ids"
            ;;
        3)
            echo "$records" | awk -F'|' '{print $1}'
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

vm_validate_backup_compress() {
    local compress="$1"
    case "$compress" in
        zstd|gzip|lzo) return 0 ;;
        *)
            display_error "不支持的压缩方式: $compress" "仅支持 zstd / gzip / lzo"
            return 1
            ;;
    esac
}

vm_validate_backup_mode() {
    local mode="$1"
    case "$mode" in
        snapshot|suspend|stop) return 0 ;;
        *)
            display_error "不支持的备份模式: $mode" "仅支持 snapshot / suspend / stop"
            return 1
            ;;
    esac
}

vm_validate_backup_keep_last() {
    local keep_last="$1"
    if [[ ! "$keep_last" =~ ^[0-9]+$ ]]; then
        display_error "保留份数必须是数字"
        return 1
    fi
}

vm_validate_backup_storage_name() {
    local store="$1"
    if [[ -z "$store" || ! "$store" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        display_error "备份存储名称不合法: $store" "请重新选择存储，避免将异常字符写入 root cron。"
        return 1
    fi
}

pve_tools_human_bytes() {
    local bytes="$1"

    if command -v numfmt >/dev/null 2>&1 && [[ "$bytes" =~ ^[0-9]+$ ]]; then
        numfmt --to=iec --suffix=B "$bytes" 2>/dev/null && return 0
    fi
    echo "$bytes"
}

pve_storage_status_records() {
    pvesm status 2>/dev/null | awk 'NR>1 {print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7}'
}

pve_storage_config_value() {
    local store="$1"
    local key="$2"

    pvesm config "$store" 2>/dev/null | awk -v key="$key" '
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ "^" key "([[:space:]]|:)") {
                sub("^" key "[[:space:]]*:?[[:space:]]*", "", line)
                print line
                exit
            }
        }
    '
}

pve_storage_file_backend() {
    local type="$1"

    case "$type" in
        dir|nfs|cifs|cephfs|glusterfs) return 0 ;;
        *) return 1 ;;
    esac
}

pve_storage_mount_path() {
    local store="$1"
    local type="$2"
    local path

    path="$(pve_storage_config_value "$store" path)"
    if [[ -n "$path" ]]; then
        echo "$path"
        return 0
    fi

    case "$type" in
        nfs|cifs|cephfs|glusterfs)
            echo "/mnt/pve/$store"
            return 0
            ;;
    esac

    return 1
}

pve_storage_content_subdir() {
    local content="$1"

    case "$content" in
        iso) echo "template/iso" ;;
        backup) echo "dump" ;;
        vztmpl) echo "template/cache" ;;
        snippets) echo "snippets" ;;
        images) echo "images" ;;
        rootdir) echo "private" ;;
        import) echo "import" ;;
        *) return 1 ;;
    esac
}

pve_storage_content_dir_override() {
    local store="$1"
    local content="$2"
    local content_dirs entry key value

    content_dirs="$(pve_storage_config_value "$store" content-dirs | tr -d ' ')"
    [[ -n "$content_dirs" ]] || return 1
    IFS=',' read -r -a entries <<< "$content_dirs"
    for entry in "${entries[@]}"; do
        key="${entry%%=*}"
        value="${entry#*=}"
        if [[ "$key" == "$content" && -n "$value" && "$value" != "$entry" ]]; then
            echo "$value"
            return 0
        fi
    done
    return 1
}

pve_storage_content_path() {
    local store="$1"
    local type="$2"
    local content="$3"
    local root subdir

    pve_storage_file_backend "$type" || return 1
    root="$(pve_storage_mount_path "$store" "$type")" || return 1
    subdir="$(pve_storage_content_dir_override "$store" "$content" || pve_storage_content_subdir "$content")" || return 1
    printf '%s/%s\n' "${root%/}" "$subdir"
}

pve_storage_list_content_paths() {
    local content="$1"
    local store type status total used avail percent path

    while IFS='|' read -r store type status total used avail percent; do
        [[ -n "$store" ]] || continue
        if vm_storage_supports_content "$store" "$content" && path="$(pve_storage_content_path "$store" "$type" "$content")"; then
            printf '%s|%s|%s|%s\n' "$store" "$type" "$status" "$path"
        fi
    done < <(pve_storage_status_records)
}

pve_storage_usage_text() {
    local path="$1"
    local target="$path"

    while [[ ! -e "$target" && "$target" != "/" ]]; do
        target="$(dirname "$target")"
    done
    if [[ -e "$target" ]]; then
        df -hP "$target" 2>/dev/null | awk 'NR==2 {printf "%s/%s 可用:%s 使用率:%s", $3, $2, $4, $5}'
    else
        echo "路径不存在或未挂载"
    fi
}

pve_storage_find_owner_by_path() {
    local file_path="$1"
    local content="${2:-backup}"
    local store type status path best_store="" best_len=0 len

    while IFS='|' read -r store type status path; do
        [[ -n "$path" ]] || continue
        if [[ "$file_path" == "$path/"* || "$file_path" == "$path" ]]; then
            len=${#path}
            if (( len > best_len )); then
                best_store="$store"
                best_len=$len
            fi
        fi
    done < <(pve_storage_list_content_paths "$content")

    [[ -n "$best_store" ]] && echo "$best_store" || echo "unknown"
}

pve_storage_location_panel() {
    if ! command -v pvesm >/dev/null 2>&1; then
        display_error "未找到 pvesm" "请在 Proxmox VE 节点上运行。"
        return 1
    fi

    clear
    show_menu_header "存储位置查询面板"
    echo -e "${YELLOW}说明:${NC} 文件级存储会显示可通过 SCP/SFTP 操作的目录；LVM/ZFS/RBD 等块存储不适合直接上传 ISO/备份文件。"
    echo "$UI_DIVIDER"

    local store type status total used avail percent contents root usage
    printf "%-18s %-10s %-8s %-18s %s\n" "存储" "类型" "状态" "内容类型" "根路径/说明"
    echo "$UI_DIVIDER"
    while IFS='|' read -r store type status total used avail percent; do
        [[ -n "$store" ]] || continue
        contents="$(pve_storage_config_value "$store" content | tr -d ' ')"
        if pve_storage_file_backend "$type" && root="$(pve_storage_mount_path "$store" "$type")"; then
            usage="$(pve_storage_usage_text "$root")"
            printf "%-18s %-10s %-8s %-18s %s (%s)\n" "$store" "$type" "$status" "${contents:-unknown}" "$root" "$usage"
        else
            printf "%-18s %-10s %-8s %-18s %s\n" "$store" "$type" "$status" "${contents:-unknown}" "块/对象存储：请通过 PVE 管理卷，不直接 SCP 文件"
        fi
    done < <(pve_storage_status_records)

    echo "$UI_DIVIDER"
    echo -e "${CYAN}常用上传路径:${NC}"
    local path
    local found=false
    while IFS='|' read -r store type status path; do
        found=true
        usage="$(pve_storage_usage_text "$path")"
        echo -e "  ${GREEN}[ISO]${NC} $store ($type): $path"
        echo "       磁盘: $usage"
        echo "       scp ./file.iso root@<PVE-IP>:\"$path/\""
    done < <(pve_storage_list_content_paths iso)
    [[ "$found" == true ]] || echo "  未发现支持 iso 内容类型的文件级存储。"

    found=false
    while IFS='|' read -r store type status path; do
        found=true
        usage="$(pve_storage_usage_text "$path")"
        echo -e "  ${GREEN}[备份]${NC} $store ($type): $path"
        echo "         磁盘: $usage"
        echo "         scp ./vzdump-qemu-100.vma.zst root@<PVE-IP>:\"$path/\""
    done < <(pve_storage_list_content_paths backup)
    [[ "$found" == true ]] || echo "  未发现支持 backup 内容类型的文件级存储。"
}

pve_storage_mount_wizard_validate_storage_id() {
    local storage_id="$1"

    if [[ -z "$storage_id" || ! "$storage_id" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{1,30}$ ]]; then
        display_error "存储 ID 不合法: $storage_id" "请使用字母、数字、点、下划线或短横线，长度 2-31。"
        return 1
    fi
    if pvesm status 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$storage_id"; then
        display_error "存储 ID 已存在: $storage_id" "请换一个名称，避免覆盖现有 PVE 存储。"
        return 1
    fi
}

pve_storage_mount_wizard_validate_mountpoint() {
    local mountpoint="$1"

    if [[ -z "$mountpoint" || "$mountpoint" != /* ]]; then
        display_error "挂载点必须是绝对路径"
        return 1
    fi
    case "$mountpoint" in
        /|/boot|/boot/*|/etc|/etc/*|/usr|/usr/*|/var|/var/lib/vz|/var/lib/vz/*|/root|/root/*)
            display_error "挂载点过于危险: $mountpoint" "建议使用 /mnt/pve/<存储ID> 或 /mnt/data/<名称>。"
            return 1
            ;;
    esac
}

pve_storage_mount_wizard() {
    block_non_pve9_destructive "磁盘挂载向导" || return 1

    local candidates idx pick line dev fstype size uuid mountpoint storage_id content_types current_mount backup_path fstab_line output

    if ! command -v lsblk >/dev/null 2>&1 || ! command -v pvesm >/dev/null 2>&1; then
        display_error "缺少 lsblk 或 pvesm" "请在 Proxmox VE 节点上运行。"
        return 1
    fi

    candidates="$(lsblk -rP -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINT,UUID 2>/dev/null | awk '
        function val(key,    pat, out) {
            pat = key "=\"[^\"]*\""
            if (match($0, pat)) {
                out = substr($0, RSTART + length(key) + 2, RLENGTH - length(key) - 3)
                return out
            }
            return ""
        }
        val("TYPE") == "part" && (val("FSTYPE") == "ext4" || val("FSTYPE") == "xfs") {
            print val("NAME") "|" val("FSTYPE") "|" val("SIZE") "|" val("MOUNTPOINT") "|" val("UUID")
        }
    ')"
    clear
    show_menu_header "磁盘挂载向导"
    echo -e "${RED}高风险提醒:${NC} 该向导只挂载已有 ext4/xfs 分区并添加 dir 存储，不会格式化磁盘。仍请先确认数据已备份。"
    echo -e "${YELLOW}已挂载分区、无文件系统分区、LVM/ZFS 成员不会作为候选。${NC}"
    echo "$UI_DIVIDER"

    if [[ -z "$candidates" ]]; then
        display_error "未发现可挂载的 ext4/xfs 分区" "可用 lsblk -f 手动确认磁盘状态。"
        return 1
    fi

    idx=1
    while IFS='|' read -r dev fstype size current_mount uuid; do
        printf "  [%d] %-22s %-6s %-8s 当前挂载:%s UUID:%s\n" "$idx" "$dev" "$fstype" "$size" "${current_mount:--}" "${uuid:--}"
        idx=$((idx + 1))
    done <<< "$candidates"
    echo "$UI_DIVIDER"

    read -p "请选择要挂载的分区序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$candidates" | awk -v n="$pick" 'NR==n{print}')"
    [[ -n "$line" ]] || return 1
    IFS='|' read -r dev fstype size current_mount uuid <<< "$line"

    if [[ -n "$current_mount" && "$current_mount" != "-" ]]; then
        display_error "该分区已挂载: $current_mount" "为避免误操作，请先人工确认是否已被使用。"
        return 1
    fi
    if [[ -z "$uuid" || "$uuid" == "-" ]]; then
        uuid="$(blkid -s UUID -o value "$dev" 2>/dev/null || true)"
    fi
    if [[ -z "$uuid" ]]; then
        display_error "无法读取分区 UUID: $dev" "请检查 blkid 输出。"
        return 1
    fi

    read -p "请输入新的 PVE 存储 ID [data-$(basename "$dev")]: " storage_id
    storage_id="${storage_id:-data-$(basename "$dev")}"
    pve_storage_mount_wizard_validate_storage_id "$storage_id" || return 1

    read -p "请输入挂载点 [/mnt/pve/$storage_id]: " mountpoint
    mountpoint="${mountpoint:-/mnt/pve/$storage_id}"
    pve_storage_mount_wizard_validate_mountpoint "$mountpoint" || return 1

    if findmnt -rn --target "$mountpoint" >/dev/null 2>&1; then
        display_error "挂载点已被占用: $mountpoint" "请换一个空目录。"
        return 1
    fi

    read -p "请输入 PVE 内容类型 [images,iso,backup,vztmpl,snippets]: " content_types
    content_types="${content_types:-images,iso,backup,vztmpl,snippets}"
    content_types="$(echo "$content_types" | tr -d ' ')"
    if [[ ! "$content_types" =~ ^[A-Za-z0-9_,]+$ ]]; then
        display_error "内容类型包含非法字符" "示例: images,iso,backup"
        return 1
    fi

    clear
    show_menu_header "确认挂载配置"
    echo -e "${CYAN}分区:${NC} $dev"
    echo -e "${CYAN}文件系统:${NC} $fstype"
    echo -e "${CYAN}UUID:${NC} $uuid"
    echo -e "${CYAN}挂载点:${NC} $mountpoint"
    echo -e "${CYAN}PVE 存储 ID:${NC} $storage_id"
    echo -e "${CYAN}内容类型:${NC} $content_types"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "挂载已有分区并添加 PVE dir 存储" "会修改 /etc/fstab、创建挂载点，并向 PVE 添加新的 dir 存储。" "UUID 或挂载点选错可能导致启动时挂载失败；存储 ID 选错会造成 PVE 存储配置混乱。" "请确认该分区确实是要复用的数据盘，已完成外部备份，并准备控制台回滚方式。" "MOUNT-DIR"; then
        return 0
    fi

    mkdir -p "$mountpoint" || {
        display_error "无法创建挂载点: $mountpoint"
        return 1
    }

    backup_file "/etc/fstab" backup_path >/dev/null 2>&1 || true
    if ! grep -Eq "UUID=${uuid}[[:space:]]" /etc/fstab 2>/dev/null; then
        fstab_line="UUID=${uuid} ${mountpoint} ${fstype} defaults,nofail 0 2"
        printf '%s\n' "$fstab_line" >> /etc/fstab
        log_success "已写入 /etc/fstab: $fstab_line"
    else
        log_warn "/etc/fstab 已存在 UUID=${uuid}，跳过重复写入。"
    fi

    if ! output="$(mount "$mountpoint" 2>&1)"; then
        [[ -n "$backup_path" && -f "$backup_path" ]] && cp -a "$backup_path" /etc/fstab >/dev/null 2>&1 || true
        echo "$output" | sed 's/^/  /'
        display_error "挂载失败，已尝试回滚 /etc/fstab" "请检查分区、文件系统和挂载点。"
        return 1
    fi

    if ! pvesm add dir "$storage_id" --path "$mountpoint" --content "$content_types" >/dev/null 2>&1; then
        umount "$mountpoint" >/dev/null 2>&1 || true
        [[ -n "$backup_path" && -f "$backup_path" ]] && cp -a "$backup_path" /etc/fstab >/dev/null 2>&1 || true
        display_error "PVE dir 存储添加失败，已尝试卸载并回滚 /etc/fstab" "请检查 pvesm 输出或手动添加存储。"
        return 1
    fi

    display_success "已有分区挂载并添加为 PVE dir 存储完成" "存储 ID: $storage_id，路径: $mountpoint"
}
vm_storage_supports_content() {
    local store="$1"
    local content="$2"
    local configured
    configured="$(pve_storage_config_value "$store" content | tr -d '[:space:]')"
    [[ -n "$configured" ]] || return 1
    echo ",$configured," | grep -Fq ",$content,"
}

vm_list_storages_by_content() {
    local content="$1"
    while IFS='|' read -r store type active; do
        [[ -n "$store" ]] || continue
        if vm_storage_supports_content "$store" "$content"; then
            printf '%s|%s|%s\n' "$store" "$type" "${active:-?}"
        fi
    done < <(pvesm status 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}')
}

vm_select_storage_by_content() {
    local content="$1"
    local prompt="${2:-请选择存储}"
    local stores
    stores="$(vm_list_storages_by_content "$content")"

    if [[ -z "$stores" ]]; then
        local manual
        read -p "未发现支持 ${content} 内容类型的存储，请手动输入存储名: " manual
        [[ -n "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}${prompt}${NC}"
        echo "$stores" | awk -F'|' '{printf "  [%d] %-18s 类型:%-12s 状态:%s\n", NR, $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "请选择存储序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1

    local line store
    line="$(echo "$stores" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    store="$(echo "$line" | awk -F'|' '{print $1}')"
    [[ -n "$store" ]] || return 1
    echo "$store"
}

vm_list_cluster_nodes() {
    if [[ -d /etc/pve/nodes ]]; then
        find /etc/pve/nodes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
    fi
}

vm_select_target_node() {
    local current_node nodes filtered
    current_node="$(hostname)"
    nodes="$(vm_list_cluster_nodes)"
    filtered="$(echo "$nodes" | grep -vx "$current_node" || true)"
    [[ -n "$filtered" ]] || return 1

    {
        echo -e "${CYAN}可迁移目标节点：${NC}"
        echo "$filtered" | awk '{printf "  [%d] %s\n", NR, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line
    read -p "请选择目标节点序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$filtered" | awk -v n="$pick" 'NR==n{print $1}')"
    [[ -n "$line" ]] || return 1
    echo "$line"
}

vm_find_free_disk_slot() {
    local vmid="$1"
    local bus="$2"
    local max_idx=0
    case "$bus" in
        scsi) max_idx=30 ;;
        sata) max_idx=5 ;;
        ide) max_idx=3 ;;
        virtio) max_idx=15 ;;
        *) return 1 ;;
    esac

    local cfg
    cfg="$(qm config "$vmid" 2>/dev/null)"
    [[ -n "$cfg" ]] || return 1

    local i
    for ((i=0; i<=max_idx; i++)); do
        if ! echo "$cfg" | grep -qE "^${bus}${i}:"; then
            echo "${bus}${i}"
            return 0
        fi
    done
    return 1
}

vm_find_free_net_index() {
    local vmid="$1"
    local cfg used i
    cfg="$(qm config "$vmid" 2>/dev/null)"
    used="$(echo "$cfg" | awk -F'[: ]' '/^net[0-9]+:/{gsub("net","",$1); print $1}' | sort -n | uniq)"
    for ((i=0; i<=31; i++)); do
        if ! echo "$used" | grep -qx "$i"; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

vm_select_disk_slot() {
    local vmid="$1"
    local slots
    slots="$(qm config "$vmid" 2>/dev/null | grep -E '^(scsi|sata|virtio|ide)[0-9]+:' | grep -v 'cloudinit')"
    [[ -n "$slots" ]] || return 1

    {
        echo -e "${CYAN}当前磁盘插槽：${NC}"
        echo "$slots" | awk '{printf "  [%d] %s\n", NR, $0}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line slot
    read -p "请选择磁盘序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$slots" | awk -v n="$pick" 'NR==n{print $0}')"
    slot="${line%%:*}"
    [[ -n "$slot" ]] || return 1
    echo "$slot"
}

vm_select_net_slot() {
    local vmid="$1"
    local nets
    nets="$(qm config "$vmid" 2>/dev/null | grep -E '^net[0-9]+:')"
    [[ -n "$nets" ]] || return 1

    {
        echo -e "${CYAN}当前网卡列表：${NC}"
        echo "$nets" | awk '{printf "  [%d] %s\n", NR, $0}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line slot
    read -p "请选择网卡序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$nets" | awk -v n="$pick" 'NR==n{print $0}')"
    slot="${line%%:*}"
    [[ -n "$slot" ]] || return 1
    echo "$slot"
}

vm_get_qm_value() {
    local vmid="$1"
    local key="$2"
    qm config "$vmid" 2>/dev/null | awk -v key="$key" '$0 ~ "^" key ": " { sub("^[^:]+: ", "", $0); print; exit }'
}

vm_is_template() {
    local vmid="$1"
    [[ "$(vm_get_qm_value "$vmid" "template")" == "1" ]]
}

vm_network_strip_mac() {
    echo "$1" | sed -E 's/^([A-Za-z0-9_-]+)=[0-9A-Fa-f:]{17}(,|$)/\1\2/' | sed -E 's/,,+/,/g; s/,$//'
}

vm_network_set_option() {
    local current="$1"
    local key="$2"
    local value="$3"
    if echo "$current" | grep -qE "(^|,)$key="; then
        echo "$current" | sed -E "s/(^|,)$key=[^,]*/\1$key=$value/" | sed -E 's/^,//; s/,,+/,/g; s/,$//'
    else
        echo "$current,$key=$value" | sed -E 's/^,//; s/,,+/,/g; s/,$//'
    fi
}

vm_network_remove_option() {
    local current="$1"
    local key="$2"
    echo "$current" | sed -E "s/(^|,)$key=[^,]*//g" | sed -E 's/^,//; s/,,+/,/g; s/,$//'
}

vm_detect_image_format() {
    local image_path="$1"
    qemu-img info "$image_path" 2>/dev/null | awk -F': ' '/^file format:/{print $2; exit}'
}

vm_discover_disk_image_files() {
    local roots=("/root" "/var/lib/vz/template/iso" "/home")
    local root
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            find "$root" -xdev -type f \( -iname '*.img' -o -iname '*.raw' -o -iname '*.qcow2' \) -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
        fi
    done | sort -u
}

vm_discover_backup_archives() {
    local roots=("/var/lib/vz/dump" "/mnt/pve" "/backup" "/backups" "/root")
    local root
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            find "$root" -maxdepth 3 -type f \( -name 'vzdump-qemu-*.vma' -o -name 'vzdump-qemu-*.vma.gz' -o -name 'vzdump-qemu-*.vma.lzo' -o -name 'vzdump-qemu-*.vma.zst' \) -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
        fi
    done | sort -u
}

vm_discover_all_backup_archives() {
    local roots=("/var/lib/vz/dump" "/mnt/pve" "/backup" "/backups" "/root")
    local root
    for root in "${roots[@]}"; do
        if [[ -d "$root" ]]; then
            find "$root" -maxdepth 4 -type f \( \
                -name 'vzdump-qemu-*.vma' -o -name 'vzdump-qemu-*.vma.gz' -o -name 'vzdump-qemu-*.vma.lzo' -o -name 'vzdump-qemu-*.vma.zst' -o \
                -name 'vzdump-lxc-*.tar' -o -name 'vzdump-lxc-*.tar.gz' -o -name 'vzdump-lxc-*.tar.lzo' -o -name 'vzdump-lxc-*.tar.zst' \
            \) -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
        fi
    done | sort -u
}

vm_backup_archive_guest_type() {
    local file_name="$1"

    case "$(basename "$file_name")" in
        vzdump-qemu-*) echo "VM" ;;
        vzdump-lxc-*) echo "CT" ;;
        *) echo "未知" ;;
    esac
}

vm_backup_archive_vmid() {
    local file_name
    file_name="$(basename "$1")"
    echo "$file_name" | sed -nE 's/^vzdump-(qemu|lxc)-([0-9]+)-.*/\2/p'
}

vm_backup_transfer_guide() {
    if ! command -v pvesm >/dev/null 2>&1; then
        display_error "未找到 pvesm" "请在 Proxmox VE 节点上运行。"
        return 1
    fi

    local archives
    archives="$(vm_discover_all_backup_archives)"

    clear
    show_menu_header "备份文件跨机恢复引导"
    echo -e "${YELLOW}说明:${NC} PVE 备份文件通常放在支持 backup 内容类型的存储 dump 目录中；跨机迁移时把备份文件复制到目标节点对应 dump 目录后，再使用 Web UI 或 qmrestore/pct restore 恢复。"
    echo "$UI_DIVIDER"

    if [[ -z "$archives" ]]; then
        log_warn "未发现常见 vzdump 备份文件。"
    else
        printf "%-5s %-6s %-8s %-10s %-16s %s\n" "序号" "类型" "VMID" "大小" "时间" "文件"
        echo "$UI_DIVIDER"
        local idx=1 path size mtime type vmid store
        while IFS='|' read -r path size mtime; do
            type="$(vm_backup_archive_guest_type "$path")"
            vmid="$(vm_backup_archive_vmid "$path")"
            store="$(pve_storage_find_owner_by_path "$path" backup)"
            printf "%-5s %-6s %-8s %-10s %-16s %s\n" "$idx" "$type" "${vmid:-?}" "$(pve_tools_human_bytes "$size")" "$mtime" "$path"
            echo "      存储: $store"
            idx=$((idx + 1))
        done <<< "$archives"
    fi

    echo "$UI_DIVIDER"
    echo -e "${CYAN}当前节点可用于上传/恢复的备份目录:${NC}"
    local path found=false
    while IFS='|' read -r store type status path; do
        found=true
        echo "  - $store ($type): $path"
        echo "    从本地上传到目标 PVE: scp ./vzdump-qemu-100.vma.zst root@<目标PVE-IP>:\"$path/\""
    done < <(pve_storage_list_content_paths backup)
    [[ "$found" == true ]] || echo "  未发现支持 backup 内容类型的文件级存储。"

    echo "$UI_DIVIDER"
    echo -e "${CYAN}从当前机器下载到本地电脑示例:${NC}"
    echo "  scp root@<当前PVE-IP>:\"/var/lib/vz/dump/vzdump-qemu-100.vma.zst\" ./"
    echo -e "${CYAN}目标机器恢复示例:${NC}"
    echo "  VM: qmrestore /var/lib/vz/dump/vzdump-qemu-100.vma.zst <新VMID> --storage <磁盘存储>"
    echo "  CT: pct restore <新CTID> /var/lib/vz/dump/vzdump-lxc-100.tar.zst --storage <rootfs存储>"
    echo -e "${YELLOW}提示:${NC} NFS/CIFS 等共享备份存储在多节点间可能路径一致，但仍要确认目标节点能访问同一存储。"
}

pve_guest_exists() {
    local guest_type="$1"
    local vmid="$2"

    [[ "$vmid" =~ ^[0-9]+$ ]] || return 1

    case "$guest_type" in
        VM|vm|qemu)
            [[ -f "/etc/pve/qemu-server/${vmid}.conf" ]] && return 0
            command -v qm >/dev/null 2>&1 && qm status "$vmid" >/dev/null 2>&1
            ;;
        CT|ct|lxc)
            [[ -f "/etc/pve/lxc/${vmid}.conf" ]] && return 0
            command -v pct >/dev/null 2>&1 && pct status "$vmid" >/dev/null 2>&1
            ;;
        *)
            pve_guest_exists VM "$vmid" || pve_guest_exists CT "$vmid"
            ;;
    esac
}

garbage_cleanup_sum_sizes() {
    awk -F'|' '{sum += $2} END {print sum + 0}'
}

garbage_cleanup_count_records() {
    awk 'NF {count++} END {print count + 0}'
}

garbage_cleanup_temp_file_candidates() {
    local age_days="${1:-3}"

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=3
    if [[ -d /tmp ]]; then
        find /tmp -maxdepth 1 -type f \( \
            -name 'pve-tools-*' -o \
            -name 'pve-third-party-*' -o \
            -name 'fastpve-install.*.sh' -o \
            -name 'pve8to9_check.log' -o \
            -name 'pve-qemu-kvm.deb' \
        \) -mtime +"$age_days" -printf '%p|%s|%TY-%Tm-%Td %TH:%TM|临时文件\n' 2>/dev/null || true
    fi
}

garbage_cleanup_pve_tools_old_file_candidates() {
    local age_days="${1:-90}"
    local root

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=90
    for root in "/var/backups/pve-tools" "$VM_CONFIG_EXPORT_DIR"; do
        if [[ -d "$root" ]]; then
            find "$root" -type f -mtime +"$age_days" -printf '%p|%s|%TY-%Tm-%Td %TH:%TM|PVE-Tools 旧文件\n' 2>/dev/null || true
        fi
    done
}

garbage_cleanup_print_file_records() {
    local records="$1"
    local idx=1 path size mtime reason

    printf "%-5s %-10s %-16s %-18s %s\n" "序号" "大小" "时间" "类型" "文件"
    echo "$UI_DIVIDER"
    while IFS='|' read -r path size mtime reason; do
        [[ -n "$path" ]] || continue
        printf "%-5s %-10s %-16s %-18s %s\n" "$idx" "$(pve_tools_human_bytes "$size")" "$mtime" "$reason" "$path"
        idx=$((idx + 1))
    done <<< "$records"
}

garbage_cleanup_delete_file_records() {
    local records="$1"
    local success=0 failed=0 skipped=0 path size mtime reason mode answer

    if [[ -z "$records" ]]; then
        log_warn "没有可删除的候选文件。"
        return 0
    fi

    read -p "删除模式：输入 all 批量删除，输入 item 逐项确认 [item]: " mode
    mode="${mode:-item}"
    [[ "$mode" == "all" || "$mode" == "item" ]] || mode="item"

    while IFS='|' read -r path size mtime reason; do
        [[ -n "$path" && -f "$path" ]] || {
            skipped=$((skipped + 1))
            continue
        }
        if [[ "$mode" == "item" ]]; then
            read -p "删除 $path ? 输入 yes 确认: " answer
            if [[ "$answer" != "yes" && "$answer" != "YES" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
        fi
        if rm -f -- "$path"; then
            log_success "已删除: $path"
            success=$((success + 1))
        else
            log_error "删除失败: $path"
            failed=$((failed + 1))
        fi
    done <<< "$records"

    log_info "删除完成：成功 $success，失败 $failed，跳过 $skipped"
}

garbage_cleanup_basic() {
    block_non_pve9_destructive "垃圾清理（缓存/日志/临时文件）" || return 1

    local temp_age journal_days pve_age auto_remove records total_size
    read -p "清理 /tmp 中超过多少天的 PVE-Tools 临时文件 [3]: " temp_age
    temp_age="${temp_age:-3}"
    [[ "$temp_age" =~ ^[0-9]+$ ]] || temp_age=3

    read -p "systemd-journal 保留天数 [14]: " journal_days
    journal_days="${journal_days:-14}"
    [[ "$journal_days" =~ ^[0-9]+$ ]] || journal_days=14

    read -p "PVE-Tools 备份/导出文件保留天数 [90]: " pve_age
    pve_age="${pve_age:-90}"
    [[ "$pve_age" =~ ^[0-9]+$ ]] || pve_age=90

    read -p "是否执行 apt autoremove 清理孤立依赖？输入 yes 启用 [no]: " auto_remove
    auto_remove="${auto_remove:-no}"

    records="$(
        garbage_cleanup_temp_file_candidates "$temp_age"
        garbage_cleanup_pve_tools_old_file_candidates "$pve_age"
    )"
    total_size="$(echo "$records" | garbage_cleanup_sum_sizes)"

    clear
    show_menu_header "垃圾清理预览"
    echo -e "${CYAN}将执行:${NC}"
    echo "  - apt-get autoclean 清理过期软件包缓存"
    echo "  - journalctl --vacuum-time=${journal_days}d 压缩系统日志保留窗口"
    echo "  - 删除超过 ${temp_age} 天的 PVE-Tools 临时文件"
    echo "  - 删除超过 ${pve_age} 天的 PVE-Tools 备份/导出文件"
    [[ "$auto_remove" == "yes" || "$auto_remove" == "YES" ]] && echo "  - apt-get autoremove -y 清理孤立依赖"
    echo "$UI_DIVIDER"
    if [[ -n "$records" ]]; then
        garbage_cleanup_print_file_records "$records"
        echo "$UI_DIVIDER"
        echo -e "${YELLOW}候选文件合计:${NC} $(pve_tools_human_bytes "$total_size")"
    else
        echo "  未发现符合年龄条件的 PVE-Tools 临时/旧文件。"
    fi

    if ! confirm_high_risk_action "执行垃圾清理" "会删除上方列出的本工具临时/旧文件，并清理 apt 缓存与 journal 日志窗口。" "文件删除不可逆；apt autoremove 如果启用，可能移除系统认为不再需要的依赖包。" "请确认候选列表只包含可丢弃文件，重要备份已另存。" "CLEAN"; then
        return 0
    fi

    log_step "清理 apt 过期缓存..."
    apt-get autoclean -y || log_warn "apt-get autoclean 执行失败，请检查 apt 状态。"

    if [[ "$auto_remove" == "yes" || "$auto_remove" == "YES" ]]; then
        log_step "清理孤立依赖..."
        apt-get autoremove -y || log_warn "apt-get autoremove 执行失败，请检查 apt 状态。"
    fi

    if command -v journalctl >/dev/null 2>&1; then
        log_step "压缩 systemd journal 日志..."
        journalctl --vacuum-time="${journal_days}d" || log_warn "journalctl 日志清理失败。"
    fi

    garbage_cleanup_delete_file_records "$records"
}

garbage_cleanup_backup_candidates() {
    local mode="${1:-both}"
    local age_days="${2:-180}"
    local now cutoff path size mtime type vmid epoch old orphan reason

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=180
    now="$(date +%s)"
    cutoff=$((now - age_days * 86400))

    while IFS='|' read -r path size mtime; do
        [[ -n "$path" && -f "$path" ]] || continue
        type="$(vm_backup_archive_guest_type "$path")"
        vmid="$(vm_backup_archive_vmid "$path")"
        epoch="$(stat -c '%Y' "$path" 2>/dev/null || echo 0)"
        old=0
        orphan=0
        reason=""

        if [[ "$epoch" =~ ^[0-9]+$ ]] && (( epoch > 0 && epoch < cutoff )); then
            old=1
            reason="超过 ${age_days} 天"
        fi
        if [[ -n "$vmid" && "$type" != "未知" ]] && ! pve_guest_exists "$type" "$vmid"; then
            orphan=1
            [[ -n "$reason" ]] && reason+=","
            reason+="无对应 ${type} ${vmid}"
        fi

        case "$mode" in
            old) (( old == 1 )) || continue ;;
            orphan) (( orphan == 1 )) || continue ;;
            both|*) (( old == 1 || orphan == 1 )) || continue ;;
        esac
        printf '%s|%s|%s|%s|%s|%s\n' "$path" "$size" "$mtime" "$type" "${vmid:-?}" "$reason"
    done < <(vm_discover_all_backup_archives)
}

garbage_cleanup_print_backup_records() {
    local records="$1"
    local idx=1 path size mtime type vmid reason

    printf "%-5s %-5s %-7s %-10s %-16s %-24s %s\n" "序号" "类型" "VMID" "大小" "时间" "原因" "文件"
    echo "$UI_DIVIDER"
    while IFS='|' read -r path size mtime type vmid reason; do
        [[ -n "$path" ]] || continue
        printf "%-5s %-5s %-7s %-10s %-16s %-24s %s\n" "$idx" "$type" "$vmid" "$(pve_tools_human_bytes "$size")" "$mtime" "$reason" "$path"
        idx=$((idx + 1))
    done <<< "$records"
}

garbage_cleanup_delete_backup_records() {
    local records="$1"
    local success=0 failed=0 skipped=0 path size mtime type vmid reason mode answer

    if [[ -z "$records" ]]; then
        log_warn "没有可删除的备份候选。"
        return 0
    fi

    read -p "删除模式：输入 all 批量删除，输入 item 逐项确认 [item]: " mode
    mode="${mode:-item}"
    [[ "$mode" == "all" || "$mode" == "item" ]] || mode="item"

    while IFS='|' read -r path size mtime type vmid reason; do
        [[ -n "$path" && -f "$path" ]] || {
            skipped=$((skipped + 1))
            continue
        }
        if [[ "$mode" == "item" ]]; then
            echo "备份: ${type:-?} ${vmid:-?} | $(pve_tools_human_bytes "$size") | ${reason:-未标注原因}"
            read -p "删除 $path ? 输入 yes 确认: " answer
            if [[ "$answer" != "yes" && "$answer" != "YES" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
        fi
        if rm -f -- "$path"; then
            log_success "已删除备份: $path"
            success=$((success + 1))
        else
            log_error "备份删除失败: $path"
            failed=$((failed + 1))
        fi
    done <<< "$records"

    log_info "备份清理完成：成功 $success，失败 $failed，跳过 $skipped"
}

garbage_cleanup_prune_backups() {
    block_non_pve9_destructive "清理过期/无主备份文件" || return 1
    vm_require_commands pvesm || return 1

    local scope age_days records total_size
    clear
    show_menu_header "备份文件清理"
    show_menu_option "1" "只列出无对应 VM/CT 的备份"
    show_menu_option "2" "只列出超过指定天数的备份"
    show_menu_option "3" "同时列出无主备份和过期备份"
    echo "$UI_DIVIDER"
    read -p "请选择筛选范围 [3]: " scope
    scope="${scope:-3}"
    case "$scope" in
        1) scope="orphan" ;;
        2) scope="old" ;;
        *) scope="both" ;;
    esac

    read -p "过期备份阈值天数 [180]: " age_days
    age_days="${age_days:-180}"
    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=180

    records="$(garbage_cleanup_backup_candidates "$scope" "$age_days")"
    clear
    show_menu_header "备份文件清理预览"
    if [[ -z "$records" ]]; then
        log_warn "未发现符合条件的备份文件。"
        return 0
    fi

    garbage_cleanup_print_backup_records "$records"
    total_size="$(echo "$records" | garbage_cleanup_sum_sizes)"
    echo "$UI_DIVIDER"
    echo -e "${YELLOW}候选备份合计:${NC} $(pve_tools_human_bytes "$total_size")"
    echo -e "${YELLOW}提醒:${NC} NFS/CIFS 共享备份可能仍被其他节点使用，删除前请确认跨机恢复需求。"

    if ! confirm_high_risk_action "删除上方列出的 vzdump 备份文件" "会永久删除备份文件，删除后无法通过这些备份恢复 VM/CT。" "如果误删最后一个可用备份，后续故障将缺少恢复点。" "请确认已有其他可用备份或确定这些备份不再需要。" "DELETE-BACKUP"; then
        return 0
    fi

    garbage_cleanup_delete_backup_records "$records"
}

garbage_cleanup_snapshot_candidates() {
    local age_days="${1:-90}"
    local cutoff conf vmid guest_type

    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=90
    cutoff=$(($(date +%s) - age_days * 86400))

    for conf in /etc/pve/qemu-server/*.conf /etc/pve/lxc/*.conf; do
        [[ -f "$conf" ]] || continue
        vmid="$(basename "$conf" .conf)"
        guest_type="VM"
        [[ "$conf" == /etc/pve/lxc/* ]] && guest_type="CT"
        awk -v guest_type="$guest_type" -v vmid="$vmid" -v cutoff="$cutoff" '
            /^\[[^]]+\]$/ {
                snap = $0
                gsub(/^\[/, "", snap)
                gsub(/\]$/, "", snap)
                next
            }
            snap != "" && /^snaptime:[[:space:]]*[0-9]+/ {
                ts = $2
                if (ts < cutoff) {
                    print guest_type "|" vmid "|" snap "|" ts
                }
                snap = ""
            }
        ' "$conf"
    done
}

garbage_cleanup_prune_snapshots() {
    block_non_pve9_destructive "清理旧快照" || return 1

    local age_days records count idx guest_type vmid snapshot_name epoch time_text mode answer success=0 failed=0 skipped=0
    read -p "列出超过多少天的快照 [90]: " age_days
    age_days="${age_days:-90}"
    [[ "$age_days" =~ ^[0-9]+$ ]] || age_days=90

    records="$(garbage_cleanup_snapshot_candidates "$age_days")"
    clear
    show_menu_header "旧快照清理预览"
    if [[ -z "$records" ]]; then
        log_warn "未发现超过 ${age_days} 天且带 snaptime 的 VM/CT 快照。"
        return 0
    fi

    printf "%-5s %-5s %-7s %-24s %-20s\n" "序号" "类型" "VMID" "快照名" "创建时间"
    echo "$UI_DIVIDER"
    idx=1
    while IFS='|' read -r guest_type vmid snapshot_name epoch; do
        [[ -n "$snapshot_name" ]] || continue
        time_text="$(date -d "@$epoch" '+%F %T' 2>/dev/null || echo "$epoch")"
        printf "%-5s %-5s %-7s %-24s %-20s\n" "$idx" "$guest_type" "$vmid" "$snapshot_name" "$time_text"
        idx=$((idx + 1))
    done <<< "$records"
    count="$(echo "$records" | garbage_cleanup_count_records)"
    echo "$UI_DIVIDER"
    echo -e "${YELLOW}候选快照数量:${NC} $count"

    if ! confirm_high_risk_action "删除上方列出的旧快照" "删除快照后将失去对应时间点的快速回滚能力。" "如果快照是业务回退基线，误删后只能依赖外部备份恢复。" "请确认这些快照已经过期，且已有必要的外部备份。" "DELETE-SNAP"; then
        return 0
    fi

    read -p "删除模式：输入 all 批量删除，输入 item 逐项确认 [item]: " mode
    mode="${mode:-item}"
    [[ "$mode" == "all" || "$mode" == "item" ]] || mode="item"

    while IFS='|' read -r guest_type vmid snapshot_name epoch; do
        [[ -n "$snapshot_name" ]] || continue
        if [[ "$mode" == "item" ]]; then
            read -p "删除 ${guest_type} ${vmid} 快照 ${snapshot_name} ? 输入 yes 确认: " answer
            if [[ "$answer" != "yes" && "$answer" != "YES" ]]; then
                skipped=$((skipped + 1))
                continue
            fi
        fi

        if [[ "$guest_type" == "VM" ]]; then
            if qm delsnapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
                log_success "已删除 VM $vmid 快照: $snapshot_name"
                success=$((success + 1))
            else
                log_error "删除 VM $vmid 快照失败: $snapshot_name"
                failed=$((failed + 1))
            fi
        else
            if pct delsnapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
                log_success "已删除 CT $vmid 快照: $snapshot_name"
                success=$((success + 1))
            else
                log_error "删除 CT $vmid 快照失败: $snapshot_name"
                failed=$((failed + 1))
            fi
        fi
    done <<< "$records"

    log_info "快照清理完成：成功 $success，失败 $failed，跳过 $skipped"
}

garbage_cleanup_collect_referenced_volumes() {
    {
        grep -hoE '[A-Za-z0-9_.-]+:(vm|base|subvol)-[0-9]+-[^,[:space:]]+' /etc/pve/qemu-server/*.conf 2>/dev/null || true
        grep -hoE '[A-Za-z0-9_.-]+:(vm|base|subvol)-[0-9]+-[^,[:space:]]+' /etc/pve/lxc/*.conf 2>/dev/null || true
    } | sort -u
}

garbage_cleanup_orphan_disk_report() {
    vm_require_commands pvesm || return 1

    local refs store type status total used avail percent content line volid size vmid owner_id records=""
    refs="$(garbage_cleanup_collect_referenced_volumes)"

    while IFS='|' read -r store type status total used avail percent; do
        [[ -n "$store" ]] || continue
        for content in images rootdir; do
            vm_storage_supports_content "$store" "$content" || continue
            while read -r line; do
                [[ -n "$line" ]] || continue
                volid="$(echo "$line" | awk '{print $1}')"
                size="$(echo "$line" | awk '{print $4}')"
                vmid="$(echo "$line" | awk '{print $5}')"
                [[ "$volid" =~ :((vm|base|subvol)-[0-9]+-) ]] || continue
                if echo "$refs" | grep -Fxq "$volid"; then
                    continue
                fi
                owner_id="$(echo "$volid" | sed -nE 's/.*:(vm|base|subvol)-([0-9]+)-.*/\2/p')"
                if [[ -n "$owner_id" ]] && pve_guest_exists any "$owner_id"; then
                    continue
                fi
                records+="${volid}|${size:-0}|${vmid:-${owner_id:-?}}|${content}|${store}"$'\n'
            done < <(pvesm list "$store" --content "$content" 2>/dev/null | awk 'NR>1')
        done
    done < <(pve_storage_status_records)

    clear
    show_menu_header "疑似孤立磁盘扫描（只读）"
    echo -e "${YELLOW}说明:${NC} 该功能只扫描，不删除。底层卷误删风险很高，请先在 Web UI / VM 配置中二次核对。"
    echo "$UI_DIVIDER"
    if [[ -z "$records" ]]; then
        log_success "未发现明显的孤立磁盘候选。"
        return 0
    fi

    printf "%-5s %-18s %-8s %-10s %-8s %s\n" "序号" "存储" "VMID" "内容" "大小" "卷"
    echo "$UI_DIVIDER"
    local idx=1
    while IFS='|' read -r volid size vmid content store; do
        [[ -n "$volid" ]] || continue
        printf "%-5s %-18s %-8s %-10s %-8s %s\n" "$idx" "$store" "$vmid" "$content" "$(pve_tools_human_bytes "$size")" "$volid"
        echo "      人工核对后可用命令: pvesm free \"$volid\""
        idx=$((idx + 1))
    done <<< "$records"
    echo "$UI_DIVIDER"
    echo -e "${RED}未在脚本中提供自动删除孤立磁盘入口。${NC}"
}

garbage_cleanup_scan_report() {
    local temp_records old_records backup_records snap_records
    local temp_count old_count backup_count snap_count apt_cache_size pve_backup_size pve_export_size

    temp_records="$(garbage_cleanup_temp_file_candidates 3)"
    old_records="$(garbage_cleanup_pve_tools_old_file_candidates 90)"
    backup_records="$(garbage_cleanup_backup_candidates both 180)"
    snap_records="$(garbage_cleanup_snapshot_candidates 90)"
    temp_count="$(echo "$temp_records" | garbage_cleanup_count_records)"
    old_count="$(echo "$old_records" | garbage_cleanup_count_records)"
    backup_count="$(echo "$backup_records" | garbage_cleanup_count_records)"
    snap_count="$(echo "$snap_records" | garbage_cleanup_count_records)"
    apt_cache_size="$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')"
    pve_backup_size="$(du -sh /var/backups/pve-tools 2>/dev/null | awk '{print $1}')"
    pve_export_size="$(du -sh "$VM_CONFIG_EXPORT_DIR" 2>/dev/null | awk '{print $1}')"

    clear
    show_menu_header "垃圾清理扫描报告"
    echo -e "${CYAN}缓存与日志:${NC}"
    echo "  apt 缓存目录: ${apt_cache_size:-未发现}"
    if command -v journalctl >/dev/null 2>&1; then
        echo -n "  systemd journal: "
        journalctl --disk-usage 2>/dev/null || echo "无法读取"
    fi
    echo "$UI_DIVIDER"
    echo -e "${CYAN}本工具旧文件:${NC}"
    echo "  /tmp 中超过 3 天的 PVE-Tools 临时文件: $temp_count"
    echo "  /var/backups/pve-tools 总大小: ${pve_backup_size:-未发现}"
    echo "  $VM_CONFIG_EXPORT_DIR 总大小: ${pve_export_size:-未发现}"
    echo "  超过 90 天的 PVE-Tools 备份/导出文件: $old_count"
    echo "$UI_DIVIDER"
    echo -e "${CYAN}PVE 资源候选:${NC}"
    echo "  无主或超过 180 天的 vzdump 备份: $backup_count"
    echo "  超过 90 天且带 snaptime 的 VM/CT 快照: $snap_count"
    echo "  疑似孤立磁盘请使用菜单中的只读扫描单独查看。"
}

garbage_cleanup_menu() {
    while true; do
        clear
        show_menu_header "垃圾清理"
        show_menu_option "1" "一键扫描报告 ${CYAN}(只读)${NC}"
        show_menu_option "2" "清理缓存、日志与本工具旧文件"
        show_menu_option "3" "清理过期/无主 vzdump 备份"
        show_menu_option "4" "清理旧 VM/CT 快照"
        show_menu_option "5" "扫描疑似孤立磁盘 ${YELLOW}(只读，不删除)${NC}"
        echo "$UI_DIVIDER"
        echo -e "${YELLOW}说明:${NC} 清理前会列出候选项；备份和快照删除均需要高风险确认。"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-5]: " choice
        case "$choice" in
            1) garbage_cleanup_scan_report ;;
            2) garbage_cleanup_basic ;;
            3) garbage_cleanup_prune_backups ;;
            4) garbage_cleanup_prune_snapshots ;;
            5) garbage_cleanup_orphan_disk_report ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

vm_select_backup_archive() {
    local archives
    archives="$(vm_discover_backup_archives)"
    if [[ -z "$archives" ]]; then
        local manual
        read -p "未自动发现备份文件，请手动输入备份文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}已发现备份文件：${NC}"
        echo "$archives" | awk -F'|' '{printf "  [%d] %-10s %-16s %s\n", NR, $2, $3, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line path
    read -p "请选择备份序号 (0 手动输入): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        local manual
        read -p "请输入备份文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$archives" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    path="$(echo "$line" | awk -F'|' '{print $1}')"
    [[ -n "$path" && -f "$path" ]] || return 1
    echo "$path"
}

vm_discover_export_files() {
    if [[ -d "$VM_CONFIG_EXPORT_DIR" ]]; then
        find "$VM_CONFIG_EXPORT_DIR" -maxdepth 1 -type f -name 'vm-*.conf' -printf '%p|%s|%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null | sort -u
    fi
}

vm_select_export_file() {
    local files
    files="$(vm_discover_export_files)"
    if [[ -z "$files" ]]; then
        local manual
        read -p "未自动发现导出文件，请手动输入配置文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi

    {
        echo -e "${CYAN}已发现 VM 配置导出文件：${NC}"
        echo "$files" | awk -F'|' '{printf "  [%d] %-10s %-16s %s\n", NR, $2, $3, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick line path
    read -p "请选择配置文件序号 (0 手动输入): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        local manual
        read -p "请输入配置文件完整路径: " manual
        [[ -n "$manual" && -f "$manual" ]] || return 1
        echo "$manual"
        return 0
    fi
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    line="$(echo "$files" | awk -F'|' -v n="$pick" 'NR==n{print $0}')"
    path="$(echo "$line" | awk -F'|' '{print $1}')"
    [[ -n "$path" && -f "$path" ]] || return 1
    echo "$path"
}

vm_get_snapshot_names() {
    local vmid="$1"
    qm listsnapshot "$vmid" 2>/dev/null | awk 'NR>1 && $1 != "current" {print $1}'
}

vm_select_snapshot_name() {
    local vmid="$1"
    local snapshots
    snapshots="$(vm_get_snapshot_names "$vmid")"
    [[ -n "$snapshots" ]] || return 1

    {
        echo -e "${CYAN}当前快照列表：${NC}"
        echo "$snapshots" | awk '{printf "  [%d] %s\n", NR, $1}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick name
    read -p "请选择快照序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    name="$(echo "$snapshots" | awk -v n="$pick" 'NR==n{print $1}')"
    [[ -n "$name" ]] || return 1
    echo "$name"
}

vm_list_template_records() {
    local records vmid name status
    records="$(vm_list_vm_records)"
    [[ -n "$records" ]] || return 0
    while IFS='|' read -r vmid name status; do
        if vm_is_template "$vmid"; then
            printf '%s|%s|%s\n' "$vmid" "$name" "$status"
        fi
    done <<< "$records"
}

vm_show_template_records() {
    local templates
    templates="$(vm_list_template_records)"
    if [[ -z "$templates" ]]; then
        echo -e "${YELLOW}当前没有模板虚拟机${NC}"
        return 0
    fi
    echo -e "${CYAN}模板列表：${NC}"
    echo "$templates" | awk -F'|' '{printf "  VMID: %-6s Name: %-22s Status: %s\n", $1, $2, $3}'
}

vm_ensure_vm_config_backup() {
    local vmid="$1"
    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi
}

vm_ensure_cloudinit_drive() {
    local vmid="$1"
    local store="$2"
    local cfg slot
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if echo "$cfg" | grep -Eq '^(ide2|scsi2): .*cloudinit'; then
        return 0
    fi

    slot="ide2"
    if echo "$cfg" | grep -q '^ide2:'; then
        slot="scsi2"
        if echo "$cfg" | grep -q '^scsi2:'; then
            display_error "无法自动添加 Cloud-Init 盘" "ide2 与 scsi2 都已被占用，请先释放一个插槽。"
            return 1
        fi
    fi

    if ! qm set "$vmid" "-$slot" "$store:cloudinit" >/dev/null 2>&1; then
        display_error "添加 Cloud-Init 盘失败" "请检查存储 $store 是否支持 images 内容类型。"
        return 1
    fi
}

vm_validate_cicustom_volumes() {
    local raw="$1"
    local ref volume store
    IFS=',' read -r -a refs <<< "$raw"
    for ref in "${refs[@]}"; do
        volume="${ref#*=}"
        store="${volume%%:*}"
        if [[ -z "$store" || "$store" == "$volume" ]]; then
            log_error "cicustom 引用格式无效: $ref"
            return 1
        fi
        if ! vm_storage_supports_content "$store" snippets; then
            log_error "存储 $store 不支持 snippets 内容类型，无法作为 cicustom 来源"
            return 1
        fi
    done
}
vm_backup_create() {
    vm_require_commands qm vzdump pvesm || return 1

    local vmids_text
    vmids_text="$(vm_collect_target_vmids)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmids_text" ]] || return 1

    mapfile -t vmids < <(printf '%s\n' "$vmids_text" | awk 'NF')

    local store
    store="$(vm_select_storage_by_content backup "请选择备份存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$store" ]] || return 1

    local compress mode keep_last
    read -p "请选择压缩方式 (zstd/gzip/lzo) [zstd]: " compress
    compress="${compress:-zstd}"
    if [[ "$compress" != "zstd" && "$compress" != "gzip" && "$compress" != "lzo" ]]; then
        display_error "不支持的压缩方式: $compress" "仅支持 zstd / gzip / lzo"
        return 1
    fi

    read -p "请选择备份模式 (snapshot/suspend/stop) [snapshot]: " mode
    mode="${mode:-snapshot}"
    if [[ "$mode" != "snapshot" && "$mode" != "suspend" && "$mode" != "stop" ]]; then
        display_error "不支持的备份模式: $mode" "仅支持 snapshot / suspend / stop"
        return 1
    fi

    read -p "请输入保留份数（0 表示不启用自动清理） [7]: " keep_last
    keep_last="${keep_last:-7}"
    if [[ ! "$keep_last" =~ ^[0-9]+$ ]]; then
        display_error "保留份数必须是数字"
        return 1
    fi

    clear
    show_menu_header "VM 备份与恢复"
    echo -e "${YELLOW}目标 VM:${NC} ${vmids[*]}"
    echo -e "${YELLOW}备份存储:${NC} $store"
    echo -e "${YELLOW}压缩方式:${NC} $compress"
    echo -e "${YELLOW}备份模式:${NC} $mode"
    echo -e "${YELLOW}保留份数:${NC} $keep_last"
    echo -e "${UI_DIVIDER}"

    if ! confirm_high_risk_action "为 VM ${vmids[*]} 执行 vzdump 备份" "备份任务会占用大量 IO 与备份存储空间，错误的保留策略可能挤占生产容量。" "可能触发快照/锁定/短暂性能抖动，存储空间不足时任务会失败。" "请确认目标存储可用空间、保留策略和维护窗口，再执行备份。" "BACKUP"; then
        return 0
    fi

    local -a cmd=(vzdump)
    cmd+=("${vmids[@]}")
    cmd+=(--storage "$store" --compress "$compress" --mode "$mode")
    if (( keep_last > 0 )); then
        cmd+=(--prune-backups "keep-last=$keep_last")
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "vzdump 执行失败" "请检查目标存储空间、任务锁定状态或日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    display_success "备份完成" "可在对应存储的 dump 目录中查看生成的备份文件。"
}

vm_schedule_add_backup_job() {
    vm_require_commands qm vzdump pvesm || return 1

    local scope job_targets target_label
    {
        show_menu_option "1" "单个 VM"
        show_menu_option "2" "多个 VM"
        show_menu_option "3" "全部 VM"
    }
    read -p "请选择定时备份范围 [1-3]: " scope
    case "$scope" in
        1|2)
            job_targets="$(vm_collect_target_vmids)"
            local rc=$?
            [[ "$rc" -eq 2 ]] && return 0
            [[ -n "$job_targets" ]] || return 1
            target_label="$(echo "$job_targets" | tr '\n' '-' | sed 's/-$//')"
            ;;
        3)
            target_label="all"
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    local store
    store="$(vm_select_storage_by_content backup "请选择备份存储")" || return 1
    vm_validate_backup_storage_name "$store" || return 1

    local compress mode keep_last run_time
    read -p "请选择压缩方式 (zstd/gzip/lzo) [zstd]: " compress
    compress="${compress:-zstd}"
    vm_validate_backup_compress "$compress" || return 1

    read -p "请选择备份模式 (snapshot/suspend/stop) [snapshot]: " mode
    mode="${mode:-snapshot}"
    vm_validate_backup_mode "$mode" || return 1

    read -p "请输入保留份数（0 表示不启用自动清理） [7]: " keep_last
    keep_last="${keep_last:-7}"
    vm_validate_backup_keep_last "$keep_last" || return 1

    read -p "请输入每日执行时间 (HH:MM) [03:00]: " run_time
    run_time="${run_time:-03:00}"
    if [[ ! "$run_time" =~ ^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
        display_error "时间格式错误: $run_time" "请使用 HH:MM 格式。"
        return 1
    fi

    local hour minute
    hour="$((10#${BASH_REMATCH[1]}))"
    minute="$((10#${BASH_REMATCH[2]}))"

    local command_text target_args vmid
    command_text="/usr/sbin/vzdump"
    if [[ "$scope" == "3" ]]; then
        command_text+=" --all 1"
    else
        target_args=""
        while IFS= read -r vmid; do
            [[ "$vmid" =~ ^[0-9]+$ ]] || {
                display_error "检测到非法 VMID: $vmid" "已拒绝将未经校验的文本写入 root cron。"
                return 1
            }
            target_args+=" $vmid"
        done <<< "$job_targets"
        [[ -n "$target_args" ]] || {
            display_error "未生成有效的 VMID 参数"
            return 1
        }
        command_text+="$target_args"
    fi
    command_text+=" --storage $store --compress $compress --mode $mode"
    if (( keep_last > 0 )); then
        command_text+=" --prune-backups keep-last=$keep_last"
    fi

    if ! confirm_high_risk_action "写入 VM 定时备份任务" "计划任务会以 root 权限定期执行 vzdump，并持续占用 IO、CPU 与备份存储容量。" "错误的 VMID、存储或保留策略会周期性影响生产负载，问题会反复发生。" "请确认执行时间、目标范围、备份存储与保留策略均已核对。" "CRON-BACKUP"; then
        return 0
    fi

    local marker="VMBACKUP_${target_label}_$(date +%Y%m%d%H%M%S)"
    local cron_line="$minute $hour * * * root $command_text >/var/log/pve-tools-vm-backup.log 2>&1"

    touch "$VM_BACKUP_CRON_FILE"
    apply_block "$VM_BACKUP_CRON_FILE" "$marker" "$cron_line"
    systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    display_success "定时备份任务已写入" "cron 标记: $marker"
}
vm_schedule_remove_backup_job() {
    if [[ ! -f "$VM_BACKUP_CRON_FILE" ]]; then
        display_error "当前没有定时备份任务"
        return 1
    fi

    local markers
    markers="$(grep '^# PVE-TOOLS BEGIN VMBACKUP_' "$VM_BACKUP_CRON_FILE" 2>/dev/null | awk '{print $4}')"
    if [[ -z "$markers" ]]; then
        display_error "当前没有定时备份任务"
        return 1
    fi

    echo -e "${CYAN}当前定时备份任务：${NC}"
    grep -E '^[^#]' "$VM_BACKUP_CRON_FILE" 2>/dev/null | sed 's/^/  /'
    echo -e "${UI_DIVIDER}"
    echo "$markers" | awk '{printf "  [%d] %s\n", NR, $1}'
    echo -e "${UI_DIVIDER}"

    local pick marker
    read -p "请选择要删除的任务序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    marker="$(echo "$markers" | awk -v n="$pick" 'NR==n{print $1}')"
    [[ -n "$marker" ]] || return 1

    remove_block "$VM_BACKUP_CRON_FILE" "$marker"
    systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    display_success "定时备份任务已删除" "$marker"
}

vm_schedule_backup_menu() {
    while true; do
        clear
        show_menu_header "VM 定时备份"
        echo -e "${YELLOW}当前任务：${NC}"
        if [[ -f "$VM_BACKUP_CRON_FILE" ]]; then
            grep -E '^[^#]' "$VM_BACKUP_CRON_FILE" 2>/dev/null | sed 's/^/  /' || true
        else
            echo "  暂无定时任务"
        fi
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "新增定时备份任务"
        show_menu_option "2" "删除定时备份任务"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) vm_schedule_add_backup_job ;;
            2) vm_schedule_remove_backup_job ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

vm_restore_from_backup() {
    vm_require_commands qmrestore qm pvesm || return 1

    local archive
    archive="$(vm_select_backup_archive)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$archive" ]] || return 1

    local new_vmid
    read -p "请输入新的 VMID: " new_vmid
    vm_validate_new_vmid "$new_vmid" || return 1

    local store
    store="$(vm_select_storage_by_content images "请选择恢复后的磁盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$store" ]] || return 1

    local unique start_after
    read -p "是否重新生成唯一标识（推荐 yes）?(yes/no) [yes]: " unique
    unique="${unique:-yes}"
    read -p "恢复后是否自动启动 VM？(yes/no) [no]: " start_after
    start_after="${start_after:-no}"

    clear
    show_menu_header "从备份恢复 VM"
    echo -e "${YELLOW}备份文件:${NC} $archive"
    echo -e "${YELLOW}新 VMID:${NC} $new_vmid"
    echo -e "${YELLOW}目标存储:${NC} $store"
    echo -e "${YELLOW}唯一标识重建:${NC} $unique"
    echo -e "${UI_DIVIDER}"

    if ! confirm_high_risk_action "从备份恢复为新 VM $new_vmid" "恢复会创建新的 VM 和磁盘卷；如果关闭唯一标识重建，还可能引入 MAC/系统标识冲突。" "可能大量占用目标存储，并在误选备份文件时恢复出错误业务数据。" "请确认备份文件来源、目标 VMID 与目标存储均已核对，并预留足够空间。" "RESTORE"; then
        return 0
    fi

    local -a cmd=(qmrestore "$archive" "$new_vmid" --storage "$store")
    if [[ "$unique" == "yes" || "$unique" == "YES" ]]; then
        cmd+=(--unique 1)
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "qmrestore 执行失败" "请检查备份文件、目标存储和日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    if [[ "$start_after" == "yes" || "$start_after" == "YES" ]]; then
        qm start "$new_vmid" >/dev/null 2>&1 || log_warn "自动启动 VM 失败，请手动检查。"
    fi
    display_success "恢复完成" "新 VMID: $new_vmid"
}

vm_backup_restore_menu() {
    while true; do
        clear
        show_menu_header "VM 备份与恢复"
        vm_show_data_risk_banner
        show_menu_option "1" "创建 VM 备份（vzdump）"
        show_menu_option "2" "从备份恢复为新 VM"
        show_menu_option "3" "定时备份任务管理"
        show_menu_option "4" "备份文件跨机恢复引导"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_backup_create ;;
            2) vm_restore_from_backup ;;
            3) vm_schedule_backup_menu ;;
            4) vm_backup_transfer_guide ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

vm_export_config() {
    vm_require_commands qm || return 1

    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    mkdir -p "$VM_CONFIG_EXPORT_DIR"
    local output_file timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    output_file="$VM_CONFIG_EXPORT_DIR/vm-${vmid}-${timestamp}.conf"

    {
        echo "# PVE-Tools VM Export"
        echo "# source_vmid=${vmid}"
        echo "# source_node=$(hostname)"
        echo "# exported_at=$(date +%F' '%T)"
        qm config "$vmid"
    } > "$output_file"

    display_success "VM 配置已导出" "$output_file"
}

vm_import_config() {
    vm_require_commands qm || return 1

    local file
    file="$(vm_select_export_file)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$file" ]] || return 1

    local new_vmid
    read -p "请输入新的 VMID: " new_vmid
    vm_validate_new_vmid "$new_vmid" || return 1

    local exported_name new_name import_mode regenerate_mac
    exported_name="$(awk -F': ' '/^name: /{print $2; exit}' "$file")"
    read -p "请输入新 VM 名称 [${exported_name:-vm-$new_vmid}]: " new_name
    new_name="${new_name:-${exported_name:-vm-$new_vmid}}"
    read -p "导入模式 (config/rebind-disks) [config]: " import_mode
    import_mode="${import_mode:-config}"
    case "$import_mode" in
        config|rebind-disks) ;;
        *)
            display_error "不支持的导入模式: $import_mode" "仅支持 config 或 rebind-disks。"
            return 1
            ;;
    esac
    read -p "是否重建网卡 MAC 地址？(yes/no) [yes]: " regenerate_mac
    regenerate_mac="${regenerate_mac:-yes}"
    case "$regenerate_mac" in
        yes|YES|no|NO) ;;
        *)
            display_error "是否重建网卡 MAC 地址仅支持 yes/no"
            return 1
            ;;
    esac

    if [[ "$import_mode" == "rebind-disks" ]]; then
        if ! confirm_high_risk_action "以 rebind-disks 模式导入 VM $new_vmid" "该模式会把导出配置中的磁盘引用重新绑定到新 VM，选错卷会直接指向现有数据。" "错误重绑可能造成数据卷误挂载、业务串卷或后续误删风险。" "请逐项核对导出文件中的磁盘卷 ID，仅在确实理解每个卷来源时继续。" "REBIND-DISKS"; then
            return 0
        fi
    fi

    if ! confirm_high_risk_action "导入配置文件并创建新 VM $new_vmid" "配置回放会逐项写入新 VM；如果选择 rebind-disks，错误的磁盘引用可能绑定到不应接管的数据卷。" "可能造成新 VM 配置错误、网络冲突，或因错误重绑磁盘而影响现有数据卷识别。" "请确认导入文件来源可信，目标 VMID 空闲，并已核对磁盘引用与网卡规划。" "IMPORT-CONFIG"; then
        return 0
    fi

    local -a option_lines disk_lines failed_keys attached_disk_keys
    local bootdisk_value=""
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        [[ "$line" != *': '* ]] && continue
        local key="${line%%:*}"
        local value="${line#*: }"
        case "$key" in
            name|template|digest|lock|meta|parent|vmgenid|unused*|snapstate|runningmachine|runningcpu)
                continue
                ;;
            bootdisk)
                bootdisk_value="$value"
                continue
                ;;
            scsi*|sata*|virtio*|ide*|efidisk0|tpmstate0)
                disk_lines+=("$key|$value")
                continue
                ;;
            net*)
                if [[ "$regenerate_mac" == "yes" || "$regenerate_mac" == "YES" ]]; then
                    value="$(vm_network_strip_mac "$value")"
                fi
                option_lines+=("$key|$value")
                ;;
            *)
                option_lines+=("$key|$value")
                ;;
        esac
    done < "$file"

    if ! qm create "$new_vmid" --name "$new_name" >/dev/null 2>&1; then
        display_error "qm create 失败" "请检查 VMID 是否冲突，或查看任务日志。"
        return 1
    fi

    local entry key value
    for entry in "${option_lines[@]}"; do
        key="${entry%%|*}"
        value="${entry#*|}"
        if ! qm set "$new_vmid" "-$key" "$value" >/dev/null 2>&1; then
            failed_keys+=("$key")
        fi
    done

    if [[ "$import_mode" == "rebind-disks" ]]; then
        for entry in "${disk_lines[@]}"; do
            key="${entry%%|*}"
            value="${entry#*|}"
            if qm set "$new_vmid" "-$key" "$value" >/dev/null 2>&1; then
                attached_disk_keys+=("$key")
            else
                failed_keys+=("$key")
            fi
        done
        if [[ -n "$bootdisk_value" ]]; then
            if ! qm set "$new_vmid" --bootdisk "$bootdisk_value" >/dev/null 2>&1; then
                failed_keys+=("bootdisk")
            fi
        fi
    fi

    if (( ${#failed_keys[@]} > 0 )); then
        if [[ "$import_mode" == "rebind-disks" ]]; then
            local attached_key
            for attached_key in "${attached_disk_keys[@]}"; do
                qm set "$new_vmid" --delete "$attached_key" >/dev/null 2>&1 || log_warn "回滚重绑磁盘槽位失败: $attached_key"
            done
        fi

        if qm destroy "$new_vmid" --purge 1 >/dev/null 2>&1; then
            display_error "VM 配置导入失败，已自动回滚" "失败项: ${failed_keys[*]}"
        else
            display_error "VM 配置导入失败" "失败项: ${failed_keys[*]}；已尝试回滚，但自动清理未完成，请立即检查 VM $new_vmid。"
        fi
        return 1
    fi

    display_success "VM 配置导入完成" "新 VMID: $new_vmid"
}
vm_config_io_menu() {
    while true; do
        clear
        show_menu_header "VM 配置导入/导出"
        vm_show_data_risk_banner
        show_menu_option "1" "导出 VM 配置"
        show_menu_option "2" "导入 VM 配置"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) vm_export_config ;;
            2) vm_import_config ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
vm_convert_to_template() {
    vm_require_commands qm || return 1

    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    if vm_is_template "$vmid"; then
        display_error "该 VM 已经是模板"
        return 1
    fi

    vm_ensure_vm_config_backup "$vmid"
    if ! confirm_high_risk_action "将 VM $vmid 转换为模板" "模板化会改变 VM 的交付语义，后续不应再把它当作普通生产实例直接运行。" "如果选错对象，可能误把正在使用的业务 VM 转为模板，影响后续运维与交付。" "请确认该 VM 已停机或处于预期状态，并已导出配置或留存快照。" "TEMPLATE"; then
        return 0
    fi

    if ! qm template "$vmid" >/dev/null 2>&1; then
        display_error "模板转换失败" "请检查 VM 状态和任务日志。"
        return 1
    fi

    display_success "模板转换完成" "VMID: $vmid"
}

vm_clone_vm() {
    vm_require_commands qm || return 1

    local mode="$1"
    local source_vmid
    source_vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$source_vmid" ]] || return 1

    if [[ "$mode" == "linked" ]] && ! vm_is_template "$source_vmid"; then
        display_error "链接克隆仅支持模板虚拟机" "请先将源 VM 转换为模板。"
        return 1
    fi

    local new_vmid new_name full_flag store
    read -p "请输入新的 VMID: " new_vmid
    vm_validate_new_vmid "$new_vmid" || return 1
    read -p "请输入新 VM 名称 [clone-$new_vmid]: " new_name
    new_name="${new_name:-clone-$new_vmid}"

    full_flag=1
    if [[ "$mode" == "linked" ]]; then
        full_flag=0
    else
        store="$(vm_select_storage_by_content images "请选择完整克隆目标存储")"
        rc=$?
        [[ "$rc" -eq 2 ]] && return 0
        [[ -n "$store" ]] || return 1
    fi

    local -a cmd=(qm clone "$source_vmid" "$new_vmid" --name "$new_name" --full "$full_flag")
    if [[ "$full_flag" -eq 1 && -n "$store" ]]; then
        cmd+=(--storage "$store")
    fi

    if ! confirm_high_risk_action "从 VM $source_vmid 创建 ${mode} 克隆到 $new_vmid" "克隆会复制或引用源磁盘，完整克隆会大量占用空间，链接克隆依赖模板与底层存储能力。" "目标存储、模板状态或 VMID 选择错误时，可能产生错误副本或交付错误实例。" "请确认源 VM、目标 VMID、目标存储和交付计划均已核对。" "CLONE"; then
        return 0
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "克隆失败" "请检查源 VM 状态、目标存储及日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    display_success "克隆完成" "新 VMID: $new_vmid"
}

vm_cloudinit_configure_for_vmid() {
    local vmid="$1"
    vm_require_commands qm pvesm || return 1

    local cfg ci_store
    cfg="$(qm config "$vmid" 2>/dev/null)"
    if ! echo "$cfg" | grep -Eq '^(ide2|scsi2): .*cloudinit'; then
        ci_store="$(vm_select_storage_by_content images "请选择 Cloud-Init 盘存储")"
        local rc=$?
        [[ "$rc" -eq 2 ]] && return 0
        [[ -n "$ci_store" ]] || return 1
        vm_ensure_cloudinit_drive "$vmid" "$ci_store" || return 1
    fi

    local ciuser cipassword ipconfig0 nameserver searchdomain citype sshkeys_path cicustom console_mode
    read -p "Cloud-Init 用户名（留空跳过）: " ciuser
    read -p "Cloud-Init 密码（留空跳过）: " cipassword
    read -p "网络配置 ipconfig0（示例 ip=dhcp 或 ip=192.168.1.10/24,gw=192.168.1.1，留空跳过）: " ipconfig0
    read -p "nameserver（留空跳过）: " nameserver
    read -p "searchdomain（留空跳过）: " searchdomain
    read -p "citype (nocloud/configdrive2/opennebula，留空跳过) [nocloud]: " citype
    citype="${citype:-nocloud}"
    read -p "SSH 公钥文件路径（留空跳过）: " sshkeys_path
    if [[ -n "$sshkeys_path" && ! -f "$sshkeys_path" ]]; then
        display_error "SSH 公钥文件不存在: $sshkeys_path"
        return 1
    fi
    read -p "cicustom（示例 user=local:snippets/user.yaml，留空跳过）: " cicustom
    if [[ -n "$cicustom" ]]; then
        vm_validate_cicustom_volumes "$cicustom" || return 1
    fi
    read -p "是否启用串口控制台输出？(yes/no) [yes]: " console_mode
    console_mode="${console_mode:-yes}"

    local -a cmd=(qm set "$vmid")
    [[ -n "$ciuser" ]] && cmd+=(--ciuser "$ciuser")
    [[ -n "$cipassword" ]] && cmd+=(--cipassword "$cipassword")
    [[ -n "$ipconfig0" ]] && cmd+=(--ipconfig0 "$ipconfig0")
    [[ -n "$nameserver" ]] && cmd+=(--nameserver "$nameserver")
    [[ -n "$searchdomain" ]] && cmd+=(--searchdomain "$searchdomain")
    [[ -n "$citype" ]] && cmd+=(--citype "$citype")
    [[ -n "$sshkeys_path" ]] && cmd+=(--sshkeys "$sshkeys_path")
    [[ -n "$cicustom" ]] && cmd+=(--cicustom "$cicustom")

    if (( ${#cmd[@]} > 2 )); then
        if ! confirm_high_risk_action "写入 VM $vmid 的 Cloud-Init 参数" "会直接覆盖现有 Cloud-Init 用户、密码、网络、DNS、SSH 密钥或 cicustom 指向。" "后续启动、重新生成 cloud-init 数据或交付克隆时，实例身份与网络行为可能发生变化。" "请确认参数、snippets 来源与 SSH 公钥均正确，并已记录旧配置。" "CLOUDINIT"; then
            return 0
        fi
        if ! "${cmd[@]}" >/dev/null 2>&1; then
            display_error "Cloud-Init 参数写入失败" "请检查参数格式、snippets 存储和日志输出。"
            return 1
        fi
    fi

    if [[ "$console_mode" == "yes" || "$console_mode" == "YES" ]]; then
        qm set "$vmid" --serial0 socket --vga serial0 >/dev/null 2>&1 || log_warn "串口控制台配置失败，可稍后手工设置。"
    fi

    display_success "Cloud-Init 配置已写入" "可使用 qm cloudinit dump $vmid user 查看生成结果。"
}

vm_cloudinit_configure() {
    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    vm_cloudinit_configure_for_vmid "$vmid"
}

vm_cloud_image_to_template() {
    vm_require_commands qm pvesm qemu-img || return 1

    local image_path
    image_path="$(img_select_img_file)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$image_path" ]] || return 1

    local vmid vm_name memory cores bridge image_store ci_store
    read -p "请输入新的 VMID: " vmid
    vm_validate_new_vmid "$vmid" || return 1
    read -p "请输入 VM 名称 [cloud-template-$vmid]: " vm_name
    vm_name="${vm_name:-cloud-template-$vmid}"
    read -p "内存大小 MB [2048]: " memory
    memory="${memory:-2048}"
    read -p "CPU 核心数 [2]: " cores
    cores="${cores:-2}"
    read -p "默认桥接 [${VM_DEFAULT_CLOUDINIT_BRIDGE}]: " bridge
    bridge="${bridge:-$VM_DEFAULT_CLOUDINIT_BRIDGE}"

    image_store="$(vm_select_storage_by_content images "请选择系统盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$image_store" ]] || return 1
    ci_store="$(vm_select_storage_by_content images "请选择 Cloud-Init 盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$ci_store" ]] || return 1

    if ! confirm_high_risk_action "基于镜像 $image_path 创建 VM $vmid 并导入系统盘" "该流程会创建新 VM、写入磁盘卷并占用目标存储；镜像、VMID 或目标存储选错时会把流程导向错误对象。" "可能产生错误模板、错误网络配置或额外占用大量存储空间。" "请确认镜像来源可信，目标 VMID 空闲，系统盘存储与 Cloud-Init 存储已核对。" "IMPORT-IMAGE"; then
        return 0
    fi

    if ! qm create "$vmid" --name "$vm_name" --memory "$memory" --cores "$cores" --net0 "virtio,bridge=$bridge" >/dev/null 2>&1; then
        display_error "基础 VM 创建失败" "请检查参数和当前集群状态。"
        return 1
    fi

    local import_out vol
    if ! import_out="$(qm importdisk "$vmid" "$image_path" "$image_store" 2>&1)"; then
        echo "$import_out" | sed 's/^/  /'
        display_error "云镜像导入失败" "请检查镜像格式、目标存储空间和日志输出。"
        return 1
    fi

    vol="$(echo "$import_out" | sed -n "s/.*as '\([^']\+\)'.*/\1/p" | tail -n 1)"
    [[ -z "$vol" ]] && vol="$(echo "$import_out" | grep -oE "${image_store}:[^ ]+" | tail -n 1)"
    if [[ -z "$vol" ]]; then
        display_error "无法解析导入后的卷 ID" "请手动查看 qm importdisk 输出后继续处理。"
        return 1
    fi

    if ! qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$vol" --boot order=scsi0 --ide2 "$ci_store:cloudinit" --serial0 socket --vga serial0 --agent 1 >/dev/null 2>&1; then
        display_error "模板基础参数写入失败" "请检查存储、控制器类型与日志输出。"
        return 1
    fi

    vm_cloudinit_configure_for_vmid "$vmid"

    if confirm_high_risk_action "将 VM $vmid 转换为云镜像模板" "模板化后该 VM 会被视为母版，后续克隆将继承当前磁盘与 Cloud-Init 状态。" "如果模板内容未校验，错误会被批量复制到后续所有实例。" "请确认系统盘、Cloud-Init 与基础软件状态均已验证，再执行模板转换。" "TEMPLATE"; then
        qm template "$vmid" >/dev/null 2>&1 || {
            display_error "模板转换失败" "请检查当前任务状态。"
            return 1
        }
    fi

    display_success "云镜像模板准备完成" "VMID: $vmid"
}

vm_template_cloudinit_menu() {
    while true; do
        clear
        show_menu_header "模板 / 克隆 / Cloud-Init"
        vm_show_data_risk_banner
        show_menu_option "1" "列出所有模板"
        show_menu_option "2" "将现有 VM 转换为模板"
        show_menu_option "3" "完整克隆 VM"
        show_menu_option "4" "链接克隆模板"
        show_menu_option "5" "导入云镜像并生成模板"
        show_menu_option "6" "配置 Cloud-Init 参数"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-6]: " choice
        case "$choice" in
            1) vm_show_template_records ;;
            2) vm_convert_to_template ;;
            3) vm_clone_vm full ;;
            4) vm_clone_vm linked ;;
            5) vm_cloud_image_to_template ;;
            6) vm_cloudinit_configure ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
vm_resize_disk() {
    vm_require_commands qm || return 1

    local vmid slot size_change
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_disk_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    read -p "请输入扩容值（示例 +10G 或 64G）: " size_change
    [[ -n "$size_change" ]] || return 1

    if ! confirm_high_risk_action "为 VM $vmid 的 $slot 执行磁盘扩容" "扩容通常不可逆；访客系统内若未正确扩展分区/文件系统，可能导致识别异常。" "错误的磁盘槽位或大小参数会把变更写到错误磁盘对象。" "请确认磁盘槽位、目标容量和访客系统扩容方案已准备完毕。" "RESIZE"; then
        return 0
    fi

    if qm disk resize "$vmid" "$slot" "$size_change" >/dev/null 2>&1 || qm resize "$vmid" "$slot" "$size_change" >/dev/null 2>&1; then
        display_success "磁盘扩容完成" "$slot -> $size_change"
    else
        display_error "磁盘扩容失败" "请检查磁盘插槽、大小参数和日志输出。"
        return 1
    fi
}

vm_add_disk() {
    vm_require_commands qm pvesm || return 1

    local vmid store bus slot disk_size
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    store="$(vm_select_storage_by_content images "请选择新磁盘存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$store" ]] || return 1

    read -p "磁盘总线类型 (scsi/sata/virtio/ide) [scsi]: " bus
    bus="${bus:-scsi}"
    slot="$(vm_find_free_disk_slot "$vmid" "$bus")"
    [[ -n "$slot" ]] || {
        display_error "未找到可用磁盘插槽" "请先释放对应总线插槽后再试。"
        return 1
    }

    read -p "磁盘大小（示例 32G / 512M）: " disk_size
    [[ "$disk_size" =~ ^[0-9]+[KMGTP]$ ]] || {
        display_error "磁盘大小格式错误" "请使用类似 32G、512M 的格式。"
        return 1
    }

    vm_ensure_vm_config_backup "$vmid"
    if ! confirm_high_risk_action "为 VM $vmid 添加磁盘 $slot" "将立即在目标存储分配新卷并写入 VM 配置。" "错误的总线、存储或容量选择会造成资源浪费，甚至影响后续系统盘识别。" "请确认目标存储、总线类型与容量规划已核对。" "ADDDISK"; then
        return 0
    fi

    if ! qm set "$vmid" "-$slot" "$store:$disk_size" >/dev/null 2>&1; then
        display_error "添加磁盘失败" "请检查存储、容量与日志输出。"
        return 1
    fi

    display_success "磁盘添加完成" "$slot = $store:$disk_size"
}

vm_remove_disk() {
    vm_require_commands qm || return 1

    local vmid slot
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_disk_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    vm_ensure_vm_config_backup "$vmid"
    if ! confirm_high_risk_action "从 VM $vmid 删除磁盘插槽 $slot" "删除磁盘配置会让访客系统失去该磁盘引用，若误删系统盘或关键数据盘会导致业务中断。" "后续若继续写入或重新分配卷，数据恢复难度会快速上升。" "请确认该槽位不是系统关键盘，且已完成卷级备份或快照。" "DELETE"; then
        return 0
    fi

    if ! qm set "$vmid" --delete "$slot" >/dev/null 2>&1; then
        display_error "删除磁盘失败" "请检查 VM 锁定状态和日志输出。"
        return 1
    fi

    display_success "磁盘已移除" "$slot"
}

vm_move_disk() {
    vm_require_commands qm pvesm || return 1

    local vmid slot target_store delete_source
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_disk_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1
    target_store="$(vm_select_storage_by_content images "请选择目标存储")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_store" ]] || return 1
    read -p "迁移后是否删除源磁盘？(yes/no) [yes]: " delete_source
    delete_source="${delete_source:-yes}"

    if ! confirm_high_risk_action "将 VM $vmid 的 $slot 迁移到 $target_store" "迁移磁盘会复制或移动底层卷；若启用删除源盘，源卷在流程完成后会被清理。" "目标存储选错或空间不足时可能导致任务失败；删除源盘后回退复杂度更高。" "请确认目标存储、可用空间和是否删除源盘的策略已核对。" "MOVE-DISK"; then
        return 0
    fi

    if [[ "$delete_source" == "yes" || "$delete_source" == "YES" ]]; then
        qm disk move "$vmid" "$slot" "$target_store" --delete 1 >/dev/null 2>&1 || qm move_disk "$vmid" "$slot" "$target_store" --delete 1 >/dev/null 2>&1 || {
            display_error "磁盘迁移失败" "请检查存储状态和日志输出。"
            return 1
        }
    else
        qm disk move "$vmid" "$slot" "$target_store" >/dev/null 2>&1 || qm move_disk "$vmid" "$slot" "$target_store" >/dev/null 2>&1 || {
            display_error "磁盘迁移失败" "请检查存储状态和日志输出。"
            return 1
        }
    fi

    display_success "磁盘迁移完成" "$slot -> $target_store"
}

vm_disk_management_menu() {
    while true; do
        clear
        show_menu_header "虚拟机磁盘管理"
        vm_show_data_risk_banner
        show_menu_option "1" "磁盘扩容"
        show_menu_option "2" "添加磁盘"
        show_menu_option "3" "移除磁盘"
        show_menu_option "4" "迁移磁盘到其他存储"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_resize_disk ;;
            2) vm_add_disk ;;
            3) vm_remove_disk ;;
            4) vm_move_disk ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

vm_create_snapshot() {
    vm_require_commands qm || return 1

    local vmids_text snapshot_name description
    vmids_text="$(vm_collect_target_vmids)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmids_text" ]] || return 1
    mapfile -t vmids < <(printf '%s\n' "$vmids_text" | awk 'NF')

    read -p "请输入快照名称: " snapshot_name
    [[ "$snapshot_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
        display_error "快照名称格式无效" "仅支持字母、数字、点、下划线和中划线。"
        return 1
    }
    read -p "请输入快照描述（留空跳过）: " description

    local success=0 failed=0 vmid
    for vmid in "${vmids[@]}"; do
        if [[ -n "$description" ]]; then
            qm snapshot "$vmid" "$snapshot_name" --description "$description" >/dev/null 2>&1 && ((success++)) || ((failed++))
        else
            qm snapshot "$vmid" "$snapshot_name" >/dev/null 2>&1 && ((success++)) || ((failed++))
        fi
    done

    display_success "快照创建任务完成" "成功: $success, 失败: $failed"
}

vm_list_snapshots() {
    vm_require_commands qm || return 1
    local vmid
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    clear
    show_menu_header "快照列表"
    qm listsnapshot "$vmid" 2>/dev/null | sed 's/^/  /'
    echo -e "${UI_DIVIDER}"
}

vm_delete_snapshot() {
    vm_require_commands qm || return 1
    local vmid snapshot_name
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    snapshot_name="$(vm_select_snapshot_name "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$snapshot_name" ]] || return 1

    if ! confirm_high_risk_action "删除 VM $vmid 的快照 $snapshot_name" "删除快照后将失去对应时间点的快速回退能力。" "若该快照是重要恢复点，误删后只能依赖外部备份或更高成本的恢复手段。" "请确认该快照不再承担回滚基线，并已保留外部备份。" "DROP-SNAP"; then
        return 0
    fi

    if ! qm delsnapshot "$vmid" "$snapshot_name" >/dev/null 2>&1; then
        display_error "删除快照失败" "请检查快照名称和日志输出。"
        return 1
    fi

    display_success "快照已删除" "$snapshot_name"
}

vm_rollback_snapshot() {
    vm_require_commands qm || return 1
    local vmid snapshot_name
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    snapshot_name="$(vm_select_snapshot_name "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$snapshot_name" ]] || return 1

    if ! confirm_high_risk_action "将 VM $vmid 回滚到快照 $snapshot_name" "回滚会把磁盘与配置状态拉回到旧时间点，之后的数据写入可能丢失。" "如果当前业务数据尚未导出或备份，回滚可能造成不可逆的新数据丢失。" "请确认当前数据已备份，且业务方已批准回退到该时间点。" "ROLLBACK"; then
        return 0
    fi

    if ! qm rollback "$vmid" "$snapshot_name" >/dev/null 2>&1; then
        display_error "快照回滚失败" "请检查 VM 状态和日志输出。"
        return 1
    fi

    display_success "快照回滚完成" "$snapshot_name"
}

vm_snapshot_menu() {
    while true; do
        clear
        show_menu_header "快照管理"
        vm_show_data_risk_banner
        show_menu_option "1" "创建快照（支持批量）"
        show_menu_option "2" "列出 VM 快照"
        show_menu_option "3" "删除快照"
        show_menu_option "4" "回滚到快照"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_create_snapshot ;;
            2) vm_list_snapshots ;;
            3) vm_delete_snapshot ;;
            4) vm_rollback_snapshot ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

vm_configure_startup_policy() {
    vm_require_commands qm || return 1
    local vmid onboot boot_order startup_cfg
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    read -p "是否开机自启？(yes/no/skip) [skip]: " onboot
    onboot="${onboot:-skip}"
    read -p "启动顺序（示例 scsi0;ide2;net0，留空跳过）: " boot_order
    read -p "启动策略（示例 order=1,up=30,down=30，留空跳过）: " startup_cfg

    if [[ "$onboot" == "yes" || "$onboot" == "YES" ]]; then
        qm set "$vmid" --onboot 1 >/dev/null 2>&1 || log_warn "设置 onboot 失败"
    elif [[ "$onboot" == "no" || "$onboot" == "NO" ]]; then
        qm set "$vmid" --onboot 0 >/dev/null 2>&1 || log_warn "设置 onboot 失败"
    fi

    [[ -n "$boot_order" ]] && qm set "$vmid" --boot "order=$boot_order" >/dev/null 2>&1 || true
    [[ -n "$startup_cfg" ]] && qm set "$vmid" --startup "$startup_cfg" >/dev/null 2>&1 || true
    display_success "启动策略已更新" "VMID: $vmid"
}

vm_add_network() {
    vm_require_commands qm || return 1
    local vmid bridge vlan model idx net_value
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1

    idx="$(vm_find_free_net_index "$vmid")"
    [[ -n "$idx" ]] || {
        display_error "未找到可用网卡插槽"
        return 1
    }

    read -p "网卡模型 (virtio/e1000/vmxnet3) [virtio]: " model
    model="${model:-virtio}"
    read -p "桥接名称 [vmbr0]: " bridge
    bridge="${bridge:-vmbr0}"
    read -p "VLAN Tag（留空不设置）: " vlan

    net_value="$model,bridge=$bridge"
    [[ -n "$vlan" ]] && net_value="$net_value,tag=$vlan"

    if ! qm set "$vmid" "-net$idx" "$net_value" >/dev/null 2>&1; then
        display_error "添加网卡失败" "请检查桥接、VLAN 和日志输出。"
        return 1
    fi

    display_success "网卡添加完成" "net$idx = $net_value"
}

vm_remove_network() {
    vm_require_commands qm || return 1
    local vmid slot
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_net_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    if ! confirm_action "删除 VM $vmid 的网卡 $slot？"; then
        return 0
    fi
    if ! qm set "$vmid" --delete "$slot" >/dev/null 2>&1; then
        display_error "删除网卡失败" "请检查 VM 状态和日志输出。"
        return 1
    fi

    display_success "网卡已删除" "$slot"
}

vm_modify_network() {
    vm_require_commands qm || return 1
    local vmid slot current bridge current_bridge current_tag vlan_input updated
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    slot="$(vm_select_net_slot "$vmid")"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$slot" ]] || return 1

    current="$(vm_get_qm_value "$vmid" "$slot")"
    current_bridge="$(echo "$current" | sed -n 's/.*bridge=\([^,]*\).*/\1/p')"
    current_tag="$(echo "$current" | sed -n 's/.*tag=\([^,]*\).*/\1/p')"

    read -p "桥接名称 [${current_bridge:-vmbr0}]: " bridge
    bridge="${bridge:-${current_bridge:-vmbr0}}"
    read -p "VLAN Tag（留空保持当前，输入 none 清除） [${current_tag:-none}]: " vlan_input

    updated="$(vm_network_set_option "$current" bridge "$bridge")"
    if [[ "$vlan_input" == "none" || "$vlan_input" == "NONE" ]]; then
        updated="$(vm_network_remove_option "$updated" tag)"
    elif [[ -n "$vlan_input" ]]; then
        updated="$(vm_network_set_option "$updated" tag "$vlan_input")"
    fi

    if ! qm set "$vmid" "-$slot" "$updated" >/dev/null 2>&1; then
        display_error "更新网卡失败" "请检查 bridge/VLAN 参数和日志输出。"
        return 1
    fi

    display_success "网卡参数已更新" "$slot = $updated"
}

vm_startup_network_menu() {
    while true; do
        clear
        show_menu_header "启动顺序与网络管理"
        vm_show_data_risk_banner
        show_menu_option "1" "设置开机自启 / 启动顺序 / 启动延迟"
        show_menu_option "2" "添加网卡"
        show_menu_option "3" "移除网卡"
        show_menu_option "4" "修改 bridge / VLAN"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) vm_configure_startup_policy ;;
            2) vm_add_network ;;
            3) vm_remove_network ;;
            4) vm_modify_network ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

vm_cluster_migrate() {
    vm_require_commands qm || return 1

    local vmid target_node with_local live_mode storage_mode target_storage cfg status
    vmid="$(img_select_vmid)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$vmid" ]] || return 1
    target_node="$(vm_select_target_node)"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_node" ]] || {
        display_error "未发现可用的目标节点" "请确认当前处于多节点集群环境。"
        return 1
    }

    cfg="$(qm config "$vmid" 2>/dev/null)"
    if echo "$cfg" | grep -qE '^hostpci[0-9]+:'; then
        log_warn "检测到该 VM 使用 PCI/直通设备，迁移前请确认目标节点拥有相同硬件。"
    fi

    read -p "是否携带本地磁盘一起迁移？(yes/no) [yes]: " with_local
    with_local="${with_local:-yes}"
    status="$(qm status "$vmid" 2>/dev/null | awk '{print $2}' | head -n 1)"
    if [[ "$status" == "running" ]]; then
        read -p "是否启用在线迁移？(yes/no) [yes]: " live_mode
        live_mode="${live_mode:-yes}"
    else
        live_mode="no"
    fi

    {
        show_menu_option "1" "目标节点同名存储映射（--targetstorage 1）"
        show_menu_option "2" "统一迁移到指定存储"
        show_menu_option "3" "不指定 targetstorage"
    }
    read -p "请选择目标存储策略 [1-3]: " storage_mode
    case "$storage_mode" in
        1) target_storage='1' ;;
        2)
            target_storage="$(vm_select_storage_by_content images "请选择迁移目标存储")"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 0
            [[ -n "$target_storage" ]] || return 1
            ;;
        3) target_storage='' ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac

    local -a cmd=(qm migrate "$vmid" "$target_node")
    if [[ "$with_local" == "yes" || "$with_local" == "YES" ]]; then
        cmd+=(--with-local-disks 1)
    fi
    if [[ "$live_mode" == "yes" || "$live_mode" == "YES" ]]; then
        cmd+=(--online 1)
    fi
    [[ -n "$target_storage" ]] && cmd+=(--targetstorage "$target_storage")

    if ! confirm_high_risk_action "将 VM $vmid 迁移到节点 $target_node" "迁移会改写 VM 所在节点与磁盘位置；带本地盘迁移时对网络、存储映射和目标节点能力要求更高。" "目标节点、目标存储或在线迁移条件判断错误时，可能造成任务失败、停机或业务抖动。" "请确认目标节点在线、存储映射正确，并已评估直通设备与维护窗口。" "MIGRATE"; then
        return 0
    fi

    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
        echo "$output" | sed 's/^/  /'
        display_error "迁移失败" "请检查节点连通性、存储映射和日志输出。"
        return 1
    fi

    echo "$output" | sed 's/^/  /'
    display_success "迁移任务已提交" "目标节点: $target_node"
}

vm_advanced_operations_menu() {
    while true; do
        clear
        show_menu_header "虚拟机高级运维工具箱"
        vm_show_data_risk_banner
        show_menu_option "1" "VM 备份与恢复"
        show_menu_option "2" "VM 配置导入/导出"
        show_menu_option "3" "模板 / 克隆 / Cloud-Init"
        show_menu_option "4" "虚拟机磁盘管理"
        show_menu_option "5" "快照管理"
        show_menu_option "6" "启动顺序与网络管理"
        show_menu_option "7" "集群内迁移 VM"
        echo -e "${RED}警告：涉及备份恢复、磁盘、快照、模板与迁移时，必须先确认备份可用，再核对 VMID / 槽位 / 目标存储。${NC}"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-7]: " choice
        case "$choice" in
            1) vm_backup_restore_menu ;;
            2) vm_config_io_menu ;;
            3) vm_template_cloudinit_menu ;;
            4) vm_disk_management_menu ;;
            5) vm_snapshot_menu ;;
            6) vm_startup_network_menu ;;
            7) vm_cluster_migrate ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}
# 二级菜单：虚拟机与容器
menu_vm_container() {
    while true; do
        clear
        show_menu_header "虚拟机与容器"
        show_menu_option "1" "${CYAN}FastPVE${NC} - 虚拟机快速下载"
        show_menu_option "2" "虚拟机/容器定时开关机"
        show_menu_option "3" "IMG 镜像导入（转 QCOW2/RAW）"
        show_menu_option "4" "虚拟机高级运维工具箱"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1) fastpve_quick_download_menu ;;
            2) manage_vm_schedule ;;
            3) img_convert_import_menu ;;
            4) vm_advanced_operations_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# ============ 宿主机网络 / 防火墙 / IPv6 / 诊断工具箱 ============

host_network_show_risk_banner() {
    echo -e "${RED}${UI_DIVIDER}${NC}"
    echo -e "${RED}高风险提示：以下功能会直接改写宿主机网络、防火墙和 IPv6 行为。${NC}"
    echo -e "${YELLOW}请仅在控制台或带外管理可用、已确认维护窗口、已准备回滚方案时继续。${NC}"
    echo -e "${YELLOW}错误的 bridge / bond / VLAN / 路由 / 防火墙规则可能导致 SSH 与 WebUI 断连。${NC}"
    echo -e "${RED}${UI_DIVIDER}${NC}"
}

host_network_ensure_interfaces_file() {
    if [[ ! -f "$HOST_NETWORK_INTERFACES_FILE" ]]; then
        cat > "$HOST_NETWORK_INTERFACES_FILE" <<'EOF_INTERFACES'
auto lo
iface lo inet loopback
EOF_INTERFACES
    fi
}

host_network_get_all_interface_names() {
    host_network_ensure_interfaces_file
    {
        awk '/^iface[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null
        ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1
    } | awk 'NF && $1 != "lo"' | sort -u
}

host_network_get_configured_bridges() {
    host_network_ensure_interfaces_file
    awk '/^iface[[:space:]]+vmbr[0-9]+[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | sort -u
}

host_network_get_configured_vlans() {
    host_network_ensure_interfaces_file
    awk '/^iface[[:space:]]+[A-Za-z0-9_.:-]+\.[0-9]+[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | sort -u
}

host_network_get_configured_bonds() {
    host_network_ensure_interfaces_file
    awk '/^iface[[:space:]]+bond[0-9]+[[:space:]]+/ {print $2}' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | sort -u
}

host_network_guess_next_name() {
    local prefix="$1"
    local idx=0
    while :; do
        if ! host_network_get_all_interface_names | grep -qx "${prefix}${idx}"; then
            echo "${prefix}${idx}"
            return 0
        fi
        idx=$((idx + 1))
    done
}

host_network_validate_iface_name() {
    local name="$1"
    [[ -n "$name" && ${#name} -le 15 && "$name" =~ ^[A-Za-z0-9_.:-]+$ ]]
}

host_network_validate_mtu() {
    local mtu="$1"
    [[ -z "$mtu" ]] && return 0
    if [[ ! "$mtu" =~ ^[0-9]+$ || "$mtu" -lt 576 || "$mtu" -gt 9216 ]]; then
        display_error "MTU 不合法: $mtu" "请输入 576-9216 之间的整数，或留空保持默认。"
        return 1
    fi
}

host_network_get_iface_mac() {
    local iface="$1"
    local mac
    mac="$(cat "/sys/class/net/${iface}/address" 2>/dev/null || true)"
    [[ "$mac" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] && echo "$mac" || echo ""
}

host_network_get_physical_ifaces_with_mac() {
    local iface mac
    for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | sort -u); do
        [[ "$iface" == "lo" ]] && continue
        # 跳过 bridge、bond、vlan 等虚拟接口
        [[ -f "/sys/class/net/${iface}/device/vendor" ]] || continue
        mac="$(host_network_get_iface_mac "$iface")"
        [[ -n "$mac" ]] || continue
        printf '%s|%s\n' "$iface" "$mac"
    done
}

host_network_validate_mac() {
    local mac="$1"
    [[ "$mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]
}

host_network_mac_to_iface() {
    local target_mac="$1"
    target_mac="$(echo "$target_mac" | tr '[:upper:]' '[:lower:]')"
    local iface mac
    for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | sort -u); do
        [[ "$iface" == "lo" ]] && continue
        mac="$(host_network_get_iface_mac "$iface")"
        [[ "$(echo "$mac" | tr '[:upper:]' '[:lower:]')" == "$target_mac" ]] && { echo "$iface"; return 0; }
    done
    return 1
}

host_network_validate_systemd_link_name() {
    local name="$1"
    [[ -n "$name" && ${#name} -le 15 ]] || return 1
    [[ "$name" != "." && "$name" != ".." && "$name" != "all" && "$name" != "default" ]] || return 1
    [[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
    [[ "$name" =~ ^[0-9]+$ ]] && return 1
}

host_network_systemd_link_dir() {
    echo "/etc/systemd/network"
}

host_network_systemd_link_file_for_mac() {
    local mac="$1"
    local lower_mac
    lower_mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"
    echo "$(host_network_systemd_link_dir)/10-pve-tools-${lower_mac//:/-}.link"
}

host_network_systemd_link_get_value() {
    local file="$1"
    local section="$2"
    local key="$3"

    [[ -f "$file" ]] || return 1

    awk -v section="$section" -v key="$key" '
        BEGIN { in_section=0 }
        {
            line=$0
            sub(/[[:space:]]*#.*/, "", line)
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line == "") next
            if (line ~ /^\[[^]]+\]$/) {
                in_section = (line == "[" section "]")
                next
            }
            if (in_section && line ~ ("^" key "[[:space:]]*=[[:space:]]*")) {
                sub("^" key "[[:space:]]*=[[:space:]]*", "", line)
                gsub(/^"/, "", line)
                gsub(/"$/, "", line)
                print line
                exit
            }
        }
    ' "$file"
}

host_network_systemd_link_file_has_binding() {
    local file="$1"
    local mac="$2"
    local name="$3"
    local lower_mac file_mac file_name

    file_mac="$(host_network_systemd_link_get_value "$file" "Match" "MACAddress" 2>/dev/null || true)"
    file_name="$(host_network_systemd_link_get_value "$file" "Link" "Name" 2>/dev/null || true)"
    lower_mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"
    file_mac="$(echo "$file_mac" | tr '[:upper:]' '[:lower:]')"

    [[ "$file_mac" == "$lower_mac" && "$file_name" == "$name" ]]
}

host_network_systemd_link_list_managed_files() {
    local dir
    dir="$(host_network_systemd_link_dir)"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -type f -name '10-pve-tools-*.link' 2>/dev/null | sort
}

host_network_systemd_link_find_conflicts() {
    local mac="$1"
    local name="$2"
    local target_file="$3"
    local dir file file_mac file_name search_dirs=()

    for dir in /etc/systemd/network /run/systemd/network /usr/local/lib/systemd/network /usr/lib/systemd/network; do
        [[ -d "$dir" ]] && search_dirs+=("$dir")
    done

    (( ${#search_dirs[@]} > 0 )) || return 0

    while IFS= read -r -d '' file; do
        [[ "$file" == "$target_file" ]] && continue
        file_mac="$(host_network_systemd_link_get_value "$file" "Match" "MACAddress" 2>/dev/null || true)"
        file_name="$(host_network_systemd_link_get_value "$file" "Link" "Name" 2>/dev/null || true)"
        file_mac="$(echo "$file_mac" | tr '[:upper:]' '[:lower:]')"
        if [[ "$file_mac" == "$mac" ]]; then
            printf '%s|MACAddress=%s\n' "$file" "$file_mac"
        elif [[ "$file_name" == "$name" ]]; then
            printf '%s|Name=%s\n' "$file" "$file_name"
        fi
    done < <(find "${search_dirs[@]}" -maxdepth 1 -type f -name '*.link' -print0 2>/dev/null)
}

host_network_systemd_link_write_binding() {
    local mac="$1"
    local name="$2"
    local lower_mac target_dir target_file tmp backup_path=""
    lower_mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"
    target_dir="$(host_network_systemd_link_dir)"
    target_file="$(host_network_systemd_link_file_for_mac "$lower_mac")"

    mkdir -p "$target_dir" 2>/dev/null || {
        log_error "无法创建 systemd .link 目录: $target_dir"
        return 1
    }

    if [[ -f "$target_file" ]]; then
        if ! backup_file "$target_file" backup_path >/dev/null 2>&1; then
            log_error "无法备份现有 systemd .link 文件: $target_file"
            return 1
        fi
    fi

    tmp="$(mktemp "${target_dir}/.pve-tools-link.XXXXXX")" || {
        log_error "无法创建临时文件: $target_dir"
        return 1
    }

    cat > "$tmp" <<EOF
# Generated by PVE-Tools
[Match]
MACAddress=$lower_mac

[Link]
Name=$name
EOF

    chmod 0644 "$tmp" >/dev/null 2>&1 || true

    if ! mv -f "$tmp" "$target_file"; then
        rm -f "$tmp" >/dev/null 2>&1 || true
        if [[ -n "$backup_path" && -f "$backup_path" ]]; then
            cp -a "$backup_path" "$target_file" >/dev/null 2>&1 || true
        else
            rm -f "$target_file" >/dev/null 2>&1 || true
        fi
        log_error "写入 systemd .link 文件失败: $target_file"
        return 1
    fi

    local verify_mac verify_name
    verify_mac="$(host_network_systemd_link_get_value "$target_file" "Match" "MACAddress" 2>/dev/null || true)"
    verify_name="$(host_network_systemd_link_get_value "$target_file" "Link" "Name" 2>/dev/null || true)"
    verify_mac="$(echo "$verify_mac" | tr '[:upper:]' '[:lower:]')"
    if [[ "$verify_mac" != "$lower_mac" || "$verify_name" != "$name" ]]; then
        if [[ -n "$backup_path" && -f "$backup_path" ]]; then
            cp -a "$backup_path" "$target_file" >/dev/null 2>&1 || rm -f "$target_file" >/dev/null 2>&1 || true
        else
            rm -f "$target_file" >/dev/null 2>&1 || true
        fi
        log_error "写入后的 systemd .link 规则校验失败: $target_file"
        return 1
    fi

    printf '%s\n' "$target_file"
}

host_network_systemd_link_remove_binding_by_mac() {
    local mac="$1"
    local target_file backup_path=""

    target_file="$(host_network_systemd_link_file_for_mac "$mac")"
    [[ -f "$target_file" ]] || return 0

    if ! backup_file "$target_file" backup_path >/dev/null 2>&1; then
        log_error "无法备份待删除的 systemd .link 文件: $target_file"
        return 1
    fi

    if ! rm -f "$target_file"; then
        log_error "删除 systemd .link 文件失败: $target_file"
        return 1
    fi

    [[ -e "$target_file" ]] && {
        log_error "systemd .link 文件仍然存在: $target_file"
        return 1
    }
}

host_network_legacy_udev_rules_file() {
    echo "/etc/udev/rules.d/70-persistent-net.rules"
}

host_network_legacy_udev_list_bindings() {
    local file line mac legacy_name
    file="$(host_network_legacy_udev_rules_file)"
    [[ -f "$file" ]] || return 0

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        mac="$(echo "$line" | sed -n 's/.*ATTR{address}=="\([^"]*\)".*/\1/p')"
        legacy_name="$(echo "$line" | sed -n 's/.*NAME="\([^"]*\)".*/\1/p')"
        [[ -n "$mac" && -n "$legacy_name" ]] || continue
        printf '%s|%s\n' "$mac" "$legacy_name"
    done < "$file"
}

host_network_legacy_udev_name_conflicts() {
    local mac="$1"
    local name="$2"
    local file line legacy_mac legacy_name lower_mac
    file="$(host_network_legacy_udev_rules_file)"
    [[ -f "$file" ]] || return 1

    lower_mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        legacy_mac="$(echo "$line" | sed -n 's/.*ATTR{address}=="\([^"]*\)".*/\1/p')"
        legacy_name="$(echo "$line" | sed -n 's/.*NAME="\([^"]*\)".*/\1/p')"
        [[ -n "$legacy_mac" && -n "$legacy_name" ]] || continue
        legacy_mac="$(echo "$legacy_mac" | tr '[:upper:]' '[:lower:]')"
        if [[ "$legacy_name" == "$name" && "$legacy_mac" != "$lower_mac" ]]; then
            return 0
        fi
    done < "$file"

    return 1
}

host_network_legacy_udev_prune_binding() {
    local mac="$1"
    local file tmp backup_path="" lower_mac

    file="$(host_network_legacy_udev_rules_file)"
    [[ -f "$file" ]] || return 0

    if ! backup_file "$file" backup_path >/dev/null 2>&1; then
        log_error "无法备份 legacy udev 规则文件: $file"
        return 1
    fi

    lower_mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"
    tmp="$(mktemp)" || {
        log_error "无法创建临时文件用于清理 legacy udev 规则"
        return 1
    }

    awk -v mac="$lower_mac" '
        {
            line=$0
            line_lc=tolower(line)
            if (index(line_lc, "ATTR{address}==\"" mac "\"") > 0) next
            print
        }
    ' "$file" > "$tmp"

    if ! mv -f "$tmp" "$file"; then
        rm -f "$tmp" >/dev/null 2>&1 || true
        if [[ -n "$backup_path" && -f "$backup_path" ]]; then
            cp -a "$backup_path" "$file" >/dev/null 2>&1 || true
        fi
        log_error "清理 legacy udev 规则失败: $file"
        return 1
    fi

    [[ -s "$file" ]] || rm -f "$file"
}

host_network_interface_has_config_reference() {
    local iface_name="$1"
    awk -v iface_name="$iface_name" '
        {
            line=$0
            sub(/[[:space:]]*#.*/, "", line)
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line == "") next

            n=split(line, fields, /[[:space:]]+/)
            if (fields[1] == "iface" && n >= 2 && fields[2] == iface_name) {
                print line
                exit
            }
            if (fields[1] == "auto" || fields[1] ~ /^allow-/ || fields[1] == "bridge-ports" || fields[1] == "bond-slaves" || fields[1] == "vlan-raw-device") {
                for (i=2; i<=n; i++) {
                    if (fields[i] == iface_name) {
                        print line
                        exit
                    }
                }
            }
        }
    ' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | grep -q .
}

host_network_mac_binding_has_dependency() {
    local iface_name="$1"
    host_network_interface_has_master_dependency "$iface_name" && return 0
    host_network_interface_has_config_reference "$iface_name"
}

host_network_show_mac_bindings() {
    local file iface mac link_name
    echo -e "${CYAN}当前 MAC 地址绑定（systemd .link 规则）：${NC}"
    if host_network_systemd_link_list_managed_files | grep -q .; then
        while IFS= read -r file; do
            [[ -n "$file" ]] || continue
            mac="$(host_network_systemd_link_get_value "$file" "Match" "MACAddress" 2>/dev/null || true)"
            link_name="$(host_network_systemd_link_get_value "$file" "Link" "Name" 2>/dev/null || true)"
            [[ -n "$mac" && -n "$link_name" ]] || continue
            iface="$(host_network_mac_to_iface "$mac" 2>/dev/null || true)"
            if [[ -n "$iface" ]]; then
                printf '  %s → %s (当前接口: %s)\n' "$mac" "$link_name" "$iface"
            else
                printf '  %s → %s (当前未识别)\n' "$mac" "$link_name"
            fi
        done < <(host_network_systemd_link_list_managed_files)
    else
        echo "  (无)"
    fi
    echo "$UI_DIVIDER"
    echo -e "${YELLOW}旧式 udev 绑定（兼容清理中）：${NC}"
    if host_network_legacy_udev_list_bindings | grep -q .; then
        while IFS='|' read -r mac link_name; do
            [[ -n "$mac" ]] || continue
            printf '  %s → %s\n' "$mac" "$link_name"
        done < <(host_network_legacy_udev_list_bindings)
    else
        echo "  (无)"
    fi
    echo "$UI_DIVIDER"
    echo -e "${CYAN}物理网卡 MAC 地址列表：${NC}"
    local entry iface_name iface_mac
    while IFS='|' read -r iface_name iface_mac; do
        [[ -n "$iface_name" ]] || continue
        link_name="$(host_network_systemd_link_get_value "$(host_network_systemd_link_file_for_mac "$iface_mac")" "Link" "Name" 2>/dev/null || true)"
        if [[ -n "$link_name" ]]; then
            printf '  [%s] %s (已绑定为 %s)\n' "$iface_name" "$iface_mac" "$link_name"
        else
            printf '  [%s] %s\n' "$iface_name" "$iface_mac"
        fi
    done < <(host_network_get_physical_ifaces_with_mac)
}

host_network_create_mac_binding() {
    local entries=()
    local entry iface_name iface_mac idx pick fixed_name target_file backup_path link_name

    while IFS='|' read -r iface_name iface_mac; do
        [[ -n "$iface_name" ]] || continue
        entries+=("$iface_name|$iface_mac")
    done < <(host_network_get_physical_ifaces_with_mac)

    if (( ${#entries[@]} == 0 )); then
        display_error "未发现物理网卡" "请确认系统存在带有 PCI 设备的网络接口。"
        return 1
    fi

    echo -e "${CYAN}可用物理网卡（按 MAC 地址固定命名）：${NC}"
    idx=1
    for entry in "${entries[@]}"; do
        iface_name="${entry%%|*}"
        iface_mac="${entry##*|}"
        link_name="$(host_network_systemd_link_get_value "$(host_network_systemd_link_file_for_mac "$iface_mac")" "Link" "Name" 2>/dev/null || true)"
        if [[ -n "$link_name" ]]; then
            printf '  [%d] %s | %s (已绑定: %s)\n' "$idx" "$iface_name" "$iface_mac" "$link_name"
        else
            printf '  [%d] %s | %s\n' "$idx" "$iface_name" "$iface_mac"
        fi
        idx=$((idx + 1))
    done
    echo "$UI_DIVIDER"

    read -p "请选择要固定命名的网卡序号 (0 返回): " pick
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || { display_error "无效选择"; return 1; }
    if (( pick < 1 || pick > ${#entries[@]} )); then
        display_error "选择超出范围"
        return 1
    fi

    entry="${entries[$((pick - 1))]}"
    iface_name="${entry%%|*}"
    iface_mac="${entry##*|}"
    target_file="$(host_network_systemd_link_file_for_mac "$iface_mac")"

    read -r -p "请输入固定接口名称（如 lan0、pve-eth0）: " fixed_name
    [[ -n "$fixed_name" ]] || { display_error "接口名称不能为空"; return 1; }
    host_network_validate_systemd_link_name "$fixed_name" || {
        display_error "接口名称不合法: $fixed_name" "名称需为 1-15 位，只允许字母、数字、_、.、-，且不能是纯数字或保留名。"
        return 1
    }

    if [[ "$fixed_name" != "$iface_name" ]] && host_network_iface_exists "$fixed_name"; then
        display_error "目标接口名称已被占用: $fixed_name" "请改用未被现有接口使用的名称。"
        return 1
    fi

    if host_network_mac_binding_has_dependency "$iface_name"; then
        display_error "该网卡已被宿主机网络配置引用" "请先迁移或删除依赖该接口的 bridge / bond / VLAN / direct iface 配置，再修改命名。"
        return 1
    fi

    if host_network_legacy_udev_name_conflicts "$iface_mac" "$fixed_name"; then
        display_error "旧式 udev 规则中已存在同名绑定" "请先人工处理 /etc/udev/rules.d/70-persistent-net.rules 中的同名规则，再继续迁移。"
        return 1
    fi

    mapfile -t conflicts < <(host_network_systemd_link_find_conflicts "$iface_mac" "$fixed_name" "$target_file")
    if (( ${#conflicts[@]} > 0 )); then
        local conflict_report="检测到其他 systemd .link 文件已经匹配相同 MAC 或同名接口："
        local conflict
        for conflict in "${conflicts[@]}"; do
            conflict_report+=$'\n  - '"${conflict%%|*} (${conflict##*|})"
        done
        display_error "检测到 systemd .link 规则冲突" "$conflict_report"
        return 1
    fi

    if [[ -f "$target_file" ]] && host_network_systemd_link_file_has_binding "$target_file" "$iface_mac" "$fixed_name"; then
        display_success "固定命名规则已存在" "文件: $target_file；重启宿主机后仍会保持该命名。"
        return 0
    fi

    if ! confirm_high_risk_action "为 MAC 地址 ${iface_mac} 写入固定命名 ${fixed_name}" "将生成 ${target_file}，让 systemd 根据 MAC 在启动时重命名接口。" "固定名与现有接口或其他 .link 文件冲突时，接口命名可能变得不可预测。" "请确认名称唯一，并准备好控制台或带外管理手段以便回滚。" "BIND-LINK"; then
        return 0
    fi

    if ! host_network_legacy_udev_prune_binding "$iface_mac"; then
        display_error "清理旧式 udev 绑定失败" "请先处理 /etc/udev/rules.d/70-persistent-net.rules 后重试。"
        return 1
    fi

    if ! target_file="$(host_network_systemd_link_write_binding "$iface_mac" "$fixed_name")"; then
        display_error "MAC 地址固定命名写入失败" "请先处理冲突提示，或检查 /etc/systemd/network 目录权限。"
        return 1
    fi

    display_success "MAC 地址固定命名规则已写入" "文件: $target_file；建议重启宿主机后生效。"
}

host_network_delete_mac_binding() {
    local file mac link_name entries=() idx pick file_list
    file_list="$(host_network_systemd_link_list_managed_files)" || file_list=""

    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        mac="$(host_network_systemd_link_get_value "$file" "Match" "MACAddress" 2>/dev/null || true)"
        link_name="$(host_network_systemd_link_get_value "$file" "Link" "Name" 2>/dev/null || true)"
        [[ -n "$mac" && -n "$link_name" ]] || continue
        entries+=("$file|$mac|$link_name")
    done <<< "$file_list"

    if (( ${#entries[@]} == 0 )); then
        display_error "没有可删除的 MAC 绑定规则" "当前没有 PVE-Tools 管理的 systemd .link 文件。"
        return 1
    fi

    echo -e "${CYAN}已存在的 MAC 地址绑定：${NC}"
    idx=1
    for entry in "${entries[@]}"; do
        file="${entry%%|*}"
        mac="${entry#*|}"
        mac="${mac%%|*}"
        link_name="${entry##*|}"
        printf '  [%d] %s → %s (%s)\n' "$idx" "$mac" "$link_name" "$(basename "$file")"
        idx=$((idx + 1))
    done
    echo "$UI_DIVIDER"

    read -p "请选择要删除的绑定序号 (0 返回): " pick
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || { display_error "无效选择"; return 1; }
    if (( pick < 1 || pick > ${#entries[@]} )); then
        display_error "选择超出范围"
        return 1
    fi

    entry="${entries[$((pick - 1))]}"
    file="${entry%%|*}"
    mac="${entry#*|}"
    mac="${mac%%|*}"
    link_name="${entry##*|}"

    if ! confirm_action "删除 MAC 地址固定命名 ${mac} → ${link_name}"; then
        return 0
    fi

    if ! host_network_legacy_udev_prune_binding "$mac"; then
        display_error "清理旧式 udev 绑定失败" "请检查 /etc/udev/rules.d/70-persistent-net.rules 的权限与内容。"
        return 1
    fi

    if ! host_network_systemd_link_remove_binding_by_mac "$mac"; then
        display_error "删除 MAC 地址固定命名失败" "请检查文件权限或磁盘状态。"
        return 1
    fi

    display_success "MAC 地址固定命名已删除: ${mac} → ${link_name}" "如需恢复，请重新创建对应 .link 文件。"
}

host_network_validate_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    awk -F'.' '{for(i=1;i<=4;i++) if($i < 0 || $i > 255) exit 1; exit 0}' <<< "$ip"
}

host_network_validate_ipv4_cidr() {
    local value="$1"
    local ip="${value%/*}"
    local prefix="${value##*/}"
    [[ "$value" == */* ]] || return 1
    host_network_validate_ipv4 "$ip" || return 1
    [[ "$prefix" =~ ^[0-9]+$ && "$prefix" -ge 0 && "$prefix" -le 32 ]]
}

host_network_validate_ipv6() {
    local ip="$1"
    [[ "$ip" == *:* ]] || return 1
    [[ "$ip" =~ ^[0-9A-Fa-f:]+(%[A-Za-z0-9_.-]+)?$ ]]
}

host_network_validate_ipv6_cidr() {
    local value="$1"
    local ip="${value%/*}"
    local prefix="${value##*/}"
    [[ "$value" == */* ]] || return 1
    host_network_validate_ipv6 "$ip" || return 1
    [[ "$prefix" =~ ^[0-9]+$ && "$prefix" -ge 0 && "$prefix" -le 128 ]]
}

host_network_validate_static_address() {
    local family="$1"
    local address="$2"
    case "$family" in
        inet) host_network_validate_ipv4_cidr "$address" ;;
        inet6) host_network_validate_ipv6_cidr "$address" ;;
        *) return 1 ;;
    esac
}

host_network_validate_gateway() {
    local family="$1"
    local gateway="$2"
    [[ -z "$gateway" ]] && return 0
    case "$family" in
        inet) host_network_validate_ipv4 "$gateway" ;;
        inet6) host_network_validate_ipv6 "$gateway" ;;
        *) return 1 ;;
    esac
}

host_network_iface_exists() {
    local iface_name="$1"
    host_network_get_all_interface_names | grep -qx "$iface_name"
}

host_network_interface_has_master_dependency() {
    local iface_name="$1"
    awk -v iface_name="$iface_name" '
        /^[[:space:]]*(bridge-ports|bond-slaves)[[:space:]]+/ {
            for (i=2; i<=NF; i++) {
                if ($i == iface_name) {
                    print $0
                    exit
                }
            }
        }
    ' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null | grep -q .
}

host_network_validate_member_list() {
    local members_text="$1"
    local owner_name="$2"
    local relation_label="$3"
    local -A seen=()
    local member count=0

    while IFS= read -r member; do
        [[ -n "$member" ]] || continue
        host_network_validate_iface_name "$member" || {
            display_error "$relation_label 中包含非法接口名: $member"
            return 1
        }
        [[ "$member" != "$owner_name" ]] || {
            display_error "$relation_label 不能引用自身接口: $owner_name"
            return 1
        }
        if [[ -n "${seen[$member]:-}" ]]; then
            display_error "$relation_label 中存在重复成员: $member"
            return 1
        fi
        seen[$member]=1
        host_network_iface_exists "$member" || {
            display_error "接口不存在: $member" "请先确认该接口已经存在于宿主机链路或配置中。"
            return 1
        }
        if host_network_interface_has_master_dependency "$member"; then
            display_error "接口已被其他 bridge/bond 使用: $member" "请先解除现有从属关系，再重新编排宿主机网络。"
            return 1
        fi
        count=$((count + 1))
    done < <(printf '%s\n' "$members_text" | tr ' ' '\n' | awk 'NF')

    if (( count == 0 )); then
        display_error "$relation_label 不能为空"
        return 1
    fi
}
host_network_select_from_text() {
    local title="$1"
    local items_text="$2"
    mapfile -t items < <(printf '%s\n' "$items_text" | awk 'NF')
    if (( ${#items[@]} == 0 )); then
        return 1
    fi

    echo -e "${CYAN}${title}${NC}" >&2
    local i=1
    for item in "${items[@]}"; do
        printf '  [%d] %s\n' "$i" "$item" >&2
        i=$((i + 1))
    done
    echo "$UI_DIVIDER" >&2

    local pick
    read -p "请选择序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#items[@]} )); then
        return 1
    fi
    printf '%s\n' "${items[$((pick - 1))]}"
}

host_network_select_interface_name() {
    host_network_select_from_text "可用接口：" "$(host_network_get_all_interface_names)"
}

host_network_select_bridge_name() {
    host_network_select_from_text "已配置桥接：" "$(host_network_get_configured_bridges)"
}

host_network_select_bond_name() {
    host_network_select_from_text "已配置 Bond：" "$(host_network_get_configured_bonds)"
}

host_network_select_vlan_name() {
    host_network_select_from_text "已配置 VLAN 子接口：" "$(host_network_get_configured_vlans)"
}

host_network_show_current_overview() {
    clear
    show_menu_header "宿主机网络概览"
    echo -e "${CYAN}运行时链路：${NC}"
    ip -brief link 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}运行时地址：${NC}"
    ip -brief addr 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}默认路由：${NC}"
    ip route 2>/dev/null | sed 's/^/  /' || true
    ip -6 route 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}当前配置中的 bridge / bond / VLAN：${NC}"
    awk '
        /^iface[[:space:]]+/ {
            name=$2
            fam=$3
            method=$4
            if (name ~ /^vmbr[0-9]+$/ || name ~ /^bond[0-9]+$/ || name ~ /\.[0-9]+$/) {
                printf "  %s (%s %s)\n", name, fam, method
            }
        }
    ' "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null || true
    echo "$UI_DIVIDER"
}

host_network_collect_family_config() {
    local family="$1"
    local phase="${2:-create}"
    local choice method address gateway extra

    if [[ "$family" == "inet" ]]; then
        if [[ "$phase" == "update" ]]; then
            echo "  [1] 保持当前 IPv4" >&2
            echo "  [2] 静态 IPv4" >&2
            echo "  [3] DHCPv4" >&2
            read -p "请选择 IPv4 模式 [1-3]: " choice
            case "$choice" in
                1|"") echo "keep|||"; return 0 ;;
                2) method="static" ;;
                3) method="dhcp" ;;
                *) return 1 ;;
            esac
        else
            echo "  [1] 静态 IPv4" >&2
            echo "  [2] DHCPv4" >&2
            echo "  [3] 不配置 IPv4" >&2
            read -p "请选择 IPv4 模式 [1-3]: " choice
            case "$choice" in
                1) method="static" ;;
                2) method="dhcp" ;;
                3|"") echo "none|||"; return 0 ;;
                *) return 1 ;;
            esac
        fi
    else
        if [[ "$phase" == "update" ]]; then
            echo "  [1] 保持当前 IPv6" >&2
            echo "  [2] 静态 IPv6" >&2
            echo "  [3] DHCPv6" >&2
            echo "  [4] SLAAC" >&2
            echo "  [5] 移除 IPv6 stanza" >&2
            read -p "请选择 IPv6 模式 [1-5]: " choice
            case "$choice" in
                1|"") echo "keep|||"; return 0 ;;
                2) method="static" ;;
                3) method="dhcp" ;;
                4) method="auto"; extra="accept-ra 2" ;;
                5) echo "remove|||"; return 0 ;;
                *) return 1 ;;
            esac
        else
            echo "  [1] 静态 IPv6" >&2
            echo "  [2] DHCPv6" >&2
            echo "  [3] SLAAC" >&2
            echo "  [4] 不配置 IPv6" >&2
            read -p "请选择 IPv6 模式 [1-4]: " choice
            case "$choice" in
                1) method="static" ;;
                2) method="dhcp" ;;
                3) method="auto"; extra="accept-ra 2" ;;
                4|"") echo "none|||"; return 0 ;;
                *) return 1 ;;
            esac
        fi
    fi

    if [[ "$method" == "static" ]]; then
        if [[ "$family" == "inet" ]]; then
            read -p "请输入静态 IPv4/CIDR（示例 192.168.10.2/24）: " address
        else
            read -p "请输入静态 IPv6/CIDR（示例 2001:db8::2/64）: " address
        fi
        [[ -n "$address" ]] || return 1
        host_network_validate_static_address "$family" "$address" || {
            display_error "静态地址格式无效: $address"
            return 1
        }
        read -p "请输入网关（留空跳过）: " gateway
        host_network_validate_gateway "$family" "$gateway" || {
            display_error "网关格式无效: $gateway"
            return 1
        }
    fi

    printf '%s|%s|%s|%s\n' "$method" "$address" "$gateway" "$extra"
}
host_network_extract_family_stanza() {
    local file_path="$1"
    local iface_name="$2"
    local family="$3"
    awk -v iface_name="$iface_name" -v family="$family" '
        BEGIN { capture=0 }
        {
            if (capture) {
                if ($0 !~ /^[[:space:]]/ && $0 ~ /^(iface|auto|allow-)/) {
                    exit
                }
                print
                next
            }
            if ($0 ~ ("^iface[[:space:]]+" iface_name "[[:space:]]+" family "([[:space:]]+|$)")) {
                capture=1
                print
            }
        }
    ' "$file_path"
}

host_network_collect_preserved_family_options() {
    local file_path="$1"
    local iface_name="$2"
    local family="$3"
    host_network_extract_family_stanza "$file_path" "$iface_name" "$family" | awk '
        NR == 1 { next }
        /^[[:space:]]+/ {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            if (line ~ /^(address|gateway|netmask|broadcast|pointopoint|accept-ra|dns-nameservers|dns-search)([[:space:]]|$)/) next
            if (line ~ /MASQUERADE/) next
            if (line ~ /net\.ipv6\.conf\.all\.forwarding/) next
            print line
        }
    '
}

host_network_remove_iface_family_from_candidate() {
    local file_path="$1"
    local iface_name="$2"
    local family="$3"
    local tmp
    tmp=$(mktemp)
    awk -v iface_name="$iface_name" -v family="$family" '
        BEGIN { skip=0 }
        {
            if (skip) {
                if ($0 !~ /^[[:space:]]/ && $0 !~ /^$/) {
                    skip=0
                } else {
                    next
                }
            }
            if ($0 ~ ("^iface[[:space:]]+" iface_name "[[:space:]]+" family "([[:space:]]+|$)")) {
                skip=1
                next
            }
            print
        }
    ' "$file_path" > "$tmp"
    mv "$tmp" "$file_path"
}

host_network_remove_iface_from_candidate() {
    local file_path="$1"
    local iface_name="$2"
    local tmp
    tmp=$(mktemp)
    awk -v iface_name="$iface_name" '
        BEGIN { skip=0 }
        function rebuild_line(line,   n, i, parts, out, kept) {
            n=split(line, parts, /[[:space:]]+/)
            out=parts[1]
            kept=0
            for (i=2; i<=n; i++) {
                if (parts[i] == iface_name || parts[i] == "") continue
                out=out " " parts[i]
                kept=1
            }
            if (kept) print out
        }
        {
            if (skip) {
                if ($0 !~ /^[[:space:]]/ && $0 !~ /^$/) {
                    skip=0
                } else {
                    next
                }
            }
            if ($0 ~ ("^# PVE-TOOLS HOST IFACE (BEGIN|END) " iface_name "$")) next
            if ($0 ~ /^(auto|allow-[^[:space:]]+)/) {
                if ($0 ~ ("(^|[[:space:]])" iface_name "([[:space:]]|$)")) {
                    rebuild_line($0)
                    next
                }
            }
            if ($0 ~ ("^iface[[:space:]]+" iface_name "[[:space:]]+(inet|inet6)([[:space:]]+|$)")) {
                skip=1
                next
            }
            print
        }
    ' "$file_path" > "$tmp"
    mv "$tmp" "$file_path"
}

host_network_ensure_auto_line_in_candidate() {
    local file_path="$1"
    local iface_name="$2"
    if ! grep -Eq "^(auto|allow-[^[:space:]]+)[[:space:]].*\b${iface_name}\b" "$file_path"; then
        printf '\nauto %s\n' "$iface_name" >> "$file_path"
    fi
}

host_network_append_text_to_candidate() {
    local file_path="$1"
    local text="$2"
    printf '\n%s\n' "$text" >> "$file_path"
}

host_network_build_family_stanza() {
    local iface_name="$1"
    local family="$2"
    local cfg="$3"
    local preserved_text="$4"
    local method address gateway extra
    IFS='|' read -r method address gateway extra <<< "$cfg"

    [[ "$method" == "remove" ]] && return 0
    [[ "$method" == "keep" ]] && return 0

    printf 'iface %s %s %s\n' "$iface_name" "$family" "$method"
    if [[ -n "$preserved_text" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf '    %s\n' "$line"
        done <<< "$preserved_text"
    fi
    [[ -n "$address" ]] && printf '    address %s\n' "$address"
    [[ -n "$gateway" ]] && printf '    gateway %s\n' "$gateway"
    [[ -n "$extra" ]] && printf '    %s\n' "$extra"
}

host_network_build_bridge_block() {
    local iface_name="$1"
    local ports="$2"
    local vlan_aware="$3"
    local mtu="$4"
    local ipv4_cfg="$5"
    local ipv6_cfg="$6"
    local v4_method v4_addr v4_gw v4_extra
    local v6_method v6_addr v6_gw v6_extra
    IFS='|' read -r v4_method v4_addr v4_gw v4_extra <<< "$ipv4_cfg"
    IFS='|' read -r v6_method v6_addr v6_gw v6_extra <<< "$ipv6_cfg"

    [[ "$v4_method" == "none" ]] && v4_method="manual"
    printf 'auto %s\n' "$iface_name"
    printf 'iface %s inet %s\n' "$iface_name" "$v4_method"
    printf '    bridge-ports %s\n' "${ports:-none}"
    printf '    bridge-stp off\n'
    printf '    bridge-fd 0\n'
    [[ "$vlan_aware" == "yes" || "$vlan_aware" == "YES" ]] && printf '    bridge-vlan-aware yes\n'
    [[ -n "$mtu" ]] && printf '    mtu %s\n' "$mtu"
    [[ "$v4_method" == "static" && -n "$v4_addr" ]] && printf '    address %s\n' "$v4_addr"
    [[ "$v4_method" == "static" && -n "$v4_gw" ]] && printf '    gateway %s\n' "$v4_gw"

    if [[ "$v6_method" != "none" ]]; then
        printf '\niface %s inet6 %s\n' "$iface_name" "$v6_method"
        [[ -n "$v6_addr" ]] && printf '    address %s\n' "$v6_addr"
        [[ -n "$v6_gw" ]] && printf '    gateway %s\n' "$v6_gw"
        [[ -n "$v6_extra" ]] && printf '    %s\n' "$v6_extra"
    fi
}

host_network_build_vlan_block() {
    local iface_name="$1"
    local raw_dev="$2"
    local mtu="$3"
    local ipv4_cfg="$4"
    local ipv6_cfg="$5"
    local v4_method v4_addr v4_gw v4_extra
    local v6_method v6_addr v6_gw v6_extra
    IFS='|' read -r v4_method v4_addr v4_gw v4_extra <<< "$ipv4_cfg"
    IFS='|' read -r v6_method v6_addr v6_gw v6_extra <<< "$ipv6_cfg"

    [[ "$v4_method" == "none" ]] && v4_method="manual"
    printf 'auto %s\n' "$iface_name"
    printf 'iface %s inet %s\n' "$iface_name" "$v4_method"
    printf '    vlan-raw-device %s\n' "$raw_dev"
    [[ -n "$mtu" ]] && printf '    mtu %s\n' "$mtu"
    [[ "$v4_method" == "static" && -n "$v4_addr" ]] && printf '    address %s\n' "$v4_addr"
    [[ "$v4_method" == "static" && -n "$v4_gw" ]] && printf '    gateway %s\n' "$v4_gw"

    if [[ "$v6_method" != "none" ]]; then
        printf '\niface %s inet6 %s\n' "$iface_name" "$v6_method"
        [[ -n "$v6_addr" ]] && printf '    address %s\n' "$v6_addr"
        [[ -n "$v6_gw" ]] && printf '    gateway %s\n' "$v6_gw"
        [[ -n "$v6_extra" ]] && printf '    %s\n' "$v6_extra"
    fi
}

host_network_build_bond_block() {
    local iface_name="$1"
    local slaves="$2"
    local mode="$3"
    local mtu="$4"
    local ipv4_cfg="$5"
    local ipv6_cfg="$6"
    local mode_name=""
    local v4_method v4_addr v4_gw v4_extra
    local v6_method v6_addr v6_gw v6_extra
    IFS='|' read -r v4_method v4_addr v4_gw v4_extra <<< "$ipv4_cfg"
    IFS='|' read -r v6_method v6_addr v6_gw v6_extra <<< "$ipv6_cfg"

    case "$mode" in
        0) mode_name="balance-rr" ;;
        1) mode_name="active-backup" ;;
        4) mode_name="802.3ad" ;;
        6) mode_name="balance-alb" ;;
        *) return 1 ;;
    esac

    [[ "$v4_method" == "none" ]] && v4_method="manual"
    printf 'auto %s\n' "$iface_name"
    printf 'iface %s inet %s\n' "$iface_name" "$v4_method"
    printf '    bond-slaves %s\n' "$slaves"
    printf '    bond-mode %s\n' "$mode_name"
    printf '    bond-miimon 100\n'
    [[ "$mode_name" == "802.3ad" ]] && printf '    bond-xmit-hash-policy layer2+3\n    bond-lacp-rate fast\n'
    [[ -n "$mtu" ]] && printf '    mtu %s\n' "$mtu"
    [[ "$v4_method" == "static" && -n "$v4_addr" ]] && printf '    address %s\n' "$v4_addr"
    [[ "$v4_method" == "static" && -n "$v4_gw" ]] && printf '    gateway %s\n' "$v4_gw"

    if [[ "$v6_method" != "none" ]]; then
        printf '\niface %s inet6 %s\n' "$iface_name" "$v6_method"
        [[ -n "$v6_addr" ]] && printf '    address %s\n' "$v6_addr"
        [[ -n "$v6_gw" ]] && printf '    gateway %s\n' "$v6_gw"
        [[ -n "$v6_extra" ]] && printf '    %s\n' "$v6_extra"
    fi
}

host_network_commit_candidate() {
    local candidate_file="$1"
    local action_desc="$2"
    local risk_desc="$3"
    local impact_desc="$4"
    local backup_desc="$5"
    local backup_path=""

    mkdir -p "$(dirname "$HOST_NETWORK_INTERFACES_STAGED_FILE")" >/dev/null 2>&1 || true
    cp "$candidate_file" "$HOST_NETWORK_INTERFACES_STAGED_FILE"

    clear
    show_menu_header "宿主机网络变更预览"
    echo -e "${YELLOW}动作:${NC} $action_desc"
    echo -e "${YELLOW}已写入 staged:${NC} $HOST_NETWORK_INTERFACES_STAGED_FILE"
    echo "$UI_DIVIDER"
    diff -u "$HOST_NETWORK_INTERFACES_FILE" "$candidate_file" 2>/dev/null | sed 's/^/  /' || true
    echo "$UI_DIVIDER"

    local stage_only
    read -p "是否只写入 staged 文件而不立即应用？(yes/no) [yes]: " stage_only
    stage_only="${stage_only:-yes}"
    if [[ "$stage_only" == "yes" || "$stage_only" == "YES" ]]; then
        display_success "候选网络配置已写入 staged 文件" "建议先在控制台或带外环境审阅后，再使用 pvenetcommit / ifreload 正式切换。"
        return 0
    fi

    if ! confirm_high_risk_action "$action_desc" "$risk_desc" "$impact_desc" "$backup_desc" "APPLY-NET"; then
        return 0
    fi

    backup_file "$HOST_NETWORK_INTERFACES_FILE" backup_path >/dev/null 2>&1 || true

    if command -v pvenetcommit >/dev/null 2>&1; then
        if pvenetcommit >/dev/null 2>&1; then
            display_success "网络配置已通过 pvenetcommit 提交" "如 SSH 断连，请通过控制台确认新链路已生效。"
            return 0
        fi
        log_warn "pvenetcommit 执行失败，准备回退到显式文件切换流程。"
    fi

    if ! command -v ifreload >/dev/null 2>&1; then
        display_error "当前环境缺少 ifreload，已拒绝直接覆盖正式网络配置" "请保留 staged 文件，并在控制台中使用 pvenetcommit 或人工审核后再应用。"
        return 1
    fi

    cp "$candidate_file" "$HOST_NETWORK_INTERFACES_FILE"
    if ifreload -a >/dev/null 2>&1; then
        display_success "网络配置已应用" "如当前会话断连，请通过控制台确认 bridge / bond / VLAN 和路由状态。"
        return 0
    fi

    if [[ -n "$backup_path" && -f "$backup_path" ]]; then
        log_warn "新网络配置应用失败，正在尝试自动恢复备份。"
        cp "$backup_path" "$HOST_NETWORK_INTERFACES_FILE"
        if ifreload -a >/dev/null 2>&1; then
            display_error "网络配置应用失败，已自动回滚" "请审阅 $HOST_NETWORK_INTERFACES_STAGED_FILE 与备份 $backup_path 后再重试。"
            return 1
        fi
        display_error "网络配置应用失败，且自动回滚未能重新加载" "请立即通过控制台检查 $HOST_NETWORK_INTERFACES_FILE、$HOST_NETWORK_INTERFACES_STAGED_FILE 与备份 $backup_path。"
        return 1
    fi

    display_error "网络配置应用失败" "未获取到可用备份，需立即通过控制台检查 $HOST_NETWORK_INTERFACES_FILE。"
    return 1
}
host_network_create_bridge() {
    host_network_show_current_overview
    local default_name bridge_name ports vlan_aware mtu ipv4_cfg ipv6_cfg tmp block
    default_name="$(host_network_guess_next_name vmbr)"
    read -p "请输入桥接名称 [$default_name]: " bridge_name
    bridge_name="${bridge_name:-$default_name}"
    host_network_validate_iface_name "$bridge_name" || {
        display_error "桥接名称不合法: $bridge_name" "接口名需为 1-15 位，且仅允许字母、数字、._:-。"
        return 1
    }
    if host_network_get_all_interface_names | grep -qx "$bridge_name"; then
        display_error "接口已存在: $bridge_name"
        return 1
    fi

    echo -e "${CYAN}可作为 bridge-ports 的接口（可输入多个，以空格分隔；留空表示 none）：${NC}"
    host_network_get_all_interface_names | sed 's/^/  - /'
    read -p "bridge-ports [none]: " ports
    ports="${ports:-none}"
    if [[ "$ports" != "none" ]]; then
        host_network_validate_member_list "$ports" "$bridge_name" "bridge-ports" || return 1
    fi

    read -p "是否启用 VLAN Aware？(yes/no) [yes]: " vlan_aware
    vlan_aware="${vlan_aware:-yes}"
    case "$vlan_aware" in
        yes|YES|no|NO) ;;
        *)
            display_error "VLAN Aware 仅支持 yes/no"
            return 1
            ;;
    esac

    read -p "MTU（留空保持默认）: " mtu
    host_network_validate_mtu "$mtu" || return 1
    echo "$UI_DIVIDER"
    ipv4_cfg="$(host_network_collect_family_config inet create)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 create)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    block="$(host_network_build_bridge_block "$bridge_name" "$ports" "$vlan_aware" "$mtu" "$ipv4_cfg" "$ipv6_cfg")"
    host_network_remove_iface_from_candidate "$tmp" "$bridge_name"
    host_network_append_text_to_candidate "$tmp" "# PVE-TOOLS HOST IFACE BEGIN $bridge_name
$block
# PVE-TOOLS HOST IFACE END $bridge_name"
    host_network_commit_candidate "$tmp" "创建桥接 $bridge_name" "将直接改写宿主机网桥配置，错误的桥接成员口、地址或网关会导致宿主机失联。" "SSH/WebUI、集群网络、VM 出口网络都可能受到影响。" "请确认控制台可用、bridge-ports 和网关正确，并已准备回滚。"
    rm -f "$tmp"
}
host_network_delete_bridge() {
    local bridge_name
    bridge_name="$(host_network_select_bridge_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bridge_name" ]] || return 1

    if grep -Eq "(bridge-ports|bond-slaves|vlan-raw-device)[[:space:]].*\b${bridge_name}\b" "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null; then
        display_error "检测到其他接口仍依赖 $bridge_name" "请先删除依赖它的 VLAN、bond 或 bridge 关系后再试。"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    host_network_remove_iface_from_candidate "$tmp" "$bridge_name"
    host_network_commit_candidate "$tmp" "删除桥接 $bridge_name" "删除桥接会切断与该 bridge 绑定的宿主机与 VM 网络配置。" "如果该 bridge 承载管理口或生产流量，宿主机会立即失联。" "请确认管理流量不走该桥接，且相关 VM 已迁移或停机。"
    rm -f "$tmp"
}

host_network_bridge_menu() {
    while true; do
        clear
        show_menu_header "桥接管理"
        host_network_show_risk_banner
        echo -e "${CYAN}当前 bridge：${NC}"
        if host_network_get_configured_bridges | awk 'NF{print "  - "$0}'; then :; fi
        echo "$UI_DIVIDER"
        show_menu_option "1" "列出当前网卡与桥接"
        show_menu_option "2" "创建桥接"
        show_menu_option "3" "删除桥接"
        show_menu_option "4" "MAC 地址绑定管理（防网卡顺序变化）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_create_bridge ;;
            3) host_network_delete_bridge ;;
            4) host_network_mac_binding_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

host_network_mac_binding_menu() {
    while true; do
        clear
        show_menu_header "MAC 地址绑定管理"
        echo -e "${YELLOW}说明：通过 MAC 地址而不是接口名来固定网卡命名，避免重启或硬件变更后网卡顺序变化导致网络配置失效。${NC}"
        echo -e "${YELLOW}绑定后会在 /etc/systemd/network/ 中生成 .link 规则；若系统残留旧式 udev 规则，脚本会尝试同步清理。${NC}"
        echo "$UI_DIVIDER"
        host_network_show_mac_bindings
        echo "$UI_DIVIDER"
        show_menu_option "1" "创建 MAC 地址绑定"
        show_menu_option "2" "删除 MAC 地址绑定"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) host_network_create_mac_binding ;;
            2) host_network_delete_mac_binding ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

host_network_create_vlan() {
    local raw_dev vlan_id iface_name mtu ipv4_cfg ipv6_cfg tmp block
    raw_dev="$(host_network_select_interface_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$raw_dev" ]] || return 1

    host_network_iface_exists "$raw_dev" || {
        display_error "上联接口不存在: $raw_dev"
        return 1
    }

    read -p "请输入 VLAN ID: " vlan_id
    [[ "$vlan_id" =~ ^[0-9]+$ && "$vlan_id" -ge 1 && "$vlan_id" -le 4094 ]] || {
        display_error "VLAN ID 不合法: $vlan_id" "请输入 1-4094 之间的整数。"
        return 1
    }
    iface_name="${raw_dev}.${vlan_id}"
    read -p "请输入 VLAN 子接口名称 [$iface_name]: " iface_name
    iface_name="${iface_name:-${raw_dev}.${vlan_id}}"
    host_network_validate_iface_name "$iface_name" || {
        display_error "接口名称不合法: $iface_name" "接口名需为 1-15 位，且仅允许字母、数字、._:-。"
        return 1
    }
    if host_network_get_all_interface_names | grep -qx "$iface_name"; then
        display_error "接口已存在: $iface_name"
        return 1
    fi
    read -p "MTU（留空保持默认）: " mtu
    host_network_validate_mtu "$mtu" || return 1
    echo "$UI_DIVIDER"
    ipv4_cfg="$(host_network_collect_family_config inet create)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 create)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    block="$(host_network_build_vlan_block "$iface_name" "$raw_dev" "$mtu" "$ipv4_cfg" "$ipv6_cfg")"
    host_network_remove_iface_from_candidate "$tmp" "$iface_name"
    host_network_append_text_to_candidate "$tmp" "# PVE-TOOLS HOST IFACE BEGIN $iface_name
$block
# PVE-TOOLS HOST IFACE END $iface_name"
    host_network_commit_candidate "$tmp" "创建 VLAN 子接口 $iface_name" "VLAN 子接口会改写宿主机链路与上联 VLAN 规划。" "VLAN ID、上联接口或网关错误时，相关业务与管理流量会中断。" "请确认上联交换机配置、VLAN ID、地址规划和控制台回滚路径。"
    rm -f "$tmp"
}
host_network_delete_vlan() {
    local iface_name
    iface_name="$(host_network_select_vlan_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$iface_name" ]] || return 1

    if grep -Eq "(bridge-ports|bond-slaves|vlan-raw-device)[[:space:]].*\b${iface_name}\b" "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null; then
        display_error "检测到其他接口仍依赖 $iface_name" "请先删除依赖关系后再试。"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    host_network_remove_iface_from_candidate "$tmp" "$iface_name"
    host_network_commit_candidate "$tmp" "删除 VLAN 子接口 $iface_name" "删除 VLAN 子接口会中断承载在该 VLAN 上的宿主机和 VM 网络。" "业务中断、管理口断连和路由丢失都可能立即发生。" "请先确认该 VLAN 不再承担管理面或生产流量。"
    rm -f "$tmp"
}

host_network_vlan_menu() {
    while true; do
        clear
        show_menu_header "VLAN 子接口管理"
        host_network_show_risk_banner
        echo -e "${CYAN}当前 VLAN 子接口：${NC}"
        if host_network_get_configured_vlans | awk 'NF{print "  - "$0}'; then :; fi
        echo "$UI_DIVIDER"
        show_menu_option "1" "列出 VLAN 子接口"
        show_menu_option "2" "创建 VLAN 子接口"
        show_menu_option "3" "删除 VLAN 子接口"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_create_vlan ;;
            3) host_network_delete_vlan ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

host_network_create_bond() {
    local default_name bond_name slaves mode mtu ipv4_cfg ipv6_cfg tmp block
    default_name="$(host_network_guess_next_name bond)"
    read -p "请输入 Bond 名称 [$default_name]: " bond_name
    bond_name="${bond_name:-$default_name}"
    host_network_validate_iface_name "$bond_name" || {
        display_error "Bond 名称不合法: $bond_name" "接口名需为 1-15 位，且仅允许字母、数字、._:-。"
        return 1
    }
    if host_network_get_all_interface_names | grep -qx "$bond_name"; then
        display_error "接口已存在: $bond_name"
        return 1
    fi
    echo -e "${CYAN}可加入 Bond 的接口（输入多个，以空格分隔）：${NC}"
    host_network_get_all_interface_names | sed 's/^/  - /'
    read -p "bond-slaves: " slaves
    host_network_validate_member_list "$slaves" "$bond_name" "bond-slaves" || return 1

    echo "  [0] mode 0  = balance-rr"
    echo "  [1] mode 1  = active-backup"
    echo "  [4] mode 4  = 802.3ad"
    echo "  [6] mode 6  = balance-alb"
    read -p "请选择 Bond 模式 [0/1/4/6]: " mode
    [[ "$mode" =~ ^(0|1|4|6)$ ]] || {
        display_error "仅支持 Bond 模式 0/1/4/6"
        return 1
    }
    read -p "MTU（留空保持默认）: " mtu
    host_network_validate_mtu "$mtu" || return 1
    echo "$UI_DIVIDER"
    ipv4_cfg="$(host_network_collect_family_config inet create)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 create)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    block="$(host_network_build_bond_block "$bond_name" "$slaves" "$mode" "$mtu" "$ipv4_cfg" "$ipv6_cfg")"
    host_network_remove_iface_from_candidate "$tmp" "$bond_name"
    host_network_append_text_to_candidate "$tmp" "# PVE-TOOLS HOST IFACE BEGIN $bond_name
$block
# PVE-TOOLS HOST IFACE END $bond_name"
    host_network_commit_candidate "$tmp" "创建 Bond $bond_name" "Bond 会重组宿主机上联链路，错误的成员口或模式会导致管理面和业务流量异常。" "交换机 LACP/静态聚合不匹配时，链路可能抖动、黑洞或单向丢包。" "请确认交换机侧聚合模式、成员口、MTU 与回滚路径已经准备好。"
    rm -f "$tmp"
}
host_network_delete_bond() {
    local bond_name
    bond_name="$(host_network_select_bond_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bond_name" ]] || return 1

    if grep -Eq "(bridge-ports|bond-slaves|vlan-raw-device)[[:space:]].*\b${bond_name}\b" "$HOST_NETWORK_INTERFACES_FILE" 2>/dev/null; then
        display_error "检测到其他接口仍依赖 $bond_name" "请先解除 bridge、VLAN 或其他依赖后再删除。"
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    host_network_remove_iface_from_candidate "$tmp" "$bond_name"
    host_network_commit_candidate "$tmp" "删除 Bond $bond_name" "删除 Bond 会让其上的 bridge、VLAN、地址和上联聚合失效。" "生产网络、存储网络、集群心跳都可能立即受影响。" "请确认已迁移上层依赖，并通过控制台执行。"
    rm -f "$tmp"
}

host_network_bond_menu() {
    while true; do
        clear
        show_menu_header "Bond 管理"
        host_network_show_risk_banner
        echo -e "${CYAN}当前 Bond：${NC}"
        if host_network_get_configured_bonds | awk 'NF{print "  - "$0}'; then :; fi
        echo "$UI_DIVIDER"
        show_menu_option "1" "列出 Bond"
        show_menu_option "2" "创建 Bond"
        show_menu_option "3" "删除 Bond"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-3]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_create_bond ;;
            3) host_network_delete_bond ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

host_network_configure_interface_addressing() {
    local iface_name ipv4_cfg ipv6_cfg tmp preserved block method
    iface_name="$(host_network_select_interface_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$iface_name" ]] || return 1

    echo -e "${CYAN}为接口 $iface_name 更新地址模式：${NC}"
    ipv4_cfg="$(host_network_collect_family_config inet update)" || return 1
    ipv6_cfg="$(host_network_collect_family_config inet6 update)" || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"

    IFS='|' read -r method _ <<< "$ipv4_cfg"
    if [[ "$method" != "keep" ]]; then
        preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$iface_name" inet)"
        host_network_remove_iface_family_from_candidate "$tmp" "$iface_name" inet
        if [[ "$method" != "remove" ]]; then
            host_network_ensure_auto_line_in_candidate "$tmp" "$iface_name"
            block="$(host_network_build_family_stanza "$iface_name" inet "$ipv4_cfg" "$preserved")"
            host_network_append_text_to_candidate "$tmp" "$block"
        fi
    fi

    IFS='|' read -r method _ <<< "$ipv6_cfg"
    if [[ "$method" != "keep" ]]; then
        preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$iface_name" inet6)"
        host_network_remove_iface_family_from_candidate "$tmp" "$iface_name" inet6
        if [[ "$method" != "remove" ]]; then
            host_network_ensure_auto_line_in_candidate "$tmp" "$iface_name"
            block="$(host_network_build_family_stanza "$iface_name" inet6 "$ipv6_cfg" "$preserved")"
            host_network_append_text_to_candidate "$tmp" "$block"
        fi
    fi

    host_network_commit_candidate "$tmp" "更新接口 $iface_name 的 IPv4/IPv6 地址模式" "会直接改写宿主机接口地址、网关和 RA/DHCP 行为。" "管理面 IP、默认路由和业务地址可能立即切换。" "请确认新的地址、网关、前缀和维护窗口都已校对。"
    rm -f "$tmp"
}

host_firewall_get_node_names() {
    find /etc/pve/nodes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

host_firewall_select_node_name() {
    host_network_select_from_text "可用节点：" "$(host_firewall_get_node_names)"
}

host_firewall_select_guest() {
    local kind="$1"
    local list_text
    if [[ "$kind" == "vm" ]]; then
        list_text="$(qm list 2>/dev/null | awk 'NR>1 {print $1 "|" $2}')"
    else
        list_text="$(pct list 2>/dev/null | awk 'NR>1 {print $1 "|" $2}')"
    fi
    mapfile -t items < <(printf '%s\n' "$list_text" | awk 'NF')
    (( ${#items[@]} > 0 )) || return 1
    echo -e "${CYAN}请选择${kind^^}：${NC}" >&2
    local idx=1
    local item id name
    for item in "${items[@]}"; do
        id="${item%%|*}"
        name="${item#*|}"
        printf '  [%d] %s (%s)\n' "$idx" "$id" "$name" >&2
        idx=$((idx + 1))
    done
    echo "$UI_DIVIDER" >&2
    local pick
    read -p "请选择序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 2
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#items[@]} )); then
        return 1
    fi
    id="${items[$((pick - 1))]%%|*}"
    printf '%s\n' "$id"
}

host_firewall_validate_group_name() {
    local group_name="$1"
    [[ -n "$group_name" && "$group_name" =~ ^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$ ]]
}

host_firewall_validate_identifier() {
    local scope="$1"
    local identifier="$2"
    case "$scope" in
        datacenter)
            [[ "$identifier" == "cluster" ]]
            ;;
        node)
            [[ "$identifier" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]]
            ;;
        vm|ct)
            [[ "$identifier" =~ ^[0-9]+$ ]]
            ;;
        security-group)
            host_firewall_validate_group_name "$identifier"
            ;;
        *)
            return 1
            ;;
    esac
}

host_firewall_is_allowed_target_path() {
    local file_path="$1"
    case "$file_path" in
        /etc/pve/firewall/cluster.fw|/etc/pve/nodes/*/host.fw|/etc/pve/firewall/*.fw)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

host_firewall_target_path() {
    local scope="$1"
    local identifier="$2"
    local path=""

    host_firewall_validate_identifier "$scope" "$identifier" || return 1

    case "$scope" in
        datacenter) path="$PVE_CLUSTER_FIREWALL_FILE" ;;
        node) printf -v path '/etc/pve/nodes/%s/host.fw' "$identifier" ;;
        vm|ct) printf -v path '/etc/pve/firewall/%s.fw' "$identifier" ;;
        *) return 1 ;;
    esac

    host_firewall_is_allowed_target_path "$path" || return 1
    printf '%s\n' "$path"
}

host_firewall_validate_ruleset_content_for_target() {
    local kind="$1"
    local content="$2"
    if [[ "$kind" == "security-group" ]]; then
        printf '%s\n' "$content" | awk 'NF{exit !($0 ~ /^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/)} END{if(NR==0) exit 1}'
        return $?
    fi
    printf '%s\n' "$content" | grep -Eq '^\[[^]]+\]'
}

host_firewall_prepare_group_section() {
    local group_name="$1"
    local content="$2"
    awk -v target="[group ${group_name}]" '
        BEGIN { started=0 }
        {
            if (!started) {
                if ($0 ~ /^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/) {
                    print target
                    started=1
                }
                next
            }
            if ($0 ~ /^\[/) {
                exit
            }
            print
        }
        END { if (!started) exit 1 }
    ' <<< "$content"
}

host_firewall_ensure_target_file() {
    local file_path="$1"
    mkdir -p "$(dirname "$file_path")" >/dev/null 2>&1 || true
    if [[ ! -f "$file_path" ]]; then
        cat > "$file_path" <<'EOF_FW'
[OPTIONS]
enable: 0

[RULES]
EOF_FW
    fi
}

host_firewall_upsert_option() {
    local file_path="$1"
    local option_key="$2"
    local option_value="$3"
    local tmp
    tmp=$(mktemp)

    awk -v option_key="$option_key" -v option_value="$option_value" '
        BEGIN { in_options=0; found_options=0; replaced=0 }
        {
            if ($0 == "[OPTIONS]") {
                found_options=1
                in_options=1
                print
                next
            }
            if (in_options && $0 ~ /^\[/) {
                if (!replaced) {
                    printf "%s: %s\n", option_key, option_value
                    replaced=1
                }
                in_options=0
            }
            if (in_options && $0 ~ ("^" option_key ":[[:space:]]*")) {
                printf "%s: %s\n", option_key, option_value
                replaced=1
                next
            }
            print
        }
        END {
            if (!found_options) {
                print "[OPTIONS]"
                printf "%s: %s\n\n", option_key, option_value
                print "[RULES]"
            } else if (in_options && !replaced) {
                printf "%s: %s\n", option_key, option_value
            }
        }
    ' "$file_path" > "$tmp"
    mv "$tmp" "$file_path"
}

host_firewall_select_security_group() {
    local allow_new="${1:-}"
    mapfile -t groups < <(host_firewall_get_security_groups)
    echo -e "${CYAN}当前安全组：${NC}"
    local idx=1
    local group
    for group in "${groups[@]}"; do
        printf '  [%d] %s\n' "$idx" "$group"
        idx=$((idx + 1))
    done
    if [[ "$allow_new" == "allow_new" ]]; then
        echo "  [N] 新建安全组"
    fi
    echo "$UI_DIVIDER"
    local pick
    read -p "请选择安全组 (0 返回): " pick
    [[ "$pick" == "0" ]] && return 2
    if [[ "$allow_new" == "allow_new" && ( "$pick" == "N" || "$pick" == "n" ) ]]; then
        read -p "请输入新的安全组名称: " group
        host_firewall_validate_group_name "$group" || {
            display_error "安全组名称不合法: $group" "仅允许字母、数字、._:-，且长度不超过 64。"
            return 1
        }
        printf '%s\n' "$group"
        return 0
    fi
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#groups[@]} )); then
        return 1
    fi
    printf '%s\n' "${groups[$((pick - 1))]}"
}
host_firewall_get_security_groups() {
    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    awk '/^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/ {line=$0; sub(/^\[[Gg][Rr][Oo][Uu][Pp][[:space:]]+/, "", line); sub(/\]$/, "", line); print line}' "$PVE_CLUSTER_FIREWALL_FILE" 2>/dev/null | sort -u
}

host_firewall_get_group_section() {
    local group_name="$1"
    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    awk -v header="[group ${group_name}]" '
        BEGIN { capture=0 }
        {
            if (capture) {
                if ($0 ~ /^\[/ && $0 != header) {
                    exit
                }
                print
                next
            }
            if ($0 == header) {
                capture=1
                print
            }
        }
    ' "$PVE_CLUSTER_FIREWALL_FILE"
}

host_firewall_replace_group_section_in_file() {
    local group_name="$1"
    local new_content="$2"
    local tmp
    tmp=$(mktemp)
    awk -v header="[group ${group_name}]" -v new_content="$new_content" '
        BEGIN { skip=0; replaced=0; split(new_content, repl, "\n") }
        {
            if (skip) {
                if ($0 ~ /^\[/ && $0 != header) {
                    skip=0
                } else {
                    next
                }
            }
            if (!replaced && $0 == header) {
                for (i=1; i in repl; i++) print repl[i]
                replaced=1
                skip=1
                next
            }
            print
        }
        END {
            if (!replaced) {
                print ""
                for (i=1; i in repl; i++) print repl[i]
            }
        }
    ' "$PVE_CLUSTER_FIREWALL_FILE" > "$tmp"
    mv "$tmp" "$PVE_CLUSTER_FIREWALL_FILE"
}

host_firewall_select_ruleset_target() {
    echo "  [1] 数据中心 firewall"
    echo "  [2] 节点 firewall"
    echo "  [3] VM firewall"
    echo "  [4] CT firewall"
    echo "  [5] 安全组"
    read -p "请选择目标 [1-5]: " choice
    local node_name guest_id path group_name rc
    case "$choice" in
        1)
            printf 'datacenter|cluster|%s|数据中心 firewall\n' "$PVE_CLUSTER_FIREWALL_FILE"
            ;;
        2)
            node_name="$(host_firewall_select_node_name)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$node_name" ]] || return 1
            path="$(host_firewall_target_path node "$node_name")"
            printf 'node|%s|%s|节点 firewall (%s)\n' "$node_name" "$path" "$node_name"
            ;;
        3)
            guest_id="$(host_firewall_select_guest vm)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$guest_id" ]] || return 1
            path="$(host_firewall_target_path vm "$guest_id")"
            printf 'vm|%s|%s|VM firewall (%s)\n' "$guest_id" "$path" "$guest_id"
            ;;
        4)
            guest_id="$(host_firewall_select_guest ct)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$guest_id" ]] || return 1
            path="$(host_firewall_target_path ct "$guest_id")"
            printf 'ct|%s|%s|CT firewall (%s)\n' "$guest_id" "$path" "$guest_id"
            ;;
        5)
            group_name="$(host_firewall_select_security_group allow_new)"
            rc=$?
            [[ "$rc" -eq 2 ]] && return 2
            [[ -n "$group_name" ]] || return 1
            printf 'security-group|%s|%s|安全组 (%s)\n' "$group_name" "$PVE_CLUSTER_FIREWALL_FILE" "$group_name"
            ;;
        *)
            return 1
            ;;
    esac
}

host_firewall_toggle_enable() {
    local scope="$1"
    local identifier="$2"
    local label="$3"
    local state file_path
    file_path="$(host_firewall_target_path "$scope" "$identifier")" || return 1
    host_firewall_ensure_target_file "$file_path"
    read -p "是否启用 $label 防火墙？(yes/no) [yes]: " state
    state="${state:-yes}"
    if ! confirm_high_risk_action "切换 $label 防火墙状态" "错误的防火墙开关或默认策略可能导致管理口、集群通信或业务端口不可达。" "如果规则集本身有误，启用后可能立即造成 SSH/WebUI/业务中断。" "请确认已有控制台或带外管理手段，并已审查当前 firewall 规则。" "FIREWALL"; then
        return 0
    fi
    backup_file "$file_path" >/dev/null 2>&1 || true
    if [[ "$state" == "yes" || "$state" == "YES" ]]; then
        host_firewall_upsert_option "$file_path" enable 1
    else
        host_firewall_upsert_option "$file_path" enable 0
    fi
    display_success "$label 防火墙状态已更新" "$file_path"
    if [[ "$scope" == "vm" || "$scope" == "ct" ]]; then
        log_warn "PVE 客体防火墙还依赖对应网卡开启 firewall=1；如未开启，请同步检查网卡配置。"
    fi
}

host_firewall_toggle_menu() {
    while true; do
        clear
        show_menu_header "PVE 防火墙开关"
        host_network_show_risk_banner
        show_menu_option "1" "数据中心级别开关"
        show_menu_option "2" "节点级别开关"
        show_menu_option "3" "VM 级别开关"
        show_menu_option "4" "CT 级别开关"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) host_firewall_toggle_enable datacenter cluster "数据中心" ;;
            2)
                local node_name rc
                node_name="$(host_firewall_select_node_name)"
                rc=$?
                [[ "$rc" -eq 2 ]] && continue
                [[ -n "$node_name" ]] && host_firewall_toggle_enable node "$node_name" "节点 $node_name"
                ;;
            3)
                local vmid rc
                vmid="$(host_firewall_select_guest vm)"
                rc=$?
                [[ "$rc" -eq 2 ]] && continue
                [[ -n "$vmid" ]] && host_firewall_toggle_enable vm "$vmid" "VM $vmid"
                ;;
            4)
                local ctid rc
                ctid="$(host_firewall_select_guest ct)"
                rc=$?
                [[ "$rc" -eq 2 ]] && continue
                [[ -n "$ctid" ]] && host_firewall_toggle_enable ct "$ctid" "CT $ctid"
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

host_firewall_list_security_groups() {
    clear
    show_menu_header "安全组规则"
    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    local groups_text group
    groups_text="$(host_firewall_get_security_groups)"
    if [[ -z "$groups_text" ]]; then
        echo "  当前没有安全组。"
        return 0
    fi
    while IFS= read -r group; do
        [[ -z "$group" ]] && continue
        echo -e "${CYAN}[group ${group}]${NC}"
        host_firewall_get_group_section "$group" | awk 'NR>1 && NF {print "  "$0}'
        echo "$UI_DIVIDER"
    done <<< "$groups_text"
}

host_firewall_add_security_group_rule() {
    local group_name direction action rule_body existing new_section
    group_name="$(host_firewall_select_security_group allow_new)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$group_name" ]] || return 1

    echo "  [1] IN"
    echo "  [2] OUT"
    read -p "请选择方向 [1-2]: " direction
    case "$direction" in
        1) direction="IN" ;;
        2) direction="OUT" ;;
        *) return 1 ;;
    esac
    echo "  [1] ACCEPT"
    echo "  [2] DROP"
    echo "  [3] REJECT"
    read -p "请选择动作 [1-3]: " action
    case "$action" in
        1) action="ACCEPT" ;;
        2) action="DROP" ;;
        3) action="REJECT" ;;
        *) return 1 ;;
    esac
    read -p "请输入规则主体（示例 -p tcp --dport 22 -source +management，留空则仅写方向/动作）: " rule_body

    host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
    backup_file "$PVE_CLUSTER_FIREWALL_FILE" >/dev/null 2>&1 || true
    existing="$(host_firewall_get_group_section "$group_name")"
    if [[ -z "$existing" ]]; then
        new_section="[group ${group_name}]"
    else
        new_section="$existing"
    fi
    new_section+=$'\n'
    new_section+="${direction} ${action}"
    [[ -n "$rule_body" ]] && new_section+=" ${rule_body}"
    host_firewall_replace_group_section_in_file "$group_name" "$new_section"
    display_success "安全组规则已写入" "group ${group_name}"
}

host_firewall_delete_security_group_rule() {
    local group_name section idx pick new_section
    group_name="$(host_firewall_select_security_group)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$group_name" ]] || return 1

    section="$(host_firewall_get_group_section "$group_name")"
    [[ -n "$section" ]] || {
        display_error "安全组不存在或无规则: $group_name"
        return 1
    }

    mapfile -t rules < <(printf '%s\n' "$section" | awk 'NR>1 && NF && $0 !~ /^#/ {print}')
    (( ${#rules[@]} > 0 )) || {
        display_error "安全组没有可删除的规则: $group_name"
        return 1
    }

    echo -e "${CYAN}[group ${group_name}]${NC}"
    idx=1
    local rule
    for rule in "${rules[@]}"; do
        printf '  [%d] %s\n' "$idx" "$rule"
        idx=$((idx + 1))
    done
    echo "$UI_DIVIDER"
    read -p "请选择要删除的规则序号 (0 返回): " pick
    pick="${pick:-0}"
    [[ "$pick" == "0" ]] && return 0
    [[ "$pick" =~ ^[0-9]+$ ]] || return 1
    if (( pick < 1 || pick > ${#rules[@]} )); then
        return 1
    fi

    new_section="[group ${group_name}]"
    idx=1
    for rule in "${rules[@]}"; do
        if (( idx != pick )); then
            new_section+=$'\n'
            new_section+="$rule"
        fi
        idx=$((idx + 1))
    done
    backup_file "$PVE_CLUSTER_FIREWALL_FILE" >/dev/null 2>&1 || true
    host_firewall_replace_group_section_in_file "$group_name" "$new_section"
    display_success "安全组规则已删除" "group ${group_name}"
}

host_firewall_show_target_rules() {
    local target_data kind identifier path label content
    target_data="$(host_firewall_select_ruleset_target)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_data" ]] || return 1
    IFS='|' read -r kind identifier path label <<< "$target_data"
    clear
    show_menu_header "$label"
    if [[ "$kind" == "security-group" ]]; then
        content="$(host_firewall_get_group_section "$identifier")"
        [[ -n "$content" ]] && printf '%s\n' "$content" | sed 's/^/  /' || echo '  当前安全组为空。'
    else
        host_firewall_ensure_target_file "$path"
        sed 's/^/  /' "$path"
    fi
    echo "$UI_DIVIDER"
}

host_firewall_export_ruleset() {
    local target_data kind identifier path label format export_file content b64 safe_name
    target_data="$(host_firewall_select_ruleset_target)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_data" ]] || return 1
    IFS='|' read -r kind identifier path label <<< "$target_data"

    if [[ "$kind" == "security-group" ]]; then
        content="$(host_firewall_get_group_section "$identifier")"
    else
        host_firewall_ensure_target_file "$path"
        content="$(cat "$path")"
    fi

    mkdir -p "$HOST_NETWORK_EXPORT_DIR"
    safe_name="$(echo "$identifier" | tr '/: ' '___')"
    echo "  [1] JSON"
    echo "  [2] CLI / raw"
    read -p "请选择导出格式 [1-2]: " format
    case "$format" in
        1)
            export_file="$HOST_NETWORK_EXPORT_DIR/${kind}-${safe_name}-$(date +%Y%m%d_%H%M%S).json"
            b64="$(printf '%s' "$content" | base64 | tr -d '\n')"
            cat > "$export_file" <<EOF_JSON
{
  "format": "pve-tools-firewall-json",
  "target_kind": "${kind}",
  "identifier": "${identifier}",
  "exported_at": "$(date +%F' '%T)",
  "content_base64": "${b64}"
}
EOF_JSON
            ;;
        2)
            export_file="$HOST_NETWORK_EXPORT_DIR/${kind}-${safe_name}-$(date +%Y%m%d_%H%M%S).fw"
            printf '%s\n' "$content" > "$export_file"
            ;;
        *)
            return 1
            ;;
    esac
    display_success "规则集已导出" "$export_file"
}

host_firewall_import_ruleset() {
    local import_path source_kind source_identifier content b64 target_data kind identifier path label prepared_content rc
    read -p "请输入要导入的规则集文件路径: " import_path
    [[ -f "$import_path" ]] || {
        display_error "文件不存在: $import_path"
        return 1
    }

    if grep -q '"format": "pve-tools-firewall-json"' "$import_path" 2>/dev/null; then
        source_kind="$(sed -n 's/.*"target_kind": "\([^"]*\)".*/\1/p' "$import_path" | head -n 1)"
        source_identifier="$(sed -n 's/.*"identifier": "\([^"]*\)".*/\1/p' "$import_path" | head -n 1)"
        b64="$(sed -n 's/.*"content_base64": "\([^"]*\)".*/\1/p' "$import_path" | head -n 1)"
        content="$(printf '%s' "$b64" | base64 -d 2>/dev/null)"
    else
        content="$(cat "$import_path")"
    fi

    [[ -n "$content" ]] || {
        display_error "导入内容为空或解析失败"
        return 1
    }

    if [[ -n "$source_kind" || -n "$source_identifier" ]]; then
        log_warn "导入文件携带的原始目标为 ${source_kind:-unknown}:${source_identifier:-unknown}，实际写入目标仍需重新选择。"
    fi

    target_data="$(host_firewall_select_ruleset_target)"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$target_data" ]] || return 1
    IFS='|' read -r kind identifier path label <<< "$target_data"

    host_firewall_validate_identifier "$kind" "$identifier" || {
        display_error "导入目标不合法: ${kind}:${identifier}"
        return 1
    }
    if [[ "$kind" != "security-group" ]]; then
        path="$(host_firewall_target_path "$kind" "$identifier")" || {
            display_error "导入目标路径非法或超出允许范围"
            return 1
        }
    fi
    host_firewall_validate_ruleset_content_for_target "$kind" "$content" || {
        display_error "规则集内容与目标类型不匹配" "请避免把整份 firewall 文件导入到安全组，或把安全组片段导入到数据中心/节点/客体 firewall。"
        return 1
    }

    if ! confirm_high_risk_action "导入规则集到 $label" "导入会覆盖当前目标的规则或安全组内容。" "错误的规则集可能立即封死管理口、业务端口或集群通信。" "请确认已导出当前规则备份，并通过控制台进行高风险导入。" "IMPORT-FW"; then
        return 0
    fi

    if [[ "$kind" == "security-group" ]]; then
        prepared_content="$(host_firewall_prepare_group_section "$identifier" "$content")" || {
            display_error "无法从导入文件中提取有效安全组段落"
            return 1
        }
        host_firewall_ensure_target_file "$PVE_CLUSTER_FIREWALL_FILE"
        backup_file "$PVE_CLUSTER_FIREWALL_FILE" >/dev/null 2>&1 || true
        host_firewall_replace_group_section_in_file "$identifier" "$prepared_content"
        display_success "安全组规则已导入" "group ${identifier}"
        return 0
    fi

    host_firewall_ensure_target_file "$path"
    backup_file "$path" >/dev/null 2>&1 || true
    printf '%s\n' "$content" > "$path"
    display_success "规则集已导入" "$path"
}
host_firewall_menu() {
    while true; do
        clear
        show_menu_header "PVE 防火墙管理"
        host_network_show_risk_banner
        show_menu_option "1" "数据中心 / 节点 / VM / CT 防火墙开关"
        show_menu_option "2" "查看目标规则集"
        show_menu_option "3" "列出安全组规则"
        show_menu_option "4" "新增安全组规则"
        show_menu_option "5" "删除安全组规则"
        show_menu_option "6" "导出规则集（JSON / CLI）"
        show_menu_option "7" "导入规则集（JSON / CLI）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-7]: " choice
        case "$choice" in
            1) host_firewall_toggle_menu ;;
            2) host_firewall_show_target_rules ;;
            3) host_firewall_list_security_groups ;;
            4) host_firewall_add_security_group_rule ;;
            5) host_firewall_delete_security_group_rule ;;
            6) host_firewall_export_ruleset ;;
            7) host_firewall_import_ruleset ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

ipv6_helper_detect_host_readiness() {
    clear
    show_menu_header "IPv6 宿主机就绪度"
    echo -e "${CYAN}全局 IPv6 地址：${NC}"
    ip -6 -o addr show scope global 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}IPv6 默认路由：${NC}"
    ip -6 route show default 2>/dev/null | sed 's/^/  /' || true
    echo -e "${CYAN}IPv6 连通性测试：${NC}"
    if ping -6 -c 2 -W 2 2606:4700:4700::1111 >/dev/null 2>&1; then
        echo "  Cloudflare DNS IPv6 连通正常"
    else
        echo "  Cloudflare DNS IPv6 连通失败"
    fi
    echo "$UI_DIVIDER"
}

ipv6_helper_detect_vm_readiness() {
    clear
    show_menu_header "VM IPv6 就绪度（Guest Agent 最佳）"
    local vmid name ips
    while read -r vmid name _; do
        [[ -n "$vmid" && "$vmid" != "VMID" ]] || continue
        ips="$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | grep -oE '([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F]{0,4}(/[0-9]+)?' | grep -v '^fe80' | sort -u | tr '\n' ' ')"
        if [[ -n "$ips" ]]; then
            printf '  VM %s (%s): %s\n' "$vmid" "$name" "$ips"
        else
            printf '  VM %s (%s): 无法通过 Guest Agent 获取 IPv6（可能未安装 agent 或未启动）\n' "$vmid" "$name"
        fi
    done < <(qm list 2>/dev/null)
    echo "$UI_DIVIDER"
}

ipv6_helper_configure_passthrough() {
    local bridge_name preserved tmp block
    bridge_name="$(host_network_select_bridge_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bridge_name" ]] || return 1

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$bridge_name" inet6)"
    host_network_remove_iface_family_from_candidate "$tmp" "$bridge_name" inet6
    host_network_ensure_auto_line_in_candidate "$tmp" "$bridge_name"
    block="$(host_network_build_family_stanza "$bridge_name" inet6 'auto|||accept-ra 2' "$preserved")"
    host_network_append_text_to_candidate "$tmp" "$block"
    host_network_commit_candidate "$tmp" "为桥接 $bridge_name 启用 IPv6 透传 / SLAAC" "会调整桥接的 IPv6 获取方式和 RA 行为。" "若上游 IPv6/RA 不可用或桥接承载管理口，可能导致地址和默认路由改变。" "请确认上游已提供 IPv6 RA，并通过控制台执行。"
    rm -f "$tmp"
}

ipv6_helper_configure_nat6() {
    local bridge_name uplink prefix bridge_addr preserved tmp block
    bridge_name="$(host_network_select_bridge_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$bridge_name" ]] || return 1
    uplink="$(host_network_select_interface_name)"
    rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$uplink" ]] || return 1
    [[ "$uplink" != "$bridge_name" ]] || {
        display_error "NAT6 上联接口不能与桥接接口相同"
        return 1
    }
    command -v ip6tables >/dev/null 2>&1 || {
        display_error "未检测到 ip6tables" "请先确认系统已安装并启用 IPv6 NAT 所需工具。"
        return 1
    }
    host_network_iface_exists "$uplink" || {
        display_error "上联接口不存在: $uplink"
        return 1
    }

    read -p "请输入 NAT6 内网前缀（示例 fd10:10:10::/64）: " prefix
    host_network_validate_static_address inet6 "$prefix" || {
        display_error "前缀格式无效: $prefix" "请使用类似 fd10:10:10::/64 的 IPv6 前缀。"
        return 1
    }
    read -p "请输入桥接 IPv6 地址（示例 fd10:10:10::1/64）: " bridge_addr
    host_network_validate_static_address inet6 "$bridge_addr" || {
        display_error "桥接 IPv6 地址格式无效: $bridge_addr"
        return 1
    }

    tmp=$(mktemp)
    cp "$HOST_NETWORK_INTERFACES_FILE" "$tmp"
    preserved="$(host_network_collect_preserved_family_options "$HOST_NETWORK_INTERFACES_FILE" "$bridge_name" inet6)"
    host_network_remove_iface_family_from_candidate "$tmp" "$bridge_name" inet6
    host_network_ensure_auto_line_in_candidate "$tmp" "$bridge_name"
    block=$(cat <<EOF_NAT6
iface $bridge_name inet6 static
$(while IFS= read -r line; do [[ -n "$line" ]] && printf '    %s\n' "$line"; done <<< "$preserved")    address $bridge_addr
    post-up sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
    post-up ip6tables -t nat -C POSTROUTING -s $prefix -o $uplink -j MASQUERADE || ip6tables -t nat -A POSTROUTING -s $prefix -o $uplink -j MASQUERADE
    post-down ip6tables -t nat -D POSTROUTING -s $prefix -o $uplink -j MASQUERADE || true
EOF_NAT6
)
    host_network_append_text_to_candidate "$tmp" "$block"
    host_network_commit_candidate "$tmp" "为桥接 $bridge_name 配置 NAT6" "会开启 IPv6 转发并对 $prefix 执行 NAT6 出口伪装。" "错误的 uplink、前缀或防火墙策略会导致 IPv6 业务不可达。" "请确认上游具备 IPv6 出口、ip6tables 可用，并已在控制台中准备回滚。"
    rm -f "$tmp"
}
ipv6_helper_test_connectivity() {
    local target
    read -p "请输入要测试的 IPv6 目标 [2606:4700:4700::1111]: " target
    target="${target:-2606:4700:4700::1111}"
    clear
    show_menu_header "IPv6 连通性测试"
    echo -e "${CYAN}ping -6 ${target}${NC}"
    ping -6 -c 4 -W 2 "$target" 2>&1 | sed 's/^/  /'
    echo "$UI_DIVIDER"
}

ipv6_helper_menu() {
    while true; do
        clear
        show_menu_header "IPv6 助手"
        host_network_show_risk_banner
        show_menu_option "1" "检测宿主机 IPv6 就绪度"
        show_menu_option "2" "检测 VM IPv6 就绪度（Guest Agent）"
        show_menu_option "3" "一键配置桥接 IPv6 透传 / SLAAC"
        show_menu_option "4" "一键配置桥接 NAT6"
        show_menu_option "5" "测试 IPv6 连通性"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-5]: " choice
        case "$choice" in
            1) ipv6_helper_detect_host_readiness ;;
            2) ipv6_helper_detect_vm_readiness ;;
            3) ipv6_helper_configure_passthrough ;;
            4) ipv6_helper_configure_nat6 ;;
            5) ipv6_helper_test_connectivity ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

netdiag_require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        display_error "缺少命令: $cmd" "请先安装对应工具后再试。"
        return 1
    fi
}

netdiag_run_traceroute() {
    netdiag_require_cmd traceroute || return 1
    local target
    read -p "请输入 traceroute 目标 [1.1.1.1]: " target
    target="${target:-1.1.1.1}"
    traceroute "$target"
}

netdiag_run_mtr() {
    netdiag_require_cmd mtr || return 1
    local target
    read -p "请输入 mtr 目标 [1.1.1.1]: " target
    target="${target:-1.1.1.1}"
    mtr -rwzc 10 "$target"
}

netdiag_run_nmap() {
    netdiag_require_cmd nmap || return 1
    local target
    read -p "请输入 nmap 扫描目标: " target
    [[ -n "$target" ]] || return 1
    nmap -Pn -T4 "$target"
}

netdiag_run_tcpdump() {
    netdiag_require_cmd tcpdump || return 1
    local iface_name filter_expr seconds
    iface_name="$(host_network_select_interface_name)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 0
    [[ -n "$iface_name" ]] || return 1
    read -p "请输入抓包过滤表达式（留空抓全部）: " filter_expr
    read -p "抓包秒数 [15]: " seconds
    seconds="${seconds:-15}"
    [[ "$seconds" =~ ^[0-9]+$ ]] || return 1
    timeout "$seconds" tcpdump -ni "$iface_name" ${filter_expr:+$filter_expr}
}

netdiag_pick_vm_ip() {
    local vmid ips vm_ip
    vmid="$(host_firewall_select_guest vm)"
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 2
    [[ -n "$vmid" ]] || return 1
    ips="$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F]{0,4}' | grep -v '^fe80' | sort -u)"
    if [[ -z "$ips" ]]; then
        read -p "Guest Agent 未返回 IP，请手工输入 VM IP: " vm_ip
        [[ -n "$vm_ip" ]] && printf '%s\n' "$vm_ip"
        return 0
    fi
    host_network_select_from_text "VM $vmid 的可用 IP：" "$ips"
}

netdiag_check_port_connectivity() {
    local target_mode target port
    echo "  [1] 检查宿主机管理口"
    echo "  [2] 检查 VM 端口"
    echo "  [3] 自定义目标"
    read -p "请选择目标类型 [1-3]: " target_mode
    case "$target_mode" in
        1)
            target="$(ip -4 -o addr show scope global 2>/dev/null | awk 'NR==1 {print $4}' | cut -d'/' -f1)"
            [[ -n "$target" ]] || target="127.0.0.1"
            ;;
        2)
            target="$(netdiag_pick_vm_ip)"
            local rc=$?
            [[ "$rc" -eq 2 ]] && return 0
            [[ -n "$target" ]] || return 1
            ;;
        3)
            read -p "请输入目标 IP / 主机名: " target
            [[ -n "$target" ]] || return 1
            ;;
        *) return 1 ;;
    esac
    read -p "请输入端口号: " port
    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    clear
    show_menu_header "端口连通性测试"
    echo -e "${CYAN}目标: ${target}:${port}${NC}"
    if command -v nc >/dev/null 2>&1; then
        nc -zvw 3 "$target" "$port"
    else
        timeout 3 bash -c "</dev/tcp/${target}/${port}" >/dev/null 2>&1 && echo "端口可达" || echo "端口不可达"
    fi
    echo "$UI_DIVIDER"
}

netdiag_quick_stack_check() {
    clear
    show_menu_header "网络诊断摘要"
    network_show_diagnostics
    echo -e "${CYAN}IPv6 地址：${NC}"
    ip -6 -o addr show scope global 2>/dev/null | awk '{print "  "$2": "$4}' || true
    echo -e "${CYAN}监听端口（前 20 条）：${NC}"
    ss -lntup 2>/dev/null | sed -n '1,20p' | sed 's/^/  /' || true
    echo "$UI_DIVIDER"
}

netdiag_toolbox_menu() {
    while true; do
        clear
        show_menu_header "网络诊断工具箱"
        show_menu_option "1" "网络摘要与监听端口"
        show_menu_option "2" "traceroute"
        show_menu_option "3" "mtr"
        show_menu_option "4" "nmap"
        show_menu_option "5" "tcpdump"
        show_menu_option "6" "端口连通性检查（宿主机 / VM / 自定义）"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-6]: " choice
        case "$choice" in
            1) netdiag_quick_stack_check ;;
            2) netdiag_run_traceroute ;;
            3) netdiag_run_mtr ;;
            4) netdiag_run_nmap ;;
            5) netdiag_run_tcpdump ;;
            6) netdiag_check_port_connectivity ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

menu_host_networking() {
    while true; do
        clear
        show_menu_header "宿主机网络配置向导"
        host_network_show_risk_banner
        show_menu_option "1" "列出当前网卡与桥接（vmbr0~N）"
        show_menu_option "2" "桥接管理（创建 / 删除）"
        show_menu_option "3" "配置接口静态 IPv4 / IPv6 / SLAAC / DHCP"
        show_menu_option "4" "VLAN 子接口管理"
        show_menu_option "5" "Bond 管理（模式 0 / 1 / 4 / 6）"
        show_menu_option "6" "PVE 防火墙管理"
        show_menu_option "7" "IPv6 助手"
        show_menu_option "8" "网络诊断工具箱"
        echo -e "${RED}警告：应用宿主机网络修改时，建议在控制台或带外管理环境中执行，避免误断 SSH / WebUI。${NC}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-8]: " choice
        case "$choice" in
            1) host_network_show_current_overview ;;
            2) host_network_bridge_menu ;;
            3) host_network_configure_interface_addressing ;;
            4) host_network_vlan_menu ;;
            5) host_network_bond_menu ;;
            6) host_firewall_menu ;;
            7) ipv6_helper_menu ;;
            8) netdiag_toolbox_menu ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：存储与硬盘
menu_storage_disk() {
    while true; do
        clear
        show_menu_header "存储与硬盘"
        show_menu_option "1" "存储位置查询面板 ${CYAN}(ISO/备份/SCP路径)${NC}"
        show_menu_option "2" "磁盘挂载向导 ${CYAN}(复用已有 ext4/xfs 分区)${NC}"
        show_menu_option "3" "合并 ${CYAN}local${NC} 与 ${CYAN}local-lvm${NC}"
        show_menu_option "4" "${CYAN}Ceph${NC} 管理 (安装/卸载/换源)"
        show_menu_option "5" "硬盘休眠配置 ${CYAN}(hdparm)${NC}"
        show_menu_option "6" "垃圾清理 ${CYAN}(缓存/备份/快照扫描)${NC}"
        show_menu_option "7" "${RED}删除 Swap 分区${NC}"
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-7]: " choice
        case $choice in
            1) pve_storage_location_panel ;;
            2) pve_storage_mount_wizard ;;
            3) merge_local_storage ;;
            4) ceph_management_menu ;;
            5) 
                lsblk -o NAME,MODEL,TYPE,SIZE,MOUNTPOINT | grep disk
                read -p "请输入要配置休眠的硬盘盘符 (如 sdb, 不含/dev/): " disk_name
                if [ -b "/dev/$disk_name" ]; then
                    read -p "请输入休眠时间 (1-255, 120=10分钟, 240=20分钟, 0=禁用): " sleep_val
                    if [[ "$sleep_val" =~ ^[0-9]+$ ]]; then
                        hdparm -S "$sleep_val" "/dev/$disk_name"
                        log_success "配置已应用到 /dev/$disk_name"
                    else
                        log_error "无效的时间值"
                    fi
                else
                    log_error "未找到磁盘 /dev/$disk_name"
                fi
                ;;
            6) garbage_cleanup_menu ;;
            7) remove_swap ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 二级菜单：工具与关于
menu_tools_about() {
    while true; do
        clear
        show_menu_header "工具与关于"
        show_menu_option "1" "系统信息概览"
        show_menu_option "2" "应急救砖工具箱"
        show_menu_option "3" "本地脚本快捷更新"
        show_menu_option "4" "${RED}本地脚本快捷卸载${NC}"
        show_menu_option "5" "给作者点个 Star 吧"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        read -p "请选择操作 [0-5]: " choice
        case $choice in
            1) show_system_info ;;
            2) show_menu_rescue ;;
            3) pve_tools_local_update ;;
            4) pve_tools_local_uninstall ;;
            5) 
                echo -e "${YELLOW}项目地址：https://github.com/PVE-Tools/PVE-Tools-9${NC}"
                echo -e "${GREEN}您的支持是我更新的最大动力，谢谢喵~${NC}"
                ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 一键配置
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
show_menu_header() {
    local title="$1"
    echo -e "${UI_BORDER}"
    echo -e "  ${H2}${title}${NC}"
    echo -e "${UI_DIVIDER}"
}

show_menu_footer() {
    echo -e "${UI_FOOTER}"
}

show_menu_option() {
    local num="$1"
    local desc="$2"
    if [[ -z "$desc" ]]; then
        # 仅作为消息或标题显示
        echo -e "  ${H2}$num${NC}"
    else
        printf "  ${PRIMARY}%-3s${NC}. %s\\n" "$num" "$desc"
    fi
}

# 镜像源选择函数
mirror_uri_by_type() {
    local source_type="$1"
    local idx="$2"

    case "$source_type" in
        debian) echo "${MIRROR_DEBIAN_URIS[$idx]}" ;;
        security) echo "${MIRROR_SECURITY_URIS[$idx]}" ;;
        pve) echo "${MIRROR_PVE_URIS[$idx]}" ;;
        ceph) echo "${MIRROR_CEPH_URIS[$idx]}" ;;
        ct) echo "${MIRROR_CT_URIS[$idx]}" ;;
        *) echo "" ;;
    esac
}

mirror_set_selected() {
    local source_type="$1"
    local idx="$2"

    case "$source_type" in
        debian) MIRROR_SELECTED_DEBIAN="$idx" ;;
        security) MIRROR_SELECTED_SECURITY="$idx" ;;
        pve) MIRROR_SELECTED_PVE="$idx" ;;
        ceph) MIRROR_SELECTED_CEPH="$idx" ;;
        ct) MIRROR_SELECTED_CT="$idx" ;;
        *) return 1 ;;
    esac
}

mirror_reset_selection() {
    MIRROR_SELECTED_DEBIAN=-1
    MIRROR_SELECTED_SECURITY=-1
    MIRROR_SELECTED_PVE=-1
    MIRROR_SELECTED_CEPH=-1
    MIRROR_SELECTED_CT=-1
}

mirror_selection_complete() {
    [[ "$MIRROR_SELECTED_DEBIAN" =~ ^[0-9]+$ && "$MIRROR_SELECTED_DEBIAN" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_SECURITY" =~ ^[0-9]+$ && "$MIRROR_SELECTED_SECURITY" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_PVE" =~ ^[0-9]+$ && "$MIRROR_SELECTED_PVE" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_CEPH" =~ ^[0-9]+$ && "$MIRROR_SELECTED_CEPH" -ge 0 ]] || return 1
    [[ "$MIRROR_SELECTED_CT" =~ ^[0-9]+$ && "$MIRROR_SELECTED_CT" -ge 0 ]] || return 1
}

mirror_selected_index_by_type() {
    local source_type="$1"

    case "$source_type" in
        debian) echo "$MIRROR_SELECTED_DEBIAN" ;;
        security) echo "$MIRROR_SELECTED_SECURITY" ;;
        pve) echo "$MIRROR_SELECTED_PVE" ;;
        ceph) echo "$MIRROR_SELECTED_CEPH" ;;
        ct) echo "$MIRROR_SELECTED_CT" ;;
        *) echo "-1" ;;
    esac
}

mirror_source_label() {
    local source_type="$1"

    case "$source_type" in
        debian) echo "Debian 软件源" ;;
        security) echo "Debian Security 安全源" ;;
        pve) echo "Proxmox VE no-subscription 源" ;;
        ceph) echo "Ceph Squid 源" ;;
        ct) echo "CT 模板源" ;;
        *) echo "$source_type" ;;
    esac
}

mirror_print_selection_summary() {
    echo "$UI_DIVIDER"
    echo -e "${CYAN}当前镜像源配置:${NC}"
    local source_type idx uri
    for source_type in debian security pve ceph ct; do
        idx="$(mirror_selected_index_by_type "$source_type")"
        if [[ "$idx" =~ ^[0-9]+$ && "$idx" -ge 0 ]]; then
            uri="$(mirror_uri_by_type "$source_type" "$idx")"
            [[ -n "$uri" ]] || uri="官方源兜底"
            printf "  %-12s %-24s %s\n" "$(mirror_source_label "$source_type"):" "${MIRROR_NAMES[$idx]}" "$uri"
        else
            printf "  %-12s %s\n" "$(mirror_source_label "$source_type"):" "未选择"
        fi
    done
    echo "$UI_DIVIDER"
}

mirror_print_recommendation_notice() {
    echo -e "  ${YELLOW}推荐优先选择靠前的镜像源。地区性高校源可能会起到反向作用，例如：同步慢、高峰期丢包、随时不可用等。${NC}"
    echo -e "  ${YELLOW}如使用生产环境，请优先使用官方源或商业源（阿里云/腾讯云）。${NC}"
    echo "$UI_DIVIDER"
}

select_mirror_for_source() {
    local source_type="$1"
    local label="$2"
    local selected_var="$3"
    local candidates=()
    local idx uri pick selected_idx

    while true; do
        clear
        show_menu_header "$label"
        mirror_print_recommendation_notice
        candidates=()
        for idx in "${!MIRROR_NAMES[@]}"; do
            uri="$(mirror_uri_by_type "$source_type" "$idx")"
            [[ -n "$uri" ]] || continue
            candidates+=("$idx")
            printf "  ${PRIMARY}%-3s${NC}. %-28s %s\n" "${#candidates[@]}" "${MIRROR_NAMES[$idx]}" "$uri"
        done
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回"
        show_menu_footer

        read -p "请选择 $label [0-${#candidates[@]}]: " pick
        pick="${pick:-0}"
        [[ "$pick" == "0" ]] && return 1
        if [[ ! "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#candidates[@]} )); then
            log_error "无效选择，请重新输入"
            pause_function
            continue
        fi

        selected_idx="${candidates[$((pick - 1))]}"
        mirror_set_selected "$source_type" "$selected_idx" || return 1
        [[ -n "$selected_var" ]] && printf -v "$selected_var" '%s' "$selected_idx"
        log_success "$label 已选择: ${MIRROR_NAMES[$selected_idx]}"
        return 0
    done
}

select_mirror_unified() {
    local candidates=()
    local idx pick selected_idx

    while true; do
        clear
        show_menu_header "全部使用同一镜像"
        mirror_print_recommendation_notice
        echo "  仅展示同时支持 Debian / Security / PVE / Ceph / CT 的镜像。"
        echo "$UI_DIVIDER"
        candidates=()
        for idx in "${!MIRROR_NAMES[@]}"; do
            [[ -n "${MIRROR_DEBIAN_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_SECURITY_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_PVE_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_CEPH_URIS[$idx]}" ]] || continue
            [[ -n "${MIRROR_CT_URIS[$idx]}" ]] || continue
            candidates+=("$idx")
            printf "  ${PRIMARY}%-3s${NC}. %s\n" "${#candidates[@]}" "${MIRROR_NAMES[$idx]}"
        done
        echo "$UI_DIVIDER"
        show_menu_option "0" "返回"
        show_menu_footer

        read -p "请选择统一镜像 [0-${#candidates[@]}]: " pick
        pick="${pick:-0}"
        [[ "$pick" == "0" ]] && return 1
        if [[ ! "$pick" =~ ^[0-9]+$ ]] || (( pick < 1 || pick > ${#candidates[@]} )); then
            log_error "无效选择，请重新输入"
            pause_function
            continue
        fi

        selected_idx="${candidates[$((pick - 1))]}"
        MIRROR_SELECTED_DEBIAN="$selected_idx"
        MIRROR_SELECTED_SECURITY="$selected_idx"
        MIRROR_SELECTED_PVE="$selected_idx"
        MIRROR_SELECTED_CEPH="$selected_idx"
        MIRROR_SELECTED_CT="$selected_idx"
        mirror_print_selection_summary
        return 0
    done
}

select_mirror_per_source() {
    mirror_reset_selection
    select_mirror_for_source debian "Debian 软件源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source security "Debian Security 安全源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source pve "Proxmox VE no-subscription 源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source ceph "Ceph Squid 源" || { mirror_reset_selection; return 1; }
    select_mirror_for_source ct "CT 模板源" || { mirror_reset_selection; return 1; }

    clear
    show_menu_header "镜像源选择摘要"
    mirror_print_selection_summary
    read -p "确认使用以上配置？输入 yes 确认，其他任意键返回: " confirm
    [[ "$confirm" == "yes" || "$confirm" == "YES" ]] || { mirror_reset_selection; return 1; }
}

select_mirror() {
    while true; do
        clear
        show_menu_header "镜像源配置"
        mirror_print_recommendation_notice
        show_menu_option "1" "全部使用同一镜像（快速）"
        show_menu_option "2" "按源类型分别选择（推荐）"
        show_menu_option "3" "跳过（稍后在菜单中配置）"
        echo "$UI_DIVIDER"
        echo "  跳过时不会写入软件源；再次执行更换软件源会重新进入本配置。"
        show_menu_footer

        local choice
        read -p "请选择 [1-3]: " choice
        case "$choice" in
            1) select_mirror_unified && return 0 ;;
            2) select_mirror_per_source && return 0 ;;
            3) mirror_reset_selection; log_info "已跳过镜像源配置"; return 1 ;;
            *) log_error "无效选择，请重新输入"; pause_function ;;
        esac
    done
}

# 版本检查函数
check_update() {
    log_info "正在检查更新..."

    # 显示进度提示
    echo -ne "[....] 正在检查更新...\033[0K\r"

    local update_urls prefer_mirror preferred_version_url preferred_update_url preferred_script_url
    local mirror_version_url="${GITHUB_MIRROR_PREFIX}${VERSION_FILE_URL}"
    local mirror_update_url="${GITHUB_MIRROR_PREFIX}${UPDATE_FILE_URL}"

    update_urls="$(pve_tools_choose_update_urls)"
    IFS='|' read -r prefer_mirror preferred_version_url preferred_update_url preferred_script_url <<< "$update_urls"
    if [[ "$prefer_mirror" -eq 1 ]]; then
        log_info "当前地区为： ${USER_COUNTRY_CODE:-unknown}，使用镜像源检查更新..."
    else
        log_info "使用 GitHub 源检查更新"
    fi

    remote_content=$(pve_tools_download_url "$preferred_version_url" 10)

    if [ -z "$remote_content" ]; then
        if [[ $prefer_mirror -eq 1 ]]; then
            log_warn "镜像源连接失败，尝试使用 GitHub 源..."
            remote_content=$(pve_tools_download_url "$VERSION_FILE_URL" 10)
        else
            log_warn "GitHub 连接失败，尝试使用镜像源..."
            remote_content=$(pve_tools_download_url "$mirror_version_url" 10)
        fi
    fi
    
    # 清除进度显示
    echo -ne "\033[0K\r"
    
    # 如果下载失败
    if [ -z "$remote_content" ]; then
        log_warn "网络连接失败，跳过版本检查"
        echo "提示：您可以手动访问以下地址检查更新："
        echo "https://github.com/PVE-Tools/PVE-Tools-9"
        echo "按回车键继续..."
        read -r
        return
    fi
    
    # 提取版本号和更新日志
    remote_version=$(echo "$remote_content" | head -1 | tr -d '[:space:]')
    version_changelog=$(echo "$remote_content" | tail -n +2)
    
    if [ -z "$remote_version" ]; then
        log_warn "获取的版本信息格式不正确"
        return
    fi

    detailed_changelog=$(pve_tools_download_url "$preferred_update_url" 10)

    if [ -z "$detailed_changelog" ]; then
        if [[ $prefer_mirror -eq 1 ]]; then
            log_warn "镜像源更新日志获取失败，尝试使用 GitHub 源..."
            detailed_changelog=$(pve_tools_download_url "$UPDATE_FILE_URL" 10)
        else
            log_warn "GitHub 更新日志获取失败，尝试使用镜像源..."
            detailed_changelog=$(pve_tools_download_url "$mirror_update_url" 10)
        fi
    fi
    
    # 比较版本
    if pve_tools_version_gt "$remote_version" "$CURRENT_VERSION"; then
        echo -e "${UI_HEADER}"
        echo -e "${YELLOW}🚀 发现新版本！推荐更新以获取最新功能和修复喵${NC}"
        echo -e "----------------------------------------------"
        echo -e "当前版本: ${WHITE}$CURRENT_VERSION${NC}"
        echo -e "最新版本: ${GREEN}$remote_version${NC}"
        echo -e "${BLUE}更新日志：${NC}"
        
        # 如果获取到了详细的更新日志
        if [ -n "$detailed_changelog" ]; then
            # 使用 sed 提取第一行作为标题，其余行缩进显示
            local first_line=$(echo "$detailed_changelog" | head -n 1)
            local rest_lines=$(echo "$detailed_changelog" | tail -n +2)
            
            echo -e "  ${CYAN}★ $first_line${NC}"
            if [ -n "$rest_lines" ]; then
                echo "$rest_lines" | sed 's/^/    /'
            fi
        else
            # 格式化显示版本文件中的更新内容
            if [ -n "$version_changelog" ] && [ "$version_changelog" != "$remote_version" ]; then
                echo "$version_changelog" | sed 's/^/    /'
            else
                echo -e "    ${YELLOW}- 请访问项目页面获取详细更新内容${NC}"
            fi
        fi
        
        echo -e "----------------------------------------------"
        echo -e "${CYAN}官方文档与最新脚本：${NC}"
        echo -e "🔗 https://pve.oowo.cc (推荐)"
        echo -e "🔗 https://github.com/PVE-Tools/PVE-Tools-9"
        echo -e "${UI_FOOTER}"
        echo -e "按 ${GREEN}回车键${NC} 进入主菜单..."
        read -r
    else
        log_success "当前已是最新版本 ($CURRENT_VERSION) 放心用吧"
    fi
}

pve_tools_local_update() {
    local current_script="${BASH_SOURCE[0]}"
    local resolved_script backup_dir backup_path tmp_script update_urls prefer_mirror version_url update_url script_url
    local remote_content remote_version detailed_changelog fallback_script_url

    if [[ -z "$current_script" || ! -f "$current_script" ]]; then
        display_error "无法定位当前脚本文件" "请使用本地文件方式运行脚本后再执行更新。"
        return 1
    fi

    resolved_script="$(readlink -f "$current_script" 2>/dev/null || realpath "$current_script" 2>/dev/null || echo "$current_script")"
    if [[ ! -w "$resolved_script" ]]; then
        display_error "当前脚本不可写: $resolved_script" "请使用 root 或确认脚本文件权限后重试。"
        return 1
    fi

    update_urls="$(pve_tools_choose_update_urls)"
    IFS='|' read -r prefer_mirror version_url update_url script_url <<< "$update_urls"
    remote_content="$(pve_tools_download_url "$version_url" 15)"
    if [[ -z "$remote_content" ]]; then
        if [[ "$prefer_mirror" -eq 1 ]]; then
            log_warn "镜像源版本文件获取失败，尝试 GitHub 源。"
            remote_content="$(pve_tools_download_url "$VERSION_FILE_URL" 15)"
        else
            log_warn "GitHub 版本文件获取失败，尝试镜像源。"
            remote_content="$(pve_tools_download_url "${GITHUB_MIRROR_PREFIX}${VERSION_FILE_URL}" 15)"
        fi
    fi

    if [[ -z "$remote_content" ]]; then
        display_error "无法获取远程版本信息" "网络不通或 GitHub/镜像源不可用，已保持本地脚本不变。"
        return 1
    fi

    remote_version="$(echo "$remote_content" | head -1 | tr -d '[:space:]')"
    if [[ -z "$remote_version" ]]; then
        display_error "远程版本文件格式异常" "已保持本地脚本不变。"
        return 1
    fi

    detailed_changelog="$(pve_tools_download_url "$update_url" 15)"
    if [[ -z "$detailed_changelog" ]]; then
        if [[ "$prefer_mirror" -eq 1 ]]; then
            detailed_changelog="$(pve_tools_download_url "$UPDATE_FILE_URL" 15)"
        else
            detailed_changelog="$(pve_tools_download_url "${GITHUB_MIRROR_PREFIX}${UPDATE_FILE_URL}" 15)"
        fi
    fi

    clear
    show_menu_header "本地脚本快捷更新"
    echo -e "${CYAN}当前脚本:${NC} $resolved_script"
    echo -e "${CYAN}当前版本:${NC} $CURRENT_VERSION"
    echo -e "${CYAN}远程版本:${NC} $remote_version"
    echo -e "${CYAN}下载来源:${NC} $script_url"
    echo "$UI_DIVIDER"
    if pve_tools_version_gt "$remote_version" "$CURRENT_VERSION"; then
        echo -e "${GREEN}发现可更新版本。${NC}"
    elif [[ "$remote_version" == "$CURRENT_VERSION" ]]; then
        echo -e "${YELLOW}远程版本与当前版本一致，也可以选择强制覆盖本地脚本。${NC}"
    else
        echo -e "${YELLOW}远程版本看起来不高于当前版本，默认不建议覆盖。${NC}"
    fi
    echo "$UI_DIVIDER"
    if [[ -n "$detailed_changelog" ]]; then
        echo -e "${CYAN}更新日志预览:${NC}"
        echo "$detailed_changelog" | head -n 30 | sed 's/^/  /'
        echo "$UI_DIVIDER"
    fi

    read -p "是否下载并替换本地脚本？(yes/no) [no]: " confirm
    confirm="${confirm:-no}"
    if [[ "$confirm" != "yes" && "$confirm" != "YES" ]]; then
        log_info "已取消脚本更新。"
        return 0
    fi

    backup_dir="/var/backups/pve-tools"
    mkdir -p "$backup_dir" || {
        display_error "无法创建备份目录: $backup_dir" "已保持本地脚本不变。"
        return 1
    }
    backup_path="${backup_dir}/PVE-Tools.sh.bak"
    tmp_script="$(mktemp /tmp/pve-tools-update.XXXXXX)" || {
        display_error "无法创建临时文件" "已保持本地脚本不变。"
        return 1
    }

    if ! cp -a "$resolved_script" "$backup_path"; then
        rm -f "$tmp_script"
        display_error "备份当前脚本失败" "目标备份: $backup_path。已保持本地脚本不变。"
        return 1
    fi
    log_success "当前脚本已备份: $backup_path"

    if ! pve_tools_download_url "$script_url" 30 > "$tmp_script"; then
        fallback_script_url="$PVE_TOOLS_SCRIPT_URL"
        [[ "$script_url" == "$PVE_TOOLS_SCRIPT_URL" ]] && fallback_script_url="${GITHUB_MIRROR_PREFIX}${PVE_TOOLS_SCRIPT_URL}"
        log_warn "首选脚本下载失败，尝试备用源: $fallback_script_url"
        if ! pve_tools_download_url "$fallback_script_url" 30 > "$tmp_script"; then
            rm -f "$tmp_script"
            display_error "下载新脚本失败" "已保留原脚本，备份位于 $backup_path。"
            return 1
        fi
    fi

    if ! grep -q '^CURRENT_VERSION=' "$tmp_script" || ! bash -n "$tmp_script"; then
        rm -f "$tmp_script"
        cp -a "$backup_path" "$resolved_script" >/dev/null 2>&1 || true
        display_error "下载的新脚本校验失败，已自动回滚" "请稍后重试或手动检查下载源。"
        return 1
    fi

    if ! cp -a "$tmp_script" "$resolved_script"; then
        cp -a "$backup_path" "$resolved_script" >/dev/null 2>&1 || true
        rm -f "$tmp_script"
        display_error "替换脚本失败，已尝试自动回滚" "备份文件: $backup_path"
        return 1
    fi
    chmod +x "$resolved_script" >/dev/null 2>&1 || true
    rm -f "$tmp_script"

    display_success "本地脚本更新完成" "备份文件: $backup_path；请重新运行脚本以加载新版本。"
}

pve_tools_local_uninstall() {
    local current_script resolved_script clean_cron delete_targets=()
    current_script="${BASH_SOURCE[0]}"
    resolved_script="$(readlink -f "$current_script" 2>/dev/null || realpath "$current_script" 2>/dev/null || echo "$current_script")"

    clear
    show_menu_header "本地脚本快捷卸载"
    echo -e "${RED}将删除 PVE-Tools 本地脚本及脚本产生的日志/备份/导出目录。${NC}"
    echo -e "${YELLOW}不会删除 PVE 自身软件包、VM 磁盘或系统存储配置。${NC}"
    echo "$UI_DIVIDER"

    [[ -f "$resolved_script" ]] && delete_targets+=("$resolved_script")
    [[ -f "/var/log/pve-tools.log" ]] && delete_targets+=("/var/log/pve-tools.log")
    [[ -d "/var/backups/pve-tools" ]] && delete_targets+=("/var/backups/pve-tools/")
    [[ -d "/var/lib/pve-tools" ]] && delete_targets+=("/var/lib/pve-tools/")

    if [[ -f "$VM_BACKUP_CRON_FILE" ]]; then
        read -p "是否同时清理 VM 定时备份任务 ${VM_BACKUP_CRON_FILE}？(yes/no) [no]: " clean_cron
        clean_cron="${clean_cron:-no}"
        if [[ "$clean_cron" == "yes" || "$clean_cron" == "YES" ]]; then
            delete_targets+=("$VM_BACKUP_CRON_FILE")
        fi
    fi

    if (( ${#delete_targets[@]} == 0 )); then
        log_warn "未发现可删除的 PVE-Tools 本地文件。"
        return 0
    fi

    echo -e "${CYAN}将删除以下文件/目录:${NC}"
    printf '  - %s\n' "${delete_targets[@]}"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "卸载 PVE-Tools 本地脚本及关联文件" "会永久删除上方列出的脚本、日志、备份和导出目录。" "误删备份目录会丢失脚本自动备份的历史配置副本；删除 cron 会停止后续定时备份。" "请确认已经导出仍需保留的备份/配置文件，并确认删除清单只包含 PVE-Tools 文件。" "UNINSTALL"; then
        return 0
    fi

    local target
    for target in "${delete_targets[@]}"; do
        if [[ -d "${target%/}" ]]; then
            rm -rf -- "${target%/}"
            echo -e "${GREEN}已删除目录:${NC} ${target%/}"
        elif [[ -e "$target" ]]; then
            rm -f -- "$target"
            echo -e "${GREEN}已删除文件:${NC} $target"
        fi
    done

    if [[ "$clean_cron" == "yes" || "$clean_cron" == "YES" ]]; then
        systemctl restart cron 2>/dev/null || service cron restart 2>/dev/null || true
    fi

    echo -e "${GREEN}卸载完成。当前脚本文件如已删除，本次会话结束后请直接退出。${NC}"
}

security_ssh_service_name() {
    local service

    for service in ssh.service sshd.service ssh; do
        if systemctl list-unit-files "$service" >/dev/null 2>&1 || systemctl status "$service" >/dev/null 2>&1; then
            echo "${service%.service}"
            return 0
        fi
    done
    echo "ssh"
}

security_sshd_effective_option() {
    local key="$1"
    local lower_key
    lower_key="$(echo "$key" | tr 'A-Z' 'a-z')"

    if command -v sshd >/dev/null 2>&1; then
        sshd -T 2>/dev/null | awk -v key="$lower_key" '$1 == key {print $2; exit}'
    fi
}

security_root_authorized_keys_ready() {
    local auth_file="/root/.ssh/authorized_keys"

    [[ -f "$auth_file" ]] || return 1
    grep -Ev '^[[:space:]]*(#|$)' "$auth_file" >/dev/null 2>&1
}

security_validate_ssh_port() {
    local port="$1"

    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
        display_error "SSH 端口不合法: $port" "请使用 1024-65535 之间的高位端口。"
        return 1
    fi
    if (( port == 8006 )); then
        display_error "端口 8006 是 PVE Web UI 常用端口" "请换一个端口。"
        return 1
    fi
}

security_random_ssh_port() {
    local port

    if command -v shuf >/dev/null 2>&1; then
        for _ in {1..20}; do
            port="$(shuf -i 20000-60999 -n 1)"
            if ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
                echo "$port"
                return 0
            fi
        done
    fi
    echo "22222"
}

security_ensure_sshd_include() {
    local config_file="/etc/ssh/sshd_config"

    if ! grep -Eiq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$config_file" 2>/dev/null; then
        local tmp
        tmp="$(mktemp)" || return 1
        {
            echo "Include /etc/ssh/sshd_config.d/*.conf"
            cat "$config_file"
        } > "$tmp"
        cat "$tmp" > "$config_file"
        rm -f "$tmp"
    fi
}

security_comment_global_sshd_directives() {
    local config_file="/etc/ssh/sshd_config"
    local tmp

    tmp="$(mktemp)" || return 1
    awk '
        BEGIN {
            in_match = 0
            keys["port"] = 1
            keys["passwordauthentication"] = 1
            keys["kbdinteractiveauthentication"] = 1
            keys["challengeresponseauthentication"] = 1
            keys["pubkeyauthentication"] = 1
            keys["permitemptypasswords"] = 1
        }
        /^[[:space:]]*Match[[:space:]]/ { in_match = 1 }
        {
            line = $0
            probe = line
            sub(/^[[:space:]]*/, "", probe)
            split(probe, parts, /[[:space:]]+/)
            key = tolower(parts[1])
            if (!in_match && line !~ /^[[:space:]]*#/ && keys[key]) {
                print "# PVE-Tools disabled global duplicate: " line
            } else {
                print line
            }
        }
    ' "$config_file" > "$tmp" || {
        rm -f "$tmp"
        return 1
    }
    cat "$tmp" > "$config_file"
    rm -f "$tmp"
}

security_write_sshd_hardening_dropin() {
    local port="$1"
    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin_file="${dropin_dir}/99-pve-tools-hardening.conf"

    mkdir -p "$dropin_dir" || return 1
    cat > "$dropin_file" <<EOF
# Managed by PVE-Tools.
# Keep console or out-of-band access available before changing SSH policy.
Port $port
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
EOF
}

security_write_fail2ban_sshd_jail() {
    local port="$1"
    local maxretry="$2"
    local bantime="$3"
    local findtime="$4"
    local jail_dir="/etc/fail2ban/jail.d"
    local jail_file="${jail_dir}/pve-tools-sshd.conf"

    mkdir -p "$jail_dir" || return 1
    cat > "$jail_file" <<EOF
# Managed by PVE-Tools.
[sshd]
enabled = true
port = $port
maxretry = $maxretry
bantime = $bantime
findtime = $findtime
EOF
}

security_install_fail2ban_if_needed() {
    if command -v fail2ban-client >/dev/null 2>&1; then
        return 0
    fi

    log_warn "未检测到 fail2ban，准备通过 apt 安装。"
    if ! apt-get update; then
        display_error "apt-get update 失败" "请检查软件源和网络后重试。"
        return 1
    fi
    if ! apt-get install -y fail2ban; then
        display_error "fail2ban 安装失败" "请检查软件源和网络后重试。"
        return 1
    fi
}

security_restore_hardening_backups() {
    local ssh_backup="$1"
    local config_file="$2"
    local dropin_backup="$3"
    local dropin_file="$4"
    local jail_backup="$5"
    local jail_file="$6"

    [[ -n "$ssh_backup" && -f "$ssh_backup" ]] && cp -a "$ssh_backup" "$config_file" >/dev/null 2>&1 || true
    if [[ -n "$dropin_backup" && -f "$dropin_backup" ]]; then
        cp -a "$dropin_backup" "$dropin_file" >/dev/null 2>&1 || true
    else
        rm -f "$dropin_file" >/dev/null 2>&1 || true
    fi
    if [[ -n "$jail_backup" && -f "$jail_backup" ]]; then
        cp -a "$jail_backup" "$jail_file" >/dev/null 2>&1 || true
    else
        rm -f "$jail_file" >/dev/null 2>&1 || true
    fi
}

security_ssh_hardening() {
    block_non_pve9_destructive "SSH 一键加固" || return 1

    local current_port new_port maxretry bantime findtime ssh_service ssh_backup="" jail_backup="" dropin_backup=""
    local config_file="/etc/ssh/sshd_config"
    local jail_file="/etc/fail2ban/jail.d/pve-tools-sshd.conf"
    local dropin_file="/etc/ssh/sshd_config.d/99-pve-tools-hardening.conf"

    if [[ ! -f "$config_file" ]] || ! command -v sshd >/dev/null 2>&1; then
        display_error "未找到 OpenSSH Server 配置" "请确认 openssh-server 已安装。"
        return 1
    fi

    current_port="$(security_sshd_effective_option port)"
    current_port="${current_port:-22}"

    clear
    show_menu_header "SSH 一键加固"
    echo -e "${RED}重要:${NC} 禁用密码登录前，必须确认 SSH 密钥登录可用，或你有 PVE 控制台/带外管理方式。"
    echo -e "${CYAN}当前 SSH 端口:${NC} $current_port"
    echo -e "${CYAN}当前连接:${NC} ${SSH_CONNECTION:-未检测到 SSH_CONNECTION}"
    if security_root_authorized_keys_ready; then
        echo -e "${GREEN}检测到 /root/.ssh/authorized_keys 中存在公钥。${NC}"
    else
        echo -e "${RED}未检测到 root 公钥。继续后可能无法再通过密码 SSH 登录。${NC}"
    fi
    echo "$UI_DIVIDER"

    read -p "请输入新的 SSH 端口（留空随机生成高位端口）: " new_port
    new_port="${new_port:-$(security_random_ssh_port)}"
    security_validate_ssh_port "$new_port" || return 1

    read -p "fail2ban 最大失败次数 [5]: " maxretry
    maxretry="${maxretry:-5}"
    [[ "$maxretry" =~ ^[0-9]+$ && "$maxretry" -ge 1 ]] || {
        display_error "最大失败次数必须是正整数"
        return 1
    }
    read -p "fail2ban 封禁时间 [1h]: " bantime
    bantime="${bantime:-1h}"
    [[ "$bantime" =~ ^[0-9]+[smhd]?$ ]] || {
        display_error "封禁时间格式不合法" "示例: 3600 或 1h"
        return 1
    }
    read -p "fail2ban 检测时间窗口 [10m]: " findtime
    findtime="${findtime:-10m}"
    [[ "$findtime" =~ ^[0-9]+[smhd]?$ ]] || {
        display_error "检测窗口格式不合法" "示例: 600 或 10m"
        return 1
    }

    clear
    show_menu_header "SSH 加固确认"
    echo -e "${CYAN}新 SSH 端口:${NC} $new_port"
    echo -e "${CYAN}密码登录:${NC} 禁用"
    echo -e "${CYAN}密钥登录:${NC} 启用"
    echo -e "${CYAN}fail2ban:${NC} maxretry=$maxretry, bantime=$bantime, findtime=$findtime"
    echo -e "${YELLOW}执行后请使用:${NC} ssh -p $new_port root@<PVE-IP>"
    echo -e "${YELLOW}如启用 PVE/外部防火墙，请同步放行 TCP $new_port，并确认 8006 Web UI 或控制台可用。${NC}"
    echo "$UI_DIVIDER"

    if ! confirm_high_risk_action "修改 SSH 端口、禁用密码登录并配置 fail2ban" "错误配置可能导致 SSH 无法连接；未准备密钥时会失去密码登录入口。" "当前远程会话可能在 sshd 重启后无法重新连接，需要通过控制台修复。" "请确认密钥登录已测试成功，控制台/带外访问可用，并已记录原端口 $current_port。" "SSH-HARDEN"; then
        return 0
    fi

    backup_file "$config_file" ssh_backup >/dev/null 2>&1 || return 1
    [[ -f "$jail_file" ]] && backup_file "$jail_file" jail_backup >/dev/null 2>&1 || true
    [[ -f "$dropin_file" ]] && backup_file "$dropin_file" dropin_backup >/dev/null 2>&1 || true

    if ! security_install_fail2ban_if_needed; then
        return 1
    fi

    if ! security_ensure_sshd_include || ! security_comment_global_sshd_directives || ! security_write_sshd_hardening_dropin "$new_port"; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        display_error "写入 SSH 配置失败，已尝试回滚" "备份文件: $ssh_backup"
        return 1
    fi

    if ! sshd -t -f "$config_file" 2>/tmp/pve-tools-sshd-test.log; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        sed 's/^/  /' /tmp/pve-tools-sshd-test.log 2>/dev/null || true
        display_error "sshd 配置语法检查失败，已自动回滚" "请检查 $config_file。"
        return 1
    fi

    if ! security_write_fail2ban_sshd_jail "$new_port" "$maxretry" "$bantime" "$findtime"; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        display_error "写入 fail2ban 配置失败，已尝试回滚 SSH/fail2ban 配置" "请人工检查 $config_file 和 $jail_file。"
        return 1
    fi

    ssh_service="$(security_ssh_service_name)"
    if ! systemctl restart "$ssh_service" 2>/dev/null; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        systemctl restart "$ssh_service" 2>/dev/null || true
        display_error "SSH 服务重启失败，已尝试回滚" "请通过控制台检查 SSH 状态。"
        return 1
    fi

    if ! systemctl enable --now fail2ban >/dev/null 2>&1 && ! systemctl restart fail2ban >/dev/null 2>&1; then
        security_restore_hardening_backups "$ssh_backup" "$config_file" "$dropin_backup" "$dropin_file" "$jail_backup" "$jail_file"
        systemctl restart "$ssh_service" 2>/dev/null || true
        display_error "fail2ban 启动失败，已尝试回滚 SSH/fail2ban 配置" "请检查 systemctl status fail2ban。"
        return 1
    fi
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status sshd >/dev/null 2>&1 || log_warn "fail2ban sshd jail 暂未进入运行状态，请稍后用 fail2ban-client status sshd 检查。"
    fi

    display_success "SSH 加固已完成" "新连接命令: ssh -p $new_port root@<PVE-IP>；请立即新开终端验证后再关闭当前会话。"
}

security_report_item() {
    local level="$1"
    local title="$2"
    local detail="$3"
    local advice="$4"
    local color="$GREEN"

    case "$level" in
        高) color="$RED"; SECURITY_HIGH_COUNT=$((SECURITY_HIGH_COUNT + 1)) ;;
        中) color="$YELLOW"; SECURITY_MEDIUM_COUNT=$((SECURITY_MEDIUM_COUNT + 1)) ;;
        低) color="$CYAN"; SECURITY_LOW_COUNT=$((SECURITY_LOW_COUNT + 1)) ;;
    esac

    echo -e "${color}[${level}]${NC} ${title}"
    echo "  状态: $detail"
    echo "  建议: $advice"
    echo
}

security_pve_firewall_enabled() {
    local file="$1"

    [[ -f "$file" ]] || return 1
    awk '
        /^\[OPTIONS\]/ { in_options = 1; next }
        /^\[/ { in_options = 0 }
        in_options && $1 == "enable:" && $2 == "1" { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$file"
}

security_list_public_listeners() {
    if ! command -v ss >/dev/null 2>&1; then
        return 0
    fi

    ss -ltn 2>/dev/null | awk 'NR>1 {
        addr=$4
        n=split(addr, parts, ":")
        port=parts[n]
        if (addr ~ /^0\.0\.0\.0:/ || addr ~ /^\[::\]:/ || addr ~ /^\*:/ || addr ~ /^:::/) {
            print port "|" addr
        }
    }' | sort -u
}

security_risk_check() {
    local ssh_port password_auth empty_passwords fail2ban_state cluster_fw node_fw dangerous_ports upgradable uid0_extra loose_files

    SECURITY_HIGH_COUNT=0
    SECURITY_MEDIUM_COUNT=0
    SECURITY_LOW_COUNT=0

    clear
    show_menu_header "安全风险检查"
    echo -e "${YELLOW}本功能只读取配置和状态，不修改系统。${NC}"
    echo "$UI_DIVIDER"

    ssh_port="$(security_sshd_effective_option port)"
    ssh_port="${ssh_port:-unknown}"
    password_auth="$(security_sshd_effective_option passwordauthentication)"
    password_auth="${password_auth:-unknown}"
    if [[ "$ssh_port" == "22" ]]; then
        security_report_item "中" "SSH 使用默认端口 22" "当前端口: $ssh_port" "可进入本菜单的 SSH 一键加固，改为高位端口并同步防火墙规则。"
    else
        security_report_item "低" "SSH 端口检查" "当前端口: $ssh_port" "保持资产台账和防火墙规则同步。"
    fi

    if [[ "$password_auth" == "yes" ]]; then
        security_report_item "高" "SSH 允许密码登录" "PasswordAuthentication: yes" "确认密钥登录可用后，使用 SSH 一键加固禁用密码登录。"
    else
        security_report_item "低" "SSH 密码登录检查" "PasswordAuthentication: $password_auth" "定期检查 authorized_keys 和账号权限。"
    fi

    fail2ban_state="$(systemctl is-active fail2ban 2>/dev/null || echo inactive)"
    if [[ "$fail2ban_state" != "active" ]]; then
        security_report_item "中" "fail2ban 未运行" "状态: $fail2ban_state" "安装并启用 fail2ban，至少保护 sshd jail。"
    else
        security_report_item "低" "fail2ban 状态" "状态: active" "可用 fail2ban-client status sshd 复查封禁策略。"
    fi

    if security_pve_firewall_enabled "$PVE_CLUSTER_FIREWALL_FILE"; then
        cluster_fw="enabled"
    else
        cluster_fw="disabled"
    fi
    node_fw="/etc/pve/nodes/$(hostname)/host.fw"
    if security_pve_firewall_enabled "$node_fw"; then
        node_fw="enabled"
    else
        node_fw="disabled"
    fi
    if [[ "$cluster_fw" != "enabled" || "$node_fw" != "enabled" ]]; then
        security_report_item "中" "PVE 防火墙未完全启用" "datacenter=$cluster_fw, node=$node_fw" "进入宿主机网络与防火墙菜单，审查规则后启用数据中心和节点防火墙。"
    else
        security_report_item "低" "PVE 防火墙状态" "datacenter=enabled, node=enabled" "继续保持规则最小开放。"
    fi

    dangerous_ports="$(security_list_public_listeners | awk -F'|' '$1 ~ /^(21|23|25|111|139|445|3306|5432|6379|9200|9300)$/ || ($1 >= 5900 && $1 <= 5999) {print $0}')"
    if [[ -n "$dangerous_ports" ]]; then
        security_report_item "中" "检测到常见高风险端口对外监听" "$(echo "$dangerous_ports" | tr '\n' ' ')" "确认是否确需暴露；不需要时关闭服务或用防火墙限制来源。"
    else
        security_report_item "低" "服务暴露检查" "未发现常见高风险端口对外监听" "仍建议人工审查 ss -ltnup 输出。"
    fi

    upgradable="$(apt list --upgradable 2>/dev/null | awk 'NR>1 {print}' | head -n 10)"
    if [[ -n "$upgradable" ]]; then
        security_report_item "中" "存在待升级软件包" "$(echo "$upgradable" | wc -l) 个以上待升级条目（仅展示前 10 个）" "在维护窗口执行 apt update && apt upgrade，并重启到新内核后复查。"
        echo "$upgradable" | sed 's/^/    /'
        echo
    else
        security_report_item "低" "系统更新检查" "当前 apt 缓存未显示待升级包" "该检查不主动刷新 apt 缓存；建议定期运行 apt update。"
    fi

    empty_passwords="$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null | tr '\n' ' ')"
    uid0_extra="$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd 2>/dev/null | tr '\n' ' ')"
    if [[ -n "$empty_passwords" || -n "$uid0_extra" ]]; then
        security_report_item "高" "账户风险" "空密码账户: ${empty_passwords:-无}; 额外 UID0: ${uid0_extra:-无}" "立即锁定异常账户或设置强密码，并审查 /etc/passwd 与 /etc/shadow。"
    else
        security_report_item "低" "账户风险检查" "未发现空密码账户或额外 UID 0 账户" "继续保持最小账号集。"
    fi

    loose_files=""
    for file in /etc/ssh/sshd_config /etc/shadow /etc/pve/storage.cfg "$PVE_CLUSTER_FIREWALL_FILE"; do
        [[ -e "$file" ]] || continue
        if [[ -w "$file" && ! -O "$file" ]]; then
            loose_files+="$file(当前用户可写但非属主) "
        fi
        if find "$file" -maxdepth 0 -perm /022 2>/dev/null | grep -q .; then
            loose_files+="$file(组/其他可写) "
        fi
    done
    if [[ -n "$loose_files" ]]; then
        security_report_item "高" "关键配置文件权限过宽" "$loose_files" "恢复 root/系统默认属主和最小写权限，避免普通用户改写关键配置。"
    else
        security_report_item "低" "关键文件权限检查" "未发现组/其他可写的关键配置文件" "后续变更后继续复查。"
    fi

    echo "$UI_DIVIDER"
    echo -e "${CYAN}汇总:${NC} 高风险 $SECURITY_HIGH_COUNT / 中风险 $SECURITY_MEDIUM_COUNT / 低风险 $SECURITY_LOW_COUNT"
    echo -e "${YELLOW}提示:${NC} 该报告不会自动修复系统；需要改配置时请从对应菜单进入并确认风险。"
}

security_center_menu() {
    while true; do
        clear
        show_menu_header "安全中心"
        show_menu_option "1" "安全风险检查 ${CYAN}(只读报告)${NC}"
        show_menu_option "2" "SSH 一键加固 ${CYAN}(端口/密钥/fail2ban)${NC}"
        show_menu_option "0" "返回"
        show_menu_footer

        local choice
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) security_risk_check ;;
            2) security_ssh_hardening ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 温度监控管理菜单
temp_monitoring_menu() {
    while true; do
        clear
        show_menu_header "温度监控管理"
        show_menu_option "1" "配置温度监控 ${CYAN}(CPU/硬盘温度显示)${NC}"
        show_menu_option "2" "${RED}移除温度监控${NC} (移除温度监控功能)"
        show_menu_option "3" "UPS 状态诊断 ${CYAN}(NUT / upsc)${NC}"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回上级菜单"
        show_menu_footer
        echo
        read -p "请选择 [0-3]: " temp_choice
        echo
        
        case $temp_choice in
            1)
                cpu_add
                ;;
            2)
                cpu_del
                ;;
            3)
                show_ups_diagnostics
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        pause_function
    done
}

# 自定义温度监控配置
# 已经死了。

# Ceph管理菜单
ceph_management_menu() {
    while true; do
        clear

        show_menu_header "Ceph管理"
        show_menu_option "1" "添加 ${CYAN}ceph-squid${NC} 源 (PVE8/9专用)"
        show_menu_option "2" "添加 ${CYAN}ceph-quincy${NC} 源 (PVE7/8专用)"
        show_menu_option "3" "${RED}卸载 Ceph${NC} (完全移除Ceph)"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回主菜单"
        show_menu_footer
        echo
        read -p "请选择 [0-3]: " ceph_choice
        echo
        
        case $ceph_choice in
            1)
                pve9_ceph
                ;;
            2)
                pve8_ceph
                ;;
            3)
                remove_ceph
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        pause_function
    done
}

# 救砖：恢复官方 pve-qemu-kvm
restore_qemu_kvm() {
    log_step "开始恢复官方 pve-qemu-kvm"
    echo "此操作将执行以下步骤："
    echo "1. 解除 pve-qemu-kvm 的版本锁定 (unhold)"
    echo "2. 强制重新安装官方版本的 pve-qemu-kvm"
    echo "3. 恢复官方的 initramfs 设置"
    echo "适用于因安装修改版 QEMU 导致虚拟机无法启动或系统异常的情况。"
    echo

    if ! confirm_action "是否继续执行恢复操作？"; then
        return
    fi

    # 1. 解除锁定
    log_info "正在解除软件包锁定..."
    apt-mark unhold pve-qemu-kvm
    
    # 2. 强制重装官方版本
    log_info "正在重新安装官方 pve-qemu-kvm..."
    if apt-get update && apt-get install --reinstall -y pve-qemu-kvm; then
        log_success "官方 pve-qemu-kvm 恢复成功"
    else
        log_error "恢复失败，请检查网络连接或手动尝试: apt-get install --reinstall pve-qemu-kvm"
        return 1
    fi

    # 3. 清理黑名单 (可选)
    if confirm_action "是否同时清理 Intel 核显相关的驱动黑名单？"; then
        log_info "正在清理黑名单配置..."
        sed -i '/blacklist i915/d' /etc/modprobe.d/pve-blacklist.conf
        sed -i '/blacklist snd_hda_intel/d' /etc/modprobe.d/pve-blacklist.conf
        sed -i '/blacklist snd_hda_codec_hdmi/d' /etc/modprobe.d/pve-blacklist.conf
        
        log_info "正在更新 initramfs..."
        update-initramfs -u -k all
        log_success "黑名单清理完成"
    fi

    log_success "救砖操作完成！建议重启系统。"
    if confirm_action "是否现在重启系统？"; then
        reboot
    fi
}

#英特尔核显直通
intel_gpu_passthrough() {
    log_step "开始 Intel 核显直通配置"
    echo "注意：此功能基于 AICodo 的修改版 QEMU 和 ROM"
    echo "详细原理与教程：https://pve.oowo.cc/advanced/gpu-passthrough"
    echo "适用于需要将 Intel 核显直通给 Windows 虚拟机且遇到代码 43 或黑屏的情况"
    echo "支持的 CPU 架构：6代(Skylake) 到 14代(Raptor Lake Refresh)"
    echo "项目地址：https://github.com/AICodo/intel6-14rom"
    echo
    log_warn "警告"
    log_warn "本功能并非能100%一次成功！"
    echo 
    log_warn "由于 Intel 牙膏厂混乱的代号和半代升级策略（如 N5105 Jasper Lake 等）"
    log_warn "通用 ROM 无法保证 100% 适用于所有 CPU 型号！"
    log_warn "直通失败属于正常现象，请尝试更换其他版本的 ROM 或自行寻找专用 ROM"
    log_warn "本功能仅提供自动化配置辅助，作者精力有限，无法提供免费的一对一排错服务"
    log_warn "折腾有风险，入坑需谨慎！"
    echo
    log_tips "如果配置失败，请访问文档站查看详细教程并留言反馈："
    log_tips "🔗 https://pve.oowo.cc/advanced/gpu-passthrough"
    echo
    log_tips "如需要反馈或者请求更新ROM文件适配你的CPU，请前往AICodo的GitHub仓库开ISSUE反馈，不是找我。"
    echo

    echo "请选择操作："
    echo "  1) 开始配置 (安装修改版 QEMU + 下载 ROM)"
    echo "  2) 救砖模式 (恢复官方 QEMU + 清理配置)"
    echo "  0) 返回上级菜单"
    read -p "请输入选择 [0-2]: " choice
    
    case $choice in
        1)
            # 继续执行配置流程
            ;;
        2)
            restore_qemu_kvm
            return
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            return
            ;;
    esac

    # 1. 配置黑名单
    log_step "配置驱动黑名单 (屏蔽宿主机占用核显)"
    if ! grep -q "blacklist i915" /etc/modprobe.d/pve-blacklist.conf; then
        echo "blacklist i915" >> /etc/modprobe.d/pve-blacklist.conf
        echo "blacklist snd_hda_intel" >> /etc/modprobe.d/pve-blacklist.conf
        echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/pve-blacklist.conf
        log_success "已添加黑名单配置"
        
        log_info "正在更新 initramfs..."
        update-initramfs -u -k all
    else
        log_info "黑名单配置已存在，跳过"
    fi

    # 2. 安装修改版 QEMU
    log_step "安装修改版 pve-qemu-kvm"
    echo "正在获取最新 release 版本..."
    
    # 尝试获取最新下载链接 (这里为了稳定性暂时写死或使用最新已知的逻辑，实际可爬虫获取)
    # 根据用户提供的信息，修改版 QEMU 下载地址: https://github.com/AICodo/pve-anti-detection/releases
    # 为了简化，我们使用 ghfast.top 加速下载最新的 release
    # 注意：这里需要动态获取最新 deb 包链接，或者让用户手动输入链接
    # 为方便起见，这里演示自动获取逻辑
    
    local qemu_releases_url="https://api.github.com/repos/AICodo/pve-anti-detection/releases/latest"
    local qemu_deb_url=$(curl -s $qemu_releases_url | grep "browser_download_url.*deb" | cut -d '"' -f 4 | head -n 1)
    
    if [ -z "$qemu_deb_url" ]; then
        log_warn "无法自动获取修改版 QEMU 下载链接，尝试使用备用链接或手动下载"
        # 备用逻辑：提示用户手动下载
        echo "请访问 https://github.com/AICodo/pve-anti-detection/releases 下载最新 deb 包"
        echo "然后使用 dpkg -i 安装"
    else
        # 加速下载
        local fast_qemu_url="https://ghfast.top/${qemu_deb_url}"
        log_info "正在下载: $fast_qemu_url"
        wget -O /tmp/pve-qemu-kvm.deb "$fast_qemu_url"
        
        if [ -s "/tmp/pve-qemu-kvm.deb" ]; then
            log_info "正在安装修改版 QEMU..."
            dpkg -i /tmp/pve-qemu-kvm.deb
            log_success "安装完成"
            
            # 阻止更新
            apt-mark hold pve-qemu-kvm
            log_info "已锁定 pve-qemu-kvm 防止自动更新"
        else
            log_error "下载失败"
        fi
    fi

    # 3. 下载 ROM 文件
    log_step "下载核显 ROM 文件"
    echo "正在检测 CPU 型号..."
    local cpu_model=$(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)
    echo "CPU 型号: $cpu_model"
    
    # 优先推荐的通用 ROM
    local recommended_rom="6-14-qemu10.rom"
    
    # 特殊 CPU 型号映射表 (根据 release 信息整理)
    # 格式: "关键字|ROM文件名"
    local special_cpus=(
        "J6412|11-J6412-q10.rom"
        "N5095|11-n5095-q10.rom"
        "1240P|12-1240p-q10.rom"
        "N100|12-n100-q10.rom"
        "J4125|j4125-q10.rom"
        "N2930|N2930-q10.rom"
        "N3350|N3350-q10.rom"
        "11700H|nb-11-11700h-q10.rom"
        "1185G7|nb-11-1185G7E-q10.rom"
        "12700H|nb-12-12700h-q10.rom"
        "13700H|nb-13-13700h-q10.rom"
    )
    
    # 检测是否为特殊 CPU
    for item in "${special_cpus[@]}"; do
        local keyword="${item%%|*}"
        local rom_name="${item##*|}"
        if echo "$cpu_model" | grep -qi "$keyword"; then
            recommended_rom="$rom_name"
            log_success "检测到特殊 CPU ($keyword)，推荐使用专用 ROM: $recommended_rom"
            break
        fi
    done

    # 下载 ROM 文件
    local rom_releases_url="https://api.github.com/repos/AICodo/intel6-14rom/releases/latest"
    log_info "正在获取 ROM 列表..."
    
    # 获取 release 信息
    # 注意：这里我们使用 grep 简单提取下载链接和文件名
    local release_info=$(curl -s $rom_releases_url)
    local assets=$(echo "$release_info" | grep "browser_download_url" | cut -d '"' -f 4)
    
    if [ -z "$assets" ]; then
         log_error "无法获取 ROM 下载链接"
         return
    fi

    # 显示 ROM 列表供用户选择
    echo "------------------------------------------------"
    echo "可用的 ROM 文件列表："
    local i=1
    local rom_list=()
    local recommended_index=0
    
    for url in $assets; do
        local fname=$(basename "$url")
        # 过滤非 .rom 文件 (如 patch)
        if [[ "$fname" != *.rom ]]; then
            continue
        fi
        
        rom_list+=("$fname|$url")
        
        if [[ "$fname" == "$recommended_rom" ]]; then
            echo -e "  $i) ${GREEN}$fname (推荐)${NC}"
            recommended_index=$i
        else
            echo "  $i) $fname"
        fi
        ((i++))
    done
    echo "------------------------------------------------"
    
    # 让用户选择
    local choice
    if [ $recommended_index -gt 0 ]; then
        read -p "请输入序号选择 ROM [默认 $recommended_index]: " choice
        choice=${choice:-$recommended_index}
    else
        read -p "请输入序号选择 ROM: " choice
    fi
    
    # 验证选择
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge $i ]; then
        log_error "无效选择"
        return
    fi
    
    # 获取选中的 ROM 信息
    local selected_item="${rom_list[$((choice-1))]}"
    local selected_fname="${selected_item%%|*}"
    local selected_url="${selected_item##*|}"
    
    # 下载选中的 ROM
    local fast_url="https://ghfast.top/${selected_url}"
    log_info "正在下载: $selected_fname"
    wget -O "/usr/share/kvm/$selected_fname" "$fast_url"
    
    if [ ! -s "/usr/share/kvm/$selected_fname" ]; then
        log_error "下载失败"
        return
    fi
    log_success "ROM 文件已就绪: $selected_fname"
    local rom_filename="$selected_fname"

    # 4. 自动配置虚拟机
    log_step "配置虚拟机参数"
    
    # 获取 VMID
    echo "请选择要配置直通的虚拟机 ID (VMID):"
    ls /etc/pve/qemu-server/*.conf | awk -F/ '{print $NF}' | sed 's/.conf//' | xargs -n1 echo "  -"
    read -p "请输入 VMID: " vmid
    
    if [ -z "$vmid" ] || [ ! -f "/etc/pve/qemu-server/$vmid.conf" ]; then
        log_error "无效的 VMID 或配置文件不存在"
        return
    fi
    
    # 获取核显 PCI ID
    echo "正在查找 Intel 核显设备..."
    local igpu_pci=$(lspci -D | grep -i "VGA compatible controller" | grep -i "Intel" | head -n1 | awk '{print $1}')
    
    if [ -z "$igpu_pci" ]; then
        log_error "未找到 Intel 核显设备"
        return
    fi
    echo "找到核显设备: $igpu_pci"
    
    # 获取声卡 PCI ID (通常和核显在一起，但也可能分开)
    local audio_pci=$(lspci -D | grep -i "Audio device" | grep -i "Intel" | head -n1 | awk '{print $1}')
    if [ -n "$audio_pci" ]; then
        echo "找到声卡设备: $audio_pci"
    else
        log_warn "未找到配套声卡设备，将只直通核显"
    fi

    if ! confirm_action "即将修改虚拟机 $vmid 的配置，是否继续？"; then
        return
    fi
    
    # 备份配置文件
    backup_file "/etc/pve/qemu-server/$vmid.conf"
    
    # 修改 args
    local args_line="-set device.hostpci0.bus=pcie.0 -set device.hostpci0.addr=0x02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on -set device.hostpci0.x-igd-lpc=on"
    
    # 如果有声卡，添加 hostpci1 的 args 配置
    if [ -n "$audio_pci" ]; then
        args_line="$args_line -set device.hostpci1.bus=pcie.0 -set device.hostpci1.addr=0x03.0"
    fi
    
    # 写入 args (先删除旧的 args)
    sed -i '/^args:/d' "/etc/pve/qemu-server/$vmid.conf"
    echo "args: $args_line" >> "/etc/pve/qemu-server/$vmid.conf"
    
    # 写入 hostpci0 (核显)
    # 先删除旧的 hostpci0
    sed -i '/^hostpci0:/d' "/etc/pve/qemu-server/$vmid.conf"
    # 格式: hostpci0: 0000:00:02.0,romfile=xxx.rom
    # 注意：这里 PCI ID 使用 lspci 获取到的真实 ID，通常是 0000:00:02.0
    echo "hostpci0: $igpu_pci,romfile=$rom_filename" >> "/etc/pve/qemu-server/$vmid.conf"
    
    # 写入 hostpci1 (声卡)
    if [ -n "$audio_pci" ]; then
        sed -i '/^hostpci1:/d' "/etc/pve/qemu-server/$vmid.conf"
        echo "hostpci1: $audio_pci" >> "/etc/pve/qemu-server/$vmid.conf"
    fi
    
    log_success "虚拟机 $vmid 配置完成"
    echo "已添加 args 参数和 hostpci 设备"
    echo "请记得在虚拟机中安装驱动: https://downloadmirror.intel.com/854560/gfx_win_101.6793.exe"
    
    echo
    echo "注意：需要重启宿主机使黑名单生效"
    if confirm_action "是否现在重启系统？"; then
        reboot
    fi
}

# NVIDIA显卡管理菜单
nvidia_t() {
    local key="$1"
    case "$key" in
        MENU_TITLE) echo "NVIDIA 显卡管理" ;;
        MENU_DESC) echo "请选择功能模块（高风险操作会强制二次确认）" ;;
        OPT_PT) echo "显卡直通虚拟机" ;;
        OPT_DRV_INFO) echo "驱动信息与监控" ;;
        OPT_DRV_SWITCH) echo "驱动切换（开源/闭源）" ;;
        OPT_HOST_PREP) echo "宿主机预配置（IOMMU/VFIO/黑名单）" ;;
        OPT_UNLOCK) echo "部署 vGPU Unlock（外部库）" ;;
        OPT_BACK) echo "返回" ;;
        ERR_NO_GPU) echo "未检测到 NVIDIA GPU" ;;
        ERR_IOMMU) echo "未检测到 IOMMU 已开启" ;;
        TIP_ENABLE_IOMMU) echo "请先开启 BIOS 的 VT-d/AMD-Vi，并在脚本中启用 IOMMU（硬件直通一键配置）。" ;;
        INPUT_CHOICE) echo "请选择操作" ;;
        INPUT_PICK) echo "请选择序号" ;;
        WARN_HIGH_RISK) echo "高风险操作：不同驱动性能侧重点不同，误操作可能导致宿主机不可用。" ;;
        OK_DONE) echo "操作完成" ;;
        *) echo "$key" ;;
    esac
}

nvidia_get_cols() {
    tput cols 2>/dev/null || echo 80
}

nvidia_trunc() {
    local s="$1"
    local w="$2"
    if [[ -z "$w" || "$w" -le 0 ]]; then
        echo "$s"
        return 0
    fi
    if [[ "${#s}" -le "$w" ]]; then
        echo "$s"
        return 0
    fi
    echo "${s:0:$((w-3))}..."
}

nvidia_list_vms() {
    qm list 2>/dev/null | awk 'NR>1{print $1 "|" $2 "|" $3}'
}

nvidia_list_nvidia_gpus() {
    lspci -Dnn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller' | grep -i 'NVIDIA' | awk '{bdf=$1; sub(/^[0-9a-f]{4}:/,"",bdf); print $1 "|" $0}'
}

nvidia_get_pci_ids() {
    local bdf="$1"
    lspci -n -s "$bdf" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$/){print tolower($i); exit}}'
}

nvidia_pci_has_function() {
    local bdf="$1"
    local func="$2"
    local base
    base="${bdf%.*}"
    lspci -Dnn 2>/dev/null | awk '{print $1}' | grep -qx "${base}.${func}"
}

nvidia_pci_kernel_driver() {
    local bdf="$1"
    lspci -nnk -s "$bdf" 2>/dev/null | awk -F': ' '/Kernel driver in use:/{print $2; exit}'
}

nvidia_select_vmid() {
    local vms
    vms="$(nvidia_list_vms)"
    if [[ -z "$vms" ]]; then
        log_error "未发现虚拟机"
        log_tips "请先创建虚拟机后再操作。"
        return 1
    fi

    {
        echo -e "${CYAN}可用虚拟机列表：${NC}"
        echo "$vms" | awk -F'|' '{printf "  [%d] VMID: %-6s Name: %-22s Status: %s\n", NR, $1, $2, $3}'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "$(nvidia_t INPUT_PICK) (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line vmid
    line="$(echo "$vms" | awk -v n="$pick" -F'|' 'NR==n{print $0}')"
    vmid="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$vmid" ]]; then
        log_error "无效选择"
        return 1
    fi
    if ! validate_qm_vmid "$vmid"; then
        return 1
    fi
    echo "$vmid"
    return 0
}

nvidia_select_gpu_bdf() {
    local gpus
    gpus="$(nvidia_list_nvidia_gpus)"
    if [[ -z "$gpus" ]]; then
        log_error "$(nvidia_t ERR_NO_GPU)"
        log_tips "请先确认已安装 NVIDIA GPU 并执行 lspci 可见。"
        return 1
    fi

    local cols
    cols="$(nvidia_get_cols)"
    local max_line=$((cols-6))
    if [[ "$max_line" -lt 40 ]]; then
        max_line=40
    fi

    {
        echo -e "${CYAN}可用 NVIDIA GPU 列表：${NC}"
        echo "$gpus" | awk -F'|' -v w="$max_line" '{
            line=$2;
            if (length(line)>w) line=substr(line,1,w-3)"...";
            printf "  [%d] %s\n", NR, line
        }'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "$(nvidia_t INPUT_PICK) (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$gpus" | awk -v n="$pick" -F'|' 'NR==n{print $0}')"
    bdf="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$bdf" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$bdf"
    return 0
}

nvidia_show_passthrough_status() {
    local bdf="$1"
    local drv
    drv="$(nvidia_pci_kernel_driver "$bdf")"
    echo -e "${CYAN}设备: ${NC}$bdf"
    echo -e "${CYAN}Kernel driver in use: ${NC}${drv:-unknown}"
    lspci -nnk -s "$bdf" 2>/dev/null | sed 's/^/  /'
}

nvidia_try_write_vfio_ids_conf() {
    local ids_csv="$1"
    local file="/etc/modprobe.d/pve-tools-nvidia-vfio.conf"

    local other
    other="$(grep -RhsE '^\s*options\s+vfio-pci\s+ids=' /etc/modprobe.d 2>/dev/null | grep -vF "pve-tools-nvidia-vfio.conf" || true)"
    if [[ -n "$other" ]]; then
        display_error "检测到系统已存在 vfio-pci ids 配置" "为避免冲突，本功能不会自动写入。请手工合并 vfio-pci ids 后再 update-initramfs -u。"
        return 1
    fi

    if ! confirm_action "写入 VFIO 绑定配置（$file）并要求重启宿主机？"; then
        return 0
    fi

    local content
    content="options vfio-pci ids=${ids_csv}"
    apply_block "$file" "NVIDIA_VFIO_IDS" "$content"
    display_success "VFIO 绑定配置已写入" "请执行 update-initramfs -u 并重启宿主机后再进行直通。"
    return 0
}

nvidia_gpu_passthrough_vm() {
    log_step "$(nvidia_t OPT_PT)"

    if ! iommu_is_enabled; then
        display_error "$(nvidia_t ERR_IOMMU)" "$(nvidia_t TIP_ENABLE_IOMMU)"
        return 1
    fi

    local vmid
    vmid="$(nvidia_select_vmid)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local gpu_bdf
    gpu_bdf="$(nvidia_select_gpu_bdf)"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$gpu_bdf" ]]; then
        return 1
    fi

    clear
    show_menu_header "$(nvidia_t OPT_PT)"
    echo -e "${YELLOW}VMID: ${NC}$vmid"
    echo -e "${YELLOW}GPU: ${NC}$gpu_bdf"
    echo -e "${UI_DIVIDER}"
    nvidia_show_passthrough_status "$gpu_bdf"

    local audio_bdf=""
    if nvidia_pci_has_function "$gpu_bdf" "1"; then
        audio_bdf="${gpu_bdf%.*}.1"
        echo -e "${UI_DIVIDER}"
        nvidia_show_passthrough_status "$audio_bdf"
    fi

    local gpu_id audio_id ids_csv
    gpu_id="$(nvidia_get_pci_ids "$gpu_bdf")"
    audio_id=""
    if [[ -n "$audio_bdf" ]]; then
        audio_id="$(nvidia_get_pci_ids "$audio_bdf")"
    fi
    ids_csv="$gpu_id"
    if [[ -n "$audio_id" ]]; then
        ids_csv="${ids_csv},${audio_id}"
    fi

    echo -e "${UI_DIVIDER}"
    if [[ -n "$ids_csv" ]]; then
        echo -e "${CYAN}VFIO ids 建议: ${NC}$ids_csv"
    fi
    echo -e "${YELLOW}提示：如果宿主机正在加载 nvidia/nouveau 驱动，直通可能失败。${NC}"
    echo -e "${UI_DIVIDER}"

    local include_audio="yes"
    if [[ -n "$audio_bdf" ]]; then
        read -p "是否同时直通显卡音频功能（${audio_bdf}）？(yes/no) [yes]: " include_audio
        include_audio="${include_audio:-yes}"
    else
        include_audio="no"
    fi

    if qm_has_hostpci_bdf "$vmid" "$gpu_bdf"; then
        display_error "该 GPU 已存在于 VM 的 hostpci 配置中" "无需重复添加。"
        return 1
    fi

    local idx0
    idx0="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15。"
        return 1
    }

    local hostpci0_value="${gpu_bdf}"
    if qm_is_q35_machine "$vmid"; then
        hostpci0_value="${hostpci0_value},pcie=1,x-vga=1"
    else
        hostpci0_value="${hostpci0_value},x-vga=1"
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 添加 GPU 直通（hostpci${idx0} = ${hostpci0_value}）"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx0}" "$hostpci0_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 VM 是否锁定，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$include_audio" == "yes" && -n "$audio_bdf" ]]; then
        local idx1
        idx1="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
            display_error "显卡已添加，但未找到可用 hostpci 插槽添加音频功能" "请手工添加 $audio_bdf。"
            return 1
        }

        local hostpci1_value="${audio_bdf}"
        if qm_is_q35_machine "$vmid"; then
            hostpci1_value="${hostpci1_value},pcie=1"
        fi

        if ! qm set "$vmid" "-hostpci${idx1}" "$hostpci1_value" >/dev/null 2>&1; then
            log_warn "音频功能直通写入失败（GPU 已写入）"
        else
            log_success "音频功能已写入: hostpci${idx1} = $hostpci1_value"
        fi
    fi

    local ignore_msrs="no"
    read -p "是否写入 KVM ignore_msrs（Windows/NVIDIA 常见告警缓解）（yes/no）[no]: " ignore_msrs
    ignore_msrs="${ignore_msrs:-no}"
    if [[ "$ignore_msrs" == "yes" || "$ignore_msrs" == "YES" ]]; then
        if confirm_action "写入 /etc/modprobe.d/kvm.conf 的 ignore_msrs 配置并要求重启？"; then
            local kvm_content
            kvm_content="options kvm ignore_msrs=1 report_ignored_msrs=0"
            apply_block "/etc/modprobe.d/kvm.conf" "NVIDIA_IGNORE_MSRS" "$kvm_content"
            log_success "已写入 KVM ignore_msrs 配置"
        fi
    fi

    if [[ -n "$ids_csv" ]]; then
        local set_vfio="no"
        read -p "是否写入 VFIO ids 绑定配置（用于将设备绑定到 vfio-pci）（yes/no）[no]: " set_vfio
        set_vfio="${set_vfio:-no}"
        if [[ "$set_vfio" == "yes" || "$set_vfio" == "YES" ]]; then
            nvidia_try_write_vfio_ids_conf "$ids_csv" || true
        fi
    fi

    display_success "$(nvidia_t OK_DONE)" "如 VM 正在运行中，请重启 VM；如写入了 VFIO/kvm 配置，请按提示重启宿主机。"
    return 0
}

nvidia_driver_info() {
    clear
    show_menu_header "$(nvidia_t OPT_DRV_INFO)"

    local open_loaded="no"
    local prop_loaded="no"
    if lsmod 2>/dev/null | grep -q '^nouveau'; then
        open_loaded="yes"
    fi
    if lsmod 2>/dev/null | grep -q '^nvidia'; then
        prop_loaded="yes"
    fi

    echo -e "${CYAN}驱动状态：${NC}"
    echo "  nouveau 已加载: $open_loaded"
    echo "  nvidia 已加载:  $prop_loaded"
    echo -e "${UI_DIVIDER}"

    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "${CYAN}nvidia-smi：${NC}"
        nvidia-smi 2>/dev/null | sed 's/^/  /' || true
        echo -e "${UI_DIVIDER}"
        echo -e "${CYAN}GPU 指标（CSV）：${NC}"
        nvidia-smi --query-gpu=index,name,driver_version,temperature.gpu,utilization.gpu,power.draw,power.limit,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | sed 's/^/  /' || true
    else
        display_error "未找到 nvidia-smi" "如需查看驱动信息，请先安装 NVIDIA 驱动或确认 PATH。"
    fi
}

nvidia_driver_export_report() {
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local out="/var/log/pve-tools-nvidia-report-${ts}.txt"
    {
        echo "time: $(date)"
        echo "pveversion: $(pveversion 2>/dev/null || true)"
        echo "kernel: $(uname -r)"
        echo
        echo "lspci (nvidia):"
        lspci -Dnn 2>/dev/null | grep -i nvidia || true
        echo
        echo "lsmod (nvidia/nouveau):"
        lsmod 2>/dev/null | grep -E '^(nvidia|nouveau)\b' || true
        echo
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "nvidia-smi:"
            nvidia-smi 2>/dev/null || true
            echo
            echo "nvidia-smi -q (head):"
            nvidia-smi -q 2>/dev/null | head -n 200 || true
        fi
    } > "$out" 2>/dev/null || {
        display_error "导出失败" "请检查 /var/log 写入权限与磁盘空间。"
        return 1
    }
    log_success "已导出: $out"
    return 0
}

nvidia_driver_info_menu() {
    while true; do
        clear
        show_menu_header "$(nvidia_t OPT_DRV_INFO)"
        show_menu_option "1" "查看驱动与监控面板"
        show_menu_option "2" "导出驱动诊断报告"
        show_menu_option "0" "$(nvidia_t OPT_BACK)"
        show_menu_footer
        read -p "$(nvidia_t INPUT_CHOICE) [0-2]: " choice
        case "$choice" in
            1) nvidia_driver_info ;;
            2) nvidia_driver_export_report ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

nvidia_apt_has_pkg() {
    local pkg="$1"
    apt-cache show "$pkg" >/dev/null 2>&1
}

nvidia_driver_switch_to_proprietary() {
    echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
    if ! confirm_action "安装并启用官方 NVIDIA 驱动（闭源）？"; then
        return 0
    fi

    log_step "更新软件包列表..."
    apt-get update -y >/dev/null 2>&1 || true

    if nvidia_apt_has_pkg "nvidia-driver"; then
        log_step "安装 nvidia-driver..."
        apt-get install -y nvidia-driver
    else
        display_error "未找到可用的 nvidia-driver 软件包" "请检查软件源，或使用 NVIDIA 官方安装方式。"
        return 1
    fi

    if confirm_action "安装完成，是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}

nvidia_driver_switch_to_open() {
    echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
    if ! confirm_action "卸载 NVIDIA 驱动并切回开源驱动（nouveau）？"; then
        return 0
    fi

    log_step "卸载 NVIDIA 驱动..."
    apt-get purge -y 'nvidia-*' || true
    apt-get autoremove -y || true

    if confirm_action "是否更新 initramfs（推荐）？"; then
        update-initramfs -u || true
    fi

    if confirm_action "操作完成，是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}

nvidia_restore_latest_backup_file() {
    local target="$1"
    local backup_dir="/var/backups/pve-tools"
    local base
    base="$(basename "$target")"

    if [[ ! -d "$backup_dir" ]]; then
        return 1
    fi

    local latest
    latest="$(ls -1t "${backup_dir}/${base}."*.bak 2>/dev/null | head -n 1)"
    if [[ -z "$latest" ]]; then
        return 1
    fi

    backup_file "$target" >/dev/null 2>&1 || true
    if cp -a "$latest" "$target" >/dev/null 2>&1; then
        log_success "已回滚: $target"
        log_info "使用备份: $latest"
        return 0
    fi
    return 1
}

nvidia_driver_rollback() {
    echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
    if ! confirm_action "回滚最近一次驱动相关配置备份？"; then
        return 0
    fi

    local files=(
        "/etc/modprobe.d/pve-blacklist.conf"
        "/etc/modprobe.d/kvm.conf"
        "/etc/modprobe.d/pve-tools-nvidia-vfio.conf"
        "/etc/modprobe.d/vfio.conf"
        "/etc/default/grub"
        "/etc/nvidia/gridd.conf"
    )

    local ok=0
    local f
    for f in "${files[@]}"; do
        if nvidia_restore_latest_backup_file "$f"; then
            ok=$((ok+1))
        fi
    done

    if [[ "$ok" -le 0 ]]; then
        display_error "未找到可用备份" "请确认之前确实产生过备份（/var/backups/pve-tools），或手工回滚配置。"
        return 1
    fi

    display_success "回滚完成" "建议执行 update-initramfs -u，并按需重启宿主机。"
    return 0
}

nvidia_driver_switch_menu() {
    while true; do
        clear
        show_menu_header "$(nvidia_t OPT_DRV_SWITCH)"
        echo -e "${YELLOW}$(nvidia_t WARN_HIGH_RISK)${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "切换到闭源驱动（官方 NVIDIA）"
        show_menu_option "2" "切换到开源驱动（nouveau）"
        show_menu_option "3" "回滚最近一次备份"
        show_menu_option "0" "$(nvidia_t OPT_BACK)"
        show_menu_footer
        read -p "$(nvidia_t INPUT_CHOICE) [0-3]: " choice
        case "$choice" in
            1) nvidia_driver_switch_to_proprietary ;;
            2) nvidia_driver_switch_to_open ;;
            3) nvidia_driver_rollback ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

nvidia_host_prepare_for_passthrough() {
    echo -e "${YELLOW}将执行以下操作：${NC}"
    echo "  1) 写入 GRUB IOMMU 参数"
    echo "  2) 写入 /etc/modules 的 VFIO 模块配置块"
    echo "  3) 写入 /etc/modprobe.d/pve-blacklist.conf 的 NVIDIA 黑名单配置块"
    echo "  4) 执行 update-grub 与 update-initramfs"
    echo

    if ! confirm_action "确认执行宿主机预配置？"; then
        return 0
    fi

    local cpu_vendor
    cpu_vendor="$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')"

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        grub_add_param "intel_iommu=on"
    elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
        grub_add_param "amd_iommu=on"
    else
        log_warn "未识别 CPU 厂商，跳过厂商特定 IOMMU 参数"
    fi
    grub_add_param "iommu=pt"
    grub_add_param "pcie_acs_override=downstream,multifunction"

    local modules_content
    modules_content=$(cat <<'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
)
    apply_block "/etc/modules" "NVIDIA_VFIO_MODULES" "$modules_content"

    local blacklist_content
    blacklist_content=$(cat <<'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF
)
    apply_block "/etc/modprobe.d/pve-blacklist.conf" "NVIDIA_BLACKLIST" "$blacklist_content"

    if command -v update-grub >/dev/null 2>&1; then
        update-grub || log_warn "update-grub 执行失败，请手工检查"
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || log_warn "grub-mkconfig 执行失败，请手工检查"
    else
        log_warn "未找到 update-grub/grub-mkconfig，请手工更新 GRUB"
    fi

    update-initramfs -u -k all || log_warn "update-initramfs 执行失败，请手工检查"
    display_success "宿主机预配置已完成" "建议重启宿主机后再执行直通或 vGPU 操作。"

    if confirm_action "是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}

nvidia_setup_vgpu_unlock() {
    clear
    show_menu_header "vGPU Unlock 高风险提示"
    echo -e "${RED}  请先阅读文档后再操作。${NC}"
    echo "  本功能会修改 NVIDIA vGPU 服务启动参数并加载外部 .so 文件。"
    echo "  驱动/内核/补丁版本不匹配可能导致服务异常、宿主机告警或 VM 无法使用 vGPU。"
    echo
    echo -e "${CYAN}推荐先阅读 Wiki：${NC}"
    echo "  对应文章: https://pve.oowo.cc/advanced/nvidia-vgpu-driver-notes"
    echo "${UI_DIVIDER}"
    read -p "请输入 '确认' 或 'Sure' 继续: " response
    response=$(echo "$response" | xargs)
    if [[ "$response" != "确认" && "$response" != "Sure" && "${response,,}" != "sure" ]]; then
        echo "取消"
        return 0
    fi

    local default_url="$NVIDIA_VGPU_UNLOCK_SO_URL"
    local so_url
    read -p "请输入 libvgpu_unlock_rs.so 下载地址 [$default_url]: " so_url
    so_url="${so_url:-$default_url}"

    if [[ -z "$so_url" ]]; then
        display_error "下载地址不能为空"
        return 1
    fi

    echo -e "${YELLOW}将创建并写入：${NC}"
    echo "  /etc/vgpu_unlock/profile_override.toml"
    echo "  /etc/systemd/system/nvidia-vgpud.service.d/vgpu_unlock.conf"
    echo "  /etc/systemd/system/nvidia-vgpu-mgr.service.d/vgpu_unlock.conf"
    echo "  /opt/vgpu_unlock-rs/target/release/libvgpu_unlock_rs.so"
    echo

    if ! confirm_action "确认部署 vGPU Unlock（外部库）？"; then
        return 0
    fi

    mkdir -p /etc/vgpu_unlock
    touch /etc/vgpu_unlock/profile_override.toml
    mkdir -p /etc/systemd/system/nvidia-vgpud.service.d
    mkdir -p /etc/systemd/system/nvidia-vgpu-mgr.service.d
    mkdir -p /opt/vgpu_unlock-rs/target/release

    local unlock_conf
    unlock_conf=$(cat <<'EOF'
[Service]
Environment=LD_PRELOAD=/opt/vgpu_unlock-rs/target/release/libvgpu_unlock_rs.so
EOF
)
    apply_block "/etc/systemd/system/nvidia-vgpud.service.d/vgpu_unlock.conf" "NVIDIA_VGPU_UNLOCK" "$unlock_conf"
    apply_block "/etc/systemd/system/nvidia-vgpu-mgr.service.d/vgpu_unlock.conf" "NVIDIA_VGPU_UNLOCK" "$unlock_conf"

    local so_out="/opt/vgpu_unlock-rs/target/release/libvgpu_unlock_rs.so"
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL --connect-timeout 15 --max-time 300 -o "$so_out" "$so_url"; then
            display_error "下载失败" "请检查 URL 与网络连接。"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "$so_out" "$so_url"; then
            display_error "下载失败" "请检查 URL 与网络连接。"
            return 1
        fi
    else
        display_error "未检测到 curl 或 wget" "无法下载外部库文件。"
        return 1
    fi

    if [[ ! -s "$so_out" ]]; then
        display_error "下载结果为空" "请检查 URL 是否可访问。"
        return 1
    fi

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart nvidia-vgpud.service >/dev/null 2>&1 || true
    systemctl restart nvidia-vgpu-mgr.service >/dev/null 2>&1 || true
    display_success "vGPU Unlock 已部署" "可执行 systemctl status nvidia-vgpud nvidia-vgpu-mgr 验证状态。"
    return 0
}

nvidia_gpu_management_menu() {
    while true; do
        clear
        show_menu_header "$(nvidia_t MENU_TITLE)"
        echo -e "${CYAN}$(nvidia_t MENU_DESC)${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "$(nvidia_t OPT_PT)"
        show_menu_option "2" "$(nvidia_t OPT_DRV_INFO)"
        show_menu_option "3" "$(nvidia_t OPT_DRV_SWITCH)"
        show_menu_option "4" "$(nvidia_t OPT_HOST_PREP)"
        show_menu_option "5" "$(nvidia_t OPT_UNLOCK)"
        show_menu_option "0" "$(nvidia_t OPT_BACK)"
        show_menu_footer
        read -p "$(nvidia_t INPUT_CHOICE) [0-5]: " choice
        case "$choice" in
            1) nvidia_gpu_passthrough_vm ;;
            2) nvidia_driver_info_menu ;;
            3) nvidia_driver_switch_menu ;;
            4) nvidia_host_prepare_for_passthrough ;;
            5) nvidia_setup_vgpu_unlock ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

amd_list_gpus() {
    lspci -Dnn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' | grep -iE 'AMD|ATI' | awk '{print $1 "|" $0}'
}

amd_select_gpu_bdf() {
    local title="${1:-可用 AMD GPU 列表：}"
    local prompt_label="${2:-请选择 AMD GPU 序号}"
    local gpus
    gpus="$(amd_list_gpus)"
    if [[ -z "$gpus" ]]; then
        log_error "未检测到 AMD GPU"
        log_tips "请先确认 AMD 显卡已安装，并执行 lspci -Dnn 可见。"
        return 1
    fi

    local cols max_line
    cols="$(nvidia_get_cols)"
    max_line=$((cols-6))
    if [[ "$max_line" -lt 40 ]]; then
        max_line=40
    fi

    {
        echo -e "${CYAN}${title}${NC}"
        echo "$gpus" | awk -F'|' -v w="$max_line" '{
            line=$2;
            if (length(line)>w) line=substr(line,1,w-3)"...";
            printf "  [%d] %s\n", NR, line
        }'
        echo -e "${UI_DIVIDER}"
    } >&2

    local pick
    read -p "${prompt_label} (0 返回): " pick
    pick="${pick:-0}"
    if [[ "$pick" == "0" ]]; then
        return 2
    fi
    if [[ ! "$pick" =~ ^[0-9]+$ ]]; then
        log_error "序号必须是数字"
        return 1
    fi

    local line bdf
    line="$(echo "$gpus" | awk -v n="$pick" -F'|' 'NR==n{print $0}')"
    bdf="$(echo "$line" | awk -F'|' '{print $1}')"
    if [[ -z "$bdf" ]]; then
        log_error "无效选择"
        return 1
    fi
    echo "$bdf"
    return 0
}

amd_try_write_vfio_ids_conf() {
    local ids_csv="$1"
    local file="/etc/modprobe.d/pve-tools-amd-vfio.conf"

    local other
    other="$(grep -RhsE '^\s*options\s+vfio-pci\s+ids=' /etc/modprobe.d 2>/dev/null | grep -vF 'pve-tools-amd-vfio.conf' || true)"
    if [[ -n "$other" ]]; then
        display_error "检测到系统已存在 vfio-pci ids 配置" "为避免冲突，本功能不会自动写入。请手工合并 vfio-pci ids 后再 update-initramfs -u。"
        return 1
    fi

    if ! confirm_action "写入 AMD 的 VFIO 绑定配置（$file）并要求重启宿主机？"; then
        return 0
    fi

    local content
    content="options vfio-pci ids=${ids_csv}"
    apply_block "$file" "AMD_VFIO_IDS" "$content"
    display_success "AMD 的 VFIO 绑定配置已写入" "请执行 update-initramfs -u 并重启宿主机后再进行直通。"
    return 0
}

amd_host_prepare_for_passthrough() {
    echo -e "${YELLOW}将执行以下操作：${NC}"
    echo "  1) 写入 GRUB IOMMU 参数"
    echo "  2) 写入 /etc/modules 的 VFIO 模块配置块"
    echo "  3) 写入 AMD 显卡黑名单配置 (amdgpu / radeon)"
    echo "  4) 执行 update-grub 与 update-initramfs"
    echo
    echo -e "${RED}重要提醒：如果宿主机当前依赖 AMD 核显或 AMD 独显输出，本地控制台画面可能在重启后消失。${NC}"
    echo -e "${YELLOW}如遇 Windows Code 43 或黑屏，请优先检查 BIOS 中的 Resizable BAR / Smart Access Memory 是否已关闭。${NC}"
    if lsmod 2>/dev/null | grep -Eq '^(amdgpu|radeon)\b'; then
        echo -e "${YELLOW}检测到 amdgpu / radeon 当前已加载，说明宿主机很可能正在占用 AMD 显卡。${NC}"
    fi
    echo

    if ! confirm_high_risk_action "为 AMD GPU 直通写入宿主机预配置" "会修改 GRUB、VFIO 模块和 AMD 显卡黑名单配置。" "错误配置可能导致宿主机本地输出消失、GPU 无法用于宿主机图形界面，甚至在重启后需要控制台修复。" "请确认已准备带外管理或物理控制台，并已理解回滚方式。" "AMD-HOST"; then
        return 0
    fi

    local cpu_vendor
    cpu_vendor="$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')"

    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        grub_add_param "intel_iommu=on"
    elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
        grub_add_param "amd_iommu=on"
    else
        log_warn "未识别 CPU 厂商，跳过厂商特定 IOMMU 参数"
    fi
    grub_add_param "iommu=pt"
    grub_add_param "pcie_acs_override=downstream,multifunction"

    local modules_content
    modules_content=$(cat <<'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
)
    apply_block "/etc/modules" "AMD_VFIO_MODULES" "$modules_content"

    local blacklist_content
    blacklist_content=$(cat <<'EOF'
blacklist amdgpu
blacklist radeon
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF
)
    apply_block "/etc/modprobe.d/pve-tools-amd-blacklist.conf" "AMD_GPU_BLACKLIST" "$blacklist_content"

    if command -v update-grub >/dev/null 2>&1; then
        update-grub || log_warn "update-grub 执行失败，请手工检查"
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || log_warn "grub-mkconfig 执行失败，请手工检查"
    else
        log_warn "未找到 update-grub/grub-mkconfig，请手工更新 GRUB"
    fi

    update-initramfs -u -k all || log_warn "update-initramfs 执行失败，请手工检查"
    display_success "AMD 宿主机预配置已完成" "建议重启宿主机后再执行 AMD 显卡或核显直通。"

    if confirm_action "是否现在重启宿主机？"; then
        reboot
    fi
    return 0
}

amd_gpu_passthrough_vm() {
    log_step "AMD 独显直通虚拟机"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local vmid
    vmid="$(nvidia_select_vmid)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local gpu_bdf
    gpu_bdf="$(amd_select_gpu_bdf '可用 AMD 独显 / GPU 列表：' '请选择 AMD 独显序号')"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$gpu_bdf" ]]; then
        return 1
    fi

    clear
    show_menu_header "AMD 独显直通虚拟机"
    echo -e "${YELLOW}VMID: ${NC}$vmid"
    echo -e "${YELLOW}GPU: ${NC}$gpu_bdf"
    echo -e "${UI_DIVIDER}"
    nvidia_show_passthrough_status "$gpu_bdf"

    local audio_bdf=""
    if nvidia_pci_has_function "$gpu_bdf" "1"; then
        audio_bdf="${gpu_bdf%.*}.1"
        echo -e "${UI_DIVIDER}"
        nvidia_show_passthrough_status "$audio_bdf"
    fi

    local gpu_id audio_id ids_csv
    gpu_id="$(nvidia_get_pci_ids "$gpu_bdf")"
    audio_id=""
    if [[ -n "$audio_bdf" ]]; then
        audio_id="$(nvidia_get_pci_ids "$audio_bdf")"
    fi
    ids_csv="$gpu_id"
    if [[ -n "$audio_id" ]]; then
        ids_csv="${ids_csv},${audio_id}"
    fi

    echo -e "${UI_DIVIDER}"
    if [[ -n "$ids_csv" ]]; then
        echo -e "${CYAN}VFIO ids 建议: ${NC}$ids_csv"
    fi
    echo -e "${YELLOW}提示：若宿主机仍在使用 amdgpu / radeon，直通可能失败。${NC}"
    echo -e "${YELLOW}如 Windows 来宾报 Code 43，请优先检查 BIOS 的 Resizable BAR / Smart Access Memory。${NC}"
    echo -e "${UI_DIVIDER}"

    local include_audio="no"
    if [[ -n "$audio_bdf" ]]; then
        read -p "是否同时直通显卡音频功能（${audio_bdf}）？(yes/no) [yes]: " include_audio
        include_audio="${include_audio:-yes}"
    fi

    local enable_x_vga="yes"
    read -p "是否为 AMD 显卡启用 x-vga=1（Windows 常见）？(yes/no) [yes]: " enable_x_vga
    enable_x_vga="${enable_x_vga:-yes}"

    if qm_has_hostpci_bdf "$vmid" "$gpu_bdf"; then
        display_error "该 AMD GPU 已存在于 VM 的 hostpci 配置中" "无需重复添加。"
        return 1
    fi

    local idx0
    idx0="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15。"
        return 1
    }

    local hostpci0_value="$gpu_bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci0_value="${hostpci0_value},pcie=1"
    fi
    if [[ "$enable_x_vga" == "yes" || "$enable_x_vga" == "YES" ]]; then
        hostpci0_value="${hostpci0_value},x-vga=1"
    fi

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_action "为 VM $vmid 添加 AMD 独显直通（hostpci${idx0} = ${hostpci0_value}）"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx0}" "$hostpci0_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 VM 是否锁定、IOMMU / IOMMU group，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$include_audio" == "yes" || "$include_audio" == "YES" ]] && [[ -n "$audio_bdf" ]]; then
        local idx1
        idx1="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
            display_error "显卡已添加，但未找到可用 hostpci 插槽添加音频功能" "请手工添加 $audio_bdf。"
            return 1
        }

        local hostpci1_value="$audio_bdf"
        if qm_is_q35_machine "$vmid"; then
            hostpci1_value="${hostpci1_value},pcie=1"
        fi

        if ! qm set "$vmid" "-hostpci${idx1}" "$hostpci1_value" >/dev/null 2>&1; then
            log_warn "音频功能直通写入失败（GPU 已写入）"
        else
            log_success "音频功能已写入: hostpci${idx1} = $hostpci1_value"
        fi
    fi

    if [[ -n "$ids_csv" ]]; then
        local set_vfio="no"
        read -p "是否写入 AMD 的 VFIO ids 绑定配置（用于将设备绑定到 vfio-pci）（yes/no）[no]: " set_vfio
        set_vfio="${set_vfio:-no}"
        if [[ "$set_vfio" == "yes" || "$set_vfio" == "YES" ]]; then
            amd_try_write_vfio_ids_conf "$ids_csv" || true
        fi
    fi

    display_success "AMD 独显直通已写入" "如 VM 正在运行中，请重启 VM；如写入了 VFIO 配置，请按提示重启宿主机。"
    return 0
}

amd_list_romfiles() {
    if [[ ! -d "$PVE_KVM_ROM_DIR" ]]; then
        return 0
    fi
    find "$PVE_KVM_ROM_DIR" -maxdepth 1 -type f \( -iname '*.rom' -o -iname '*.bin' \) 2>/dev/null | sort
}

amd_normalize_romfile_input() {
    local input="$1"
    local rom_path base

    if [[ -z "$input" ]]; then
        return 1
    fi

    if [[ "$input" == /* ]]; then
        rom_path="$input"
    else
        rom_path="${PVE_KVM_ROM_DIR}/${input}"
    fi

    case "$rom_path" in
        "${PVE_KVM_ROM_DIR}/"*) ;;
        *)
            log_error "ROM 文件路径必须位于 ${PVE_KVM_ROM_DIR}"
            echo -e "${YELLOW}提示: 请先把用户自备的 AMD ROM / vBIOS 文件放入 ${PVE_KVM_ROM_DIR} 后再试。${NC}" >&2
            return 1
            ;;
    esac

    if [[ ! -f "$rom_path" ]]; then
        log_error "未找到 ROM 文件: $rom_path"
        echo -e "${YELLOW}提示: 请确认文件已放入 ${PVE_KVM_ROM_DIR}，并由用户自行提取、确认来源与兼容性。${NC}" >&2
        return 1
    fi

    base="$(basename "$rom_path")"
    if [[ ! "$base" =~ ^[A-Za-z0-9._+-]+$ ]]; then
        log_error "ROM 文件名包含不安全字符: $base"
        echo -e "${YELLOW}提示: 请将文件重命名为简单英文/数字文件名后再试。${NC}" >&2
        return 1
    fi

    echo "$base"
    return 0
}

amd_prompt_romfile_basename() {
    local prompt="${1:-请输入 AMD ROM / vBIOS 文件路径或文件名}"
    local roms
    roms="$(amd_list_romfiles)"

    {
        echo -e "${CYAN}ROM 文件目录: ${NC}${PVE_KVM_ROM_DIR}"
        if [[ -n "$roms" ]]; then
            echo "$roms" | sed 's/^/  /'
        else
            echo "  (当前未发现 .rom / .bin 文件)"
        fi
        echo -e "${YELLOW}ROM / vBIOS 提取通常需要由用户自行完成，本脚本只负责校验并写入 romfile。${NC}"
        echo -e "${UI_DIVIDER}"
    } >&2

    local input
    read -p "${prompt} (0 返回): " input
    input="${input:-0}"
    if [[ "$input" == "0" ]]; then
        return 2
    fi

    amd_normalize_romfile_input "$input"
}

amd_igpu_show_guidance() {
    clear
    show_menu_header "AMD 核显直通说明"
    echo -e "${CYAN}使用建议：${NC}"
    echo "  1) AMD 核显直通通常比独显更依赖正确的 ROM / vBIOS 文件。"
    echo "  2) 建议 VM 使用 q35 + OVMF，并将核显作为主显示设备。"
    echo "  3) ROM / vBIOS 提取一般交给用户自行完成，脚本不提供自动提取。"
    echo "  4) 将 ROM 文件放入 ${PVE_KVM_ROM_DIR} 后，再通过本向导写入 romfile。"
    echo "  5) 如 Windows 来宾报 Code 43 / 黑屏，请优先检查 BIOS 中的 Resizable BAR / SAM。"
    echo
    echo -e "${CYAN}参考：${NC}"
    echo "  社区参考文章: https://diyforfun.cn/712.html"
    echo "  Proxmox 官方: https://pve.proxmox.com/wiki/PCI_Passthrough"
    echo
    echo -e "${RED}免责声明：ROM / vBIOS 文件的提取、来源合法性、兼容性与由此导致的黑屏、Code 43、设备不可用等后果，由用户自行承担。${NC}"
    echo "$UI_DIVIDER"
}

amd_igpu_check_romfile() {
    clear
    show_menu_header "AMD 核显 ROM / vBIOS 检查"
    local rom_base
    rom_base="$(amd_prompt_romfile_basename '请输入要校验的 AMD ROM / vBIOS 文件路径或文件名')"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$rom_base" ]]; then
        return 1
    fi
    display_success "ROM 文件校验通过" "可在 hostpci 中使用 romfile=${rom_base}。"
    return 0
}

amd_igpu_passthrough_vm() {
    log_step "AMD 核显直通配置"

    if ! iommu_is_enabled; then
        display_error "未检测到 IOMMU 已开启" "请先在 BIOS 开启 VT-d/AMD-Vi，并在 PVE 中启用 IOMMU（可在“硬件直通一键配置(IOMMU)”里开启）。"
        return 1
    fi

    local vmid
    vmid="$(nvidia_select_vmid)"
    local rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$vmid" ]]; then
        return 1
    fi

    local gpu_bdf
    gpu_bdf="$(amd_select_gpu_bdf '可用 AMD GPU / 核显列表（请手工确认 APU 核显设备）:' '请选择 AMD 核显序号')"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$gpu_bdf" ]]; then
        return 1
    fi

    local rom_base
    rom_base="$(amd_prompt_romfile_basename '请输入 AMD 核显 ROM / vBIOS 文件路径或文件名')"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        return 0
    fi
    if [[ -z "$rom_base" ]]; then
        return 1
    fi

    clear
    show_menu_header "AMD 核显直通配置"
    echo -e "${YELLOW}VMID: ${NC}$vmid"
    echo -e "${YELLOW}iGPU: ${NC}$gpu_bdf"
    echo -e "${YELLOW}ROM: ${NC}${PVE_KVM_ROM_DIR}/${rom_base}"
    echo -e "${UI_DIVIDER}"
    nvidia_show_passthrough_status "$gpu_bdf"

    local audio_bdf=""
    if nvidia_pci_has_function "$gpu_bdf" "1"; then
        audio_bdf="${gpu_bdf%.*}.1"
        echo -e "${UI_DIVIDER}"
        nvidia_show_passthrough_status "$audio_bdf"
    fi

    local include_audio="no"
    if [[ -n "$audio_bdf" ]]; then
        read -p "是否同时直通核显音频功能（${audio_bdf}）？(yes/no) [yes]: " include_audio
        include_audio="${include_audio:-yes}"
    fi

    local gpu_id audio_id ids_csv
    gpu_id="$(nvidia_get_pci_ids "$gpu_bdf")"
    audio_id=""
    if [[ -n "$audio_bdf" ]]; then
        audio_id="$(nvidia_get_pci_ids "$audio_bdf")"
    fi
    ids_csv="$gpu_id"
    if [[ -n "$audio_id" ]]; then
        ids_csv="${ids_csv},${audio_id}"
    fi

    echo -e "${UI_DIVIDER}"
    if [[ -n "$ids_csv" ]]; then
        echo -e "${CYAN}VFIO ids 建议: ${NC}$ids_csv"
    fi
    echo -e "${YELLOW}提示：AMD 核显直通强依赖正确的 ROM / vBIOS；本脚本不会自动提取 ROM。${NC}"
    if ! qm_is_q35_machine "$vmid"; then
        echo -e "${YELLOW}警告：当前 VM 不是 q35 机型。AMD 核显直通通常更推荐 q35 + OVMF。${NC}"
    fi
    echo -e "${UI_DIVIDER}"

    if qm_has_hostpci_bdf "$vmid" "$gpu_bdf"; then
        display_error "该 AMD 核显已存在于 VM 的 hostpci 配置中" "无需重复添加。"
        return 1
    fi

    local idx0
    idx0="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
        display_error "未找到可用 hostpci 插槽" "请先释放 VM 的 hostpci0-hostpci15。"
        return 1
    }

    local hostpci0_value="$gpu_bdf"
    if qm_is_q35_machine "$vmid"; then
        hostpci0_value="${hostpci0_value},pcie=1"
    fi
    hostpci0_value="${hostpci0_value},x-vga=1,romfile=${rom_base}"

    local conf_path
    conf_path="$(get_qm_conf_path "$vmid")"
    if [[ -f "$conf_path" ]]; then
        backup_file "$conf_path" >/dev/null 2>&1 || true
    fi

    if ! confirm_high_risk_action "为 VM $vmid 写入 AMD 核显直通（hostpci${idx0} = ${hostpci0_value}）" "错误的 ROM / vBIOS、错误的 BDF 或错误的 hostpci 配置可能导致 VM 黑屏、来宾驱动报错或设备无法初始化。" "如果宿主机当前仍依赖该 AMD 核显输出，后续黑名单和 VFIO 绑定还可能导致宿主机本地画面丢失。" "请确认 ROM 文件由用户自行提取并已放入 ${PVE_KVM_ROM_DIR}，且已准备好回滚 hostpci 配置。" "AMD-iGPU"; then
        return 0
    fi

    if ! qm set "$vmid" "-hostpci${idx0}" "$hostpci0_value" >/dev/null 2>&1; then
        display_error "qm set 执行失败" "请检查 VM 是否锁定、IOMMU / IOMMU group，或查看 /var/log/pve-tools.log。"
        return 1
    fi

    if [[ "$include_audio" == "yes" || "$include_audio" == "YES" ]] && [[ -n "$audio_bdf" ]]; then
        local idx1
        idx1="$(qm_find_free_hostpci_index "$vmid" 2>/dev/null)" || {
            display_error "核显已添加，但未找到可用 hostpci 插槽添加音频功能" "请手工添加 $audio_bdf。"
            return 1
        }

        local hostpci1_value="$audio_bdf"
        if qm_is_q35_machine "$vmid"; then
            hostpci1_value="${hostpci1_value},pcie=1"
        fi

        if ! qm set "$vmid" "-hostpci${idx1}" "$hostpci1_value" >/dev/null 2>&1; then
            log_warn "核显音频功能直通写入失败（核显已写入）"
        else
            log_success "核显音频功能已写入: hostpci${idx1} = $hostpci1_value"
        fi
    fi

    if [[ -n "$ids_csv" ]]; then
        local set_vfio="no"
        read -p "是否写入 AMD 的 VFIO ids 绑定配置（用于将设备绑定到 vfio-pci）（yes/no）[no]: " set_vfio
        set_vfio="${set_vfio:-no}"
        if [[ "$set_vfio" == "yes" || "$set_vfio" == "YES" ]]; then
            amd_try_write_vfio_ids_conf "$ids_csv" || true
        fi
    fi

    display_success "AMD 核显直通已写入" "请在来宾中按需安装驱动；如写入了 VFIO 配置，请按提示重启宿主机。"
    return 0
}

amd_gpu_management_menu() {
    while true; do
        clear
        show_menu_header "AMD 独显直通"
        echo -e "${CYAN}提示：如宿主机仍在使用 amdgpu / radeon，占用中的 AMD 独显通常无法直接直通。${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "AMD 显卡直通虚拟机"
        show_menu_option "2" "AMD 宿主机预配置 ( IOMMU / VFIO / 黑名单 )"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-2]: " choice
        case "$choice" in
            1) amd_gpu_passthrough_vm ;;
            2) amd_host_prepare_for_passthrough ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

amd_igpu_management_menu() {
    while true; do
        clear
        show_menu_header "AMD 核显直通"
        echo -e "${RED}注意：AMD 核显直通通常需要用户自备 ROM / vBIOS 文件，本脚本不负责提取。${NC}"
        echo -e "${UI_DIVIDER}"
        show_menu_option "1" "配置 AMD 核显直通"
        show_menu_option "2" "检查 ROM / vBIOS 文件"
        show_menu_option "3" "查看 AMD 核显直通说明"
        show_menu_option "4" "AMD 宿主机预配置 ( IOMMU / VFIO / 黑名单 )"
        show_menu_option "0" "返回"
        show_menu_footer
        read -p "请选择操作 [0-4]: " choice
        case "$choice" in
            1) amd_igpu_passthrough_vm ;;
            2) amd_igpu_check_romfile ;;
            3) amd_igpu_show_guidance ;;
            4) amd_host_prepare_for_passthrough ;;
            0) return ;;
            *) log_error "无效选择" ;;
        esac
        pause_function
    done
}

# 主程序
main() {
    check_root
    ensure_legal_acceptance
    check_debug_mode "$@"
    check_pve_version
    network_offline_guard

    if [[ "$IS_OFFLINE_MODE" -eq 0 ]]; then
        detect_network_region >/dev/null 2>&1 || true
    fi
    fetch_session_tip

    if [[ "$IS_OFFLINE_MODE" -eq 1 ]]; then
        log_warn "离线模式下将跳过更新检查与镜像自动策略。"
    else
        check_update
    fi
    
    while true; do

        show_menu
        read -r choice
        echo
        
        case $choice in
            1)
                menu_optimization
                ;;
            2)
                menu_sources_updates
                ;;
            3)
                menu_boot_kernel
                ;;
            4)
                menu_gpu_passthrough
                ;;
            5)
                menu_vm_container
                ;;
            6)
                menu_host_networking
                ;;
            7)
                menu_storage_disk
                ;;
            8)
                menu_tools_about
                ;;
            9)
                security_center_menu
                ;;
            10)
                third_party_tools_menu
                ;;
            0)
                echo "感谢使用,谢谢喵"
                echo "再见！"
                exit 0
                ;;
            *)
                log_error "哎呀，这个选项不存在呢"
                log_warn "请输入 0-10 之间的数字"
                ;;
        esac
        
        echo
        pause_function
    done
}

# 运行主程序
main "$@"
