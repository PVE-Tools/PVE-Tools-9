[根目录](../CLAUDE.md) > **.github**

# .github -- CI/CD 工作流与社区治理

## 模块职责

管理项目的持续集成/持续部署流水线和社区 Issue 模板。三条工作流覆盖 PR 验证、正式发布和测试版发布。

## 入口与启动

| 项目 | 说明 |
|---|---|
| 触发方式 | GitHub Actions，由 push/pull_request 事件触发 |
| 运行环境 | `ubuntu-latest` |
| 权限 | `contents: write`（Release 工作流需要） |

## 工作流清单

### release.yml -- 正式发布工作流

**触发条件**: 推送版本标签 (`v*.*.*`, `*.*.*`, `v*.*.*-stable`, `*.*.*-stable`)

**步骤**:
1. `actions/checkout@v4`（fetch-depth: 0 以获取完整历史）
2. 从 tag 提取版本号
3. **`bash build.sh`** -- 将 lib/ + src/modules/ 组装为 `dist/PVE-Tools.sh`
4. 安装 `shc`（via neurobin/ppa）
5. `shc -f dist/PVE-Tools.sh -o pve-tools` -- 编译为二进制
6. 生成 release notes（基于 git 提交历史）
7. `softprops/action-gh-release@v2` 创建 GitHub Release，上传 `pve-tools` + `dist/PVE-Tools.sh`

**构建产物**:
- `pve-tools` -- 编译后的二进制文件
- `dist/PVE-Tools.sh` -- 拼接后的单文件脚本

### beta-release.yml -- 测试版发布工作流

**触发条件**: 推送 beta/alpha 标签

功能与 release.yml 类似，但标记为 prerelease。

### pr-validation.yml -- PR 验证工作流

**触发条件**: PR 合并到 `main` 或 `beta` 分支

**检查项**:

| 检查 | 命令 | 说明 |
|---|---|---|
| Shellcheck | `shellcheck -f gcc PVE-Tools.sh` | 静态分析，有 error/warning 则失败 |
| 语法检查 | `bash -n PVE-Tools.sh`、`bash -n dev.sh`、`bash -n dist/PVE-Tools.sh` | 先运行 `bash build.sh` 构建再检查 |
| 构建验证 | `bash build.sh` | 验证构建不报错 |
| 版本一致性 | 比较 `lib/config.sh` 中的 `CURRENT_VERSION` 与 `VERSION` 文件 | 不一致则失败 |
| 安全扫描 | grep 检测 `eval`/`source` 使用 | 发现则告警 |

## Issue 模板

| 文件 | 用途 |
|---|---|
| `fast-bugs-report.md` | 快速 Bug 报告 |
| `feature-request.md` | 功能请求 |
| `plugin-submit.md` | 插件提交 |
| `report-bugs.md` | 详细 Bug 报告 |
| `config.yml` | Issue 模板配置 |

## 其他文件

| 文件 | 用途 |
|---|---|
| `FUNDING.yml` | GitHub Sponsors 赞助配置 |

## 关键依赖与配置

- **GitHub Actions**: 免费额度，`ubuntu-latest` runner
- **shc**: 来自 `ppa:neurobin/ppa`，用于 Bash 编译
- **softprops/action-gh-release@v2**: 第三方 GitHub Action，用于创建 Release
- **shellcheck**: Ubuntu 自带或通过 apt 安装

## 测试与质量

CI/CD 本身即为项目的测试与质量保障体系：
- 每次 PR 自动执行静态分析、语法检查、版本一致性校验、安全扫描
- Release 前自动构建并验证构建产物

## 常见问题 (FAQ)

**Q: 为什么 Release 要用 shc 编译？**
shc 将 Bash 脚本编译为二进制文件，提供基础的源码保护，同时便于分发。构建产物 `dist/PVE-Tools.sh` 同时发布以保持 `bash <(curl ...)` 兼容性。

**Q: PR 验证中 build.sh 会失败怎么办？**
检查 lib/ 和 src/modules/ 中的文件是否存在、语法是否正确。`bash -n` 仅检查语法不执行代码。

**Q: 如何添加新的 Issue 模板？**
在 `ISSUE_TEMPLATE/` 目录添加 `.md` 文件并更新 `config.yml` 即可，GitHub 会自动识别。

## 相关文件清单

```
.github/
  workflows/
    release.yml                    # 正式发布工作流
    beta-release.yml               # 测试版发布工作流
    pr-validation.yml              # PR 验证工作流
  ISSUE_TEMPLATE/
    fast-bugs-report.md            # 快速 Bug 报告模板
    feature-request.md             # 功能请求模板
    plugin-submit.md               # 插件提交模板
    report-bugs.md                 # 详细 Bug 报告模板
    config.yml                     # Issue 模板配置
  FUNDING.yml                      # 赞助配置
```

## 变更记录 (Changelog)

| 日期 | 变更 |
|---|---|
| 2026-07-08 | 初始化 .github 模块 CLAUDE.md。PR 验证已适配模块化（build.sh/build -n dist）。Release 已添加 build.sh 步骤。 |
