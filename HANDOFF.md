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
