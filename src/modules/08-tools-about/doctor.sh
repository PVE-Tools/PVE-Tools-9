#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# 安装环境诊断 (doctor)：定位「已安装 pvetools 但运行的不是新版」类环境问题。
# 典型成因：v10 时代的旧引导脚本残留（自身或用户自建的 alias/副本指向它）。
# 旧引导从 raw main 拉取 dist/PVE-Tools.sh，而 dist/ 自 v10.2.1 起不入库，
# 该 URL 必然 404，因此含此特征的脚本可安全判定为失效残留。

# 旧引导脚本特征：v10.x 引导专用变量（下载 raw main 的 dist 路径，自 v10.2.1 起
# dist 不入库，该路径必然 404），完整版 dist 与新版入口均不含此变量
PVE_TOOLS_DOCTOR_LEGACY_URL_PATTERN="PVE_TOOLS_REMOTE_BASE"
# 引导脚本特征：不含 CURRENT_VERSION 但含入口引导变量（启动器副本而非完整版）
PVE_TOOLS_DOCTOR_ENTRY_PATTERN="PVE_TOOLS_REMOTE_DIST_URL"

# 扫描结果（全局，供 fix 阶段复用）：
# ALIAS_RC 文件清单（含可自动清理的无标记 pvetools 别名行）
PVE_TOOLS_DOCTOR_ALIAS_RC_FILES=()
# 待删除的精确别名行，每项格式 "rc 文件路径<US 分隔符>别名行原文"；
# 仅收录指向旧引导/启动器副本的行，指向其他目标的别名一律保留并提示手动处理
PVE_TOOLS_DOCTOR_ALIAS_REMOVE=()
# 含无标记 pvetools 函数定义的 rc 文件（结构复杂，仅提示手动处理）
PVE_TOOLS_DOCTOR_FUNC_RC_FILES=()
# 判定为旧引导/启动器副本的脚本文件（可自动删除）
PVE_TOOLS_DOCTOR_LEGACY_FILES=()
# 完整版副本（多份共存提示，不自动删除）
PVE_TOOLS_DOCTOR_FULL_COPIES=()
# 问题计数
PVE_TOOLS_DOCTOR_ISSUES=0

# 分类脚本文件：full=完整版 / legacy-bootstrap=v10 旧引导（死链） /
# entry-copy=新版启动器副本 / other=无法识别 / missing=不存在。
# 引导/启动器特征均锚定为行首赋值语句，避免注释、字符串等无关出现位置误判
pve_tools_doctor_classify_file() {
    local file_path="$1"

    [[ -f "$file_path" ]] || { echo "missing"; return; }
    if grep -q '^CURRENT_VERSION=' "$file_path" 2>/dev/null; then
        echo "full"
    elif grep -q "^[[:space:]]*${PVE_TOOLS_DOCTOR_LEGACY_URL_PATTERN}=" "$file_path" 2>/dev/null; then
        echo "legacy-bootstrap"
    elif grep -q "^[[:space:]]*${PVE_TOOLS_DOCTOR_ENTRY_PATTERN}=" "$file_path" 2>/dev/null; then
        echo "entry-copy"
    else
        echo "other"
    fi
}

# 解析 root 的 rc 文件：安装器元数据记录值优先，缺失时回退 getent 显式解析
# （与入口安装器/self-update 的默认值逻辑保持一致）
pve_tools_doctor_resolve_rc_file() {
    local rc_file=""

    pve_tools_load_installer_meta
    if [[ -n "${PVE_TOOLS_RC_FILE:-}" ]]; then
        rc_file="$PVE_TOOLS_RC_FILE"
    else
        rc_file="$(getent passwd root 2>/dev/null | cut -d: -f6)"
        rc_file="${rc_file:-/root}/.bashrc"
    fi
    # rc 文件可能是指向真实配置的符号链接（如 dotfiles 托管）：解析到真实目标，
    # 后续备份、读取与替换都落在目标文件上，避免 mv 把链接替换成普通文件
    readlink -f -- "$rc_file" 2>/dev/null || echo "$rc_file"
}

