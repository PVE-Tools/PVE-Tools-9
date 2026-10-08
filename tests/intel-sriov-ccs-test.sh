#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# Intel SR-IOV CCS0 兼容性（Issue #106）回归测试。
#
# 覆盖：DKMS 版本门槛、内核范围核对、CCS0 决策表、GRUB 参数文件级语义
#       （追加/幂等/同 key 更新/删除精度/写入失败）、参数归属与清理、
#       引导方式识别、核显平台提示。
#
# 只用纯逻辑 + mock：不读写 /etc、/var，不执行 apt/dpkg/reboot，也不校验真实硬件。
#
# 用法:
#     bash tests/intel-sriov-ccs-test.sh
#
# shellcheck disable=SC2034,SC2317
# （本文件覆盖的全局变量与桩函数由 source 进来的模块函数间接使用）

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/config.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/core.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/04-gpu-passthrough/intel-sriov.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  PASS  $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  FAIL  $1"
    echo "        期望: $2"
    echo "        实际: $3"
}

assert_eq() {
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        fail "$1" "$2" "$3"
    fi
}

assert_true() {
    local name="$1"
    shift
    if "$@"; then
        pass "$name"
    else
        fail "$name" "返回 0" "返回非 0"
    fi
}

assert_false() {
    local name="$1"
    shift
    if "$@"; then
        fail "$name" "返回非 0" "返回 0"
    else
        pass "$name"
    fi
}

# ---- 副作用桩：真实环境由 lib/core.sh 提供，测试中不触碰系统路径 ----
backup_file() { :; }
log_info() { :; }
log_warn() { :; }
log_error() { :; }
log_success() { :; }
log_tips() { :; }

# 归属标记指向临时目录（模块函数在调用时读取该全局变量）
INTEL_SRIOV_CCS_FLAG_FILE="$TMP_DIR/intel-sriov-ccs-param"

# 写入一个最小 /etc/default/grub 等价文件，返回其路径
make_grub_file() {
    local params="$1"
    local file
    file="$TMP_DIR/grub.$RANDOM.$RANDOM.conf"
    printf 'GRUB_DEFAULT=0\nGRUB_CMDLINE_LINUX_DEFAULT="%s"\nGRUB_TIMEOUT=5\n' "$params" > "$file"
    echo "$file"
}

# 取出文件里 GRUB_CMDLINE_LINUX_DEFAULT 的参数列表
cmdline_params() {
    sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/\1/p' "$1"
}

echo "== 版本门槛与内核范围（上游 release 声明）=="

assert_true "版本比较: 2026.09.16 >= 2026.09.16" sriov_version_ge "2026.09.16" "2026.09.16"
assert_true "版本比较: 2026.03.05.7 >= 2026.03.05" sriov_version_ge "2026.03.05.7" "2026.03.05"
assert_false "版本比较: 2026.09.14 < 2026.09.16" sriov_version_ge "2026.09.14" "2026.09.16"

assert_true "Case A 2026.09.16 提供 xelp_enable_ccs 参数" sriov_dkms_ccs0_supported "2026.09.16"
assert_true "2026.10.01 提供该参数" sriov_dkms_ccs0_supported "2026.10.01"
assert_true "带 v 前缀同样识别" sriov_dkms_ccs0_supported "v2026.09.16"
assert_false "2026.09.14（变更前一个 release）无该参数" sriov_dkms_ccs0_supported "2026.09.14"
assert_false "Case C 2025.11.10（默认版本）无该参数" sriov_dkms_ccs0_supported "2025.11.10"
assert_false "2026.03.05.7（6.12~6.19 分支）无该参数" sriov_dkms_ccs0_supported "2026.03.05.7"

assert_eq "2026.09.16 声明支持 6.17~7.2" "6.17 7.2" "$(sriov_dkms_kernel_range "2026.09.16")"
assert_eq "2026.09.14 声明支持 6.17~7.1" "6.17 7.1" "$(sriov_dkms_kernel_range "2026.09.14")"
assert_eq "2026.05.06 声明支持 6.17~7.0" "6.17 7.0" "$(sriov_dkms_kernel_range "2026.05.06")"
assert_eq "2026.03.05.7 声明支持 6.12~6.19" "6.12 6.19" "$(sriov_dkms_kernel_range "2026.03.05.7")"
assert_eq "2025.07.22 声明支持 6.8~6.12" "6.8 6.12" "$(sriov_dkms_kernel_range "2025.07.22")"
assert_false "Case H 未声明范围的版本不假装已确认兼容" sriov_dkms_kernel_range "2025.11.10"

