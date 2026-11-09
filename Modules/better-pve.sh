#!/bin/bash
## name:better-pve Web 界面美化
## author:dbstd2333
## version:0.2.0
## github:https://github.com/dbstd2333/better-pve-web
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 dbstd2333
#
# PVE-Tools 第三方软件市场（Modules）插件：安装 / 卸载 better-pve-web。
# 第 2~5 行是市场解析用的元信息（third_party_market_menu 固定读取 sed -n '2,5p'），
# 因此 SPDX 与版权声明紧随其后。
#
# 安全设计：
# - 只下载固定版本的发布包，并用本文件内置的 SHA-256 校验；本文件随 PVE-Tools 仓库审核分发，
#   因此 GitHub 直连与加速镜像下载到的内容都必须与审核时一致，否则拒绝执行
# - 安装 / 卸载前须输入确认词
# - 安装 / 卸载脚本内部持有 flock 锁、在替换文件前校验未被其他程序改动，安装失败自动回滚

# 市场以 `sh <脚本>` 方式执行插件（Debian 上 sh 为 dash），这里切换到 bash 重新执行自身。
# 本段之前只能使用 POSIX sh 语法。
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -uo pipefail

# ---- 固定版本与校验值（每次升级插件时同步修改）-------------------------------------------------
BPVE_VERSION="0.2.0"
BPVE_SHA256="986b81cbe9d0d87106012ea87cc144dc339b0ced9b56a84c0ae2ecb2f5693a65"
BPVE_ARCHIVE="better-pve-web-${BPVE_VERSION}.tar.gz"
BPVE_URL="https://github.com/dbstd2333/better-pve-web/releases/download/v${BPVE_VERSION}/${BPVE_ARCHIVE}"
BPVE_MIRROR_PREFIX="https://ghfast.top/"

BPVE_OPT_DIR="/opt/better-pve"
BPVE_NODES_PM="/usr/share/perl5/PVE/API2/Nodes.pm"
BPVE_LOG_FILE="/var/log/better-pve-plugin.log"
UI_DIVIDER="------------------------------------------------------------"

WORK_DIR=""

# 初始化颜色；遵循 no-color.org（设置 NO_COLOR 或输出不是终端时禁色）
setup_colors() {
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
        CYAN=$'\033[0;36m'; MAGENTA=$'\033[0;35m'; NC=$'\033[0m'
    else
        RED=""; GREEN=""; YELLOW=""; CYAN=""; MAGENTA=""; NC=""
    fi
}

