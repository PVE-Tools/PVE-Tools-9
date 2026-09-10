<div align="center">

# PVE Tools Pro

> Proxmox VE 的新一代运维工具箱 —— 一行命令，全部就绪。休息一下，很快就好.

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](./LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell-Script-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE%209.x-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-13%20(Trixie)-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Release](https://img.shields.io/badge/Release-v11.3.1-orange)](https://github.com/PVE-Tools/PVE-Tools-9/releases)

<img src="./images/main.png" width="100%" alt="PVE Tools Pro" />

</div>

---

## 项目简介

**PVE Tools Pro 是一个面向 Proxmox VE 9.x 的交互式 Bash 运维工具箱.**

它不替代 PVE 原生命令，而是围绕高频运维场景做了集中封装，把**易错**、**需要大量人工检查**的操作打包为菜单化流程，并提供更强的校验与更明确的高风险提示.

## 文档

| 文档 | [![使用指南](https://img.shields.io/badge/文档-使用指南-orange)](https://pve.u3u.icu/guide/) | [![功能特性](https://img.shields.io/badge/文档-功能特性-blue)](https://pve.u3u.icu/guide/features) | [![更新日志](https://img.shields.io/badge/文档-更新日志-informational)](https://pve.u3u.icu/changelog/) | [![常见问题](https://img.shields.io/badge/文档-FAQ-green)](https://pve.u3u.icu/guide/faq) |
|:-:|:-:|:-:|:-:|:-:|

| 高级教程 | [![数据恢复](https://img.shields.io/badge/教程-数据恢复-red)](https://pve.u3u.icu/tutorial/data-recovery-after-mistake) | [![宿主机网络](https://img.shields.io/badge/教程-网络防火墙-yellow)](https://pve.u3u.icu/tutorial/host-network-firewall-ipv6) | [![VM 运维](https://img.shields.io/badge/教程-VM%20运维-9cf)](https://pve.u3u.icu/tutorial/vm-backup-migration-cloudinit) |
|:-:|:-:|:-:|:-:|
---

## 快速开始

>[!WARNING]
>本软件会做您明确告诉它要做的事情，无论那件事情多么荒谬或具有破坏性。
>执行备份恢复、迁移、磁盘调整、GPU 直通、网络或防火墙变更前，请确认已有经过验证的备份和回滚方案。

**如果您仍然心存疑虑，请不要使用本软件。**

### 在线使用启动器安装

在 PVE 终端粘贴执行（需要 Proxmox VE 9.0 以上并以 root 运行），启动器引导自动下载完整程序：

```bash
bash <(curl -sSL https://pve.u3u.icu/PVE-Tools.sh)
```
- PS: 缺少 curl 时先执行 `apt update && apt install curl -y`.
- **快速体验**：默认回车一次性启动，不在系统留文件.
- **安装为系统命令（推荐）**：选择「[2] 安装到系统」或追加 `--install`，之后直接使用 `pvetools`：
> 安装时若检测到 v10 时代旧引导脚本残留或别名遮蔽，可使用菜单 8 的「安装环境诊断」自动清理.

---

### 安装好启动器了？命令在这里

```bash
pvetools              # 启动
pvetools --help       # 帮助
pvetools --uninstall  # 卸载并清理 /opt/pve-tools、日志、备份目录与别名
```

---

### 离线使用？

**中国大陆用户**
```bash
wget https://cnb.cool/PVE-Tools/PVE-Tools-Pro/-/git/raw/main/PVE-Tools.sh
```

**国际用户**
```bash
wget https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/latest/download/PVE-Tools.sh
```

**下载后运行方式**
```bash
chmod +x PVE-Tools.sh && bash PVE-Tools.sh
```

---

## 社区

| 社区 | [![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-black)](https://github.com/PVE-Tools/PVE-Tools-9/issues) | [![QQ Group](https://img.shields.io/badge/QQ%20群%201031976463-加群密码%20PVE%20Tools%20Pro-blue)](https://qm.qq.com/q/pvetools) | [![Telegram](https://img.shields.io/badge/Telegram-pvetools233-26A5E4)](https://t.me/pvetools233) |
|:-:|:-:|:-:|:-:|

---

## 功能特性

- **软件源与系统维护**
  - Debian 官方源与常用国内镜像切换；PVE 企业源转非订阅源、Ceph 镜像源、CT 模板源；系统更新、PVE 8 → 9 升级、内核管理、订阅管理、电源管理、温度监控、漏洞修复、GRUB 备份恢复、Ceph 维护、邮件通知；启动时自动检测远端版本并展示最新发布信息.
- **虚拟机与容器运维**
  - FastPVE（常用 VM 模板快速下载安装）、定时开关机、虚拟机高级运维工具箱——备份与恢复（vzdump、定时备份、压缩与保留策略）、配置导入 / 导出、模板 / 克隆 / Cloud-Init（cloud image 导入）、磁盘 / 快照 / 启动顺序 / 网卡与 VLAN / 集群内迁移.
- **宿主机网络、防火墙与 IPv6**
  - 网络配置向导（vmbr0~N 交互式建删 bridge）、接口地址（静态 IPv4 / IPv6、DHCPv4 / v6、SLAAC、staged 预提交）、VLAN 子接口、Bond（模式 0/1/4/6）、PVE 防火墙与安全组、规则集 JSON / CLI 导入导出、IPv6 助手（就绪度检测、桥接透传或 NAT6 一键配置）、网络诊断工具箱（traceroute / mtr / nmap / tcpdump）.
- **GPU / PCI 直通**
  - Intel 核显虚拟化（SR-IOV / GVT-g）、Intel 核显直通（修改版 QEMU、ROM 下载、引导辅助）、NVIDIA 显卡管理（直通、驱动切换与监控、vGPU 风险引导）、AMD 独显 / 核显直通、通用 PCI 直通（IOMMU、RDM 单盘、NVMe / 磁盘 / 控制器直通）.
- **安全与风险控制**
  - 高风险操作「阅读确认 + 输入确认词」双重防护；关键操作前自动备份到 `/var/backups/pve-tools/`；带时间戳的审计日志与回滚引导.
- **社区与第三方生态**
  - FastPVE 社区模板市场、Community Scripts 脚本合集、Modules 第三方功能模块市场（支持在线提交与安装），均附加风险确认流程.



> 提交 Issue 或提问前，请确认已完整阅读文档、页面告示及已有 Issue。不提供复现步骤、日志等有效信息的反馈，将被直接关闭。开源不等于当孙子，尊重是相互的。

## 支持项目

如果这个项目帮你节省了时间、避开了误操作，或者单纯想支持后续维护与继续更新，可以通过以下渠道赞助：

| 赞助渠道 | [![赞助页面](https://img.shields.io/badge/赞助-pve.u3u.icu%2Fsponsor-pink)](https://pve.u3u.icu/support/sponsor) | [![爱发电](https://img.shields.io/badge/爱发电-afdian.com-red)](https://afdian.com/a/cyrenenight) | [![微信](https://img.shields.io/badge/微信-赞赏码-brightgreen)](./images/WeChat.jpg) |
|:-:|:-:|:-:|:-:|

- 赞助档位：基础支持 ¥5、进阶支持 ¥28.88（群专属头衔 + 新功能优先内测）、核心支持者 ¥50（ID 永久刻入赞助者名单），也支持自定义金额.
- 赞助是对项目本身的支持，社群只提供基础交流；需要一对一远程协助、紧急救砖、直通 / 网络排查或完整代配，请查看[付费技术支持说明](https://pve.u3u.icu/support/pay)，这里购买的是时间与交付结果.

## 特别鸣谢

- [腾讯 CNB.cool](https://docs.cnb.cool) 为项目提供稳定可靠的国内分发服务，没有国内 CDN，国内用户的下载体验根本没法看.

<div align="center">
<img src="https://docs.cnb.cool/images/logo/svg/Horizontal-Black-Domestic-SaaS.svg" width="50%" alt="CDN" />

**不过最最重要的，还是需要感谢屏幕前的你哦~**

</div>

---

## 免责声明

这是一个会真实调用 PVE 原生命令并修改宿主机 / VM 配置的运维工具。
如果你在没有经过验证的备份、没有维护窗口、没有明确回滚方案的前提下执行高风险动作，可能导致管理面失联、业务中断、配置损坏或不可逆的数据损失。所有数据损失、恢复成本与第三方恢复费用均由实际操作人自行承担。

完整用户协议（ULA）页面：https://pve.u3u.icu/legal/ula ，主要说明脚本的适用范围、风险边界、用户自担的操作责任，以及对网络中断、配置错误、数据损坏、业务不可用和衍生恢复成本的免责声明。

## 开源许可

本项目采用 [GPL-3.0](./LICENSE) 开源，使用时请遵守当地法律法规，由此造成的问题由实际操作人自行负责。