assert_true "6.17 命中 6.17~7.2" sriov_kernel_in_range "6.17" "6.17" "7.2"
assert_false "6.14 不命中 6.17~7.2" sriov_kernel_in_range "6.14" "6.17" "7.2"
assert_true "7.2 命中 6.17~7.2（上界含同主次版本）" sriov_kernel_in_range "7.2" "6.17" "7.2"
assert_false "7.3 不命中 6.17~7.2" sriov_kernel_in_range "7.3" "6.17" "7.2"
assert_true "6.19 命中 6.12~6.19" sriov_kernel_in_range "6.19" "6.12" "6.19"
assert_false "6.8 不命中 6.12~6.19" sriov_kernel_in_range "6.8" "6.12" "6.19"
assert_true "6.8 命中 6.8~6.12" sriov_kernel_in_range "6.8" "6.8" "6.12"

echo "== CCS0 参数决策表 =="

assert_eq "Case A 启用 + 驱动支持 -> add" "add" \
    "$(sriov_ccs_param_action "1" "1" "0")"
assert_eq "Case D 启用 + 驱动支持 + 已由本工具写入 -> add（幂等覆盖）" "add" \
    "$(sriov_ccs_param_action "1" "1" "1")"
assert_eq "Case B 未启用 + 无归属 -> noop" "noop" \
    "$(sriov_ccs_param_action "0" "1" "0")"
assert_eq "Case B 撤回启用（本工具写入过）-> remove" "remove" \
    "$(sriov_ccs_param_action "0" "1" "1")"
assert_eq "Case C/H 启用但驱动版本不支持 -> skip-unsupported" "skip-unsupported" \
    "$(sriov_ccs_param_action "1" "0" "0")"
assert_eq "换回旧驱动 + 曾启用 -> remove" "remove" \
    "$(sriov_ccs_param_action "1" "0" "1")"
assert_eq "未启用 + 驱动不支持 + 无归属 -> noop" "noop" \
    "$(sriov_ccs_param_action "0" "0" "0")"
assert_eq "未启用 + 驱动不支持 + 有归属 -> remove" "remove" \
    "$(sriov_ccs_param_action "0" "0" "1")"

echo "== GRUB 参数文件级语义（真实 grub_* 函数 + 临时文件）=="

# Case F：原有无关参数必须保留
grub_f="$(make_grub_file "intel_iommu=on pcie_aspm=force mitigations=off")"
assert_true "Case F 追加 CCS0 参数成功" grub_add_param "i915.xelp_enable_ccs=1" "$grub_f"
assert_eq "Case F 原有无关参数保留" \
    "intel_iommu=on pcie_aspm=force mitigations=off i915.xelp_enable_ccs=1" "$(cmdline_params "$grub_f")"

# Case D：重复执行不产生重复参数
grub_add_param "i915.xelp_enable_ccs=1" "$grub_f"
grub_add_param "i915.xelp_enable_ccs=1" "$grub_f"
assert_eq "Case D 重复执行后参数仍只出现一次" "1" \
    "$(cmdline_params "$grub_f" | tr ' ' '\n' | grep -c '^i915\.xelp_enable_ccs=1$')"
assert_eq "Case D 重复执行后参数列表不变" \
    "intel_iommu=on pcie_aspm=force mitigations=off i915.xelp_enable_ccs=1" "$(cmdline_params "$grub_f")"

# Case G：同 key 旧值被更新，且不影响其他 i915.* 参数
grub_g="$(make_grub_file "i915.enable_guc=3 i915.xelp_enable_ccs=0")"
grub_add_param "i915.xelp_enable_ccs=1" "$grub_g"
assert_eq "Case G 同 key 旧值更新为 1" "i915.enable_guc=3 i915.xelp_enable_ccs=1" "$(cmdline_params "$grub_g")"
assert_true "Case G 其他 i915.* 参数未被误删" grub_has_param "i915.enable_guc" "$grub_g"

grub_add_param "i915.max_vfs=7" "$grub_g"
assert_true "点号 key 追加后 CCS0 参数仍在" grub_has_param "i915.xelp_enable_ccs" "$grub_g"
assert_true "点号 key 追加后 enable_guc 仍在" grub_has_param "i915.enable_guc" "$grub_g"

