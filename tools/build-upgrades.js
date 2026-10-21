#!/usr/bin/env node
/**
 * build-upgrades.js —— 生成「开局给玩家解锁的全部科技协议」名单
 * ----------------------------------------------------------------------------
 * 只读解析三处现成名单（这些地图本来就是靠它们给玩家满科技的）：
 *   1. 双兵种作战-狭路相逢3.258V8/Troop Selection/initialization.lua
 *        Tech_Upgrade / Enhanced_Tech_Upgrade —— 玩家可购买的科技协议
 *        （含龙船全套：Upgrade_CelestialDragonShip_*）
 *   2. DSA_ggz自走棋/lua/Upgrade.lua 的 upgrades 列表 —— 抽卡升级完成通知用的全量表
 *   3. 双兵种作战-狭路相逢3.258V8/lib/enums/UpgradeEnum.lua —— 整个 mod 的升级枚举
 *
 * 输出 scripts/lua/chouka/gen_upgrades.lua：ChoukaUnlockUpgrades = { "Upgrade_X", ... }
 * 运行时由 15_upgrades.lua 用 ExecuteAction("GIVE_PLAYER_UPGRADE", "<All Players>", name) 发下去。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const BASE = 'E:\\Ra3_CenterChess\\日冕地图lua例子';
const SRC_DUAL_INIT = path.join(BASE, '双兵种作战-狭路相逢3.258V8', 'Troop Selection', 'initialization.lua');
const SRC_DSA_UPGRADE = path.join(BASE, 'DSA_ggz自走棋', 'lua', 'Upgrade.lua');
const SRC_ENUM = path.join(BASE, '双兵种作战-狭路相逢3.258V8', 'lib', 'enums', 'UpgradeEnum.lua');
const OUT = path.resolve(__dirname, '..', 'scripts', 'lua', 'chouka', 'gen_upgrades.lua');

// 不给的：带 RANK 的是自走棋的"升星"特殊升级，发下去会触发它自己的升星脚本逻辑
const DENY = [
    'Upgrade_CelestialTech_RANK3',
];

function read(file) {
    if (!fs.existsSync(file)) throw new Error(`找不到：${file}`);
    return fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
}

/** 从 `表名 = { ... }` 里抓出所有 "Upgrade_X" */
function extractTable(src, tableName) {
    const start = src.indexOf(tableName);
    if (start < 0) return [];
    const open = src.indexOf('{', start);
    if (open < 0) return [];
    const close = src.indexOf('}', open);
    if (close < 0) return [];
    const body = src.slice(open + 1, close);
    const out = [];
    const re = /"([A-Za-z0-9_]+)"/g;
    let m;
    while ((m = re.exec(body)) !== null) out.push(m[1]);
    return out;
}

/** 抓文件里所有 Upgrade_ 开头的标识符 */
function extractAll(src) {
    const out = [];
    const re = /\b(Upgrade_[A-Za-z0-9_]+)\b/g;
    let m;
    while ((m = re.exec(src)) !== null) out.push(m[1]);
    return out;
}

function main() {
    const dual = read(SRC_DUAL_INIT);
    const dsa = read(SRC_DSA_UPGRADE);
    const enumSrc = read(SRC_ENUM);

    const tech = extractTable(dual, 'Tech_Upgrade');
    const enhanced = extractTable(dual, 'Enhanced_Tech_Upgrade');
    const dsaList = extractTable(dsa, 'upgrades');
    const enumAll = extractAll(enumSrc).filter(n => n !== 'UpgradeEnum');

    const order = [];
    const seen = new Set();
    const denied = [];
    function push(list) {
        for (const name of list) {
            if (name === 'Upgrade' || name === 'UpgradeEnum') continue;
            if (DENY.indexOf(name) >= 0) {
                if (denied.indexOf(name) < 0) denied.push(name);
                continue;
            }
            if (seen.has(name)) continue;
            seen.add(name);
            order.push(name);
        }
    }
    push(tech);
    push(enhanced);
    push(dsaList);
    push(enumAll);

    const dragonShip = order.filter(n => n.indexOf('DragonShip') >= 0);

    const out = [];
    out.push('-- ============================================================');
    out.push('-- 开局解锁的全部科技协议 —— **自动生成，勿手改**');
    out.push('-- 生成器：ALittlePlot/tools/build-upgrades.js');
    out.push('-- ⚠ 玩家不能造建筑，科技协议也买不了，所以干脆全部直接发下去。');
    out.push('-- 名单来源：双兵种作战 Tech_Upgrade + Enhanced_Tech_Upgrade，');
    out.push('--           DSA Upgrade.lua 的 upgrades 列表，双兵种 UpgradeEnum 全量枚举。');
    out.push(`-- 共 ${order.length} 条，其中龙船专属 ${dragonShip.length} 条。`);
    out.push('-- ============================================================');
    out.push('');
    out.push('ChoukaUnlockUpgrades = {');
    const chunk = order.map(n => `"${n}",`);
    for (let i = 0; i < chunk.length; i += 3) {
        out.push('    ' + chunk.slice(i, i + 3).join(' '));
    }
    out.push('}');
    out.push('');
    if (dragonShip.length) {
        out.push('-- 龙船（青龙战斗核心舰）专属升级：');
        for (const n of dragonShip) out.push(`--   ${n}`);
        out.push('');
    }

    fs.writeFileSync(OUT, out.join('\n'), 'utf8');
    console.log(`出：${OUT}  (${fs.statSync(OUT).size} B)`);
    console.log(`  共 ${order.length} 条：双兵种科技 ${tech.length} / 双兵种增强 ${enhanced.length} / DSA ${dsaList.length} / 枚举 ${enumAll.length}（去重后 ${order.length}）`);
    console.log(`  龙船专属 ${dragonShip.length} 条：${dragonShip.join(', ')}`);
    if (denied.length) console.log(`  按 DENY 排除：${denied.join(', ')}`);
}

main();
