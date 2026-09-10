#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# CNB 发布流水线脚本：构建 dist 单文件 → 复刻 PR 门禁 → 发布到 dist 分支。
# 触发条件：VERSION 变更，或 dist 分支产物版本落后/缺失（自愈补发）。
# 发布语义为覆盖式 latest：dist 分支始终只有最新产物两个文件：
#   PVE-Tools.sh / SHA256SUMS.txt
# 用户侧固定下载地址：https://cnb.cool/PVE-Tools/PVE-Tools-Pro/-/git/raw/dist/PVE-Tools.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# 复用仓库既有语义化版本比较 pve_tools_version_gt（strip pre-release + sort -V，
# 空值 fail-closed）。ci 脚本不进 dist，直接 source 共享实现避免逻辑漂移
# shellcheck source=lib/core.sh
source lib/core.sh

# ---------------------------------------------------------------------------
# 发布触发判断：VERSION 变更，或 dist 产物版本落后/缺失时自愈补发。
# 仅看 VERSION diff 会让 CI 失败恢复、审查修复等“内容已变但版本号未动”的
# 提交永远无法补发 dist，导致线上产物静默落后于源码。
# ---------------------------------------------------------------------------
VERSION_FILE_VERSION=$(cat VERSION)
if [ -z "$VERSION_FILE_VERSION" ]; then
    echo "VERSION 文件为空，无法判定发布条件，跳过发布（fail-closed）。"
    exit 0
fi
NEED_PUBLISH=false
if ! git rev-parse HEAD~1 >/dev/null 2>&1; then
    echo "单提交（无 HEAD~1），无法比对 VERSION diff，保守起见执行发布。"
    NEED_PUBLISH=true
elif ! git diff --quiet HEAD~1 HEAD -- VERSION; then
    NEED_PUBLISH=true
else
    # 自愈检查：仅当 dist 分支缺失，或本地版本严格更新于 dist 产物时补发；
    # 版本相同或远端更新则跳过，防止覆盖（如 hotfix 直推的更新产物）
    git fetch -q origin dist 2>/dev/null || true
    if git rev-parse -q --verify FETCH_HEAD >/dev/null 2>&1; then
        DIST_ONLINE_VERSION="$(git show FETCH_HEAD:PVE-Tools.sh 2>/dev/null \
            | grep -m1 '^CURRENT_VERSION=' | sed 's/^CURRENT_VERSION=//' | tr -d '"')"
        if [ -z "$DIST_ONLINE_VERSION" ]; then
            echo "dist 产物存在但版本无法解析，新旧关系未知，跳过发布（fail-closed）。"
            exit 0
        fi
        if pve_tools_version_gt "$VERSION_FILE_VERSION" "$DIST_ONLINE_VERSION"; then
            echo "dist 产物版本($DIST_ONLINE_VERSION)落后于源码版本($VERSION_FILE_VERSION)，自愈补发。"
            NEED_PUBLISH=true
        else
            echo "dist 产物版本($DIST_ONLINE_VERSION)不落后于源码版本($VERSION_FILE_VERSION)，跳过发布。"
            exit 0
        fi
    else
        echo "dist 分支不存在，执行首次发布。"
        NEED_PUBLISH=true
    fi
fi
if [ "$NEED_PUBLISH" != true ]; then
    echo "VERSION 未变更且 dist 产物已是最新，跳过 dist 发布。"
    exit 0
fi

# ---------------------------------------------------------------------------
# 构建与基础校验
# ---------------------------------------------------------------------------
echo "== 构建与语法校验 =="
bash build.sh
# 逐个源文件与产物都做语法检查（build.sh 只拼接不校验，源文件语法错误需在此拦下）
# find + -print0 递归覆盖所有层级的 shell 脚本，文件名带空格也安全
while IFS= read -r -d '' src_file; do
    bash -n "$src_file" || { echo "语法检查失败：$src_file"; exit 1; }
done < <(find PVE-Tools.sh lib src/modules -type f -name '*.sh' -print0)
bash -n dist/PVE-Tools.sh

echo "== 版本一致性 =="
SCRIPT_VERSION=$(grep "CURRENT_VERSION=" lib/config.sh | cut -d'"' -f2)
# VERSION_FILE_VERSION 已在触发判断段读取
if [ "$SCRIPT_VERSION" != "$VERSION_FILE_VERSION" ]; then
    echo "版本不一致: lib/config.sh($SCRIPT_VERSION) != VERSION($VERSION_FILE_VERSION)"
    exit 1
fi
if ! head -1 UPDATE | grep -qF "$VERSION_FILE_VERSION"; then
    echo "UPDATE 首行未包含当前版本 $VERSION_FILE_VERSION，更新日志已脱节"
    exit 1
fi

echo "== 构建产物与源码函数集合一致性 =="
# 断言 lib/ 与 src/modules/ 中定义的每个函数都进入了构建产物（双向一致）
diff <(grep -rhoE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' lib src/modules --include='*.sh' | sort -u) \
     <(grep -hoE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' dist/PVE-Tools.sh | sort -u) \
    || { echo "函数集合不一致（< 仅源码有 / > 仅产物有）"; exit 1; }

