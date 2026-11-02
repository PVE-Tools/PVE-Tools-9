# 更新日志 (Changelog)

更新日志明细，面向用户。线上更新检测数据源见根目录 `UPDATE` 文件（本文件为详细版）。

## v11.1.0 (2026-08-19)

### 新增：获取帮助板块（主菜单 11）

新增独立板块，二级菜单三个入口：

1. **加 Q 群水群** — QQ 群 `1031976463`，PVE 玩法与踩坑经验交流
2. **加聊天社区咨询** — Telegram 群 `https://t.me/pvetools233`，与 QQ 水群相互独立
3. **加作者付费咨询** — 一对一技术支持 / 紧急情况 / 深度排查 / 合作洽谈

付费咨询说明：项目免费开源，但作者**一般不提供免费的技术支持和免费解答方案**；紧急情况或谈合作欢迎直接联系作者（QQ `1520942621` / 微信 `kilomaple2024` / Telegram `https://t.me/pvetools_bot` / 邮件 `contact@ciriu.com`）。觉得工具好用想赞助作者，可前往官网支持页 `https://pve.ciriu.com/support` 或直接联系作者转账。

### 新增：硬件直通一键配置 (IOMMU) 可选增强参数

在「4. 硬件直通与显卡 → 6. 硬件直通一键配置 (IOMMU)」开启流程中，新增可选确认步骤，可选择写入直通增强参数：

- `iommu=pt` — 开启 IOMMU 直通模式，减少 DMA 重映射开销
- `pcie_acs_override=downstream,multifunction` — 强制拆分 IOMMU 组

适用场景：部分主板在 PCIe 拆分后会将 GPU 与系统盘/NVMe 分配到**同一个 IOMMU 组**，GPU 直通时 vfio-pci 会按组接管所有设备（包括系统盘），导致开机即崩溃。本选项可避免此问题。关闭流程已同步移除这两个参数。

### 修复：温度监控误报 nvme0

修复了无 NVMe 硬盘时温度监控误报「检测到 nvme0 / 已添加 1 块」的问题。根因是 bash glob 在无匹配时返回字面模式字符串 `/dev/nvme[0-9]`，被误当作真实设备；现在循环内增加真实块设备校验，无设备时正确显示「已添加 0 块」。

### 其他

- 修正 MAC 绑定接口名校验的错误提示文案（「不允许特殊字符」）

---

## v11.0.0 (2026-07-26)

- 交互层框架化：新增 `lib/menu.sh`，全部菜单迁移 `run_menu`，统一 EOF/Ctrl+C 守卫与 pause 节奏
- 确认体系两档成文：轻档 `confirm_action` / 重档 `confirm_high_risk_action`（指定确认词）
- GPU 直通加固：marker 统一写入、多方案互斥检测、IOMMU 开/关强制确认；去掉写死 PCI ID 与默认核显黑名单
- GRUB 参数数组化精确增删，新增 `grub_has_param`；默认内核优先 `proxmox-boot-tool kernel pin`
- 远程安装与自更新改走 GitHub Releases 完整单文件；修正 vGPU so 真实路径
- CI 护栏补全：源码 shellcheck、构建函数一致性、UPDATE 新鲜度、dist 安全扫描、发版前校验与 SHA256SUMS
- 文档与仓库卫生：按现实重写 CLAUDE/AGENTS；修正 README-JP 文件名；清理历史截图与无关大文件
- Build 代号更新为 Liino

更早期版本历史请见根目录 `UPDATE` 文件与 GitHub Releases。
