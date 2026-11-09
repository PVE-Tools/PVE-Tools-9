<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 Ciriu Networks -->

# 维护记录

## PR #113：企业源禁用与取消操作

- [deb822 文档](https://manpages.debian.org/trixie/apt/sources.list.5.en.html#DEB822-STYLE_FORMAT)规定注释以首列 `#` 开头，不应把缩进后的 `#` 行直接当作注释保留。禁用企业源时，仅保留首列 `#` 行，其余行加一个首列 `#`，保留原文并保持幂等。此次 APT 3.0.3 / 3.0.4 实测接受了原缩进示例，未复现审查声称的解析错误；回归测试同时验证规范输出和真实 APT 解析，不能把前者的失败说成后者报错。
- 不要把源操作的取消和失败混用。`select_mirror`、`change_sources`、`quick_setup`：`0` 完成，`1` 失败，`2` 取消。镜像跳过、镜像输入结束、拒绝写入确认都必须在写源前停止；一键优化不能继续删除弹窗或更新系统。
- 菜单分发器：`0` 已处理，`1` 无效输入，`2` 操作失败，`3` 操作取消。`run_menu` 对取消不报错；之前的失败仍须在退出时返回 `2`。不要把动作的取消码 `2` 直接传给菜单框架。
- Bash 在条件调用中会抑制函数内的 `set -e`。失败和取消必须显式返回；测试应通过真实分发器和完整菜单输入验证，不能仅依赖叶函数或 `set -e`。

验证命令（Linux、GNU sed、真实 APT）：

```bash
bash tests/sources-enterprise-test.sh
bash tests/sources-cancellation-test.sh
bash tests/menu-action-status-test.sh
bash build.sh
bash -n dist/PVE-Tools.sh
```

测试把 APT 源、CT 模板路径和备份重定向到临时目录；APT 使用 `--print-uris update`，不下载索引。不要直接执行 `change_sources`、`quick_setup` 或启动真实运维入口来测试。

macOS 的 BSD `sed -i` 不兼容源码；企业源测试应在隔离 Linux 环境运行。此修复不新增依赖、后台任务或网络请求，企业源仍只执行一次线性扫描。


## Issue #114：UPS 服务器地址可配置

- `cpu_add` 的 NUT 采集目标由 `<设备名>@localhost` 改为 `<设备名>@<服务器地址>`；交互新增地址输入，默认 `localhost`，空回车走默认值，非法输入回退 `localhost` 并给出提示。
- 地址支持主机名、IPv4、`[IPv6]` 与可选 `:端口`。依据 NUT 源码 `upscli_splitaddr`：方括号用于区分 IPv6 与端口（如 `[1234:5678]:3493`），内部解析缓冲为 256 字节，因此校验同时限制字符集与长度（≤255）。
- 该校验同时承担防注入职责：目标地址会拼进生成的 Perl 采集片段（`UPS_TARGET="..."`），只放行 `A-Za-z0-9._:-` 与方括号。
- 远程地址仅在非回环时提示检查 `upsd.conf` 的 `LISTEN`/`ACL`；脚本仍不启停 NUT、不改 `ups.conf`。
- 回归：`bash tests/ups-config-test.sh`（52 项纯逻辑，含源码级断言「不再硬编码 localhost」）。

验证命令：

```bash
bash tests/ups-config-test.sh
bash build.sh && bash -n dist/PVE-Tools.sh
```