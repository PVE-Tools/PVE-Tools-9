#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# 内核清理（remove_old_kernels）回归测试，覆盖 Issue #107 相关场景。
# 无外部依赖，不读写系统内核，可任意环境执行（Windows Git Bash / PVE 宿主机均可）。
#
# 用法:
#     bash tests/kernel-cleanup-test.sh
#
# shellcheck disable=SC2034,SC2317
# （mock 函数/颜色变量由被 source 的 kernel.sh 间接调用：SC2034 变量看似未用、
#   SC2317 函数看似不可达，均为跨文件误报）

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/03-boot-kernel/kernel.sh"

PASS_COUNT=0
FAIL_COUNT=0
APT_CALLS_FILE="$(mktemp)"
MOCK_DPKG_FILE=""
trap 'rm -f "$APT_CALLS_FILE"; [[ -n "$MOCK_DPKG_FILE" ]] && rm -f "$MOCK_DPKG_FILE"' EXIT

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

# 纯逻辑用例: assert_removals <用例名> <当前 release> <期望删除(空格分隔,可空)> <pin(空格分隔,可空)> <包名...>
assert_removals() {
    local name="$1"
    local current_release="$2"
    local expected="$3"
    local pinned="$4"
    shift 4

    local -a installed=("$@")
    local -a pinned_arr=()
    if [[ -n "$pinned" ]]; then
        read -r -a pinned_arr <<< "$pinned"
    fi

    local status=0
    local raw=""
    raw="$(printf '%s\n' "${installed[@]}" | kernel_cleanup_select_removals "$current_release" "${pinned_arr[@]}")" || status=$?

    if [[ $status -ne 0 ]]; then
        fail "$name" "选择器返回 0" "返回 $status (fail-safe)"
        return
    fi

    local actual=""
    actual="$(printf '%s\n' "$raw" | sed '/^$/d' | sort | tr '\n' ' ')"
    actual="${actual% }"

    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "$expected" "$actual"
    fi
}

# fail-safe 用例: assert_failsafe <用例名> <当前 release> <包名...>
assert_failsafe() {
    local name="$1"
    local current_release="$2"
    shift 2

    local status=0
    printf '%s\n' "$@" | kernel_cleanup_select_removals "$current_release" >/dev/null || status=$?

    if [[ $status -ne 0 ]]; then
        pass "$name"
    else
        fail "$name" "选择器返回非 0（放弃自动删除）" "返回 0（会继续删除）"
    fi
}

echo "== 候选计算（纯逻辑）=="

# Case A: 当前运行内核就是最新版，按 release 保留最新两个
assert_removals "Case A 当前=最新版，删除第 3 新" \
    "7.0.14-20-pve" "proxmox-kernel-7.0.14-17-pve-signed" "" \
    proxmox-kernel-7.0.14-17-pve-signed \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# Case B: 当前运行内核较旧，仍必须保留，同时保留最新两个 release
assert_removals "Case B 当前内核较旧仍受保护" \
    "6.17.13-21-pve" "proxmox-kernel-7.0.14-17-pve-signed" "" \
    proxmox-kernel-6.17.13-21-pve-signed \
    proxmox-kernel-7.0.14-17-pve-signed \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# Case C: 只有两个内核（即最新两个），不执行清理
assert_removals "Case C 仅两个内核，无删除候选" \
    "7.0.14-19-pve" "" "" \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# Case D: 运行的是 -signed 包，release 与 uname -r 一致，必须识别为当前内核
assert_removals "Case D signed 包识别为当前运行内核" \
    "6.17.13-21-pve" "" "" \
    proxmox-kernel-6.17.13-21-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# Case E1: 同一 release 的 signed / unsigned 并存，不能算作两个内核版本
assert_removals "Case E1 同 release 的 signed+unsigned 不重复计数" \
    "7.0.14-20-pve" "proxmox-kernel-7.0.14-17-pve-signed" "" \
    proxmox-kernel-7.0.14-20-pve-signed \
    proxmox-kernel-7.0.14-20-pve \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-17-pve-signed

