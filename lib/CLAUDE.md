[根目录](../CLAUDE.md) > **lib**

# lib -- 基础设施层

## 模块职责

提供 PVE Tools Pro 全部功能模块所需的基础设施函数与全局变量，零业务逻辑。按固定顺序加载：config.sh -> core.sh -> network.sh -> runtime.sh。

## 入口与启动

| 项目 | 说明 |
|---|---|
| 加载方式 | 由 `PVE-Tools.sh`（生产）或 `dev.sh`（开发）按固定顺序 source |
| 加载顺序 | `config.sh` -> `core.sh` -> `network.sh` -> `runtime.sh`（严格） |
| 对外暴露 | 全部函数和全局变量对后续加载的 `src/modules/` 可见 |

## 文件清单

### config.sh -- 全局变量与常量（约 254 行）

| 类别 | 变量 | 说明 |
|---|---|---|
| 版本信息 | `CURRENT_VERSION`, `BUILD_NICKNAME`, `VERSION_FILE_URL`, `UPDATE_FILE_URL`, `PVE_TOOLS_SCRIPT_URL` | 版本号、更新 URL |
| 镜像源注册表 | `MIRROR_NAMES[]`, `MIRROR_IDS[]`, `MIRROR_DEBIAN_URIS[]`, `MIRROR_SECURITY_URIS[]`, `MIRROR_PVE_URIS[]`, `MIRROR_CEPH_URIS[]`, `MIRROR_CT_URIS[]` | 20+ 个镜像源（官方/阿里云/腾讯云/清华/中科大等） |
| 镜像选择状态 | `MIRROR_SELECTED_DEBIAN`, `MIRROR_SELECTED_SECURITY`, `MIRROR_SELECTED_PVE`, `MIRROR_SELECTED_CEPH`, `MIRROR_SELECTED_CT` | 当前选中的镜像索引 |
| 网络检测 | `CF_TRACE_URL`, `GITHUB_MIRROR_PREFIX`, `USER_COUNTRY_CODE`, `NETWORK_MODE`, `IS_OFFLINE_MODE`, `USE_MIRROR_FOR_UPDATE` | Cloudflare 地区检测、镜像加速 |
| URL 常量 | `FASTPVE_INSTALLER_URL`, `COOLERCONTROL_*_URL`, `NVIDIA_*_URL`, `THIRD_PARTY_*_URL` | 各功能的外部资源地址 |
| 路径常量 | `VM_CONFIG_EXPORT_DIR`, `VM_BACKUP_CRON_FILE`, `HOST_NETWORK_*_FILE`, `PVE_CLUSTER_FIREWALL_FILE`, `PVE_KVM_ROM_DIR` | 运行时文件路径 |
| PVE 版本 | `PVE_VERSION_DETECTED`, `PVE_MAJOR_VERSION` | 运行时检测结果 |
| 安全 | `RISK_ACK_BYPASS`, `DEBUG_MODE`, `LEGAL_VERSION` | 风险控制标志 |

### core.sh -- 核心工具函数（约 507 行）

| 函数 | 说明 |
|---|---|
| `setup_colors()` | 颜色系统初始化，支持 `NO_COLOR` 环境变量 |
| `log_info()`, `log_warn()`, `log_error()`, `log_step()`, `log_success()`, `log_tips()` | 统一日志（带时间戳，写入 `/var/log/pve-tools.log`） |
| `display_error()`, `display_success()` | 带提示的增增强错误/成功反馈 |
| `confirm_action()` | 通用确认提示（输入 'yes'） |
| `confirm_high_risk_action()` | 高风险确认（需输入指定确认词如 `CONFIRM`） |
| `vm_show_data_risk_banner()` | VM 数据风险横幅 |
| `ensure_legal_acceptance()` | 许可条款首次接受检查 |
| `backup_file()` | 配置文件备份到 `/var/backups/pve-tools/` |
| `pve_tools_download_url()`, `pve_tools_download_file()` | curl/wget 封装的下载工具 |
| `pve_tools_choose_update_urls()`, `pve_tools_version_gt()` | 更新 URL 选择与版本比较 |
| `apply_block()`, `remove_block()` | 标记配置块写入/删除（`# PVE-TOOLS BEGIN/END`） |
| `grub_add_param()`, `grub_remove_param()` | GRUB 内核参数幂等管理 |
| `show_progress()`, `update_progress()`, `show_status()`, `show_progress_bar()` | 进度指示与状态反馈 |
| `pause_function()` | "按任意键继续..." |
| `show_menu_header()`, `show_menu_footer()`, `show_menu_option()` | 统一菜单 UI |