# 判定 rc 文件别名标记块状态：返回 0 = 无块或 BEGIN/END 配对完整；
# 返回 1 = 标记数量不等或顺序错乱（如孤儿 END 出现在 BEGIN 之前），此时
# 范围删除会从 BEGIN 一路波及文件尾或漏删块后内容，自动过滤与清理均应拒绝
# （与入口安装器 pve_tools_entry_remove_alias_block / 卸载器同一守卫语义）
pve_tools_doctor_rc_block_complete() {
    local rc_file="$1"

    # 配对 + 顺序双重校验：数量相等、首个标记为 BEGIN、末个标记为 END
    # 才判定完整（覆盖 END 在前、标记交织等乱序形态）
    awk -v marker="$PVE_TOOLS_ALIAS_MARKER" '
        $0 == ("# PVE-TOOLS BEGIN " marker) { begin++; if (first == "") first = "B"; last = "B"; next }
        $0 == ("# PVE-TOOLS END " marker)   { end++;   if (first == "") first = "E"; last = "E" }
        END {
            if (begin == 0 && end == 0) { exit 0 }
            exit (begin == end && first == "B" && last == "E") ? 0 : 1
        }
    ' "$rc_file" 2>/dev/null
}

# 输出 rc 内容但剔除安装器标记块：标记块内的 alias 由安装器/卸载器管理，
# doctor 只关注用户自建或历史遗留的无标记别名。
# awk 状态机与 pve_tools_doctor_remove_unmarked_alias 的删除范围严格一致：
# 「scan 能看到的块外别名」即「fix 会删的别名」。块不完整时（守卫在 scan 中
# 先行拒绝）块内残留可能混入输出，但不参与收集与清理
pve_tools_doctor_rc_unmarked() {
    local rc_file="$1"

    [[ -f "$rc_file" ]] || return 0
    awk -v marker="$PVE_TOOLS_ALIAS_MARKER" '
        $0 == ("# PVE-TOOLS BEGIN " marker) { inblock = 1; next }
        $0 == ("# PVE-TOOLS END " marker)   { inblock = 0; next }
        !inblock { print }
    ' "$rc_file" 2>/dev/null
}

# 从 alias 行提取脚本路径（取值中最后一个以 / 开头的 .sh 路径），失败输出空
pve_tools_doctor_alias_target_path() {
    local alias_line="$1" target=""

    target="$(printf '%s\n' "$alias_line" | grep -o '/[^"'"'"' :]*\.sh' | tail -n 1)"
    echo "${target:-}"
}

