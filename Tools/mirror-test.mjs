#!/usr/bin/env node

// SPDX-License-Identifier: GPL-3.0-only
// PVE Tools Pro - 镜像源可用性批量测试工具
// 用途: 批量测试高校镜像站的 Debian / Debian Security / PVE / Ceph / CT 源可用性
// 使用: node Tools/mirror-test.mjs [--timeout 5000] [--concurrency 6] [--output report.json]

import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";

// ==================== 镜像站列表 ====================

const MIRRORS = [
    { name: "南京大学", id: "NJUNJU", url: "https://mirrors.nju.edu.cn" },
    { name: "中国科学技术大学", id: "USTC", url: "https://mirrors.ustc.edu.cn" },
    { name: "浙江大学", id: "ZJU", url: "https://mirrors.zju.edu.cn" },
    { name: "上海交大致远", id: "SJTUG-Zhiyuan", url: "https://mirrors.sjtug.sjtu.edu.cn" },
    { name: "上海交大思源", id: "SJTUG-Siyuan", url: "https://mirror.sjtu.edu.cn" },
    { name: "南阳理工学院", id: "NYIST", url: "https://mirror.nyist.edu.cn" },
    { name: "北京外国语大学", id: "BFSU", url: "https://mirrors.bfsu.edu.cn" },
    { name: "西安交通大学", id: "XJTU", url: "https://mirrors.xjtu.edu.cn" },
    { name: "南方科技大学", id: "SUSTech", url: "https://mirrors.sustech.edu.cn" },
    { name: "重庆邮电大学", id: "CQUPT", url: "https://mirrors.cqupt.edu.cn" },
    { name: "重庆大学", id: "CQU", url: "https://mirrors.cqu.edu.cn" },
    { name: "吉林大学", id: "JLU", url: "https://mirrors.jlu.edu.cn" },
    { name: "兰州大学", id: "LZUOSS", url: "https://mirror.lzu.edu.cn" },
    { name: "哈尔滨工业大学", id: "HIT", url: "https://mirrors.hit.edu.cn" },
    { name: "河南省教育科研网", id: "HERNET", url: "https://mirrors.ha.edu.cn" },
    { name: "华中科技大学", id: "HUST", url: "https://mirrors.hust.edu.cn" },
    { name: "南京工业大学", id: "NJTech", url: "https://mirrors.njtech.edu.cn" },
    { name: "西北农林科技大学", id: "NWAFU", url: "https://mirrors.nwafu.edu.cn" },
    { name: "北京大学", id: "PKU", url: "https://mirrors.pku.edu.cn" },
    { name: "山东大学", id: "SDU", url: "https://mirrors.sdu.edu.cn" },
    { name: "清华大学", id: "TUNA", url: "https://mirrors.tuna.tsinghua.edu.cn" },
    { name: "武昌首义学院", id: "WSYU", url: "https://mirrors.wsyu.edu.cn" },
    { name: "齐鲁工业大学", id: "QLUT", url: "https://mirrors.qlu.edu.cn" },
];

// ==================== 待测路径模板 ====================
//
// 探测策略：对每个源类型，按优先级尝试多个候选路径，命中第一个即停。
// Debian 系列检查 Release 文件（APT 必读）。
// PVE/Ceph 检查 pve-no-subscription 组件的 Packages 文件（实际 APT 索引）。
// CT 模板检查 APLInfo.pm 使用的基础路径是否可访问。

