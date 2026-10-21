#!/usr/bin/env node
/**
 * import-dsa-pool.js
 * ----------------------------------------------------------------------------
 * 从《DSA_ggz自走棋》导入抽卡卡池，并**按阵营切成四份**，生成
 * `ALittlePlot/scripts/lua/chouka/gen_pool.lua`。
 *
 * 数据来源（全部只读，不改 DSA 目录）：
 *   · 卡池本体与档位权重：lua/GAME/PureDraw/02_data.lua
 *   · 阵营分类（权威依据）：lua/GAME/RecycleUnit.lua 里的 16 张表
 *       g_{Infantry,Vehicle,AirCraft,Ship}{Allied,Soviet,Japan,Celestial}
 *
 * 处理规则：
 *   1. 条目压成纯字符串，删掉 CustomDrawCount（= 每次只出 1 个）及其它本图用不到的字段；
 *   2. 按阵营分池：1=盟军 2=苏联 3=升阳 4=神州，每个玩家只从自己阵营的池子里抽；
 *   3. 阵营表里查不到的条目按名字前缀兜底，并在末尾生成一份「未收录清单」注释。
 *
 * 用法：node tools/import-dsa-pool.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const DSA = process.env.DSA_DIR || 'E:\\Ra3_CenterChess\\日冕地图lua例子\\DSA_ggz自走棋';
const SRC_POOL = path.join(DSA, 'lua', 'GAME', 'PureDraw', '02_data.lua');
const SRC_ROSTER = path.join(DSA, 'lua', 'GAME', 'RecycleUnit.lua');
const SRC_NONPROD = path.join(DSA, 'lua', 'GAME', 'HextechRune', '05_ultimate_creature.lua');
const OUT = path.resolve(__dirname, '..', 'scripts', 'lua', 'chouka', 'gen_pool.lua');

const FACTION_NAMES = { Allied: 1, Soviet: 2, Japan: 3, Celestial: 4 };

// 阵营表里查不到时的兜底（日冕的子阵营/特殊单位）
const PREFIX_FALLBACK = [
    [/^Allied/, 1],
    [/^Soviet/, 2],
    [/^VU/, 2],          // VU 系苏联子阵营载具
    [/^Japan/, 3],
    [/^Celestial/, 4],
    [/^RheinEntente/, 1], // 莱茵协约 = 盟军子阵营（DSA 把它和盟军 MBT 放同一组增益里）
    [/^WinterArmy/, 2],   // 冬军 = 苏联子阵营
];

// 前缀兜底也认不出来的，手工指定（依据 DSA 的本地化键，如 unit.SovietOverlordtank）
const FACTION_OVERRIDE = {
    Overlordtank: 2,
    Overlordtank_SpitfireEngineer: 2,
};

// 本图不要的：一切 MCV / 基地车（这张图只有起重机，没有基地车）
const EXCLUDED_PATTERN = /MCV/i;

// 手工拉黑的条目（本图不要的"非可生产单位"）。默认空。
// 加进去就整条从卡池里剔除，例如嫌 T1 太杂：
//   const BLACKLIST = ['CelestialForkLiftVehicle', 'SovietWeatherBalloon'];
const BLACKLIST = [];

function readLines(file) {
    if (!fs.existsSync(file)) throw new Error(`找不到文件：${file}`);
    return fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').split('\n');
}

/** 解析卡池：返回 { tiers: Map<tier, string[]>, weights: number[] } */
function parsePool(lines) {
    const tiers = new Map();
    let current = null;
    const tierOpen = /^\s{0,8}\[(\d+)\]\s*=\s*\{\s*$/;
    const tierClose = /^\s{0,8}\}\s*,?\s*$/;

    let started = false;
    for (const line of lines) {
        if (!started) {
            if (/^g_PureDrawBuildableUnitPool\s*=\s*\{/.test(line)) started = true;
            continue;
        }
        if (/^\}\s*;?\s*$/.test(line)) break;
        const opened = tierOpen.exec(line);
        if (opened) {
            current = Number(opened[1]);
            if (!tiers.has(current)) tiers.set(current, []);
            continue;
        }
        if (current !== null && tierClose.test(line)) { current = null; continue; }
        if (current === null) continue;
        const t = /Type\s*=\s*"([A-Za-z0-9_]+)"/.exec(line);
        if (t) tiers.get(current).push(t[1]);
    }
    if (tiers.size === 0) throw new Error('卡池解析出 0 层，02_data.lua 格式可能变了');

    const w = /TierWeights\s*=\s*\{\s*([\d,\s]+)\}/.exec(lines.join('\n'));
    const weights = w ? w[1].split(',').map(s => s.trim()).filter(Boolean).map(Number) : [37, 50, 10, 3];
    return { tiers, weights };
}

