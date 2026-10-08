#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# ============ Intel SR-IOV (i915-sriov-dkms) 辅助逻辑 ============
# 上游依据（strongtz/i915-sriov-dkms）：
#   - 2026.09.16 起 Xe_LP 平台不再默认启用 CCS0（PR #484：改为可选，规避 GPU 初始化 -ETIME）；
#     需要 CCS0 时按驱动添加 i915.xelp_enable_ccs=1 或 xe.xelp_enable_ccs=1（二者不叠加）。
#   - 各 release 声明的内核支持范围不同，安装前需按当前内核核对。
#   - 官方宿主机文档区分 GRUB（/etc/default/grub + update-grub）与
#     systemd-boot（/etc/kernel/cmdline + proxmox-boot-tool refresh）。

# 版本比较：$1 >= $2 时返回 0（点分版本号，兼容 2026.03.05.7 这类多段版本）
sriov_version_ge() {
    [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$1" ]]
}

# 所选 DKMS release 是否提供 xelp_enable_ccs 参数（上游 2026.09.16 起）
sriov_dkms_ccs0_supported() {
    local ver="${1#v}"

    [[ -n "$ver" ]] || return 1
    sriov_version_ge "$ver" "2026.09.16"
}

# 所选 DKMS release 声明的内核支持范围，输出 "最小主次版本 最大主次版本"
# 仅对上游明确声明过的分支给出范围；未声明的版本返回 1（不假装已确认兼容）
sriov_dkms_kernel_range() {
    local ver="${1#v}"

    [[ -n "$ver" ]] || return 1

    if sriov_version_ge "$ver" "2026.09.16"; then
        echo "6.17 7.2"      # 2026.09.16 release 声明
    elif sriov_version_ge "$ver" "2026.08.02"; then
        echo "6.17 7.1"      # 2026.08.02 / 2026.08.08 / 2026.08.12 / 2026.09.14
    elif sriov_version_ge "$ver" "2026.05.03"; then
        echo "6.17 7.0"      # 2026.05.03 / 2026.05.06
    elif sriov_version_ge "$ver" "2026.03.05"; then
        echo "6.12 6.19"     # 2026.03.05.x 分支
    elif [[ "$ver" == "2025.07.22" ]]; then
        echo "6.8 6.12"      # README 中为 6.8~6.12 内核指定的 release
    else
        return 1
    fi
    return 0
}

# 内核主次版本（如 6.17.13-21-pve -> 6.17）是否落在 [min, max] 内
sriov_kernel_in_range() {
    local kernel_series="$1"
    local min_series="$2"
    local max_series="$3"

    [[ -n "$kernel_series" ]] || return 1
    sriov_version_ge "$kernel_series" "$min_series" && sriov_version_ge "$max_series" "$kernel_series"
}

# CCS0 参数处理决策（纯逻辑，便于用 mock 输入测试）
#   $1=用户是否选择启用(1/0)  $2=所选驱动是否支持该参数(1/0)  $3=参数是否由本工具写入(1/0)
# 输出: add | remove | skip-unsupported | noop
#   - 用户启用且驱动支持 -> add（grub_add_param 按 key 覆盖旧值，不会重复）
#   - 否则若参数由本工具写入（用户未启用或换回旧驱动）-> remove，恢复上游默认行为
#   - 用户想启用但驱动版本不支持 -> skip-unsupported（不写入未知参数）
#   - 其余 noop：不动用户自己添加的同名参数
sriov_ccs_param_action() {
    local want="$1"
    local supported="$2"
    local owned="$3"

    if [[ "$want" == "1" && "$supported" == "1" ]]; then
        echo "add"
    elif [[ "$owned" == "1" ]]; then
        echo "remove"
    elif [[ "$want" == "1" ]]; then
        echo "skip-unsupported"
    else
        echo "noop"
    fi
    return 0
}

# 识别当前引导方式：grub / systemd-boot / unknown
# 本模块只写 /etc/default/grub，对 systemd-boot 引导不生效（需改 /etc/kernel/cmdline）。
# 参考 PVE 文档「Determine which Bootloader is Used」：efibootmgr -v 查看当前 EFI 引导项，
# 且文档明确说明"从运行中的系统判断并非 100% 准确"，因此这里只作为提示依据。
sriov_detect_boot_mode() {
    if command -v efibootmgr >/dev/null 2>&1; then
        local entries="" current="" current_line=""
        entries="$(efibootmgr -v 2>/dev/null || true)"
        current="$(printf '%s\n' "$entries" | awk '/^BootCurrent:/{print $2; exit}')"
        if [[ -n "$current" ]]; then
            current_line="$(printf '%s\n' "$entries" | grep -E "^Boot${current}\\*?" | head -n 1 || true)"
            case "$current_line" in
                *systemd-boot*) echo "systemd-boot"; return 0 ;;
                *grub*.efi*|*shim*.efi*) echo "grub"; return 0 ;;
            esac
        fi
    fi

    if command -v proxmox-boot-tool >/dev/null 2>&1; then
        local status_out=""
        status_out="$(proxmox-boot-tool status 2>/dev/null || true)"
        case "$status_out" in
            *systemd-boot*) echo "systemd-boot"; return 0 ;;
            *grub*) echo "grub"; return 0 ;;
        esac
    fi

    if [[ -s /etc/kernel/cmdline ]]; then
        echo "systemd-boot"
    elif [[ -f /etc/default/grub ]]; then
        echo "grub"
    else
        echo "unknown"
    fi
    return 0
}

