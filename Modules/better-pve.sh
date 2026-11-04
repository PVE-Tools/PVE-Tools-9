#!/bin/sh
## name:better-pve Web 界面美化
## author:dbstd2333
## version:0.1.0
## github:https://github.com/dbstd2333/better-pve-web
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 dbstd2333
#
# PVE-Tools 第三方软件市场（Modules）插件：下载 better-pve-web 并安装 / 卸载。
# 市场用 `sh` 执行插件（Debian 上是 dash），因此本脚本只用 POSIX sh 语法。
#
# 可选环境变量：
#   BPVE_REF   要安装的分支或 tag（默认 main）
#   BPVE_REPO  仓库 owner/name（默认 dbstd2333/better-pve-web）

set -u

REPO="${BPVE_REPO:-dbstd2333/better-pve-web}"
REF="${BPVE_REF:-main}"
OPT="/opt/better-pve"
MIRROR_PREFIX="https://ghfast.top/"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$(printf '\033[0;31m'); GREEN=$(printf '\033[0;32m'); YELLOW=$(printf '\033[0;33m')
    CYAN=$(printf '\033[0;36m'); NC=$(printf '\033[0m')
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

info() { printf '%s[better-pve]%s %s\n' "$CYAN" "$NC" "$*"; }
ok() { printf '%s[better-pve]%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s[better-pve] 警告:%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
die() { printf '%s[better-pve] 错误:%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

# 市场执行插件时 stdin 可能不是终端，交互输入统一从 /dev/tty 读
ask() {
    # 在子 shell 里探测：dash 中特殊内建的重定向失败会让整个脚本退出
    if (true < /dev/tty) 2>/dev/null; then
        printf '%s' "$1" > /dev/tty
        IFS= read -r REPLY < /dev/tty || REPLY=''
    else
        printf '%s' "$1"
        IFS= read -r REPLY || REPLY=''
    fi
}

[ "$(id -u)" = "0" ] || die "请以 root 身份运行"
command -v pveversion >/dev/null 2>&1 || die "未找到 pveversion，这不是 PVE 系统"
pveversion 2>/dev/null | grep -Eq 'pve-manager/(8|9)\.' \
    || die "仅支持 PVE 8.x/9.x（当前: $(pveversion 2>/dev/null | head -n 1)）"
command -v tar >/dev/null 2>&1 || die "缺少 tar"
command -v bash >/dev/null 2>&1 || die "缺少 bash"

download() { # download <url> <out>
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 120 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout=120 -O "$2" "$1"
    else
        die "未检测到 curl 或 wget"
    fi
}

WORK=''
cleanup() { if [ -n "$WORK" ]; then rm -rf "$WORK"; fi; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# 下载并解压源码，成功后把源码目录写入 SRC
fetch_source() {
    WORK="$(mktemp -d /tmp/better-pve.XXXXXX)" || die "无法创建临时目录"
    url="https://github.com/$REPO/archive/$REF.tar.gz"
    info "下载 $REPO@$REF ..."
    if ! download "$url" "$WORK/src.tar.gz"; then
        warn "GitHub 直连失败，改用加速镜像"
        download "$MIRROR_PREFIX$url" "$WORK/src.tar.gz" || die "下载失败: $url"
    fi
    mkdir "$WORK/src"
    tar -xzf "$WORK/src.tar.gz" -C "$WORK/src" --strip-components=1 || die "解压失败"
    SRC="$WORK/src"
    [ -f "$SRC/install.sh" ] || die "下载内容中没有 install.sh，REF 是否正确？"
}

do_install() {
    fetch_source
    info "开始安装（版本 $(tr -d '[:space:]' < "$SRC/VERSION")）"
    if [ "$1" = "backend" ]; then
        (cd "$SRC" && bash ./install.sh --with-backend) || die "安装失败"
    else
        (cd "$SRC" && bash ./install.sh) || die "安装失败"
    fi
    ok "完成。请在浏览器中按 Ctrl+F5 强制刷新 PVE 页面"
}

do_uninstall() {
    [ -x "$OPT/uninstall.sh" ] || die "未检测到已安装的 better-pve（$OPT/uninstall.sh 不存在）"
    ask "确认卸载 better-pve？输入 yes 继续: "
    [ "$REPLY" = "yes" ] || { info "已取消"; return 0; }
    bash "$OPT/uninstall.sh" || die "卸载失败"
}

installed="未安装"
if [ -f "$OPT/VERSION" ]; then
    installed="已安装 $(tr -d '[:space:]' < "$OPT/VERSION")"
    grep -q '^BACKEND=1$' "$OPT/config" 2>/dev/null && installed="$installed（含后端补丁）"
fi

echo "-----------------------------------------"
echo "  better-pve Web 界面美化"
echo "  暗色主题 / 卡片概览 / 数据中心仪表盘 / 实时速率 / 温度 / 去订阅弹窗"
echo "  当前状态: $installed"
echo "-----------------------------------------"
echo "  1. 安装或更新（仅前端，不修改 Perl 代码）"
echo "  2. 安装或更新（含后端补丁：节点实时速率与温度，会修改 Nodes.pm 并安装 lm-sensors）"
echo "  3. 卸载"
echo "  0. 返回"
if grep -qF 'modbyshowtempfreq' /usr/share/perl5/PVE/API2/Nodes.pm 2>/dev/null; then
    echo
    echo "  ${YELLOW}检测到 PVE-Tools 温度监控已启用：两者可共存，节点面板只显示 PVE-Tools 的温度行${NC}"
fi
ask "请选择操作 [0-3]: "

case "$REPLY" in
    1) do_install frontend ;;
    2) do_install backend ;;
    3) do_uninstall ;;
    0|'') exit 0 ;;
    *) die "无效选项: $REPLY" ;;
esac
