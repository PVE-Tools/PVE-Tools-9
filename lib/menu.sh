#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# ============ 统一菜单交互框架 ============
#
# 约定（全项目菜单一致性的唯一事实来源）：
#   - 0 恒为"返回上级"；仅主菜单的 0 表示退出脚本（由 runtime.sh main() 处理）。
#   - 菜单循环统一由 run_menu 驱动：清屏 -> 标题 -> 渲染选项 -> 统一返回项 ->
#     读取（含 EOF / Ctrl+C 守卫）-> 分发 -> pause 节奏控制。
#   - 渲染函数：只打印功能选项（show_menu_option），不打印返回项/页脚/读取提示。
#   - 分发函数：case "$1" 处理选项；无法识别的输入 return 1（由框架统一报错），
#     其余分支默认 return 0；需要向框架报告操作失败时显式 return 2。
#     2 不视为输入错误；菜单继续可用，退出时保留本轮菜单发生过操作失败的状态。
#   - 选 0 返回、或从子菜单退回父菜单时，不再触发"按任意键继续"。

# 当前菜单嵌套深度：主循环为 0，模块顶级菜单为 1，再往下递增
MENU_DEPTH=0
# 置 1 时跳过本轮分发后的 pause（run_menu 退出时自动置位，通知父层菜单）
MENU_SKIP_PAUSE=0

# 统一读取菜单选择：menu_prompt <变量名> <范围串如 "0-5">
# EOF（Ctrl+D/输入流关闭）或输入被 Ctrl+C 中断时视为选择 0（返回上级），杜绝死循环刷屏
menu_prompt() {
    local __var_name="$1"
    local range="$2"
    local __input=""

    echo
    echo -ne "  ${PRIMARY}请选择操作 [${range}]: ${NC}"
    if ! read -r __input; then
        echo
        __input="0"
    fi
    echo
    printf -v "$__var_name" '%s' "$__input"
}

# 统一菜单循环：run_menu <标题> <渲染函数> <分发函数> <范围串>
# 返回项文案按嵌套深度自动生成：模块顶级菜单为"返回主菜单"，更深层为"返回上级菜单"
# 返回：0=正常返回；2=本轮菜单至少一次操作失败（不因随后选0或EOF而抹掉）。
run_menu() {
    local title="$1"
    local render_fn="$2"
    local dispatch_fn="$3"
    local range="$4"
    local choice back_label
    local dispatch_status action_status=0

    MENU_DEPTH=$((MENU_DEPTH + 1))
    if [[ "$MENU_DEPTH" -le 1 ]]; then
        back_label="返回主菜单"
    else
        back_label="返回上级菜单"
    fi

    while true; do
        clear
        show_menu_header "$title"
        "$render_fn"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "$back_label"
        show_menu_footer
        menu_prompt choice "$range"

        if [[ "$choice" == "0" ]]; then
            break
        fi

        MENU_SKIP_PAUSE=0
        dispatch_status=0
        "$dispatch_fn" "$choice" || dispatch_status=$?
        case "$dispatch_status" in
            0) ;;
            2)
                action_status=2
                log_error "操作执行失败，请查看上方错误信息。"
                ;;
            *)
                log_error "无效选择: ${choice:-<空>}"
                log_warn "请输入 [${range}] 范围内的编号"
                ;;
        esac
        if [[ "$MENU_SKIP_PAUSE" -eq 0 ]]; then
            echo
            pause_function
        fi
    done

    MENU_DEPTH=$((MENU_DEPTH - 1))
    MENU_SKIP_PAUSE=1
    return "$action_status"
}

# 统一单值输入：prompt_value <变量名> <提示语> [默认值] [校验函数]
# 有默认值：提示为 "提示语 [默认值]: "，空回车取默认值
# 无默认值：提示为 "提示语 (回车取消): "，空回车视为取消
# 校验函数（可选）：接收输入值，返回非 0 表示无效（原因由校验函数自行打印），将重新输入
# 返回: 0=值已写入变量  2=用户取消或输入流关闭
prompt_value() {
    local __var_name="$1"
    local label="$2"
    local default_value="${3:-}"
    local validator="${4:-}"
    local __input

    while true; do
        if [[ -n "$default_value" ]]; then
            echo -ne "  ${PRIMARY}${label} [${default_value}]: ${NC}"
        else
            echo -ne "  ${PRIMARY}${label} (回车取消): ${NC}"
        fi
        if ! read -r __input; then
            echo
            log_info "输入已取消"
            return 2
        fi
        __input="${__input:-$default_value}"
        if [[ -z "$__input" ]]; then
            log_info "未输入内容，已取消"
            return 2
        fi
        if [[ -n "$validator" ]] && ! "$validator" "$__input"; then
            continue
        fi
        printf -v "$__var_name" '%s' "$__input"
        return 0
    done
}

# 统一是/否询问：prompt_yes_no <提示语> [默认 yes|no]
# 返回: 0=yes  1=no（EOF/输入流关闭一律按 no 处理，保守优先）
# 注意：这是流程中的普通选择题；涉及风险的确认请用 confirm_action / confirm_high_risk_action
prompt_yes_no() {
    local label="$1"
    local default_answer="${2:-no}"
    local __input

    echo -ne "  ${PRIMARY}${label} (yes/no) [${default_answer}]: ${NC}"
    if ! read -r __input; then
        echo
        return 1
    fi
    __input="${__input:-$default_answer}"
    case "$__input" in
        yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

# 统一列表选择器：prompt_pick_from_list <变量名> <提示语> <数组名>
# 打印 1..N 编号列表与 0=返回；选中项内容写入变量
# 返回: 0=已选中  2=用户选 0 返回/输入流关闭（与既有 vm_select_* 选择器约定一致）
prompt_pick_from_list() {
    local __var_name="$1"
    local label="$2"
    local -n __items_ref="$3"
    local __count="${#__items_ref[@]}"
    local __idx __input

    if [[ "$__count" -eq 0 ]]; then
        log_warn "没有可选项"
        return 2
    fi

    echo -e "  ${H2}${label}${NC}"
    for __idx in "${!__items_ref[@]}"; do
        show_menu_option "$((__idx + 1))" "${__items_ref[$__idx]}"
    done
    show_menu_option "0" "返回"

    while true; do
        echo -ne "  ${PRIMARY}请选择序号 [0-${__count}]: ${NC}"
        if ! read -r __input; then
            echo
            return 2
        fi
        __input="${__input:-0}"
        if [[ "$__input" == "0" ]]; then
            return 2
        fi
        if [[ "$__input" =~ ^[0-9]+$ ]] && [[ "$__input" -ge 1 && "$__input" -le "$__count" ]]; then
            printf -v "$__var_name" '%s' "${__items_ref[$((__input - 1))]}"
            return 0
        fi
        log_warn "无效序号: ${__input}，请重新输入"
    done
}

# 长输出分页展示：命令 | show_report
# 交互终端且有 less 时走分页器（上下翻页，q 退出），否则原样输出
show_report() {
    if [[ -t 1 ]] && command -v less >/dev/null 2>&1; then
        less -R
    else
        cat
    fi
}
