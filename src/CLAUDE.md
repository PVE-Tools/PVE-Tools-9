[根目录](../CLAUDE.md) > [lib](../lib/) > **src/modules**

# src/modules -- 功能模块层

## 模块职责

承载 PVE Tools Pro 全部业务逻辑，按主菜单编号拆分为 10 个子模块。每个子模块的 `init.sh` 为菜单入口函数，其余文件按功能领域进一步拆分。所有脚本由 `PVE-Tools.sh` 或 `dev.sh` 在 lib/ 加载完成后统一 source。

## 入口与启动

| 项目 | 说明 |
|---|---|
| 加载方式 | `find src/modules -name '*.sh' -print0 | sort -z` 递归加载 |
| 加载顺序 | 按文件路径名排序（`sort -z`），同一子目录内 `init.sh` 通常先加载 |
| 构建时 | `build.sh` 按同样顺序拼接到 `dist/PVE-Tools.sh` |

## 子模块概览

| 编号 | 目录 | 主菜单项 | 文件数 | 复杂度 |
|---|---|---|---|---|
| 1 | `01-optimization/` | 日常优化与通知 | 6 | 中等 |
| 2 | `02-sources/` | 软件源与系统升级 | 4 | 低 |
| 3 | `03-boot-kernel/` | 启动与内核管理 | 3 | 中等 |
| 4 | `04-gpu-passthrough/` | 硬件直通与显卡 | 12 | **高** |
| 5 | `05-vm-container/` | 虚拟机运维与导入 | 15 | **高** |
| 6 | `06-networking/` | 宿主机网络与防火墙 | 10 | **高** |
| 7 | `07-storage-disk/` | 存储与磁盘维护 | 6 | 中等 |
| 8 | `08-tools-about/` | 诊断工具与项目信息 | 3 | 低 |
| 9 | `09-security/` | 安全中心 | 3 | 中等 |
| 10 | `10-third-party/` | 第三方工具 | 4 | 低 |

---

## 01-optimization -- 日常优化与通知

**菜单入口**: `menu_optimization()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_optimization()` | 二级菜单：弹窗/优化/温度/电源/邮件 |
| `popup.sh` | `remove_subscription_popup()`, `restore_proxmoxlib()`, `reinstall_pve_webui_packages()` | 删除/恢复订阅弹窗 |
| `tune.sh` | `quick_setup()` | 一键优化（换源+删弹窗+更新） |
| `cpupower.sh` | `cpupower()`, `cpu_add()`, `cpu_del()`, `show_grub_config()`, `backup_grub_with_note()`, `list_grub_backups()`, `restore_grub_backup()` | CPU 电源模式 + GRUB 备份管理 |
| `temperature.sh` | `temp_monitoring_menu()` | 温度监控管理（CPU/硬盘） |
| `email.sh` | `pve_mail_notification_setup()`, `pve_mail_send_test()`, `pve_mail_configure_postfix_smtp()` | 邮件通知配置（SMTP/Postfix） |

**依赖**: 仅依赖 `lib/`，无跨模块依赖。

---

## 02-sources -- 软件源与系统升级

**菜单入口**: `menu_sources_updates()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_sources_updates()` | 二级菜单：换源/更新/升级 |
| `mirrors.sh` | `change_sources()` | 更换软件源（修改 `/etc/apt/sources.list`） |
| `update.sh` | `update_system()` | 系统软件包更新 |
| `upgrade-pve.sh` | `pve8_to_pve9_upgrade()` | PVE 8.x 升级到 9.x |

**依赖**: `lib/` 中的镜像选择函数（`select_mirror*` 系列）和 `block_non_pve9_destructive()`。

---

## 03-boot-kernel -- 启动与内核管理

**菜单入口**: `menu_boot_kernel()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_boot_kernel()` | 二级菜单：内核管理/GRUB 配置 |
| `kernel.sh` | `kernel_management_menu()`, `install_kernel()`, `set_default_kernel()`, `remove_old_kernels()`, `sync_kernel_update()` | 内核安装/切换/清理/同步 |
| `grub.sh` | `update_grub_config()` | GRUB 配置更新 |

**依赖**: `lib/core.sh` 中的 `grub_add_param()`、`grub_remove_param()`、`backup_file()`。

---

## 04-gpu-passthrough -- 硬件直通与显卡