const SOURCE_PROBES = [
    {
        key: "debian",
        label: "Debian 基础源",
        required: true,
        candidates: [
            "/debian/dists/trixie/Release",
            "/debian/dists/bookworm/Release",
        ],
    },
    {
        key: "debian_security",
        label: "Debian 安全源",
        required: true,
        candidates: [
            "/debian-security/dists/trixie-security/Release",
            "/debian-security/dists/bookworm-security/Release",
        ],
    },
    {
        key: "pve",
        label: "PVE 源",
        required: false,
        candidates: [
            // 无订阅源实际 Packages 索引
            "/proxmox/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/Packages",
            "/proxmox/debian/pve/dists/bookworm/pve-no-subscription/binary-amd64/Packages",
            // Release 文件（部分镜像可能只同步了 Release）
            "/proxmox/debian/pve/dists/trixie/Release",
        ],
    },
    {
        key: "ceph",
        label: "Ceph 源",
        required: false,
        candidates: [
            "/proxmox/debian/ceph-squid/dists/trixie/Release",
            "/proxmox/debian/ceph-squid/dists/bookworm/Release",
        ],
    },
    {
        key: "ct_template",
        label: "CT 模板源",
        required: false,
        // CT 模板: APLInfo.pm 将 http://download.proxmox.com 替换为镜像的 /proxmox
        // 实际模板文件在 /proxmox/template/cache/ 下（扁平目录，无 index，目录列表常被禁用）
        // 探测策略: 先检查 /proxmox/ 父目录（APLInfo.pm 的替换目标），再检查子目录
        // 启用 fallbackGet: 目录页可能禁用 HEAD 但允许 GET
        candidates: [
            "/proxmox/",
            "/proxmox/template/cache/",
            "/proxmox/template/",
        ],
        fallbackGet: true,
    },
];

// ==================== CLI 参数解析 ====================

function parseArgs() {
    const args = process.argv.slice(2);
    const opts = {
        timeout: 8000,
        concurrency: 6,
        output: null,
        verbose: false,
    };

    const fail = (message) => {
        console.error(`参数错误: ${message}`);
        console.error("使用 --help 查看用法。");
        process.exit(1);
    };
    const readValue = (index, option, { allowDashValue = false } = {}) => {
        const value = args[index + 1];
        if (value === undefined || (!allowDashValue && value.startsWith("-"))) {
            fail(`${option} 需要提供参数值`);
        }
        return value;
    };

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case "--timeout": {
                const value = Number(readValue(i, args[i], { allowDashValue: true }));
                if (!Number.isFinite(value) || value <= 0) {
                    fail("--timeout 必须是正数");
                }
                opts.timeout = value;
                i++;
                break;
            }
            case "--concurrency": {
                const value = Number(readValue(i, args[i], { allowDashValue: true }));
                if (!Number.isInteger(value) || value <= 0) {
                    fail("--concurrency 必须是正整数");
                }
                opts.concurrency = value;
                i++;
                break;
            }
            case "--output":
            case "-o": {
                const value = readValue(i, args[i]);
                opts.output = value;
                i++;
                break;
            }
            case "--verbose":
            case "-v":
                opts.verbose = true;
                break;
            case "--help":
            case "-h":
                console.log(`用法: node mirror-test.mjs [选项]

选项:
  --timeout <ms>      单次请求超时(毫秒)，默认 8000
  --concurrency <n>   并发数，默认 6
  --output <file>     输出 JSON 报告文件路径
  --verbose, -v       显示每个探测请求的详细信息
  --help, -h          显示帮助`);
                process.exit(0);
            default:
                fail(`未知参数 ${args[i]}`);
        }
    }
    return opts;
}

// ==================== HTTP 探测核心 ====================

async function probeUrl(url, timeoutMs, method = "HEAD") {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
        const res = await fetch(url, {
            method,
            signal: controller.signal,
            redirect: "follow",
            headers: { "User-Agent": "PVE-Tools-MirrorTest/1.0" },
        });
        // 200/301/302/403 均视为路径存在
        // 403 = 目录存在但禁止列表（常见于禁用 autoindex 的 nginx）
        return { status: res.status, ok: res.ok || res.status === 301 || res.status === 302 || res.status === 403 };
    } catch {
        return { status: 0, ok: false };
    } finally {
        clearTimeout(timer);
    }
}

// 带退避的重试探测（网络抖动时重试一次）
// fallbackGet: HEAD 失败后自动用 GET 重试（目录页可能禁用 HEAD）
async function probeWithRetry(url, timeoutMs, { retries = 1, fallbackGet = false } = {}) {
    let lastResult = { status: 0, ok: false };
    for (let attempt = 0; attempt <= retries; attempt++) {
        let result = await probeUrl(url, timeoutMs, "HEAD");
        lastResult = result;
        if (result.ok) return result;
        // HEAD 失败且启用 GET 回退时，用 GET 再试一次
        if (fallbackGet && attempt === retries) {
            result = await probeUrl(url, timeoutMs, "GET");
            lastResult = result;
            if (result.ok) return result;
        }
        if (attempt < retries) await sleep(300);
    }
    return lastResult;
}

