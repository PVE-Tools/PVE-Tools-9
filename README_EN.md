# PVE Tools Pro

<div align="center">

An all-in-one operations script for Proxmox VE 9.x, covering VM lifecycle workflows, host networking / firewall / IPv6, GPU / PCI passthrough, day-to-day maintenance, and third-party integrations.

[Docs](https://pve.u3u.icu) | [Changelog](https://pve.u3u.icu/update) | [FAQ](https://pve.u3u.icu/faq) | [中文](./README.md) | [日本語](./REAMDE-JP.md)

</div>

> [!CAUTION]
> **Announcement: Don't bite the hand that feeds you.**
>
> This project is free and open source, maintained solely by personal passion. Before opening an issue or asking a question, please make sure you have read the documentation, on-screen notices, and existing issues thoroughly.
> Feedback without reproduction steps, logs, or other useful information will be closed directly. Open source does not make anyone your servant. Respect is a two-way street.
>
> **The `main` branch (Shell version) will stop receiving updates after v8.8.8. Future development will move to the Go rewrite ([beta-go](https://github.com/PVE-Tools/PVE-Tools-9/tree/beta-go) branch), which will remain free and open source.**

## Overview

PVE Tools Pro is an interactive Bash toolkit for Proxmox VE 9.x. It does not try to replace native PVE commands. Instead, it wraps high-frequency and error-prone operational workflows with clearer menus, stronger validation, and more explicit risk warnings.

Key capabilities:

- VM lifecycle workflows: backup, restore, config export / import, templates, cloning, Cloud-Init, disk management, snapshots, startup order, guest networking, and in-cluster migration.
- Host networking and firewall: bridge, Bond, VLAN, IPv4 / IPv6 / SLAAC / DHCP, PVE firewall, security groups, IPv6 helper, and network diagnostics.
- GPU / PCI passthrough: Intel iGPU virtualization and passthrough, NVIDIA GPU management, AMD dGPU passthrough, AMD iGPU passthrough, RDM, NVMe, and controller passthrough.
- System maintenance: mirror switching, updates, PVE 8 -> 9 upgrade, kernel management, GRUB backup / restore, mail notifications, and hardware monitoring helpers.

## Quick Start

```bash
bash <(curl -sSL https://pve.u3u.icu/PVE-Tools.sh)
```

## Safety Notes

- The script performs real changes to host networking, firewall rules, GRUB, module loading, VM config, and data-plane objects.
- Backup / restore, template / clone / Cloud-Init, disk, snapshot, and migration workflows are high-risk operations. Always verify backups first.
- Misconfigured host networking or firewall rules may immediately break SSH, WebUI, or production traffic.
- AMD iGPU passthrough usually requires a user-supplied ROM / vBIOS. The script validates and writes `romfile`, but does not extract the ROM for you.

## Website Links

- Documentation: https://pve.u3u.icu
- Features: https://pve.u3u.icu/features
- Changelog: https://pve.u3u.icu/update
- FAQ: https://pve.u3u.icu/faq
- Host network / firewall / IPv6 guide: https://pve.u3u.icu/advanced/host-network-firewall-ipv6
- VM backup / migration / Cloud-Init guide: https://pve.u3u.icu/advanced/vm-backup-migration-cloudinit

## Sponsor

If this project saves you time or helps you avoid costly mistakes, you can support ongoing maintenance here:

- Sponsor page: https://pve.u3u.icu/sponsor
- Afdian: https://afdian.com/a/cyrenenight

## Pay For Services

If you need one-on-one remote support, emergency recovery, passthrough troubleshooting, network work, or a full PVE setup, check the paid support page:

- Paid support: https://pve.u3u.icu/pay

## Other Languages

- 中文: [README.md](./README.md)
- 日本語: [REAMDE-JP.md](./REAMDE-JP.md)

## Disclaimer

This project is a real operations tool for Proxmox VE hosts and guests. If you run high-risk actions without validated backups, a maintenance window, and a rollback plan, you may cause management-plane loss, guest outage, or irreversible data damage. All data loss, recovery cost, and third-party recovery expenses remain the responsibility of the operator.

Full ULA page: https://pve.u3u.icu/ula
The ULA outlines the intended scope of the script, its risk boundaries, the operator's responsibilities, and the disclaimer for network interruption, configuration mistakes, data damage, service unavailability, and related recovery costs. Read it before running backup or restore, migration, Cloud-Init, disk changes, GPU passthrough, host networking, or firewall operations.

## License

GPL-3.0. See [LICENSE](LICENSE).

