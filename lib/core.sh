#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

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