### network.sh -- 网络基础设施（约 218 行，仅头部已读）

| 函数 | 说明 |
|---|---|
| `detect_network_region()` | Cloudflare Trace 检测用户地区（CN 自动启用镜像） |
| `fetch_session_tip()` | 一言 API 获取每日提示 |
| `network_show_diagnostics()` | 网络诊断（IP/路由/DNS） |
| `network_can_access_internet()`, `network_offline_guard()` | 连通性检测与离线模式 |
| `disable_ups_service()`, `enable_ups_service()`, `show_ups_diagnostics()` | NUT UPS 服务管理 |
| `mirror_*()` 系列函数 | 镜像源选择系统（URI 查询、选择、重置、汇总、推荐提示） |
| `select_mirror()` | 镜像统一选择入口 |
| `show_banner()` | 启动横幅显示 |

### runtime.sh -- 运行时守卫与主入口（约 235 行）

| 函数 | 说明 |
|---|---|
| `check_root()` | root 权限检查 |
| `check_debug_mode()` | 解析 `--i-know-what-i-do` 和 `--debug` 参数 |
| `check_packages()` | 依赖包检查（sudo, curl） |
| `check_pve_version()` | PVE 版本检测（非 PVE9 环境拦截高风险操作） |
| `block_non_pve9_destructive()` | 非 PVE9 环境拦截一键优化/换源/升级等破坏性操作 |
| `show_menu()` | 主菜单（10 个功能入口 + 一言 Tips） |
| `main()` | **脚本主入口**：权限检查 -> 许可确认 -> 调试模式 -> PVE 版本 -> 网络检测 -> 一言 -> 更新检查 -> 主循环 |

## 关键依赖与配置

- **运行环境**: Proxmox VE 9.x (Debian 13 Trixie)，root 权限
- **外部依赖**: `curl` 或 `wget`（网络操作）、`sudo`（权限提升）
- **加载顺序严格**: `config.sh` 必须先于 `core.sh` 加载（全局变量依赖）；`runtime.sh` 最后加载（包含 `main()` 函数）
- **全局变量**: 所有以大写字母开头的变量为全局变量，`src/modules/` 中所有脚本均可直接访问

## 数据模型

本模块不涉及持久化数据。全局变量在脚本运行期间存在于内存中。`/var/lib/pve-tools/legal_acceptance_*` 文件用于记录许可条款接受状态。

## 测试与质量

- **语法检查**: `bash -n` 对每个 `lib/*.sh` 文件
- **静态分析**: `shellcheck` 覆盖（需配合 `--source-path` 处理跨文件引用）
- **CI 覆盖**: 所有 lib 文件在 `pr-validation.yml` 的 shellcheck 范围内

## 常见问题 (FAQ)

**Q: 为什么加载顺序很重要？**
`config.sh` 定义全局变量，`core.sh` 的 `setup_colors()` 和日志函数依赖颜色变量，`network.sh` 的镜像选择函数依赖 `core.sh` 中的 UI 函数，`runtime.sh` 的 `main()` 调用 `network.sh` 和 `core.sh` 中的函数。

**Q: 可以在 src/modules/ 中重新加载 lib 文件吗？**
不需要。`PVE-Tools.sh` 和 `dev.sh` 在加载任何模块之前已经 source 了所有 lib 文件，所有函数和变量对后续加载的模块全局可见。

**Q: config.sh 中新增镜像源如何操作？**
在每个并行数组末尾追加对应元素即可。`MIRROR_NAMES`、`MIRROR_IDS`、`MIRROR_*_URIS` 数组的索引一一对应。

## 相关文件清单

```
lib/
  config.sh                       # 全局变量与常量（254行）
  core.sh                         # 核心工具函数（507行）
  network.sh                      # 网络检测与镜像选择（~218行+镜像函数）
  runtime.sh                      # 运行时守卫与 main()（235行）
```

## 变更记录 (Changelog)

| 日期 | 变更 |
|---|---|
| 2026-07-08 | 初始化 lib 模块 CLAUDE.md（模块化重构新增模块） |