**菜单入口**: `menu_gpu_passthrough()` 定义于 `init.sh`  
**复杂度**: 最高模块之一，12 个文件，约 200+ 个函数

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_gpu_passthrough()`, `menu_disk_controller_passthrough()` | 主菜单 + 磁盘/控制器子菜单 |
| `iommu.sh` | `iommu_is_enabled()`, `enable_pass()`, `disable_pass()`, `hw_passth()`, `list_storage_controllers()` | IOMMU 基础设施与硬件直通一键配置 |
| `intel-sriov.sh` | `igpu_sriov_setup()` | Intel 核显 SR-IOV 虚拟化 |
| `intel-gvtg.sh` | `igpu_gvtg_setup()` | Intel 核显 GVT-g 虚拟化 |
| `intel-legacy.sh` | `intel_gpu_passthrough()`, `restore_qemu_kvm()` | Intel 核显直通（修改版 QEMU） |
| `igpu-shared.sh` | `igpu_management_menu()`, `igpu_verify()`, `igpu_remove()`, `restore_igpu_config()` | iGPU 共享管理（被 intel-sriov/gvtg 复用） |
| `nvidia.sh` | `nvidia_gpu_management_menu()`, `nvidia_gpu_passthrough_vm()`, `nvidia_driver_switch_menu()`, `nvidia_setup_vgpu_unlock()` | NVIDIA 显卡直通/驱动管理/vGPU |
| `amd-dgpu.sh` | `amd_gpu_management_menu()`, `amd_gpu_passthrough_vm()`, `amd_host_prepare_for_passthrough()` | AMD 独显直通 |
| `amd-igpu.sh` | `amd_igpu_management_menu()`, `amd_igpu_passthrough_vm()`, `amd_igpu_check_romfile()` | AMD 核显直通（需 ROM/vBIOS） |
| `rdm.sh` | `rdm_single_disk_attach()`, `rdm_single_disk_detach()`, `rdm_discover_whole_disks()` | RDM（裸磁盘映射）直通 |
| `controller.sh` | `storage_controller_passthrough()`, `nvme_passthrough()` | PCIe/NVMe 控制器直通 |
| `boot-assist.sh` | `boot_config_assistant()`, `detect_disk_boot_mode()` | 引导配置辅助（GRUB/systemd-boot 检测） |

**跨文件内部依赖**:
- `nvidia.sh` 中的 `nvidia_select_vmid()`、`nvidia_get_pci_ids()` 等被 `amd-dgpu.sh` 和 `amd-igpu.sh` 复用
- `iommu.sh` 中的 `iommu_is_enabled()` 被 `rdm.sh`、`controller.sh` 等复用

---

## 05-vm-container -- 虚拟机运维与导入

**菜单入口**: `menu_vm_container()` 定义于 `init.sh`  
**复杂度**: 最高模块之二，15 个文件

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_vm_container()`, `vm_advanced_operations_menu()` | 主菜单 + 高级运维子菜单 |
| `fastpve.sh` | `fastpve_quick_download_menu()` | FastPVE 快速下载 VM |
| `schedule.sh` | `manage_vm_schedule()` | VM 定时开关机 |
| `img-import.sh` | `img_convert_import_menu()`, `img_convert_and_import_to_vm()` | IMG 镜像导入（转 QCOW2/RAW） |
| `storage-helper.sh` | `vm_select_storage_by_content()`, `pve_storage_content_path()`, `vm_list_storages_by_content()` | 存储辅助函数（被多文件复用） |
| `backup.sh` | `vm_backup_restore_menu()`, `vm_backup_create()`, `vm_schedule_backup_menu()` | VM 备份与定时备份 |
| `restore.sh` | `vm_restore_from_backup()`, `vm_config_io_menu()`, `vm_export_config()`, `vm_import_config()` | VM 恢复与配置导入导出 |
| `clone.sh` | `vm_clone_vm()`, `vm_convert_to_template()` | VM 克隆与模板转换 |
| `cloudinit.sh` | `vm_template_cloudinit_menu()`, `vm_cloudinit_configure()`, `vm_cloud_image_to_template()` | Cloud-Init 配置与云镜像模板 |
| `snapshot.sh` | `vm_snapshot_menu()`, `vm_create_snapshot()`, `vm_rollback_snapshot()` | 快照管理（创建/删除/回滚） |
| `disk.sh` | `vm_disk_management_menu()`, `vm_add_disk()`, `vm_remove_disk()`, `vm_resize_disk()`, `vm_move_disk()` | VM 磁盘管理 |
| `network.sh` | `vm_startup_network_menu()`, `vm_add_network()`, `vm_remove_network()`, `vm_modify_network()` | VM 网络管理 |
| `migrate.sh` | `vm_cluster_migrate()` | 集群内 VM 迁移 |
| `garbage-cleanup.sh` | `garbage_cleanup_menu()`, `garbage_cleanup_basic()`, `garbage_cleanup_prune_backups()`, `garbage_cleanup_orphan_disk_report()` | 垃圾清理（缓存/备份/快照/孤立磁盘） |

