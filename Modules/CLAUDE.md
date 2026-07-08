[根目录](../CLAUDE.md) > **Modules**

# Modules -- 第三方插件市场与模块

## 模块职责

提供 PVE Tools Pro 的第三方插件/模块市场。主脚本通过 GitHub API 自动扫描本目录中的 `.sh` 脚本，根据脚本头部元信息（name/author/version/github）展示并允许用户选择执行。同时存放附加二进制资源（如 NVIDIA vGPU Unlock .so 文件）。

## 入口与启动

| 项目 | 说明 |
|---|---|
| 发现机制 | 主脚本通过 GitHub API 获取 `Modules/` 树结构，自动发现 `.sh` 文件 |
| 元信息格式 | 脚本第 2-5 行必须包含 `## name:`、`## author:`、`## version:`、`## github:` 注释 |
| 执行入口 | 用户在主菜单的"第三方工具集"中选择对应插件执行 |
| 下载方式 | 从 `https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/Modules/<name>.sh` 下载 |

### 插件元信息模板

```bash
#!/bin/bash
## name:插件名称
## author:作者名
## version:1.0.0
## github:https://github.com/xxx/xxx
```

## 当前模块清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `install-zsh.sh` | Bash 脚本 | ZSH 安装脚本 v3.0 (by Maple)，自动安装 oh-my-zsh 并配置 |
| `VGPU/libvgpu_unlock_rs_20230207_44d5bb3.so` | 二进制 (.so) | NVIDIA vGPU Unlock 补丁库，用于解锁消费级 GPU 的 vGPU 功能 |

### install-zsh.sh 概述

- **作者**: Maple
- **版本**: 3.0
- **功能**: 在 Debian 系系统上自动安装 ZSH + oh-my-zsh
- **流程**: 环境预检(检查是否为 Debian) -> 网络诊断与镜像选择 -> 安装 ZSH -> 安装 oh-my-zsh -> 配置主题和插件
- **特点**: 支持检测 GitHub 连通性并自动切换镜像源

### VGPU/libvgpu_unlock_rs.so

- **来源**: 基于 Rust 重写的 vgpu_unlock 项目（第三方开源项目）
- **用途**: 用作 NVIDIA vGPU 破解的共享库
- **大小**: 较大二进制文件，仅记录路径不读取内容
- **风险**: 主脚本对此功能采用"文档引导优先"策略，先全屏警告并引导到 Wiki 文章后再继续

## 关键依赖与配置

| 依赖 | 说明 |
|---|---|
| GitHub API | 主脚本通过 `GET /repos/PVE-Tools/PVE-Tools-9/git/trees/main?recursive=1` 发现模块 |
| raw.githubusercontent.com | 模块脚本的下载源 |
| 主脚本配置变量 | `THIRD_PARTY_MODULES_TREE_API_MAIN_URL`、`THIRD_PARTY_MODULES_RAW_BASE_URL` |

## 数据模型

插件元信息数据结构（从脚本头部注释解析）:

```
name: string      # 插件名称
author: string    # 作者名
version: string   # 版本号
github: string    # GitHub 项目地址
```

## 测试与质量

- **插件审核**: 通过 GitHub PR 或 Issue Template 提交，由维护者人工审核
- **执行前风险确认**: 主脚本在执行任何第三方模块前强制要求用户确认
- **无自动化测试**: 模块为第三方贡献，无 CI 覆盖

## 常见问题 (FAQ)

**Q: 如何提交新插件？**
两种方式：
1. Fork 仓库 -> 添加 `.sh` 到 `Modules/` -> 提交 PR（推荐）
2. 在 GitHub Issues 选择"插件提交"模板，填写元信息和脚本内容

**Q: 插件需要遵守什么规范？**
- 文件名以 `.sh` 结尾
- 第 2-5 行包含元信息（name/author/version/github）
- 高风险操作必须在脚本中给出交互确认

**Q: VGPU 模块如何工作？**
主脚本不再自动执行 vGPU 配置。用户通过主菜单进入后，会先看到全屏警告和 Wiki 链接，确认后手动操作。`.so` 文件作为可选资源供高级用户使用。

## 相关文件清单

```
Modules/
  install-zsh.sh                  # ZSH 安装插件 v3.0
  VGPU/
    libvgpu_unlock_rs_20230207_44d5bb3.so  # NVIDIA vGPU Unlock 库（二进制）
```

## 变更记录 (Changelog)

| 日期 | 变更 |
|---|---|
| 2026-07-08 | 更新：项目模块化后 Modules 目录无变化，install-zsh.sh 和 VGPU 状态不变 |
| 2026-04-28 | 初始化 Modules 模块 CLAUDE.md |