// ==================== 并发控制 ====================

function sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
}

async function mapWithConcurrency(items, concurrency, fn) {
    const results = [];
    let index = 0;
    const workers = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
        while (index < items.length) {
            const i = index++;
            results[i] = await fn(items[i], i);
        }
    });
    await Promise.all(workers);
    return results;
}

// ==================== 单个镜像站测试 ====================

async function testMirror(mirror, opts) {
    const results = {};

    for (const probe of SOURCE_PROBES) {
        let found = false;
        let matchedPath = null;
        let statusCode = 0;

        for (const candidate of probe.candidates) {
            const url = `${mirror.url}${candidate}`;
            if (opts.verbose) {
                process.stdout.write(`  探测 ${mirror.id} ${probe.label}: ${candidate} ...`);
            }
            const { status, ok } = await probeWithRetry(url, opts.timeout, {
                fallbackGet: !!probe.fallbackGet,
            });
            if (opts.verbose) {
                console.log(ok ? ` ✅ (${status})` : ` ❌ (${status})`);
            }
            if (ok) {
                found = true;
                matchedPath = candidate;
                statusCode = status;
                break;
            }
            statusCode = status;
        }

        results[probe.key] = {
            available: found,
            path: matchedPath,
            status: statusCode,
        };
    }

    // 计算综合评级
    const hasRequired = results.debian.available && results.debian_security.available;
    const optionalCount = SOURCE_PROBES.filter(
        (p) => !p.required && results[p.key].available
    ).length;

    let rating;
    if (hasRequired && optionalCount >= 3) rating = "★★★ 全量可用";
    else if (hasRequired && optionalCount >= 1) rating = "★★☆ 核心可用+部分扩展";
    else if (hasRequired) rating = "★☆☆ 仅 Debian 可用";
    else rating = "☆☆☆ 不可用";

    return {
        ...mirror,
        results,
        hasRequired,
        optionalCount,
        rating,
    };
}

// ==================== 报告输出 ====================

function printReport(testResults) {
    const line = "═".repeat(100);
    const thinLine = "─".repeat(100);

    console.log();
    console.log(line);
    console.log("  PVE Tools Pro - 镜像源可用性测试报告");
    console.log(line);
    console.log();

    // 按评级排序：全量 > 核心+扩展 > 仅Debian > 不可用
    const sorted = [...testResults].sort((a, b) => {
        const rank = (r) => (r.hasRequired ? 10 : 0) + r.optionalCount;
        return rank(b) - rank(a);
    });

    // 表头
    console.log(
        pad("镜像站", 20) +
            pad("ID", 16) +
            pad("评级", 22) +
            pad("Debian", 10) +
            pad("Security", 10) +
            pad("PVE", 10) +
            pad("Ceph", 10) +
            pad("CT", 10)
    );
    console.log(thinLine);

    for (const m of sorted) {
        const mark = (key) => (m.results[key].available ? "✅" : "❌");
        console.log(
            pad(m.name, 20) +
                pad(m.id, 16) +
                pad(m.rating, 22) +
                mark("debian").padEnd(10) +
                mark("debian_security").padEnd(10) +
                mark("pve").padEnd(10) +
                mark("ceph").padEnd(10) +
                mark("ct_template").padEnd(10)
        );
    }

    console.log(thinLine);
    console.log();

    // 统计汇总
    const full = sorted.filter((m) => m.rating.startsWith("★★★")).length;
    const partial = sorted.filter((m) => m.rating.startsWith("★★☆")).length;
    const debianOnly = sorted.filter((m) => m.rating.startsWith("★☆☆")).length;
    const unavailable = sorted.filter((m) => m.rating.startsWith("☆☆☆")).length;

    console.log("  汇总统计:");
    console.log(`    ★★★ 全量可用 (Debian + Security + PVE/Ceph/CT):  ${full} 个`);
    console.log(`    ★★☆ 核心可用 + 部分扩展:                         ${partial} 个`);
    console.log(`    ★☆☆ 仅 Debian 可用:                              ${debianOnly} 个`);
    console.log(`    ☆☆☆ 不可用:                                      ${unavailable} 个`);
    console.log();

    // 详细信息（仅展示可用镜像的匹配路径）
    console.log(line);
    console.log("  可用镜像站详细信息:");
    console.log(line);
    for (const m of sorted.filter((m) => m.hasRequired)) {
        console.log();
        console.log(`  ${m.name} (${m.id}) - ${m.url}`);
        for (const probe of SOURCE_PROBES) {
            const r = m.results[probe.key];
            const status = r.available ? `✅ ${r.path}` : "❌ 不可用";
            console.log(`    ${probe.label.padEnd(14)} ${status}`);
        }
    }
    console.log();

    // 生成 shell 变量建议
    console.log(line);
    console.log("  可直接用于 PVE-Tools.sh 的镜像变量:");
    console.log(line);
    console.log();
    for (const m of sorted.filter((m) => m.hasRequired)) {
        const debPath = m.results.debian.path?.replace("/dists/trixie/Release", "")
            .replace("/dists/bookworm/Release", "");
        const secPath = m.results.debian_security.path
            ?.replace("/dists/trixie-security/Release", "")
            .replace("/dists/bookworm-security/Release", "");
        // PVE: 从 Packages 路径反推基础 URI
        // /proxmox/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/Packages → /proxmox/debian/pve
        const pvePath = m.results.pve.available
            ? m.results.pve.path.replace(/\/dists\/.*/, "")
            : null;
        const ctPath = m.results.ct_template.available
            ? m.results.ct_template.path.replace(/\/template\/cache\/.*/, "").replace(/\/dists\/.*/, "")
            : null;

        console.log(`  # ${m.name} (${m.id})`);
        console.log(`  MIRROR_${m.id.toUpperCase().replace(/-/g, "_")}="${m.url}"`);
        console.log(`  # Debian:    ${m.url}${debPath}`);
        console.log(`  # Security:  ${m.url}${secPath}`);
        if (pvePath) {
            console.log(`  # PVE:       ${m.url}${pvePath}`);
        } else {
            console.log(`  # PVE:       ❌ 不可用`);
        }
        if (ctPath) {
            console.log(`  # CT模板:    ${m.url}${ctPath}`);
        } else {
            console.log(`  # CT模板:    ❌ 不可用`);
        }
        console.log();
    }
}