# Case E2: 受保护 release 的两种 flavor 一并保留；旧 release 的两种 flavor 一并删除
assert_removals "Case E2 旧 release 的 signed+unsigned 一并删除" \
    "7.0.14-20-pve" "proxmox-kernel-7.0.14-17-pve proxmox-kernel-7.0.14-17-pve-signed" "" \
    proxmox-kernel-7.0.14-20-pve-signed \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-17-pve-signed \
    proxmox-kernel-7.0.14-17-pve

# Case F: Issue #107 实际数据（当前 6.17.13-21 落后于最新两个 7.0.14 内核）
assert_removals "Case F Issue #107 场景" \
    "6.17.13-21-pve" \
    "proxmox-kernel-6.17.13-13-pve-signed proxmox-kernel-7.0.14-14-pve-signed proxmox-kernel-7.0.14-15-pve-signed proxmox-kernel-7.0.14-16-pve-signed proxmox-kernel-7.0.14-17-pve-signed proxmox-kernel-7.0.14-8-pve-signed" \
    "" \
    proxmox-kernel-6.17.13-13-pve-signed \
    proxmox-kernel-6.17.13-21-pve-signed \
    proxmox-kernel-7.0.14-8-pve-signed \
    proxmox-kernel-7.0.14-14-pve-signed \
    proxmox-kernel-7.0.14-15-pve-signed \
    proxmox-kernel-7.0.14-16-pve-signed \
    proxmox-kernel-7.0.14-17-pve-signed \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# Case G: 无法解析的包名 -> fail-safe
assert_failsafe "Case G 无法解析的包名触发 fail-safe" \
    "7.0.14-20-pve" \
    proxmox-kernel-7.0.14-20-pve-signed \
    linux-image-6.1.0-13-amd64

# Case G2: 当前运行内核无法对应到任何已安装包 -> fail-safe
assert_failsafe "Case G2 当前内核不在已安装列表时 fail-safe" \
    "6.17.13-21-pve" \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# 空输入 -> fail-safe
assert_failsafe "Case G3 空内核列表 fail-safe" "7.0.14-20-pve"

# pin 保护: 明确 pin 的旧内核不得出现在删除列表
assert_removals "pin 内核受保护" \
    "7.0.14-20-pve" "proxmox-kernel-7.0.14-17-pve-signed" "7.0.14-8-pve" \
    proxmox-kernel-7.0.14-8-pve-signed \
    proxmox-kernel-7.0.14-17-pve-signed \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

# 旧包名 pve-kernel-* 兼容
assert_removals "旧包名 pve-kernel-* 兼容" \
    "6.8.12-1-pve" "pve-kernel-6.5.13-1-pve" "" \
    pve-kernel-6.5.13-1-pve \
    pve-kernel-6.8.12-1-pve \
    pve-kernel-6.8.12-2-pve

# 混用新旧包名前缀时仍按 release 排序
assert_removals "新旧包名前缀混用" \
    "7.0.14-20-pve" "pve-kernel-6.5.13-1-pve" "" \
    pve-kernel-6.5.13-1-pve \
    proxmox-kernel-7.0.14-19-pve-signed \
    proxmox-kernel-7.0.14-20-pve-signed

echo "== get_installed_kernel_packages（mock dpkg -l）=="

MOCK_DPKG_FILE="$(mktemp)"
cat > "$MOCK_DPKG_FILE" <<'EOF'
Desired=Unknown/Install/Remove/Purge/Hold
||/ Name                                  Version        Architecture Description
+++-=====================================-==============-============-===========
ii  proxmox-kernel-6.17.13-21-pve-signed  6.17.13-21     amd64        PVE Kernel
ii  proxmox-kernel-7.0.14-19-pve-signed   7.0.14-19      amd64        PVE Kernel
ii  proxmox-kernel-7.0.14-20-pve-signed   7.0.14-20      amd64        PVE Kernel
hi  proxmox-kernel-7.0.14-8-pve           7.0.14-8       amd64        PVE Kernel (held)
ii  proxmox-kernel-6.17                   7.0.14-20      amd64        PVE Kernel meta
ii  pve-kernel-6.8.12-1-pve               6.8.12-1       amd64        PVE Kernel
rc  proxmox-kernel-7.0.14-17-pve-signed   7.0.14-17      amd64        PVE Kernel
ii  linux-image-amd64                     6.1.0-13       amd64        Linux image
EOF

dpkg() { cat "$MOCK_DPKG_FILE"; }