# 扫描全部检查点并打印诊断报告，同时填充全局结果数组。
# 返回 0 表示发现需处理的问题，1 表示环境干净
pve_tools_doctor_scan() {
    PVE_TOOLS_DOCTOR_ALIAS_RC_FILES=()
    PVE_TOOLS_DOCTOR_ALIAS_REMOVE=()
    PVE_TOOLS_DOCTOR_FUNC_RC_FILES=()
    PVE_TOOLS_DOCTOR_LEGACY_FILES=()
    PVE_TOOLS_DOCTOR_FULL_COPIES=()
    PVE_TOOLS_DOCTOR_ISSUES=0

    local rc_file="" bin_class="" file_path="" file_class="" alias_line="" alias_target=""
    local -a candidate_paths=()

    rc_file="$(pve_tools_doctor_resolve_rc_file)"

    echo "$UI_HEADER"
    echo -e "${GREEN}PVE-Tools 安装环境诊断${NC}"
    echo "$UI_DIVIDER"

    # 检查 1：系统命令文件本体
    bin_class="$(pve_tools_doctor_classify_file "$PVE_TOOLS_BIN_PATH")"
    case "$bin_class" in
        full)
            echo -e "${GREEN}[正常]${NC} 命令文件 $PVE_TOOLS_BIN_PATH 为完整版 (v$(grep -m1 '^CURRENT_VERSION=' "$PVE_TOOLS_BIN_PATH" | cut -d'"' -f2))"
            ;;
        missing)
            echo -e "${YELLOW}[提示]${NC} 未安装系统命令 $PVE_TOOLS_BIN_PATH"
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            ;;
        legacy-bootstrap)
            echo -e "${RED}[问题]${NC} 命令文件 $PVE_TOOLS_BIN_PATH 是 v10 旧引导脚本（下载死链，必然 404）"
            PVE_TOOLS_DOCTOR_LEGACY_FILES+=("$PVE_TOOLS_BIN_PATH")
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            ;;
        entry-copy)
            echo -e "${RED}[问题]${NC} 命令文件 $PVE_TOOLS_BIN_PATH 是启动器副本而非完整版，无法独立工作"
            PVE_TOOLS_DOCTOR_LEGACY_FILES+=("$PVE_TOOLS_BIN_PATH")
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            ;;
        *)
            echo -e "${YELLOW}[警告]${NC} $PVE_TOOLS_BIN_PATH 存在但无法识别为 PVE-Tools 文件，已跳过"
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            ;;
    esac

    # 检查 2：rc 文件中的无标记别名（交互 shell 中别名优先于 PATH，是遮蔽主因）
    if [[ -f "$rc_file" ]]; then
        # 标记块不完整（标记缺失/数量不等/顺序错乱）时无法区分托管与遗留别名，
        # 自动清理会误删托管别名：单独告警并跳过该 rc 文件的别名/函数收集，留给用户手动处理
        local block_incomplete=0
        if ! pve_tools_doctor_rc_block_complete "$rc_file"; then
            echo -e "${YELLOW}[警告]${NC} ${rc_file} 中别名标记块不完整（标记缺失或顺序错乱），无法区分托管与遗留别名，请手动检查该文件"
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            block_incomplete=1
        fi
        if [[ "$block_incomplete" -eq 0 ]]; then
            # 仅指向旧引导/启动器副本的别名允许自动删除；指向完整版副本或无法
            # 识别目标的别名可能是用户自建，只提示不删除，避免误动用户配置
            local rc_has_removable=0
            while IFS= read -r alias_line; do
                [[ -z "$alias_line" ]] && continue
                alias_target="$(pve_tools_doctor_alias_target_path "$alias_line")"
                file_class="$(pve_tools_doctor_classify_file "$alias_target")"
                case "$file_class" in
                    legacy-bootstrap|entry-copy)
                        echo -e "${RED}[问题]${NC} ${rc_file} 存在无标记别名指向旧脚本：${alias_line#${alias_line%%[![:space:]]*}}"
                        [[ -f "$alias_target" ]] && PVE_TOOLS_DOCTOR_LEGACY_FILES+=("$alias_target")
                        PVE_TOOLS_DOCTOR_ALIAS_REMOVE+=("${rc_file}"$'\x1f'"${alias_line}")
                        rc_has_removable=1
                        ;;
                    full)
                        echo -e "${YELLOW}[警告]${NC} ${rc_file} 存在无标记别名指向完整版副本：$alias_target（别名优先于命令文件生效，已保留，请手动确认处理）"
                        [[ -f "$alias_target" ]] && PVE_TOOLS_DOCTOR_FULL_COPIES+=("$alias_target")
                        ;;
                    *)
                        echo -e "${YELLOW}[警告]${NC} ${rc_file} 存在无法识别的 pvetools 别名：${alias_line#${alias_line%%[![:space:]]*}}（已保留，请手动确认处理）"
                        ;;
                esac
                PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            done < <(pve_tools_doctor_rc_unmarked "$rc_file" | grep "^[[:space:]]*alias[[:space:]]\+pvetools=" || true)
            if [[ "$rc_has_removable" -eq 1 ]]; then
                PVE_TOOLS_DOCTOR_ALIAS_RC_FILES+=("$rc_file")
            fi

            # 检查 3：rc 文件中的 pvetools 函数定义（结构复杂，不自动清理）。
            # 兼容 pvetools() 与 function pvetools() 两种声明形态
            if pve_tools_doctor_rc_unmarked "$rc_file" | grep -qE '^[[:space:]]*(function[[:space:]]+)?pvetools[[:space:]]*\(' 2>/dev/null; then
                echo -e "${YELLOW}[警告]${NC} ${rc_file} 存在 pvetools 函数定义，会遮蔽命令文件，请手动确认处理"
                PVE_TOOLS_DOCTOR_FUNC_RC_FILES+=("$rc_file")
                PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
            fi
        fi
    fi

    # 检查 4：常见位置的旧脚本副本
    candidate_paths=(
        "/usr/local/bin/pvetools"
        "/usr/bin/pvetools"
        "/bin/pvetools"
        "/root/PVE-Tools.sh"
        "/root/bin/pvetools"
        "${PVE_TOOLS_OPT_DIR}/PVE-Tools.sh"
        "${HOME:-/root}/PVE-Tools.sh"
    )
    for file_path in "${candidate_paths[@]}"; do
        [[ -f "$file_path" ]] || continue
        [[ "$file_path" == "$PVE_TOOLS_BIN_PATH" ]] && continue
        # alias 模式的托管目标：rc 中存在配对完整的托管标记块（安装确实处于
        # alias 托管状态）且文件确为完整版时，是合法安装产物，不作为残留/多副本
        # 上报；其余情况按普通候选处理。仅凭 rc_block_complete 不够——它对"完全
        # 无块"的 rc 也返回 0，会把无托管关系的孤儿副本错误豁免
        if [[ "$file_path" == "${PVE_TOOLS_OPT_DIR}/PVE-Tools.sh" ]] \
            && grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null \
            && grep -q "^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null \
            && pve_tools_doctor_rc_block_complete "$rc_file" \
            && grep -q '^CURRENT_VERSION=' "$file_path" 2>/dev/null; then
            echo -e "${GREEN}[正常]${NC} alias 托管副本 $file_path 为完整版 (v$(grep -m1 '^CURRENT_VERSION=' "$file_path" | cut -d'"' -f2))"
            continue
        fi
        file_class="$(pve_tools_doctor_classify_file "$file_path")"
        case "$file_class" in
            legacy-bootstrap)
                echo -e "${RED}[问题]${NC} 发现 v10 旧引导脚本副本：$file_path（下载死链，必然 404）"
                PVE_TOOLS_DOCTOR_LEGACY_FILES+=("$file_path")
                PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
                ;;
            entry-copy)
                echo -e "${YELLOW}[警告]${NC} 发现启动器副本：$file_path（仅用于远程下载，不能作为本地命令运行）"
                PVE_TOOLS_DOCTOR_LEGACY_FILES+=("$file_path")
                PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
                ;;
            full)
                if [[ ! " ${PVE_TOOLS_DOCTOR_FULL_COPIES[*]} " == *" $file_path "* ]]; then
                    echo -e "${YELLOW}[提示]${NC} 存在另一份完整版副本：$file_path（多份共存时升级可能只更新其中一份）"
                    PVE_TOOLS_DOCTOR_FULL_COPIES+=("$file_path")
                    PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
                fi
                ;;
        esac
    done

    echo "$UI_DIVIDER"
    if [[ "$PVE_TOOLS_DOCTOR_ISSUES" -eq 0 ]]; then
        echo -e "${GREEN}诊断完成：未发现影响 pvetools 命令的环境问题。${NC}"
        return 1
    fi
    echo -e "${YELLOW}诊断完成：发现 $PVE_TOOLS_DOCTOR_ISSUES 个需要处理的问题。${NC}"
    return 0
}