# 从 PCI 设备描述（pci.ids 名称）判断核显平台，仅用于提示，不阻断用户选择
# 输出: xelp | rocketlake | non-xelp | unknown
#   上游 i915 实现的 Xe_LP 集合为 tgl/adl_s/adl_p/dg1（RPL 复用 adl_*），Rocket Lake 不在其中；
#   xe 实现为 graphics_xelp 且排除 Rocket Lake。非该集合的平台启用参数不会生效（无副作用）。
sriov_gpu_platform_hint() {
    local desc=""

    desc="$(lspci -nn 2>/dev/null | grep -iE 'vga|display' | grep -i intel | head -n 1 || true)"
    [[ -n "$desc" ]] || { echo "unknown"; return 0; }

    case "$desc" in
        *"Tiger Lake"*|*"Alder Lake"*|*"Raptor Lake"*) echo "xelp" ;;
        *"Rocket Lake"*) echo "rocketlake" ;;
        *"Meteor Lake"*|*"Lunar Lake"*|*"Arrow Lake"*|*"Arc"*) echo "non-xelp" ;;
        *) echo "unknown" ;;
    esac
    return 0
}

# i915.xelp_enable_ccs 归属标记：仅当本工具写入过该参数时存在
sriov_ccs_param_owned() {
    [[ -f "$INTEL_SRIOV_CCS_FLAG_FILE" ]]
}

sriov_mark_ccs_param_owned() {
    mkdir -p "$(dirname "$INTEL_SRIOV_CCS_FLAG_FILE")" >/dev/null 2>&1 || true
    printf '%s\n' "i915.xelp_enable_ccs=1" > "$INTEL_SRIOV_CCS_FLAG_FILE" 2>/dev/null || true
}

sriov_unmark_ccs_param_owned() {
    rm -f "$INTEL_SRIOV_CCS_FLAG_FILE"
}

# 仅移除由本工具写入的 i915.xelp_enable_ccs；用户自行添加的同名参数保持不动
# 用法: sriov_remove_ccs_param_if_owned [grub 文件路径]（第二参数仅用于测试）
# shellcheck disable=SC2120
sriov_remove_ccs_param_if_owned() {
    local grub_file="${1:-/etc/default/grub}"

    if sriov_ccs_param_owned; then
        grub_remove_param "i915.xelp_enable_ccs" "$grub_file"
        sriov_unmark_ccs_param_owned
        echo -e "  ${CYAN}提示:${NC} 已移除本工具此前写入的 i915.xelp_enable_ccs"
    elif grub_has_param "i915.xelp_enable_ccs" "$grub_file"; then
        echo -e "  ${YELLOW}提示:${NC} 检测到 i915.xelp_enable_ccs 但并非本工具写入，保留不动（如需移除请手动编辑 /etc/default/grub）"
    fi
    return 0
}