# 删除精度：只删指定 key
grub_remove_param "i915.xelp_enable_ccs" "$grub_g"
assert_false "删除后 CCS0 key 不存在" grub_has_param "i915.xelp_enable_ccs" "$grub_g"
assert_true "删除 CCS0 不影响 i915.enable_guc" grub_has_param "i915.enable_guc" "$grub_g"
assert_true "删除 CCS0 不影响 i915.max_vfs" grub_has_param "i915.max_vfs" "$grub_g"
assert_eq "删除后剩余参数正确" "i915.enable_guc=3 i915.max_vfs=7" "$(cmdline_params "$grub_g")"

# 写入失败必须如实报错（不得报告成功）
assert_false "目标文件不存在时 grub_add_param 返回非 0" \
    grub_add_param "i915.xelp_enable_ccs=1" "$TMP_DIR/not-exist.conf" 2>/dev/null
printf 'GRUB_TIMEOUT=5\n' > "$TMP_DIR/no-cmdline.conf"
assert_false "缺少 GRUB_CMDLINE_LINUX_DEFAULT 时不报告成功" \
    grub_add_param "i915.xelp_enable_ccs=1" "$TMP_DIR/no-cmdline.conf" 2>/dev/null

echo "== 参数归属与清理（Case E）=="

# 本工具写入（有归属标记）-> 清理时移除
grub_e1="$(make_grub_file "intel_iommu=on")"
grub_add_param "i915.xelp_enable_ccs=1" "$grub_e1"
rm -f "$INTEL_SRIOV_CCS_FLAG_FILE"
sriov_mark_ccs_param_owned
assert_true "归属标记已写入" sriov_ccs_param_owned
sriov_remove_ccs_param_if_owned "$grub_e1"
assert_false "Case E 切换/移除时清除本工具写入的 CCS0 参数" grub_has_param "i915.xelp_enable_ccs" "$grub_e1"
assert_false "Case E 归属标记同时清除" sriov_ccs_param_owned
assert_eq "Case E 仅移除 CCS0，其他参数保留" "intel_iommu=on" "$(cmdline_params "$grub_e1")"

# 用户自建参数（无归属标记）-> 不得删除
grub_e2="$(make_grub_file "i915.xelp_enable_ccs=1 pcie_aspm=force")"
rm -f "$INTEL_SRIOV_CCS_FLAG_FILE"
sriov_remove_ccs_param_if_owned "$grub_e2"
assert_true "Case E 非本工具写入的 CCS0 参数保留" grub_has_param "i915.xelp_enable_ccs" "$grub_e2"
assert_eq "Case E 用户自建配置整体不变" "i915.xelp_enable_ccs=1 pcie_aspm=force" "$(cmdline_params "$grub_e2")"

# 无标记且无参数 -> 静默无操作
grub_e3="$(make_grub_file "quiet")"
assert_true "Case E 无归属、无参数时正常返回" sriov_remove_ccs_param_if_owned "$grub_e3"
assert_eq "Case E 未受影响的配置不变" "quiet" "$(cmdline_params "$grub_e3")"

echo "== 引导方式识别（Case I）=="

# bash 允许函数名包含 '-'，可用于遮蔽真实命令，保证结果可复现
efibootmgr() { printf '%s\n' "$MOCK_EFIBOOT"; }
proxmox-boot-tool() { printf '%s\n' "$MOCK_PBT"; }

MOCK_EFIBOOT=""
MOCK_PBT=""
MOCK_EFIBOOT=$'BootCurrent: 0006\nBoot0006* Linux Boot Manager\tHD(2,GPT,..)/File(\\EFI\\systemd\\systemd-bootx64.efi)'
assert_eq "EFI 当前项为 systemd-boot" "systemd-boot" "$(sriov_detect_boot_mode)"

MOCK_EFIBOOT=$'BootCurrent: 0005\nBoot0005* proxmox\tHD(2,GPT,..)/File(\\EFI\\proxmox\\grubx64.efi)'
assert_eq "EFI 当前项为 grub" "grub" "$(sriov_detect_boot_mode)"

MOCK_EFIBOOT=$'BootCurrent: 0005\nBoot0005* proxmox\tHD(2,GPT,..)/File(\\EFI\\proxmox\\shimx64.efi)'
assert_eq "EFI 当前项为 shim（Secure Boot + GRUB）" "grub" "$(sriov_detect_boot_mode)"