# 日志：同时写入带时间戳的审计日志 BPVE_LOG_FILE
log_to_file() {
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >> "$BPVE_LOG_FILE" 2>/dev/null || true
}
log_info() { echo -e "${CYAN}[INFO]${NC} $*"; log_to_file INFO "$*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; log_to_file WARN "$*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; log_to_file ERROR "$*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; log_to_file OK "$*"; }

# 从终端读取一行输入（市场执行插件时 stdin 未必是终端）；结果写入变量 $1
read_input() {
    local __var="$1" __prompt="$2" __value=""
    if (true < /dev/tty) 2>/dev/null; then
        printf '%s' "$__prompt" > /dev/tty
        IFS= read -r __value < /dev/tty || __value=""
    else
        printf '%s' "$__prompt"
        IFS= read -r __value || __value=""
    fi
    printf -v "$__var" '%s' "$__value"
}

# 重档确认（与 PVE-Tools confirm_high_risk_action 参数一致）：
# confirm_high_risk_action <动作> <风险> <影响> <建议> <确认词>；输入完全一致才返回 0
confirm_high_risk_action() {
    local action="$1" risk="$2" impact="$3" advice="$4" word="$5" answer=""
    echo "$UI_DIVIDER"
    echo -e "  ${RED}高风险操作确认${NC}"
    echo -e "  动作: $action"
    echo -e "  风险: ${YELLOW}$risk${NC}"
    echo -e "  影响: $impact"
    echo -e "  建议: $advice"
    echo "$UI_DIVIDER"
    read_input answer "请输入确认词 ${MAGENTA}${word}${NC} 继续（其他任意输入取消）: "
    [[ "$answer" == "$word" ]]
}

# 退出时清理临时目录
cleanup() {
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

# 检查运行环境：root、PVE 8.x/9.x、所需命令
check_environment() {
    if [[ "$(id -u)" != "0" ]]; then
        log_error "请以 root 身份运行"
        return 1
    fi
    if ! command -v pveversion >/dev/null 2>&1; then
        log_error "未找到 pveversion，这不是 PVE 系统"
        return 1
    fi
    if ! pveversion 2>/dev/null | grep -Eq 'pve-manager/(8|9)\.'; then
        log_error "仅支持 PVE 8.x/9.x（当前: $(pveversion 2>/dev/null | head -n 1)）"
        return 1
    fi
    local cmd
    for cmd in tar sha256sum flock perl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "缺少命令: $cmd"
            return 1
        fi
    done
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_error "未检测到 curl 或 wget"
        return 1
    fi
    return 0
}

# 下载 URL 到文件：download_file <url> <输出文件>
download_file() {
    local url="$1" out="$2"
    : > "$out"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 120 -o "$out" "$url"
    else
        wget -q --https-only --timeout=120 -O "$out" "$url"
    fi
}

# 校验文件 SHA-256 是否等于内置值：verify_sha256 <文件>
verify_sha256() {
    local actual
    actual="$(sha256sum "$1" | cut -d' ' -f1)"
    if [[ "$actual" != "$BPVE_SHA256" ]]; then
        log_warn "SHA-256 不匹配：期望 $BPVE_SHA256，实际 $actual"
        return 1
    fi
    return 0
}

# 依次尝试 GitHub 直连与加速镜像下载发布包，只接受校验通过的文件；成功后解压并设置 SRC_DIR
fetch_release() {
    local archive url label ok=0
    WORK_DIR="$(mktemp -d /tmp/better-pve-plugin.XXXXXX)" || { log_error "无法创建临时目录"; return 1; }
    archive="$WORK_DIR/$BPVE_ARCHIVE"

    for label in "GitHub" "加速镜像"; do
        url="$BPVE_URL"
        [[ "$label" == "加速镜像" ]] && url="${BPVE_MIRROR_PREFIX}${BPVE_URL}"
        log_info "从 $label 下载 $BPVE_ARCHIVE ..."
        if ! download_file "$url" "$archive"; then
            log_warn "$label 下载失败"
            continue
        fi
        if verify_sha256 "$archive"; then
            ok=1
            break
        fi
        log_warn "$label 返回的文件未通过完整性校验，已丢弃"
    done

    if [[ $ok -ne 1 ]]; then
        log_error "没有获得通过 SHA-256 校验的发布包，已中止（未对系统做任何修改）"
        return 1
    fi
    log_success "SHA-256 校验通过: $BPVE_SHA256"

    mkdir "$WORK_DIR/src"
    if ! tar -xzf "$archive" -C "$WORK_DIR/src" --strip-components=1 --no-same-owner; then
        log_error "解压失败"
        return 1
    fi
    SRC_DIR="$WORK_DIR/src"
    if [[ ! -f "$SRC_DIR/install.sh" ]]; then
        log_error "发布包中没有 install.sh"
        return 1
    fi
    return 0
}

# 当前安装状态描述；后端补丁以 Nodes.pm 中的实际标记为准
installed_status() {
    local status="未安装"
    if [[ -f "$BPVE_OPT_DIR/VERSION" ]]; then
        status="已安装 $(tr -d '[:space:]' < "$BPVE_OPT_DIR/VERSION")"
        if grep -qF '# better-pve:begin' "$BPVE_NODES_PM" 2>/dev/null; then
            status="$status（含后端补丁）"
        else
            status="$status（仅前端）"
        fi
    fi
    echo "$status"
}

# 安装或更新：do_install frontend|backend
do_install() {
    local mode="$1" word risk impact
    if [[ "$mode" == "backend" ]]; then
        word="BPVE-BACKEND"
        risk="修改 PVE 核心文件 Nodes.pm（节点状态接口）、安装 lm-sensors，并重启 pveproxy 与 pvedaemon。"
        impact="修改 index.html.tpl 与 Nodes.pm（均为带标记的独立段落，原文件备份为 .bpve-bak），新增 /opt/better-pve 与 apt 钩子；WebUI 会短暂断开。"
    else
        word="BPVE-INSTALL"
        risk="修改 PVE Web 模板 index.html.tpl，并重启 pveproxy。若之前装过后端补丁，会将其从 Nodes.pm 中移除。"
        impact="新增 /usr/share/pve-manager/{css,js}/better-pve.*、/opt/better-pve 与 apt 钩子；WebUI 会短暂断开。"
    fi

    if ! confirm_high_risk_action \
        "安装 better-pve ${BPVE_VERSION}（$([[ "$mode" == "backend" ]] && echo "含后端补丁" || echo "仅前端")）" \
        "$risk" \
        "$impact" \
        "请通过 SSH 而不是 WebUI 内置 Shell 执行；安装失败会自动回滚，也可随时通过本插件卸载。" \
        "$word"; then
        log_info "已取消安装"
        return 0
    fi

    fetch_release || return 1

    local -a args=()
    [[ "$mode" == "backend" ]] && args+=(--with-backend)
    log_info "执行安装（日志: $BPVE_LOG_FILE）"
    ( cd "$SRC_DIR" && bash ./install.sh ${args[@]+"${args[@]}"} ) 2>&1 | tee -a "$BPVE_LOG_FILE"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "安装失败；安装脚本已自动回滚本次修改，详情见 $BPVE_LOG_FILE"
        return 1
    fi
    log_success "安装完成，请在浏览器中按 Ctrl+F5 强制刷新 PVE 页面"
    return 0
}

# 卸载：调用已安装副本中的 uninstall.sh
do_uninstall() {
    if [[ ! -x "$BPVE_OPT_DIR/uninstall.sh" ]]; then
        log_error "未检测到已安装的 better-pve（$BPVE_OPT_DIR/uninstall.sh 不存在）"
        return 1
    fi
    if ! confirm_high_risk_action \
        "卸载 better-pve" \
        "从 index.html.tpl 与 Nodes.pm 中移除 better-pve 标记段，并重启 pveproxy 与 pvedaemon。" \
        "删除 better-pve 的静态资源、/opt/better-pve 与 apt 钩子；其他工具（如 PVE-Tools 温度监控）对这些文件的修改会保留。" \
        "请通过 SSH 执行；卸载中断后可直接重新运行。" \
        "BPVE-REMOVE"; then
        log_info "已取消卸载"
        return 0
    fi
    bash "$BPVE_OPT_DIR/uninstall.sh" 2>&1 | tee -a "$BPVE_LOG_FILE"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "卸载未完成，详情见 $BPVE_LOG_FILE；可重新运行卸载"
        return 1
    fi
    log_success "卸载完成，请在浏览器中按 Ctrl+F5 强制刷新 PVE 页面"
    return 0
}

# 打印菜单
show_menu() {
    echo "$UI_DIVIDER"
    echo -e "  ${MAGENTA}better-pve Web 界面美化${NC}  插件版本 ${BPVE_VERSION}"
    echo "  暗色主题 / 卡片概览 / 数据中心仪表盘 / 实时速率 / 温度 / 去订阅弹窗"
    echo "  当前状态: $(installed_status)"
    echo "$UI_DIVIDER"
    echo -e "  ${CYAN}1.${NC} 安装或更新（仅前端，不修改 Perl 代码）"
    echo -e "  ${CYAN}2.${NC} 安装或更新（含后端补丁：节点实时速率与温度）"
    echo -e "  ${CYAN}3.${NC} ${RED}卸载${NC}"
    echo -e "  ${CYAN}0.${NC} 返回"
    if grep -qF 'modbyshowtempfreq' "$BPVE_NODES_PM" 2>/dev/null; then
        echo
        echo -e "  ${YELLOW}检测到 PVE-Tools 温度监控已启用：两者可共存，节点面板只显示 PVE-Tools 的温度行${NC}"
    fi
    echo "$UI_DIVIDER"
}

main() {
    setup_colors
    trap cleanup EXIT
    trap 'cleanup; exit 130' INT TERM

    check_environment || return 1
    if [[ ! "$BPVE_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
        log_error "插件内置的 SHA-256 无效，拒绝运行"
        return 1
    fi

    local choice=""
    show_menu
    read_input choice "请选择操作 [0-3]: "
    case "$choice" in
        1) do_install frontend ;;
        2) do_install backend ;;
        3) do_uninstall ;;
        0|"") return 0 ;;
        *) log_error "无效选项: $choice"; return 1 ;;
    esac
}

main "$@"