installed_ii="$(get_installed_kernel_packages "ii" | sort | tr '\n' ' ')"
installed_ii="${installed_ii% }"
expected_ii="proxmox-kernel-6.17.13-21-pve-signed proxmox-kernel-7.0.14-19-pve-signed proxmox-kernel-7.0.14-20-pve-signed pve-kernel-6.8.12-1-pve"
if [[ "$installed_ii" == "$expected_ii" ]]; then
    pass "ii 状态过滤：排除 meta / held / rc / 非内核包"
else
    fail "ii 状态过滤：排除 meta / held / rc / 非内核包" "$expected_ii" "$installed_ii"
fi

installed_all="$(get_installed_kernel_packages | sort | tr '\n' ' ')"
installed_all="${installed_all% }"
if [[ "$installed_all" == *"proxmox-kernel-7.0.14-8-pve"* ]]; then
    pass "默认状态过滤包含 held (hi) 内核"
else
    fail "默认状态过滤包含 held (hi) 内核" "包含 proxmox-kernel-7.0.14-8-pve" "$installed_all"
fi

echo "== remove_old_kernels（mock 系统命令）=="

# ---- mock 环境 ----
# 说明：mock 函数与颜色变量由被 source 的 kernel.sh 间接调用，跨文件误报已由文件头
# 的 shellcheck 指令统一关闭。
MOCK_UNAME_R=""
MOCK_INSTALLED=()
MOCK_APT_RC=0
MOCK_PINNED=()

uname() {
    if [[ "${1:-}" == "-r" ]]; then
        echo "$MOCK_UNAME_R"
        return 0
    fi
    echo "x86_64"
}

get_installed_kernel_packages() {
    printf '%s\n' "${MOCK_INSTALLED[@]}"
}

