#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks
#
# UPS 服务器地址配置（Issue #114）回归测试。
#
# 覆盖：地址校验（主机名 / IPv4 / [IPv6] / :端口 / 非法字符与长度）、
#       无效输入回退 localhost、回环地址判定、NUT 目标拼接，
#       以及 cpu_add 不再硬编码 localhost 的源码级断言。
#
# 只用纯逻辑：不读写 /etc、/var，不执行 apt/dpkg/upsc，也不访问网络。
#
# 用法:
#     bash tests/ups-config-test.sh

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/config.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/core.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/src/modules/01-optimization/cpupower.sh"

PASS_COUNT=0
FAIL_COUNT=0

# 记一条通过用例
pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  PASS  $1"
}

# 记一条失败用例，并打印期望值与实际值
fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  FAIL  $1"
    echo "        期望: $2"
    echo "        实际: $3"
}

# 断言给定命令返回 0
assert_true() {
    local name="$1"
    shift
    if "$@"; then
        pass "$name"
    else
        fail "$name" "返回 0" "返回非 0"
    fi
}

# 断言给定命令返回非 0
assert_false() {
    local name="$1"
    shift
    if "$@"; then
        fail "$name" "返回非 0" "返回 0"
    else
        pass "$name"
    fi
}

# 断言两个字符串相等
assert_eq() {
    if [[ "$2" == "$3" ]]; then
        pass "$1"
    else
        fail "$1" "$2" "$3"
    fi
}

echo "== 合法服务器地址 =="
for host in \
    "localhost" \
    "192.168.1.10" \
    "ups.example.lan" \
    "ups-1.example.com" \
    "[::1]" \
    "[::]" \
    "[fe80::1]" \
    "[2001:db8::10]" \
    "[2001:db8:0:0:0:0:0:1]" \
    "[::ffff:192.168.1.1]" \
    "192.168.1.10:3493" \
    "localhost:3493" \
    "[::1]:3493" \
    "[fe80::1]:1234"; do
    assert_true "接受地址: $host" nut_ups_is_valid_host "$host"
done

echo "== 非法服务器地址 =="
for host in \
    "" \
    "ho st" \
    "host;id" \
    'host"quote' \
    'host`id`' \
    'host$HOME' \
    "ups@host" \
    "host:0" \
    "host:65536" \
    "host:123456" \
    "host:34x3" \
    "-host" \
    "host-" \
    "[::1" \
    "::1" \
    "[:]" \
    "[12345::1]" \
    "[1::2::3]" \
    "[1:2:3:4:5:6:7:8:9]" \
    "host:12:34" \
    "[zzzz::1]"; do
    assert_false "拒绝地址: ${host:-<空>}" nut_ups_is_valid_host "$host"
done

long_host="$(printf '%0.sa' {1..256})"
assert_false "拒绝超长地址 (256 字符)" nut_ups_is_valid_host "$long_host"

echo "== 回退与规范化 =="
resolved=""
if resolved="$(nut_ups_resolve_host " 192.168.1.10 ")"; then
    status=0
else
    status=1
fi
assert_eq "去除首尾空白" "192.168.1.10" "$resolved"
assert_eq "有效地址返回状态 0" "0" "$status"

resolved=""
if resolved="$(nut_ups_resolve_host "")"; then
    status=0
else
    status=1
fi
assert_eq "空输入回退 localhost" "localhost" "$resolved"
assert_eq "空输入返回状态 1" "1" "$status"

resolved=""
if resolved="$(nut_ups_resolve_host "bad host")"; then
    status=0
else
    status=1
fi
assert_eq "非法输入回退 localhost" "localhost" "$resolved"
assert_eq "非法输入返回状态 1" "1" "$status"

echo "== 回环地址判定 =="
for host in \
    "localhost" \
    "localhost:3493" \
    "127.0.0.1" \
    "127.0.0.1:3493" \
    "127.0.1.1" \
    "127.0.1.1:3493" \
    "127.255.255.254" \
    "[::1]" \
    "[::1]:3493"; do
    assert_true "识别为回环: $host" nut_ups_is_loopback_host "$host"
done
for host in \
    "192.168.1.10" \
    "192.168.1.10:3493" \
    "128.0.0.1" \
    "127.0.0.1.evil" \
    "ups.example.lan" \
    "[fe80::1]" \
    "localhost.evil"; do
    assert_false "不识别为回环: $host" nut_ups_is_loopback_host "$host"
done

echo "== NUT 目标拼接 =="
assert_eq "默认目标" "ups@localhost" "$(nut_ups_build_target "ups" "localhost")"
assert_eq "IPv4 目标" "ups@192.168.1.10" "$(nut_ups_build_target "ups" "192.168.1.10")"
assert_eq "IPv4 带端口目标" "apc@192.168.1.10:3493" "$(nut_ups_build_target "apc" "192.168.1.10:3493")"
assert_eq "IPv6 带端口目标" "ups@[fe80::1]:3493" "$(nut_ups_build_target "ups" "[fe80::1]:3493")"

echo "== cpu_add 不再硬编码 localhost =="
cpupower_src="$REPO_ROOT/src/modules/01-optimization/cpupower.sh"
if grep -Fq 'nut_ups_target="$(nut_ups_build_target "$nut_ups_name" "$nut_ups_host")"' "$cpupower_src"; then
    pass "cpu_add 使用 nut_ups_build_target 拼接目标"
else
    fail "cpu_add 使用 nut_ups_build_target 拼接目标" "存在拼接调用" "未找到拼接调用"
fi
if grep -Fq 'nut_ups_target="${nut_ups_name}@localhost"' "$cpupower_src"; then
    fail "已移除 localhost 硬编码" "无硬编码" "仍存在 nut_ups_target=\"\${nut_ups_name}@localhost\""
else
    pass "已移除 localhost 硬编码"
fi

echo
if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "FAIL: $FAIL_COUNT 项失败，$PASS_COUNT 项通过" >&2
    exit 1
fi
echo "OK: $PASS_COUNT 项全部通过"