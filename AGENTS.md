# Repository Guidelines

## Project Structure & Module Organization

- `PVE-Tools.sh` — bootstrap entry + optional installer (~700 lines). Local mode sources `lib/` + `src/modules/`; remote mode (`bash <(curl ...)`) downloads the prebuilt single file from two release sources (CNB mirror first for CN users via Tencent CDN, GitHub Releases as fallback; third-party ghfast proxy removed from this chain). Installer duties: interactive offer after download (default stays direct-launch), `--install` places the validated dist as `/usr/local/bin/pvetools`, `--uninstall` removes it plus `/opt/pve-tools/` and the marker-fenced `.bashrc` alias block; installer constants must stay in sync with `lib/config.sh` (`PVE_TOOLS_BIN_PATH`, `PVE_TOOLS_OPT_DIR`, `PVE_TOOLS_ALIAS_MARKER`).
- `lib/` — infrastructure layer, loaded in strict order: `config.sh` (globals) → `core.sh` (logging/UI/backup/GRUB helpers) → `menu.sh` (menu framework) → `network.sh` (region detection, mirror selection) → `runtime.sh` (guards + `main()`).
- `src/modules/` — 10 numbered feature modules matching main-menu items 1-10; each has `init.sh` (menu entry) plus feature files.
- `build.sh` concatenates lib + modules into `dist/PVE-Tools.sh` (gitignored; built by CI). `dev.sh` sources everything for local development.
- `Tools/` — standalone community maintenance scripts (not part of the build). `Modules/` — plugin-market assets incl. `Modules/VGPU/*.so` (binary asset referenced by the vGPU unlock download URL — do not edit or remove). `Docs/` — supplementary docs incl. the modularization design doc. `images/` — README screenshots. `.github/` — issue templates and CI workflows.
- The former `Web/` VitePress documentation site has been removed from this repository.

## Build, Test, and Development Commands

```bash
bash dev.sh                                          # run from source
bash build.sh                                        # build dist/PVE-Tools.sh
bash -n PVE-Tools.sh && bash -n dist/PVE-Tools.sh    # syntax check
shellcheck -f gcc PVE-Tools.sh dist/PVE-Tools.sh     # strict lint (entry + artifact)
find lib src/modules -name '*.sh' -print0 | xargs -0 shellcheck --severity=error -f gcc
```

CI (`pr-validation.yml`) additionally asserts: source-vs-dist function-set consistency, `CURRENT_VERSION` ↔ `VERSION` match, `UPDATE` first line contains the current version, and a security scan (no `eval`, no unquoted `rm -rf $var`, no `source` in dist). Release workflows re-run these gates before publishing and attach `SHA256SUMS.txt`.

## Coding Style & Naming Conventions

`#!/bin/bash`, 4-space indent, `snake_case` functions, `UPPER_SNAKE` globals, `lower_case` locals. Every file starts with the SPDX (`GPL-3.0-only`) + Copyright header. Prefer the shared helpers over ad-hoc code: `log_info/warn/error/step/success/tips`, `display_error`/`display_success`, `backup_file` (backs up into `/var/backups/pve-tools/`), `apply_block`/`remove_block` (marker-fenced config blocks: `# PVE-TOOLS BEGIN/END <MARKER>`), `grub_add_param`/`grub_remove_param`/`grub_has_param` (idempotent, key-exact GRUB cmdline management).

## Menus & Interaction

All menus go through the framework in `lib/menu.sh`: `run_menu <title> <render_fn> <dispatch_fn> <range>` — never hand-write `while true` menu loops. Render functions print options only (`show_menu_option`); dispatch functions `case "$1"`, `return 1` for unknown input, `return 0` at the end. `0` is always "back" and is appended by the framework. For input use `prompt_value` (default-value annotation, empty = cancel), `prompt_yes_no`, `prompt_pick_from_list` (returns 2 on cancel — same convention as the `vm_select_*` pickers).

Confirmations are two-tier: `confirm_action` (light, type `yes`) for reversible config writes; `confirm_high_risk_action` (heavy, type a specific confirm word) for anything touching GRUB/VFIO, apt sources, fstab, LVM, qm disk slots, firewall, SSH, or cron.

## Commit & Pull Request Guidelines

Conventional Commits (`feat:`, `fix(scope):`, `docs:`, `chore:`). When bumping the version keep three places in sync: `CURRENT_VERSION` in `lib/config.sh`, the `VERSION` file, and the top entry of `UPDATE` (CI enforces all three). Describe operational risk when touching networking, firewall, storage, GRUB, passthrough, or VM lifecycle logic.

## Security & Configuration Tips

No `eval`; no unreviewed `source`. Back up host configuration via `backup_file` before writes, and wrap system-config writes in marker blocks (`apply_block`) so they can be removed cleanly and detected by `gpu_detect_active_stacks`-style probes. Treat network, firewall, storage, kernel, and passthrough changes as high risk and verify manually on a Proxmox VE 9.x box with backups and a rollback plan.