# 仅存在未启用的 systemd-boot 项时，应以当前项（GRUB）为准
MOCK_EFIBOOT=$'BootCurrent: 0005\nBoot0005* proxmox\tHD(2,GPT,..)/File(\\EFI\\proxmox\\grubx64.efi)\nBoot0006* Linux Boot Manager\tHD(2,GPT,..)/File(\\EFI\\systemd\\systemd-bootx64.efi)'
assert_eq "以当前引导项为准，未被未启用项误导" "grub" "$(sriov_detect_boot_mode)"

# 无 EFI 变量时回退 proxmox-boot-tool 状态
MOCK_EFIBOOT=""
MOCK_PBT=$'System currently booted with uefi\nAA11-BB22 is configured with: systemd-boot (versions: 6.17.13-21-pve)'
assert_eq "回退 proxmox-boot-tool 状态识别 systemd-boot" "systemd-boot" "$(sriov_detect_boot_mode)"

MOCK_PBT=$'System currently booted with uefi\nAA11-BB22 is configured with: grub (versions: 6.17.13-21-pve)'
assert_eq "回退 proxmox-boot-tool 状态识别 grub" "grub" "$(sriov_detect_boot_mode)"

unset -f efibootmgr
unset -f proxmox-boot-tool

echo "== 核显平台提示（仅提示，不阻断）=="

lspci() { printf '%s\n' "$MOCK_LSPCI"; }

MOCK_LSPCI="00:02.0 VGA compatible controller [0300]: Intel Corporation Alder Lake-P GT2 [Iris Xe Graphics] [8086:46a6]"
assert_eq "Alder Lake -> xelp" "xelp" "$(sriov_gpu_platform_hint)"

MOCK_LSPCI="00:02.0 VGA compatible controller: Intel Corporation Raptor Lake-P [Iris Xe Graphics] [8086:a7a0]"
assert_eq "Raptor Lake -> xelp" "xelp" "$(sriov_gpu_platform_hint)"

MOCK_LSPCI="00:02.0 VGA compatible controller: Intel Corporation Rocket Lake-S GT1 [UHD Graphics 750] [8086:4c8a]"
assert_eq "Rocket Lake -> 参数不生效（上游未纳入）" "rocketlake" "$(sriov_gpu_platform_hint)"

MOCK_LSPCI="00:02.0 VGA compatible controller: Intel Corporation Meteor Lake-P [Intel Graphics] [8086:7d45]"
assert_eq "Meteor Lake -> 非 Xe_LP" "non-xelp" "$(sriov_gpu_platform_hint)"

MOCK_LSPCI=""
assert_eq "无法识别 -> unknown" "unknown" "$(sriov_gpu_platform_hint)"

unset -f lspci

echo "== 结构断言（防止顺序与范围回归）=="

SRC="$REPO_ROOT/src/modules/04-gpu-passthrough/intel-sriov.sh"
fn_start="$(grep -n '^igpu_sriov_setup()' "$SRC" | cut -d: -f1)"
dkms_prompt_line="$(awk -v s="$fn_start" 'NR > s && /选择 i915-sriov-dkms 版本/ {print NR; exit}' "$SRC")"
first_add_line="$(awk -v s="$fn_start" 'NR > s && /grub_add_param / {print NR; exit}' "$SRC")"

if [[ -n "$dkms_prompt_line" && -n "$first_add_line" && "$dkms_prompt_line" -lt "$first_add_line" ]]; then
    pass "DKMS 版本选择发生在首次 GRUB 参数写入之前"
else
    fail "DKMS 版本选择发生在首次 GRUB 参数写入之前" \
        "提示行号 < grub_add_param 行号" "提示=$dkms_prompt_line add=$first_add_line"
fi

# i915 路线只应写入 i915.* 参数；注释中引用上游文档不算代码命中
if grep -qE 'grub_(add|remove)_param[[:space:]]+"xe\.xelp_enable_ccs' "$SRC"; then
    fail "未对 xe 驱动写入 CCS0 参数" "只写 i915.xelp_enable_ccs" "命中 grub_*_param xe.xelp_enable_ccs"
else
    pass "未对 xe 驱动写入 CCS0 参数（i915 路线不应添加 xe.*）"
fi

if grep -q 'i915\.xelp_enable_ccs=1' "$SRC"; then
    pass "源码包含 i915.xelp_enable_ccs=1 写入路径"
else
    fail "源码包含 i915.xelp_enable_ccs=1 写入路径" "存在写入路径" "未找到"
fi

echo
echo "通过 $PASS_COUNT 项，失败 $FAIL_COUNT 项"

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