echo "== 安全扫描 =="
# 与 GitHub PR Validation 同款门禁：对构建产物扫描真实危险模式，命中即失败
if grep -nE '(^|[^a-zA-Z_.])eval([^a-zA-Z_]|$)' dist/PVE-Tools.sh; then
    echo "检测到 eval 使用：本项目约定禁止 eval"
    exit 1
fi
if grep -nE 'rm -rf +\$' dist/PVE-Tools.sh; then
    echo "检测到未加引号且以变量开头的 rm -rf 路径"
    exit 1
fi
if grep -nE '^[[:space:]]*(source|\.)[[:space:]]' dist/PVE-Tools.sh; then
    echo "构建产物中不应存在 source 语句"
    exit 1
fi

echo "== shellcheck（缺失时自动安装，仍缺失则拒绝发布）=="
# 发布门禁 fail-closed：shellcheck 不可用时先尝试自动安装，仍不可用则中止发布，
# 绝不允许无静态检查的产物进入 dist 分支
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck 未安装，尝试自动安装……"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1 || true
        apt-get install -y -qq shellcheck >/dev/null 2>&1 || true
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache shellcheck >/dev/null 2>&1 || true
    fi
fi
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck 不可用且自动安装失败：发布门禁无法满足，拒绝发布"
    exit 1
fi
if ! shellcheck -f gcc PVE-Tools.sh > /tmp/shellcheck_entry.out; then
    cat /tmp/shellcheck_entry.out || true
    echo "shellcheck 在入口脚本发现问题（error+warning 严格档）"
    exit 1
fi
find lib src/modules -name '*.sh' -print0 | xargs -0 shellcheck --severity=error -f gcc
# 产物为全库拼接单文件：error+warning 档不可用——拼接物存在跨函数同名变量误报
# （SC2178/SC2128 仅 dist 报、源码不报），且源码大量 warning 级遗留（SC2155 风格、
# SC1111 中文文案 unicode 引号、SC2034 跨文件引用误报）会继承进产物。
# 因此产物与源码 lib/modules 同用 error 档拦真实危险；入口单文件维持严格档。
if ! shellcheck --severity=error -f gcc dist/PVE-Tools.sh > /tmp/shellcheck_dist.out; then
    cat /tmp/shellcheck_dist.out || true
    echo "shellcheck 在构建产物发现 error"
    exit 1
fi

# ---------------------------------------------------------------------------
# 生成校验和并发布到 dist 分支（覆盖式单提交，latest 语义）
# ---------------------------------------------------------------------------
echo "== 生成 SHA256SUMS =="
sha256sum dist/PVE-Tools.sh > dist/SHA256SUMS.txt
cat dist/SHA256SUMS.txt

echo "== 发布到 dist 分支 =="
git config user.name "pve-tools-ci"
git config user.email "ci@noreply.cnb.cool"
# 用临时 index + plumbing 直接构造发布提交：不 checkout、不触碰当前工作区，
# dist 分支始终只含 PVE-Tools.sh / SHA256SUMS.txt 两个文件（覆盖式 latest 语义）
PUBLISH_INDEX="$(mktemp)"
DIST_BLOB_SCRIPT="$(git hash-object -w dist/PVE-Tools.sh)"
DIST_BLOB_SUMS="$(git hash-object -w dist/SHA256SUMS.txt)"
GIT_INDEX_FILE="$PUBLISH_INDEX" git read-tree --empty
GIT_INDEX_FILE="$PUBLISH_INDEX" git update-index --add \
    --cacheinfo "100644,${DIST_BLOB_SCRIPT},PVE-Tools.sh" \
    --cacheinfo "100644,${DIST_BLOB_SUMS},SHA256SUMS.txt"
DIST_TREE="$(GIT_INDEX_FILE="$PUBLISH_INDEX" git write-tree)"
rm -f "$PUBLISH_INDEX"
# dist 分支远端当前值：显式 fetch 一次（浅克隆可能没有 remote-tracking ref），
# 同时用作发布提交的父提交与 force-with-lease 的期望值
git fetch -q origin dist 2>/dev/null || true
DIST_PARENT="$(git rev-parse -q --verify refs/remotes/origin/dist 2>/dev/null \
    || git rev-parse -q --verify FETCH_HEAD 2>/dev/null || true)"
if [[ -n "$DIST_PARENT" ]]; then
    DIST_COMMIT="$(git commit-tree "$DIST_TREE" -p "$DIST_PARENT" \
        -m "publish: PVE-Tools dist v${VERSION_FILE_VERSION}")"
else
    DIST_COMMIT="$(git commit-tree "$DIST_TREE" \
        -m "publish: PVE-Tools dist v${VERSION_FILE_VERSION}")"
fi
# force-with-lease 防止并发/陈旧流水线覆盖更新的产物：远端 dist 当前值与预期
# 不符（已被别处更新）时推送失败；空期望值要求远端尚无 dist 分支
if [[ -n "$DIST_PARENT" ]]; then
    git push --force-with-lease="refs/heads/dist:${DIST_PARENT}" origin "${DIST_COMMIT}:refs/heads/dist"
else
    git push --force-with-lease="refs/heads/dist:" origin "${DIST_COMMIT}:refs/heads/dist"
fi

echo "dist v${VERSION_FILE_VERSION} 发布完成。"