function pad(str, len) {
    // 简易中文 padding（每个 CJK 字符占 2 列）
    let width = 0;
    for (const ch of str) {
        width += ch.charCodeAt(0) > 0x7f ? 2 : 1;
    }
    return str + " ".repeat(Math.max(0, len - width));
}

// ==================== 主流程 ====================

async function main() {
    const opts = parseArgs();

    console.log("PVE Tools Pro - 镜像源可用性批量测试");
    console.log(`镜像站数量: ${MIRRORS.length}`);
    console.log(`超时: ${opts.timeout}ms | 并发: ${opts.concurrency}`);
    console.log(`探测项: ${SOURCE_PROBES.map((p) => p.label).join(", ")}`);
    console.log();

    const startTime = Date.now();

    const testResults = await mapWithConcurrency(MIRRORS, opts.concurrency, async (mirror, i) => {
        process.stdout.write(`[${String(i + 1).padStart(2)}/${MIRRORS.length}] 测试 ${mirror.name} (${mirror.id}) ...`);
        const result = await testMirror(mirror, opts);
        console.log(` ${result.rating}`);
        return result;
    });

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n全部测试完成，耗时 ${elapsed}s\n`);

    printReport(testResults);

    // 输出 JSON 报告
    if (opts.output) {
        // 相对于当前工作目录解析（而非脚本位置）
        const outputPath = resolve(process.cwd(), opts.output);
        const report = {
            generatedAt: new Date().toISOString(),
            elapsedSeconds: Number(elapsed),
            totalMirrors: MIRRORS.length,
            probes: SOURCE_PROBES.map((p) => ({ key: p.key, label: p.label, required: p.required })),
            results: testResults.map((m) => ({
                name: m.name,
                id: m.id,
                url: m.url,
                rating: m.rating,
                hasRequired: m.hasRequired,
                optionalCount: m.optionalCount,
                sources: m.results,
            })),
        };
        await writeFile(outputPath, JSON.stringify(report, null, 2), "utf-8");
        console.log(`JSON 报告已写入: ${outputPath}`);
    }
}

main().catch((err) => {
    console.error("测试异常:", err);
    process.exit(1);
});
