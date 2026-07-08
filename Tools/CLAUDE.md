[根目录](../CLAUDE.md) > **Tools**

# Tools -- 第三方系统维护工具集

## 模块职责

集成来自 tteck (https://github.com/tteck/Proxmox) 社区的 13 个 Proxmox 系统维护脚本，覆盖系统配置、容器管理、系统维护与监控四大类别。这些脚本独立于主脚本运行，不在 PVE-Tools 主菜单中自动调用。

> 从 v5.0.0 起，主菜单中原有的 tteck 工具入口已替换为 FastPVE。本目录中的脚本如需使用请手动运行。

## 入口与启动

| 项目 | 说明 |
|---|---|
| 总入口 | 各 `.sh` 文件独立运行，无统一入口 |
| 文档 | `Tools/README.md` |
| 占位标记 | `Tools/.gitkeep`（保持空目录纳入 Git） |

### 使用方式

```bash
cd Tools
bash <script-name>.sh
```

## 脚本清单

### 系统配置工具（5个）

| 脚本 | 功能 | 来源 |
|---|---|---|
| `post-pbs-install.sh` | Proxmox Backup Server 安装后配置 | tteck |
| `post-pve-install.sh` | Proxmox VE 安装后配置（换源、更新、基础优化） | tteck |
| `scaling-governor.sh` | CPU 调频策略配置（performance/powersave/ondemand 等） | tteck |
| `microcode.sh` | CPU 微码更新工具 | tteck |
| `kernel-pin.sh` | 固定内核版本，防止自动升级 | tteck |

### 容器管理工具（3个）

| 脚本 | 功能 | 来源 |
|---|---|---|
| `update-lxcs.sh` | 批量更新所有 LXC 容器内系统包 | tteck |
| `cron-update-lxcs.sh` | 配置定时任务自动更新 LXC 容器 | tteck |
| `clean-lxcs.sh` | 清理 LXC 容器缓存和日志 | tteck |

### 系统维护工具（4个）

| 脚本 | 功能 | 来源 |
|---|---|---|
| `host-backup.sh` | Proxmox 宿主机配置备份 | tteck |
| `kernel-clean.sh` | 清理旧内核版本，释放 /boot 空间 | tteck |
| `fstrim.sh` | SSD TRIM 优化，定期执行 discard | tteck |
| `monitor-all.sh` | 系统全局状态监控 | tteck |

### 监控工具（1个）

| 脚本 | 功能 | 来源 |
|---|---|---|
| `netdata.sh` | Netdata 实时监控系统安装与配置 | tteck |

## 关键依赖与配置

- **运行环境**: Proxmox VE 宿主机（Debian 系），root 权限
- **日志文件**: 所有脚本执行日志默认写入 `/var/log/pve-tools.log`
- **外部依赖**: 各脚本各自管理依赖，通常自动通过 apt 安装
- **无统一配置**: 每个脚本独立运行，无共享配置文件

## 数据模型

本模块不涉及持久化数据模型。每个脚本直接操作 Proxmox 系统配置（如 `/etc/apt/sources.list`、`/etc/default/grub`、内核文件等）。

## 测试与质量

- **代码审查**: 脚本来自 tteck 社区，经过社区验证
- **独立测试**: 各脚本可在测试 PVE 环境中单独验证
- **无 CI 覆盖**: 这些脚本不在 `.github/workflows/pr-validation.yml` 的 shellcheck 范围内

## 常见问题 (FAQ)

**Q: 主脚本中还有这些工具吗？**
从 v5.0.0 起，主菜单第 14 项已改为 FastPVE。Tools 目录中的脚本保留供手动使用。

**Q: 这些脚本安全吗？**
来自 tteck/Proxmox（MIT License）社区维护，经过大量用户验证。但执行前仍会显示确认提示，建议先阅读脚本内容。

**Q: 执行日志在哪里？**
默认写入 `/var/log/pve-tools.log`。

## 相关文件清单

```
Tools/
  .gitkeep                        # Git 占位文件
  README.md                       # 本模块说明文档
  post-pbs-install.sh             # PBS 安装后配置
  post-pve-install.sh             # PVE 安装后配置
  scaling-governor.sh             # CPU 调频策略
  microcode.sh                    # CPU 微码更新
  kernel-pin.sh                   # 内核版本固定
  kernel-clean.sh                 # 旧内核清理
  update-lxcs.sh                  # 批量更新 LXC
  cron-update-lxcs.sh            # 定时自动更新 LXC
  clean-lxcs.sh                   # 清理 LXC 缓存
  host-backup.sh                  # 宿主机配置备份
  fstrim.sh                       # SSD TRIM 优化
  monitor-all.sh                  # 全局系统监控
  netdata.sh                      # Netdata 安装配置
```

## 变更记录 (Changelog)

| 日期 | 变更 |
|---|---|
| 2026-07-08 | 更新：项目模块化后 Tools 目录无变化，确认 13 个脚本状态不变 |
| 2026-04-28 | 初始化 Tools 模块 CLAUDE.md |
