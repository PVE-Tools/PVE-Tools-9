#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

# CNB 发布流水线脚本：构建 dist 单文件 → 复刻 PR 门禁 → 发布到 dist 分支。
# 仅在 VERSION 文件发生变更的提交上发布，普通提交直接跳过（避免重复发布）。
# 发布语义为覆盖式 latest：dist 分支始终只有最新产物两个文件：
#   PVE-Tools.sh / SHA256SUMS.txt
# 用户侧固定下载地址：https://cnb.cool/PVE-Tools/PVE-Tools-Pro/-/git/raw/dist/PVE-Tools.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# 发布触发判断：仅 VERSION 变更的提交才发布
# ---------------------------------------------------------------------------
if git rev-parse HEAD~1 >/dev/null 2>&1 && git diff --quiet HEAD~1 HEAD -- VERSION; then
    echo "VERSION 未变更，跳过 dist 发布。"
    exit 0
fi

# ---------------------------------------------------------------------------
# 构建与基础校验
# ---------------------------------------------------------------------------
echo "== 构建 dist 单文件 =="
bash build.sh
bash -n dist/PVE-Tools.sh

echo "== 版本一致性 =="
SCRIPT_VERSION=$(grep "CURRENT_VERSION=" lib/config.sh | cut -d'"' -f2)
VERSION_FILE_VERSION=$(cat VERSION)
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

echo "== shellcheck（环境可用时执行）=="
# CNB 容器镜像可能未预装 shellcheck；缺失时跳过，GitHub PR Validation 仍会执行完整检查兜底
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -f gcc PVE-Tools.sh > /tmp/shellcheck_entry.out || true
    cat /tmp/shellcheck_entry.out || true
    if grep -q "error\|warning" /tmp/shellcheck_entry.out; then
        echo "shellcheck 在入口脚本发现 error/warning"
        exit 1
    fi
    find lib src/modules -name '*.sh' -print0 | xargs -0 shellcheck --severity=error -f gcc
    shellcheck -f gcc dist/PVE-Tools.sh > /tmp/shellcheck_dist.out || true
    cat /tmp/shellcheck_dist.out || true
    if grep -q "error\|warning" /tmp/shellcheck_dist.out; then
        echo "shellcheck 在构建产物发现 error/warning"
        exit 1
    fi
else
    echo "shellcheck 不可用，已跳过静态检查。"
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
# dist 分支上一版存在时挂为父提交（历史连续），不存在则为孤儿首提交
DIST_PARENT="$(git rev-parse -q --verify refs/remotes/origin/dist 2>/dev/null || true)"
if [[ -n "$DIST_PARENT" ]]; then
    DIST_COMMIT="$(git commit-tree "$DIST_TREE" -p "$DIST_PARENT" \
        -m "publish: PVE-Tools dist v${VERSION_FILE_VERSION}")"
else
    DIST_COMMIT="$(git commit-tree "$DIST_TREE" \
        -m "publish: PVE-Tools dist v${VERSION_FILE_VERSION}")"
fi
git push -f origin "${DIST_COMMIT}:refs/heads/dist"

echo "dist v${VERSION_FILE_VERSION} 发布完成。"
