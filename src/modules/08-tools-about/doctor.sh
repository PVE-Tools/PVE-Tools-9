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
# ALIAS_RC 文件清单（含无标记 pvetools 别名行，可自动清理）
PVE_TOOLS_DOCTOR_ALIAS_RC_FILES=()
# 含无标记 pvetools 函数定义的 rc 文件（结构复杂，仅提示手动处理）
PVE_TOOLS_DOCTOR_FUNC_RC_FILES=()
# 判定为旧引导/启动器副本的脚本文件（可自动删除）
PVE_TOOLS_DOCTOR_LEGACY_FILES=()
# 完整版副本（多份共存提示，不自动删除）
PVE_TOOLS_DOCTOR_FULL_COPIES=()
# 问题计数
PVE_TOOLS_DOCTOR_ISSUES=0

# 分类脚本文件：full=完整版 / legacy-bootstrap=v10 旧引导（死链） /
# entry-copy=新版启动器副本 / other=无法识别 / missing=不存在
pve_tools_doctor_classify_file() {
    local file_path="$1"

    [[ -f "$file_path" ]] || { echo "missing"; return; }
    if grep -q '^CURRENT_VERSION=' "$file_path" 2>/dev/null; then
        echo "full"
    elif grep -q "$PVE_TOOLS_DOCTOR_LEGACY_URL_PATTERN" "$file_path" 2>/dev/null; then
        echo "legacy-bootstrap"
    elif grep -q "$PVE_TOOLS_DOCTOR_ENTRY_PATTERN" "$file_path" 2>/dev/null; then
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
        echo "$PVE_TOOLS_RC_FILE"
        return
    fi
    rc_file="$(getent passwd root 2>/dev/null | cut -d: -f6)"
    echo "${rc_file:-/root}/.bashrc"
}

# 输出 rc 内容但剔除安装器标记块：标记块内的 alias 由安装器/卸载器管理，
# doctor 只关注用户自建或历史遗留的无标记别名
pve_tools_doctor_rc_unmarked() {
    local rc_file="$1"

    if [[ ! -f "$rc_file" ]]; then
        return 0
    fi
    if grep -q "^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$" "$rc_file" 2>/dev/null; then
        sed "/^# PVE-TOOLS BEGIN $PVE_TOOLS_ALIAS_MARKER\$/,/^# PVE-TOOLS END $PVE_TOOLS_ALIAS_MARKER\$/d" "$rc_file"
    else
        cat -- "$rc_file"
    fi
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
            ;;
    esac

    # 检查 2：rc 文件中的无标记别名（交互 shell 中别名优先于 PATH，是遮蔽主因）
    if [[ -f "$rc_file" ]]; then
        while IFS= read -r alias_line; do
            [[ -z "$alias_line" ]] && continue
            if [[ ${#PVE_TOOLS_DOCTOR_ALIAS_RC_FILES[@]} -eq 0 ]]; then
                PVE_TOOLS_DOCTOR_ALIAS_RC_FILES+=("$rc_file")
            fi
            alias_target="$(pve_tools_doctor_alias_target_path "$alias_line")"
            file_class="$(pve_tools_doctor_classify_file "$alias_target")"
            case "$file_class" in
                legacy-bootstrap|entry-copy)
                    echo -e "${RED}[问题]${NC} ${rc_file} 存在无标记别名指向旧脚本：${alias_line#${alias_line%%[![:space:]]*}}"
                    [[ -f "$alias_target" ]] && PVE_TOOLS_DOCTOR_LEGACY_FILES+=("$alias_target")
                    ;;
                full)
                    echo -e "${YELLOW}[警告]${NC} ${rc_file} 存在无标记别名指向完整版副本：$alias_target（别名优先于命令文件生效）"
                    [[ -f "$alias_target" ]] && PVE_TOOLS_DOCTOR_FULL_COPIES+=("$alias_target")
                    ;;
                *)
                    echo -e "${YELLOW}[警告]${NC} ${rc_file} 存在无法识别的 pvetools 别名：${alias_line#${alias_line%%[![:space:]]*}}"
                    ;;
            esac
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
        done < <(pve_tools_doctor_rc_unmarked "$rc_file" | grep "^[[:space:]]*alias[[:space:]]\+pvetools=" || true)

        # 检查 3：rc 文件中的 pvetools 函数定义（结构复杂，不自动清理）
        if pve_tools_doctor_rc_unmarked "$rc_file" | grep -q "^[[:space:]]*pvetools[[:space:]]*(" 2>/dev/null; then
            echo -e "${YELLOW}[警告]${NC} ${rc_file} 存在 pvetools 函数定义，会遮蔽命令文件，请手动确认处理"
            PVE_TOOLS_DOCTOR_FUNC_RC_FILES+=("$rc_file")
            PVE_TOOLS_DOCTOR_ISSUES=$((PVE_TOOLS_DOCTOR_ISSUES + 1))
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

# 从 rc 文件删除无标记的 pvetools 别名行（保留安装器标记块原样），原子替换并保留属主权限
pve_tools_doctor_remove_unmarked_alias() {
    local rc_file="$1" tmp_rc=""

    tmp_rc="$(mktemp "${rc_file}.XXXXXX")" || {
        display_error "无法创建临时文件以更新 ${rc_file}"
        return 1
    }
    awk -v marker="$PVE_TOOLS_ALIAS_MARKER" '
        $0 == ("# PVE-TOOLS BEGIN " marker) { inblock = 1; print; next }
        $0 == ("# PVE-TOOLS END " marker)   { inblock = 0; print; next }
        !inblock && /^[[:space:]]*alias[[:space:]]+pvetools=/ { next }
        { print }
    ' "$rc_file" > "$tmp_rc" || {
        rm -f -- "$tmp_rc"
        display_error "读取配置文件失败：${rc_file}"
        return 1
    }
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
        "将删除清单中的旧引导/启动器副本文件，并从 rc 文件中删除无标记的 pvetools 别名行。" \
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
    if pve_tools_doctor_scan; then
        pve_tools_doctor_fix
    fi
}