/** 解析 DSA 的 16 张阵营兵种表：返回 Map<单位名, 阵营号> */
function parseRoster(lines) {
    const map = new Map();
    let faction = 0;
    let inside = false;
    for (const line of lines) {
        const head = /^g_(?:Infantry|Vehicle|AirCraft|Ship)(Allied|Soviet|Japan|Celestial)\s*=\s*\{/.exec(line);
        if (head) { faction = FACTION_NAMES[head[1]]; inside = true; continue; }
        if (inside && /^\}/.test(line)) { inside = false; faction = 0; continue; }
        if (!inside) continue;
        const t = /Type\s*=\s*"([A-Za-z0-9_]+)"/.exec(line);
        if (t && !map.has(t[1])) map.set(t[1], faction);
    }
    return map;
}

function fallbackFaction(type) {
    if (FACTION_OVERRIDE[type] !== undefined) return FACTION_OVERRIDE[type];
    for (const [re, faction] of PREFIX_FALLBACK) {
        if (re.test(type)) return faction;
    }
    return 0;
}

/**
 * 解析 DSA 自己的「非可生产单位」清单：
 *   HextechRune/05_ultimate_creature.lua 的 HextechRune.NonProductionUnitTier
 * 格式：`日本武士类型 = 档位数字,  -- 中文注释`（档位 1~5，5 = MCV/超阶）
 * 这是全仓最权威的一份"玩家造不出来的单位"名单，DSA 拿它做终极生物符文。
 */
function parseNonProducible(lines) {
    const map = new Map();
    let inside = false;
    for (const line of lines) {
        if (!inside) {
            if (/HextechRune\.NonProductionUnitTier\s*=\s*\{/.test(line)) inside = true;
            continue;
        }
        if (/^\}/.test(line)) break;
        const m = /^\s*([A-Za-z0-9_]+)\s*=\s*(\d+)\s*,/.exec(line);
        if (m) map.set(m[1], Number(m[2]));
    }
    return map;
}

function emitTierTable(out, indent, tiers, factionFilter) {
    const tierKeys = Array.from(tiers.keys()).sort((a, b) => a - b);
    for (const tier of tierKeys) {
        const list = tiers.get(tier).filter((t) => factionFilter === null || factionFilter(t));
        if (list.length === 0) continue;
        out.push(`${indent}[${tier}] = {`);
        const chunk = list.map(t => `"${t}",`);
        for (let i = 0; i < chunk.length; i += 4) {
            out.push(`${indent}    ` + chunk.slice(i, i + 4).join(' '));
        }
        out.push(`${indent}},`);
    }
}