# 从 rc 文件删除扫描阶段标记为可清理的无标记 pvetools 别名行（精确整行匹配，
# 仅限指向旧引导/启动器副本的行），保留安装器标记块与其他别名原样，
# 原子替换并保留属主权限
pve_tools_doctor_remove_unmarked_alias() {
    local rc_file="$1" tmp_rc="" lines_tmp="" entry="" us=$'\x1f'

    # 标记块不完整时拒绝清理：状态机会从 BEGIN 一路保持到文件尾，
    # 块后的无标记别名删不到；且无法区分托管与遗留别名，防止误删托管内容
    if ! pve_tools_doctor_rc_block_complete "$rc_file"; then
        display_error "标记块不完整，已拒绝清理：${rc_file}" "请手动检查该文件中的别名标记块。"
        return 1
    fi

    # 收集该文件待删除的精确别名行到临时清单；清单为空则无事可做（幂等）
    lines_tmp="$(mktemp)" || {
        display_error "无法创建临时文件以更新 ${rc_file}"
        return 1
    }
    for entry in "${PVE_TOOLS_DOCTOR_ALIAS_REMOVE[@]}"; do
        [[ "${entry%%"$us"*}" == "$rc_file" ]] || continue
        printf '%s\n' "${entry#*"$us"}" >> "$lines_tmp"
    done
    if [[ ! -s "$lines_tmp" ]]; then
        rm -f -- "$lines_tmp"
        return 0
    fi

    tmp_rc="$(mktemp "${rc_file}.XXXXXX")" || {
        rm -f -- "$lines_tmp"
        display_error "无法创建临时文件以更新 ${rc_file}"
        return 1
    }
    # FNR==NR 先读入精确删除清单（完整匹配整行）；标记块内一律保留
    awk -v marker="$PVE_TOOLS_ALIAS_MARKER" '
        FNR == NR { remove[$0] = 1; next }
        $0 == ("# PVE-TOOLS BEGIN " marker) { inblock = 1; print; next }
        $0 == ("# PVE-TOOLS END " marker)   { inblock = 0; print; next }
        !inblock && ($0 in remove) { next }
        { print }
    ' "$lines_tmp" "$rc_file" > "$tmp_rc" || {
        rm -f -- "$lines_tmp" "$tmp_rc"
        display_error "读取配置文件失败：${rc_file}"
        return 1
    }
    rm -f -- "$lines_tmp"
    if ! chmod --reference="$rc_file" "$tmp_rc" || ! chown --reference="$rc_file" "$tmp_rc" || ! mv -f "$tmp_rc" "$rc_file"; then
        rm -f -- "$tmp_rc"
        display_error "无法替换配置文件：${rc_file}"
        return 1
    fi
}