kernel_pinned_releases() {
    [[ ${#MOCK_PINNED[@]} -gt 0 ]] || return 0
    printf '%s\n' "${MOCK_PINNED[@]}"
}

apt-get() {
    echo "$*" >> "$APT_CALLS_FILE"
    return "$MOCK_APT_RC"
}

update_grub_config() { return 0; }
log_info() { echo "INFO $*"; }
log_warn() { echo "WARN $*"; }
log_error() { echo "ERROR $*" >&2; }
log_success() { echo "OK $*"; }
log_tips() { echo "TIPS $*"; }

# 颜色变量由 lib/core.sh 的 setup_colors 初始化，测试环境下置空
CYAN=""
GREEN=""
YELLOW=""
RED=""
NC=""

reset_mocks() {
    : > "$APT_CALLS_FILE"
    MOCK_APT_RC=0
    MOCK_PINNED=()
}

apt_calls() {
    sed '/^$/d' "$APT_CALLS_FILE" | tr '\n' '|'
}

# W1: fail-safe —— 当前运行内核不在已安装列表时不得调用 apt
reset_mocks
MOCK_UNAME_R="6.17.13-21-pve"
MOCK_INSTALLED=(proxmox-kernel-7.0.14-19-pve-signed proxmox-kernel-7.0.14-20-pve-signed)
status=0
out="$(printf 'y\n' | remove_old_kernels 2>&1)" || status=$?
if [[ $status -ne 0 && -z "$(apt_calls)" ]]; then
    pass "W1 fail-safe 放弃删除且不调用 apt"
else
    fail "W1 fail-safe 放弃删除且不调用 apt" "返回非 0 且 apt 未被调用" "返回 $status, apt 调用: $(apt_calls)"
fi

# W2: Issue #107 场景下确认删除列表不含当前运行内核
reset_mocks
MOCK_UNAME_R="6.17.13-21-pve"
MOCK_INSTALLED=(
    proxmox-kernel-6.17.13-13-pve-signed
    proxmox-kernel-6.17.13-21-pve-signed
    proxmox-kernel-7.0.14-17-pve-signed
    proxmox-kernel-7.0.14-19-pve-signed
    proxmox-kernel-7.0.14-20-pve-signed
)
status=0
out="$(printf 'y\n' | remove_old_kernels 2>&1)" || status=$?
if [[ $status -eq 0 ]] \
    && [[ "$(apt_calls)" == *"remove -y --purge proxmox-kernel-6.17.13-13-pve-signed|"* ]] \
    && [[ "$(apt_calls)" == *"remove -y --purge proxmox-kernel-7.0.14-17-pve-signed|"* ]] \
    && [[ "$(apt_calls)" != *"6.17.13-21-pve-signed"* ]] \
    && [[ "$(apt_calls)" != *"7.0.14-19-pve-signed"* ]] \
    && [[ "$(apt_calls)" != *"7.0.14-20-pve-signed"* ]]; then
    pass "W2 保留运行内核 6.17.13-21 与最新两个 release"
else
    fail "W2 保留运行内核 6.17.13-21 与最新两个 release" \
        "返回 0 且删除 6.17.13-13 / 7.0.14-17，保留 6.17.13-21 / 7.0.14-19 / 7.0.14-20" \
        "返回 $status, apt 调用: $(apt_calls)"
fi

# W3: 用户拒绝确认时不删除
reset_mocks
MOCK_UNAME_R="7.0.14-20-pve"
MOCK_INSTALLED=(
    proxmox-kernel-7.0.14-17-pve-signed
    proxmox-kernel-7.0.14-19-pve-signed
    proxmox-kernel-7.0.14-20-pve-signed
)
status=0
out="$(printf 'n\n' | remove_old_kernels 2>&1)" || status=$?
if [[ $status -eq 0 && -z "$(apt_calls)" ]]; then
    pass "W3 拒绝确认时不调用 apt"
else
    fail "W3 拒绝确认时不调用 apt" "返回 0 且 apt 未被调用" "返回 $status, apt 调用: $(apt_calls)"
fi

# W4: 某个包删除失败时不得报告“清理完成”
reset_mocks
MOCK_UNAME_R="7.0.14-20-pve"
MOCK_APT_RC=1
MOCK_INSTALLED=(
    proxmox-kernel-7.0.14-17-pve-signed
    proxmox-kernel-7.0.14-19-pve-signed
    proxmox-kernel-7.0.14-20-pve-signed
)
status=0
out="$(printf 'y\n' | remove_old_kernels 2>&1)" || status=$?
if [[ $status -ne 0 ]] && [[ "$out" == *"未全部完成"* ]] && [[ "$out" != *"旧内核清理完成"* ]]; then
    pass "W4 删除失败时不报告清理完成"
else
    fail "W4 删除失败时不报告清理完成" "返回非 0 且输出含「未全部完成」" "返回 $status, 输出: $out"
fi

# W5: 全部成功时报告删除数量
reset_mocks
MOCK_UNAME_R="7.0.14-20-pve"
MOCK_INSTALLED=(
    proxmox-kernel-7.0.14-17-pve-signed
    proxmox-kernel-7.0.14-19-pve-signed
    proxmox-kernel-7.0.14-20-pve-signed
)
status=0
out="$(printf 'y\n' | remove_old_kernels 2>&1)" || status=$?
if [[ $status -eq 0 && "$out" == *"旧内核清理完成"* ]]; then
    pass "W5 全部成功时报告清理完成"
else
    fail "W5 全部成功时报告清理完成" "返回 0 且输出含「旧内核清理完成」" "返回 $status, 输出: $out"
fi

# W6: pin 的内核不进入删除列表
reset_mocks
MOCK_UNAME_R="7.0.14-20-pve"
MOCK_PINNED=("7.0.14-8-pve")
MOCK_INSTALLED=(
    proxmox-kernel-7.0.14-8-pve-signed
    proxmox-kernel-7.0.14-17-pve-signed
    proxmox-kernel-7.0.14-19-pve-signed
    proxmox-kernel-7.0.14-20-pve-signed
)
status=0
out="$(printf 'y\n' | remove_old_kernels 2>&1)" || status=$?
if [[ $status -eq 0 ]] \
    && [[ "$(apt_calls)" == *"remove -y --purge proxmox-kernel-7.0.14-17-pve-signed|"* ]] \
    && [[ "$(apt_calls)" != *"7.0.14-8-pve-signed"* ]]; then
    pass "W6 pin 的 7.0.14-8 不被删除"
else
    fail "W6 pin 的 7.0.14-8 不被删除" "仅删除 7.0.14-17" "返回 $status, apt 调用: $(apt_calls)"
fi

echo
echo "通过 $PASS_COUNT 项，失败 $FAIL_COUNT 项"

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