**跨文件内部依赖**: `storage-helper.sh` 中的存储查询函数被 `backup.sh`、`disk.sh`、`cloudinit.sh`、`restore.sh`、`migrate.sh` 广泛复用。

---

## 06-networking -- 宿主机网络与防火墙

**菜单入口**: `menu_host_networking()` 定义于 `init.sh`  
**复杂度**: 最高模块之三，10 个文件

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_host_networking()`, `host_network_show_risk_banner()` | 主菜单 + 风险横幅 |
| `interface.sh` | `host_network_get_all_interface_names()`, `host_network_show_current_overview()`, `host_network_select_interface_name()` | 网卡接口基础查询与选择 |
| `addressing.sh` | `host_network_configure_interface_addressing()`, `host_network_build_*_stanza()` | IP 配置（静态 IPv4/IPv6/DHCP/SLAAC） |
| `bridge.sh` | `host_network_create_bridge()`, `host_network_delete_bridge()`, `host_network_bridge_menu()` | 网桥管理 |
| `vlan.sh` | `host_network_create_vlan()`, `host_network_delete_vlan()`, `host_network_vlan_menu()` | VLAN 子接口管理 |
| `bond.sh` | `host_network_create_bond()`, `host_network_delete_bond()`, `host_network_bond_menu()` | Bond 管理（mode 0/1/4/6） |
| `mac-bind.sh` | `host_network_create_mac_binding()`, `host_network_delete_mac_binding()`, `host_network_mac_binding_menu()` | MAC 地址绑定（systemd link） |
| `firewall.sh` | `host_firewall_menu()`, `host_firewall_add_security_group_rule()`, `host_firewall_export_ruleset()` | PVE 防火墙管理 |
| `ipv6-helper.sh` | `ipv6_helper_menu()`, `ipv6_helper_configure_passthrough()`, `ipv6_helper_configure_nat6()` | IPv6 助手（透传/NAT6/连通性测试） |
| `diagnostic.sh` | `netdiag_toolbox_menu()`, `netdiag_run_traceroute()`, `netdiag_quick_stack_check()` | 网络诊断工具箱（traceroute/mtr/nmap/tcpdump） |

**跨文件内部依赖**: `interface.sh` 中的接口查询函数被 `addressing.sh`、`bridge.sh`、`vlan.sh`、`bond.sh`、`mac-bind.sh`、`ipv6-helper.sh` 广泛复用。所有网络修改操作通过 `host_network_commit_candidate()` 统一提交。

---

## 07-storage-disk -- 存储与磁盘维护

**菜单入口**: `menu_storage_disk()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_storage_disk()` | 二级菜单（7 个选项） |
| `query.sh` | `pve_storage_location_panel()` | 存储位置查询面板 |
| `mount.sh` | `pve_storage_mount_wizard()` | 磁盘挂载向导（复用 ext4/xfs 分区） |
| `local-lvm.sh` | `merge_local_storage()` | 合并 local 与 local-lvm |
| `ceph.sh` | `ceph_management_menu()`, `pve9_ceph()`, `remove_ceph()` | Ceph 管理（安装/卸载/换源） |
| `swap.sh` | `remove_swap()` | 删除 Swap 分区 |

**依赖**: 仅依赖 `lib/`，垃圾清理的 `garbage_cleanup_menu()` 实际位于 `05-vm-container/garbage-cleanup.sh`。

---

## 08-tools-about -- 诊断工具与项目信息

**菜单入口**: `menu_tools_about()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `menu_tools_about()`, `show_menu_rescue()` | 二级菜单 + 救砖工具箱 |
| `sysinfo.sh` | `show_system_info()` | 系统信息概览 |
| `self-update.sh` | `check_update()`, `pve_tools_local_update()`, `pve_tools_local_uninstall()` | 本地脚本更新/卸载 |