function main() {
    const { tiers, weights } = parsePool(readLines(SRC_POOL));
    const roster = parseRoster(readLines(SRC_ROSTER));

    // ---- 扩充：把「非可生产单位」并进卡池（档位沿用 DSA 的 NonProductionUnitTier，每个都是 1 个）----
    const nonProd = parseNonProducible(readLines(SRC_NONPROD));
    const existing = new Set();
    for (const list of tiers.values()) for (const t of list) existing.add(t);
    const maxTier = Math.max(...Array.from(tiers.keys()));

    const added = [];
    const excludedMVC = [];
    const excludedList = [];
    const skippedExisting = [];
    const skippedUnknown = [];
    for (const [type, dsaTier] of nonProd) {
        if (EXCLUDED_PATTERN.test(type)) { excludedMVC.push(type); continue; }
        if (BLACKLIST.indexOf(type) >= 0) { excludedList.push(type); continue; }
        if (existing.has(type)) { skippedExisting.push(type); continue; }
        let f = roster.get(type);
        if (f === undefined) f = fallbackFaction(type);
        if (f < 1 || f > 4) { skippedUnknown.push(type); continue; }
        const ourTier = Math.min(Math.max(dsaTier, 1), maxTier);
        if (!tiers.has(ourTier)) tiers.set(ourTier, []);
        tiers.get(ourTier).push(type);
        existing.add(type);
        added.push({ type, tier: ourTier, faction: f, dsaTier });
    }

    // 分类
    const byFaction = { 1: [], 2: [], 3: [], 4: [] };
    const unmapped = [];
    const factionOf = new Map();
    for (const tier of Array.from(tiers.keys()).sort((a, b) => a - b)) {
        for (const type of tiers.get(tier)) {
            let f = roster.get(type);
            if (f === undefined) {
                f = fallbackFaction(type);
                unmapped.push(`T${tier} ${type} → ${f === 0 ? '未定' : f}`);
            }
            factionOf.set(type, f);
            if (f >= 1 && f <= 4) byFaction[f].push(type);
        }
    }

    const out = [];
    out.push('-- ============================================================');
    out.push('-- 抽卡卡池 —— **自动生成，勿手改**');
    out.push('-- 生成器：ALittlePlot/tools/import-dsa-pool.js');
    out.push('-- 来源  ：DSA_ggz自走棋 / lua/GAME/PureDraw/02_data.lua（卡池）');
    out.push('--          DSA_ggz自走棋 / lua/GAME/RecycleUnit.lua（阵营分类，16 张兵种表）');
    out.push('--          DSA_ggz自走棋 / lua/GAME/HextechRune/05_ultimate_creature.lua');
    out.push('--            （NonProductionUnitTier = 非可生产单位清单，已按档位并入）');
    out.push('-- 改动  ：条目压成纯字符串，删掉 CustomDrawCount（= 每次只出 1 个）；');
    out.push('--          按阵营切成四份：1=盟军 2=苏联 3=升阳 4=神州。');
    out.push(`--          本次新并入非可生产单位 ${added.length} 个`
        + (excludedMVC.length ? `（另有 ${excludedMVC.length} 个 MCV 按本图设定排除）` : ''));
    out.push('-- ============================================================');
    out.push('');
    out.push(`ChoukaDrawTierWeights = { ${weights.join(', ')} }   -- 合计 ${weights.reduce((a, b) => a + b, 0)}（必须 100）`);
    out.push('');
    out.push('-- 全池：只用来批量登记"出生事件"，抽卡不走这张表');
    out.push('ChoukaDrawPool = {');
    emitTierTable(out, '    ', tiers, null);
    out.push('}');
    out.push('');
    out.push('-- 分阵营卡池：抽卡时按玩家阵营只在自己那份里抽');
    out.push('ChoukaDrawPoolBySide = {');
    for (const f of [1, 2, 3, 4]) {
        out.push(`    [${f}] = {   -- ${{ 1: '盟军', 2: '苏联', 3: '升阳', 4: '神州' }[f]}（${byFaction[f].length} 种）`);
        emitTierTable(out, '        ', tiers, (t) => factionOf.get(t) === f);
        out.push('    },');
    }
    out.push('}');
    out.push('');
    if (unmapped.length > 0) {
        out.push('-- ⚠ 下面这些条目在 DSA 的 16 张阵营兵种表里没查到，按名字前缀兜底（数字=阵营号）');
        for (const line of unmapped) out.push(`--   ${line}`);
    }
    out.push('');

    fs.writeFileSync(OUT, out.join('\n'), 'utf8');

    const total = [1, 2, 3, 4].reduce((n, f) => n + byFaction[f].length, 0);
    console.log(`出：${OUT}  (${fs.statSync(OUT).size} B)`);
    console.log(`  全池 ${total} 种；分池：盟军 ${byFaction[1]} / 苏联 ${byFaction[2]} / 升阳 ${byFaction[3]} / 神州 ${byFaction[4]}`);
    console.log(`  本次并入非可生产单位 ${added.length} 个：`);
    const byTier = {};
    for (const a of added) byTier[a.tier] = (byTier[a.tier] || 0) + 1;
    for (const t of Object.keys(byTier).sort()) console.log(`      T${t}: ${byTier[t]} 个`);
    if (excludedMVC.length) console.log(`  按设定排除 MCV ${excludedMVC.length} 个：${excludedMVC.join(', ')}`);
    if (excludedList.length) console.log(`  按 BLACKLIST 拉黑 ${excludedList.length} 个：${excludedList.join(', ')}`);
    if (skippedExisting.length) console.log(`  卡池里本来就有、跳过 ${skippedExisting.length} 个`);
    if (skippedUnknown.length) console.log(`  ! 阵营未定、未加入：${skippedUnknown.join(', ')}`);
    if (unmapped.length > 0) {
        console.log(`  ! ${unmapped.length} 种走前缀兜底，请抽查：`);
        for (const line of unmapped) console.log(`      ${line}`);
    }
}

main();