igpu_sriov_setup() {
    echo -e "${H2}开始配置 Intel 11-15代 SR-IOV 核显虚拟化${NC}"
    echo -e "详细原理与教程： ${CYAN}https://pve.u3u.icu/advanced/gpu-virtualization${NC}"
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

    # 引导方式检查：本功能写入的是 GRUB 参数（/etc/default/grub），
    # systemd-boot 主机需改为编辑 /etc/kernel/cmdline 并执行 proxmox-boot-tool refresh
    boot_mode="$(sriov_detect_boot_mode)"
    if [[ "$boot_mode" != "grub" ]]; then
        echo
        echo "$UI_BORDER"
        if [[ "$boot_mode" == "systemd-boot" ]]; then
            log_warn "检测到本机使用 systemd-boot 引导，本功能不会修改 /etc/kernel/cmdline"
        else
            log_warn "无法确认本机引导方式（可能是 systemd-boot）"
        fi
        echo -e "  ${CYAN}本功能只写入 GRUB 参数${NC}：若本机使用 systemd-boot，这些参数${RED}不会生效${NC}。"
        echo "  继续执行只会完成驱动与模块配置，内核参数需要你手动写入"
        echo -e "  ${CYAN}/etc/kernel/cmdline${NC} 后执行 ${CYAN}proxmox-boot-tool refresh${NC}（流程结束时会列出完整参数）。"
        echo "$UI_BORDER"
        if ! confirm_action "是否仅继续安装驱动与模块配置（内核参数需手动添加）"; then
            echo "用户取消操作"
            return 0
        fi
    fi

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

    gpu_warn_active_stacks

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

    # ── DKMS 版本选择 ──
    # 必须在写入 GRUB 之前确定版本：CCS0 兼容参数只对 2026.09.16 及之后的 release 有意义，
    # 且各 release 支持的内核范围不同，需要提前核对并提示。
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "选择 i915-sriov-dkms 版本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  提示: 请在浏览器访问 https://github.com/strongtz/i915-sriov-dkms/releases 选择匹配的版本"
    echo "  各 release 声明的内核支持范围不同（例如 2026.09.16 为 6.17.x ~ 7.2.x，"
    echo "  更老的内核需使用更早的 release），请按当前内核 $(uname -r) 选择"
    echo "  输入格式：例如：2026.09.16"
    echo "  不输入回车的默认版本为 2025.11.10，可能不兼容较新内核，故障表现在无法虚拟出 VFs"

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

    # 内核兼容性核对：仅在上游明确声明支持范围时给出结论
    kernel_series="$(uname -r | awk -F'-' '{print $1}' | cut -d. -f1,2)"
    dkms_kernel_range="$(sriov_dkms_kernel_range "$dkms_asset_version" || true)"
    if [[ -n "$dkms_kernel_range" ]]; then
        read -r dkms_kernel_min dkms_kernel_max <<< "$dkms_kernel_range"
        if sriov_kernel_in_range "$kernel_series" "$dkms_kernel_min" "$dkms_kernel_max"; then
            echo -e "  ${GREEN}✓${NC} 当前内核 $(uname -r) 在 ${dkms_tag} 声明的支持范围（${dkms_kernel_min}.x ~ ${dkms_kernel_max}.x）内"
        else
            log_warn "当前内核 $(uname -r) 不在 ${dkms_tag} 声明的支持范围（${dkms_kernel_min}.x ~ ${dkms_kernel_max}.x）内"
            echo -e "  ${CYAN}提示:${NC} 内核与驱动不匹配时通常表现为无法创建 VFs，建议改用匹配的 release"
            if ! confirm_action "内核与所选 release 可能不兼容，仍要继续安装"; then
                echo "用户取消操作"
                return 0
            fi
        fi
    else
        log_warn "上游未声明 ${dkms_tag} 支持的内核范围，无法自动核对内核兼容性"
        echo -e "  ${CYAN}提示:${NC} 请自行确认该 release 与当前内核 $(uname -r) 是否匹配"
    fi

    # ── CCS0 兼容模式（可选）──
    ccs0_want=0
    ccs0_supported=0
    if sriov_dkms_ccs0_supported "$dkms_asset_version"; then
        ccs0_supported=1
    fi

    if [[ $ccs0_supported -eq 1 ]]; then
        platform_hint="$(sriov_gpu_platform_hint)"
        echo
        echo "$UI_BORDER"
        echo -e "  ${CYAN}CCS0 兼容模式（可选）${NC}"
        echo "  上游自 2026.09.16 起不再为 Xe_LP 平台（Tiger Lake / Alder Lake / Raptor Lake）"
        echo "  默认启用 CCS0；依赖 CCS0 的旧版客户机驱动（Windows 或旧内核）将无法正常工作。"
        echo "  上游将该功能改为可选，是为了规避部分 Xe_LP 平台的 GPU 初始化超时（-ETIME）。"
        case "$platform_hint" in
            xelp)
                echo -e "  本机核显: ${GREEN}检测为 Xe_LP 平台（TGL/ADL/RPL），该参数会生效${NC}" ;;
            rocketlake)
                echo -e "  本机核显: ${YELLOW}检测为 Rocket Lake，上游实现未纳入该参数，启用后很可能无效${NC}" ;;
            non-xelp)
                echo -e "  本机核显: ${YELLOW}检测为非 Xe_LP 平台，上游未在该平台启用 CCS0，参数大概率无效${NC}" ;;
            *)
                echo -e "  本机核显: ${YELLOW}未能从 PCI 描述识别平台，请自行确认是否为 Tiger Lake / Alder Lake / Raptor Lake${NC}" ;;
        esac
        echo
        echo "  仅当满足以下条件时建议启用："
        echo "    - 核显为 Tiger Lake / Alder Lake / Raptor Lake 等 Xe_LP 平台"
        echo "    - Windows 虚拟机无法正常加载核显驱动（客户机驱动早于 2026.09.16 时依赖 CCS0）"
        echo -e "  ${YELLOW}注意:${NC} 启用后存在 GPU 初始化兼容性风险；客户机驱动为 2026.09.16 及之后通常无需开启。"
        echo "$UI_BORDER"
        if confirm_action "是否启用 CCS0 兼容模式（i915.xelp_enable_ccs=1）"; then
            ccs0_want=1
        fi
    else
        echo
        echo -e "  ${CYAN}说明:${NC} 所选 release ${dkms_tag} 早于 CCS0 默认行为变更（2026.09.16），"
        echo "        该版本没有 i915.xelp_enable_ccs 参数，CCS0 行为由驱动自身决定，无需额外配置"
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

    # 记录改动前的命令行，只有确实发生变化时才重新生成引导配置
    grub_cmdline_before="$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub 2>/dev/null || true)"

    # 使用幂等的 GRUB 参数管理函数
    echo "配置 GRUB 参数..."

    grub_write_failed=0

    # 移除旧的 GVT-g 配置（如果有）
    grub_remove_param "i915.enable_gvt" || grub_write_failed=1
    grub_remove_param "pcie_acs_override" || grub_write_failed=1

    # 添加 SR-IOV 参数（幂等操作，不会重复添加）
    # 针对 6.8+ 内核，必须屏蔽 xe 驱动以防止冲突
    # 参考: https://github.com/strongtz/i915-sriov-dkms
    grub_add_param "intel_iommu=on" || grub_write_failed=1
    grub_add_param "iommu=pt" || grub_write_failed=1
    grub_add_param "i915.enable_guc=3" || grub_write_failed=1
    grub_add_param "i915.max_vfs=7" || grub_write_failed=1
    grub_add_param "module_blacklist=xe" || grub_write_failed=1

    # CCS0 兼容参数：按「用户选择 + 驱动版本支持 + 参数归属」三要素决定增删
    ccs0_owned=0
    sriov_ccs_param_owned && ccs0_owned=1
    ccs0_action="$(sriov_ccs_param_action "$ccs0_want" "$ccs0_supported" "$ccs0_owned")"
    case "$ccs0_action" in
        add)
            if grub_add_param "i915.xelp_enable_ccs=1"; then
                sriov_mark_ccs_param_owned
                echo -e "✓ 已启用 CCS0 兼容模式: i915.xelp_enable_ccs=1"
            else
                grub_write_failed=1
            fi
            ;;
        remove)
            sriov_remove_ccs_param_if_owned || grub_write_failed=1
            ;;
        skip-unsupported)
            log_warn "所选 release ${dkms_tag} 不提供 xelp_enable_ccs 参数，跳过 CCS0 配置"
            ;;
        *)
            # 未启用 CCS0 且参数非本工具写入：保持现状（不覆盖用户自己的配置）
            ;;
    esac

    if [[ $grub_write_failed -ne 0 ]]; then
        log_error "GRUB 参数写入未全部成功，请检查 /etc/default/grub 后重试"
        pause_function
        return 1
    fi

    echo -e "✓ GRUB 配置已更新 (已添加 module_blacklist=xe 以兼容 PVE 9.1)"

    # 更新 GRUB：仅在参数确有变化时执行
    grub_cmdline_after="$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub 2>/dev/null || true)"
    if [[ "$grub_cmdline_before" == "$grub_cmdline_after" ]]; then
        echo "GRUB 参数无变化，跳过 update-grub"
    else
        echo "更新 GRUB..."
        update-grub || {
            echo -e "更新 GRUB 失败"
            pause_function
            return 1
        }
    fi

    # 配置内核模块
    echo "配置内核模块..."
    backup_file "/etc/modules"

    # 清理可能存在的 i915 及音视频相关黑名单 (SR-IOV 需要 i915 驱动加载)
    echo "清理可能存在的 i915 及音视频相关黑名单..."
    for f in /etc/modprobe.d/blacklist.conf /etc/modprobe.d/pve-blacklist.conf; do
        if [ -f "$f" ]; then
            remove_block "$f" "HARDWARE_PASSTHROUGH"
            remove_block "$f" "INTEL_LEGACY_BLACKLIST"
            sed -i '/blacklist i915/d' "$f"
            sed -i '/blacklist snd_hda_intel/d' "$f"
            sed -i '/blacklist snd_hda_codec_hdmi/d' "$f"
        fi
    done

    # 添加 VFIO 模块（marker 配置块写入，自动备份并幂等；同时清掉 GVT-g 的模块块、kvmgt 与旧版裸行）
    remove_block "/etc/modules" "INTEL_GVTG_MODULES"
    sed -i -E '/^(vfio|vfio_iommu_type1|vfio_pci|vfio_virqfd|kvmgt)[[:space:]]*$/d' /etc/modules
    apply_block "/etc/modules" "INTEL_SRIOV_MODULES" "vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd"

    echo -e "✓ 内核模块配置完成"

    # 更新 initramfs
    echo "更新 initramfs..."
    update-initramfs -u -k all || {
        echo -e "更新 initramfs 失败，但可以继续"
    }

    # 下载并安装 i915-sriov-dkms 驱动（版本已在上方选定）
    echo "下载 i915-sriov-dkms 驱动 (${dkms_tag})..."

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

    # 写入 sysfs.conf（保留其它已有配置）
    backup_file "/etc/sysfs.conf"
    if [[ -f /etc/sysfs.conf ]]; then
        sed -i '/sriov_numvfs/d' /etc/sysfs.conf
    fi
    echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = $vfs_num" >> /etc/sysfs.conf
    echo -e "✓ VFs 数量配置完成"

    # 完成提示
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "✓ SR-IOV 核显虚拟化配置完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "配置摘要："
    echo "  • 内核参数: intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7 module_blacklist=xe"
    if [[ "$ccs0_action" == "add" ]]; then
        echo "  • CCS0 兼容模式: 已启用 (i915.xelp_enable_ccs=1)"
    elif [[ "$ccs0_action" == "remove" ]]; then
        echo "  • CCS0 兼容模式: 已移除本工具此前写入的 i915.xelp_enable_ccs"
    else
        echo "  • CCS0 兼容模式: 未启用（保留上游默认行为）"
    fi
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
    if [[ "$boot_mode" != "grub" ]]; then
        echo "$UI_BORDER"
        echo -e "  ${YELLOW}引导方式提醒:${NC} 本机引导方式为 ${boot_mode}，上方 GRUB 参数${RED}不会生效${NC}。"
        echo "  请将以下参数写入 /etc/kernel/cmdline（同一行）后执行 proxmox-boot-tool refresh："
        echo -n "    intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7 module_blacklist=xe"
        if [[ "$ccs0_action" == "add" ]]; then
            echo -n " i915.xelp_enable_ccs=1"
        fi
        echo
        echo "$UI_BORDER"
        echo
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if confirm_action "是否现在重启系统"; then
        echo "正在重启系统..."
        reboot
    else
        echo -e "请记得手动重启系统以使配置生效"
    fi
}

# Intel 6-10代 GVT-g 核显虚拟化配置