**依赖**: 仅依赖 `lib/`。

---

## 09-security -- 安全中心

**菜单入口**: `security_center_menu()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `security_center_menu()` | 二级菜单 |
| `audit.sh` | `security_risk_check()`, `security_list_public_listeners()` | 安全风险检查（只读报告） |
| `ssh-hardening.sh` | `security_ssh_hardening()`, `security_install_fail2ban_if_needed()` | SSH 一键加固（端口/密钥/fail2ban） |

**依赖**: 仅依赖 `lib/`。

---

## 10-third-party -- 第三方工具

**菜单入口**: `third_party_tools_menu()` 定义于 `init.sh`

| 文件 | 核心函数 | 功能 |
|---|---|---|
| `init.sh` | `third_party_tools_menu()` | 二级菜单 |
| `marketplace.sh` | `third_party_market_menu()` | 第三方软件市场（Modules 插件） |
| `coolercontrol.sh` | `coolercontrol_manager_menu()`, `coolercontrol_install()`, `coolercontrol_uninstall()` | CoolerControl 风扇控制管理 |
| `community.sh` | `third_party_community_scripts_info()` | 社区脚本集合信息 |

**依赖**: 仅依赖 `lib/`。

---

## 关键依赖与配置

- **lib/ 先决条件**: 所有模块均依赖 `lib/config.sh`（全局变量）和 `lib/core.sh`（日志/UI/备份函数）
- **模块间交叉依赖**（仅 04/05/06 存在）:
  - `04-gpu-passthrough`: nvidia.sh 的辅助函数被 amd-*.sh 复用；iommu.sh 被多个子模块复用
  - `05-vm-container`: storage-helper.sh 被 7 个同模块文件复用
  - `06-networking`: interface.sh 被 6 个同模块文件复用
- **无跨模块依赖**: 模块 01/02/03/07/08/09/10 仅依赖 lib/，不存在模块间引用

## 测试与质量

- **语法检查**: `bash -n` 对每个 `src/modules/**/*.sh` 文件
- **静态分析**: `shellcheck` 覆盖所有模块文件（CI 中强制通过）
- **构建验证**: `bash build.sh && bash -n dist/PVE-Tools.sh` 验证拼接正确性
- **功能测试**: 人工在 PVE 9.x 环境验证 `bash dev.sh`

## 常见问题 (FAQ)

**Q: 新增功能模块如何操作？**
1. 在 `src/modules/` 下创建新目录（如 `11-new-feature/`）
2. 编写 `init.sh`（菜单入口函数）和功能文件
3. 在 `lib/runtime.sh` 的 `show_menu()` 和 `main()` 的 case 中添加对应选项
4. `build.sh` 会自动扫描并包含新文件

**Q: 为什么 init.sh 和其他文件分开？**
`init.sh` 仅包含菜单入口函数，功能实现放在独立文件中。这确保了单个文件不至于过大，也便于独立维护和测试各功能模块。

**Q: 跨文件函数调用如何处理 source 顺序？**
不需要显式 source。所有模块文件在入口处一次性全部 source，且 `sort -z` 保证 `init.sh` 优先加载，因此同模块内的交叉引用天然可用。

## 相关文件清单

```
src/modules/
  01-optimization/          (6 文件) -- 日常优化与通知
  02-sources/               (4 文件) -- 软件源与系统升级
  03-boot-kernel/           (3 文件) -- 启动与内核管理
  04-gpu-passthrough/       (12 文件) -- 硬件直通与显卡
  05-vm-container/          (15 文件) -- 虚拟机运维与导入
  06-networking/            (10 文件) -- 宿主机网络与防火墙
  07-storage-disk/          (6 文件) -- 存储与磁盘维护
  08-tools-about/           (3 文件) -- 诊断工具与项目信息
  09-security/              (3 文件) -- 安全中心
  10-third-party/           (4 文件) -- 第三方工具
```

## 变更记录 (Changelog)

| 日期 | 变更 |
|---|---|
| 2026-07-08 | 初始化 src/modules 模块 CLAUDE.md（模块化重构新增模块） |