# 按扫描结果执行清理：重档确认 → 备份 rc → 删无标记别名行 → 删旧引导文件 → 收尾提示
pve_tools_doctor_fix() {
    if ! confirm_high_risk_action \
        "清理旧引导残留与遮蔽别名" \
        "将删除清单中的旧引导/启动器副本文件，并从 rc 文件中删除指向这些残留的无标记 pvetools 别名行（指向其他目标的别名不会自动删除）。" \
        "误删自建别名或脚本需要手动重建；rc 文件修改前会自动备份到 /var/backups/pve-tools/。" \
        "请确认清理清单只包含 PVE-Tools 相关的旧残留，不含你手动部署的其他程序。" \
        "DOCTOR-FIX"; then
        return 0
    fi

    local rc_file="" file_path="" failures=0
    local -a processed_rc_files=()

    for rc_file in "${PVE_TOOLS_DOCTOR_ALIAS_RC_FILES[@]}"; do
        if ! backup_file "$rc_file"; then
            echo -e "${YELLOW}警告：备份 ${rc_file} 失败，已跳过该文件的别名清理，请手动处理。${NC}" >&2
            failures=1
            continue
        fi
        if pve_tools_doctor_remove_unmarked_alias "$rc_file"; then
            echo -e "${GREEN}已清理${NC} ${rc_file} 中的无标记 pvetools 别名行"
            processed_rc_files+=("$rc_file")
        else
            failures=1
        fi
    done

    for file_path in "${PVE_TOOLS_DOCTOR_LEGACY_FILES[@]}"; do
        if rm -f -- "$file_path"; then
            echo -e "${GREEN}已删除${NC} $file_path"
        else
            echo -e "${RED}错误：删除失败：${NC} $file_path" >&2
            failures=1
        fi
    done

    # 收尾提示：当前 shell 可能残留命令 hash 与已加载别名
    echo
    echo -e "请执行 ${CYAN}hash -r${NC} 或重新打开终端，使命令解析立即生效。"
    if [[ "$(pve_tools_doctor_classify_file "$PVE_TOOLS_BIN_PATH")" != "full" ]]; then
        echo -e "当前系统命令不是完整版，建议重新执行官方安装命令：" >&2
        echo -e "  ${CYAN}bash <(curl -sSL https://pve.u3u.icu/PVE-Tools.sh)${NC}" >&2
    fi
    if [[ ${#PVE_TOOLS_DOCTOR_FULL_COPIES[@]} -gt 0 ]]; then
        echo -e "提示：以下完整版副本未自动删除，确认不再需要后可手动清理：${PVE_TOOLS_DOCTOR_FULL_COPIES[*]}" >&2
    fi

    if [[ "$failures" -ne 0 ]]; then
        display_error "清理未完全完成" "请根据上方错误信息手动处理残留项。"
        return 1
    fi
    display_success "安装环境清理完成" "重新运行 pvetools 即使用最新版本。"
}

pve_tools_doctor_run() {
    pve_tools_doctor_scan || return 0
    # 仅存在无需/无法自动清理的问题（如函数定义、标记块不完整、多副本共存提示）时
    # 不进入清理流程，避免弹出高风险确认却无事可做
    if [[ ${#PVE_TOOLS_DOCTOR_ALIAS_RC_FILES[@]} -eq 0 && ${#PVE_TOOLS_DOCTOR_LEGACY_FILES[@]} -eq 0 ]]; then
        echo -e "${YELLOW}发现的问题不涉及可自动清理项，请按上方诊断报告手动处理。${NC}"
        return 0
    fi
    pve_tools_doctor_fix
}
