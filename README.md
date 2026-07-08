# PVE Tools Pro(原 PVE-Tools-9)

<div align="center">

[官网 / Docs](https://pve.u3u.icu) | [更新日志](https://pve.u3u.icu/update) | [FAQ](https://pve.u3u.icu/faq) | [English](./README_EN.md) | [日本語](./REAMDE-JP.md)

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Shell Script](https://img.shields.io/badge/Shell-Script-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE%209.x-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-13%20(Trixie)-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)

![产品截图](./images/main.png)

</div>

>[!CAUTION]
> **Shell版本恢复更新公告**
> 
> 经过一个比较混乱的调整，我决定恢复更新 Shell 版本。
> 
> 该版本将继续维护，后续会根据用户反馈和需求进行更新。
>
> 如果想了解为何辗转两次，可以在这里了解详细: [为什么Go版本憋不出来?](https://pve.u3u.icu/blog/why-go-version-is-not-updating/)

<!-- > [!CAUTION]
> **Shell版本停更公告**
> 
> 感谢大家一直以来对 PVE-Tools-9 的支持。随着项目功能的不断增加，目前的 Shell 脚本代码量已突破 13000 行。
> 
> 受限于 Shell 语言本身的特性，继续在此基础上增加新功能或进行大规模修改，已经变得难以维护且容易引发不可预知的 Bug。
> 
> 因此，我决定暂缓当前 Shell 版本的新功能开发（但不会EOL），仅做极其重大的致命 Bug 修复。该仓库将保持原样，不会删库，大家依然可以正常使用现有功能。
> 
> `main` 分支（Shell 版本）发布 v8.8.8 后将停止更新，后续正式版本推出后将切到主main分支。
> 我目前已经开启了底层基于 Go 语言 的全新版本重构计划，后续维护将迁移至 Go 重构版本（[beta-go](https://github.com/PVE-Tools/PVE-Tools-9/tree/beta-go) 分支），Go 版本将继续免费开源,新版本将带来更好的稳定性、更友好的交互以及更严谨的环境校验，敬请期待。 -->


## 快速开始

### 使用前请先注意

本软件会做您明确告诉它要做的事情，无论那件事情多么荒谬或具有破坏性。
您已被告知所有风险，并已独立决定使用本软件。从此刻起，您与您的数据之间唯一的屏障就是您自己的谨慎与备份策略。

最后提醒：**如果您仍然心存疑虑，请不要使用本软件。世界上有许多带有商业支持、附带责任保险的成熟 PVE 管理工具，您可以考虑购买它们。**

> 本项目完全免费开源，维护全凭个人热情。提交 Issue 或提问前，请确认已完整阅读文档、页面告示及已有 Issue。
> 不提供复现步骤、日志等有效信息的反馈，将被直接关闭。开源不等于当孙子，尊重是相互的。

### cloudflare 短域名
```bash
bash <(curl -sSL https://pve.u3u.icu/PVE-Tools.sh)
```

### 中国大陆网络
```bash
bash <(curl -sSL https://ghfast.top/raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh)
```

### 国际网络
```bash
bash <(curl -sSL https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh)
```

### 本地下载运行
```bash
wget https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh
chmod +x PVE-Tools.sh
sudo ./PVE-Tools.sh
```
## 项目定位

PVE Tools Pro 是一个面向 Proxmox VE 9.x 的交互式 Bash 工具。
它不会替代 PVE 原生命令，而是把高频、易错、需要大量人工检查的运维动作收口为更清晰的菜单、更强的校验和更明确的高风险提示。

| 功能模块 | 支持能力 |
|---------|---------|
| VM 生命周期运维 | 备份、恢复、配置导入导出、模板、克隆、Cloud-Init、磁盘管理、快照、启动顺序、网络调整、集群内迁移 |
| 宿主机网络与防火墙 | bridge、Bond、VLAN、IPv4 / IPv6 / SLAAC / DHCP、PVE 防火墙、安全组、IPv6 助手、网络诊断工具箱 |
| GPU / PCI 直通 | Intel 核显虚拟化与直通、NVIDIA 显卡管理、AMD 独显直通、AMD 核显直通、RDM、NVMe、控制器直通 |
| 系统维护 | 换源、系统更新、PVE 8 → 9 升级、内核管理、GRUB 备份恢复、邮件通知、温控与基于 NUT 的 UPS 辅助能力 |
| 第三方生态 | FastPVE、Modules、Community Scripts |

## 官网入口

- 官方文档：https://pve.u3u.icu
- 功能特性：https://pve.u3u.icu/features
- 更新日志：https://pve.u3u.icu/update
- 常见问题：https://pve.u3u.icu/faq
- 数据误操作恢复参考：https://pve.u3u.icu/advanced/data-recovery-after-mistake
- 宿主机网络 / 防火墙 / IPv6 专题：https://pve.u3u.icu/advanced/host-network-firewall-ipv6
- VM 备份 / 迁移 / Cloud-Init 专题：https://pve.u3u.icu/advanced/vm-backup-migration-cloudinit

## Sponsor

如果这个项目帮你节省了时间、避开了误操作，或者单纯想支持后续维护与继续更新，可以通过以下页面赞助：

- Sponsor 页面：https://pve.u3u.icu/sponsor
- 爱发电：https://afdian.com/a/cyrenenight
- 微信：![微信赞赏码](./images/WeChat.jpg)

赞助是对项目本身的支持，不等同于一对一技术服务。

## Pay For Services

如果你需要一对一远程协助、紧急救砖、网络配置、直通问题排查或完整代配，可以直接查看官方付费支持说明：

- 付费技术支持页面：https://pve.u3u.icu/pay

这里购买的是时间与交付结果，不是单纯赞助。

## 其它语言

- English: [README_EN.md](./README_EN.md)
- 日本語: [REAMDE-JP.md](./REAMDE-JP.md)

## 免责声明

这是一个会真实调用 PVE 原生命令并修改宿主机 / VM 配置的运维工具。如果你在没有经过验证的备份、没有维护窗口、没有明确回滚方案的前提下执行高风险动作，可能导致管理面失联、业务中断、配置损坏或不可逆的数据损失。所有数据损失、恢复成本与第三方恢复费用均由实际操作人自行承担。

完整 ULA 页面：https://pve.u3u.icu/ula
该页面主要说明脚本的适用范围、风险边界、用户自担的操作责任，以及对网络中断、配置错误、数据损坏、业务不可用和衍生恢复成本的免责声明。
执行备份恢复、迁移、Cloud-Init、磁盘调整、GPU 直通、宿主机网络或防火墙变更前，建议先完整阅读。

## Community

- 官网：https://pve.u3u.icu
- GitHub Issues：https://github.com/PVE-Tools/PVE-Tools-9/issues
- QQ 群：1031976463
- Telegram 群：https://t.me/pvetools233
- Sponsor：https://pve.u3u.icu/sponsor

## License

GPL-3.0. See [LICENSE](LICENSE).

