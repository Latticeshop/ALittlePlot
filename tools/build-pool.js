#!/usr/bin/env node
/**
 * build-pool.js —— 按作者给的《完整单位表》生成抽卡卡池
 * ----------------------------------------------------------------------------
 * 真源有两份（都只读）：
 *   A. 作者清单：本文件里的 USER_POOL（T1~T5，每组按 步兵|载具|空军|海军 分组）
 *   B. 中文名 → 单位类型名 字典：
 *        · 日冕地图lua例子/自定义抽卡池.txt（DSA 抽卡池表，含 中文名/单位类型/价格）
 *        · DSA HextechRune/05_ultimate_creature.lua 的 NonProductionUnitTier 注释（非可生产单位）
 *
 * 生成 scripts/lua/chouka/gen_pool.lua，包含：
 *   ChoukaDrawTierWeights   四档权重
 *   ChoukaUnitCategory      类型名 → 类别（1步兵 2载具 3空军 4海军 5两栖）
 *   ChoukaDrawPoolBySide    [阵营][档] = { 类型名, ... }
 *
 * ⚠ 生成器会把「没能翻译成类型名」的条目全部打印出来，按提示补 ALIAS 即可。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const BASE = 'E:\\Ra3_CenterChess\\日冕地图lua例子';
const SRC_TXT = path.join(BASE, '自定义抽卡池.txt');
const SRC_NONPROD = path.join(BASE, 'DSA_ggz自走棋', 'lua', 'GAME', 'HextechRune', '05_ultimate_creature.lua');
const OUT = path.resolve(__dirname, '..', 'scripts', 'lua', 'chouka', 'gen_pool.lua');

// 档位权重（T1..T5）。T5 = 超阶（青龙/奥林匹斯/千鸟/东风/大型维修天灯），单独一档，不再并入 T4。
const TIER_WEIGHTS = [37, 50, 10, 2.5, 0.5];

// ---------------- 作者给的完整单位表（按 步兵｜载具｜空军｜海军 分组）----------------
const USER_POOL = {
    1: {
        inf: '警犬 维和步兵 标枪兵 战熊 征召兵 防空部队 爆裂机器人 帝国武士 坦克杀手 弓箭少女 天眼哨机 龙炎军 破甲铁卫 火炮机车 各国工程师 勘察飞轮 游骑兵 狂热帝国武士',
        veh: '激流ACV 多功能步兵战车 恐怖机器人 镰刀机甲 牛蛙战车 天狗 凌波 磁弩 迅雷运输艇 史普尼克勘查车 各国采矿车 各国基地车 机枪悍马 灰熊坦克 蝾螈步兵战车 石勒喀河自行高射炮 貔貅甲 貔貅乙 神州礼炮 神州军用叉车',
        air: '维护者 阿波罗 双刃 米格 毕方 凤凰 蜂鸟侦查无人机 民用气象飞艇',
        sea: '海豚 水翼船 磁爆快艇 长枪迷你潜艇 乌篷猎船',
    },
    2: {
        inf: '磁爆部队 忍者 岚影刺 间谍',
        veh: '守护者坦克 光棱 犀牛 重锤 钢铁浪人 麒麟 青锋 海啸 VX 莱茵豹主战坦克 菱齿象坦克歼击车 平定者 BMPT坦克支援车 ZSU-85自行防空炮 偏流两栖高射炮 章鱼突击炮 铁锤 收割机甲 磁爆坦克 玄铁歼击车 粉碎者',
        air: '冰冻直升机 朱雀 复仇者攻击机 夜莺直升机',
        sea: '突袭驱逐舰 阿库拉 薙刀 计蒙 海翼 气垫登陆舰',
    },
    3: {
        inf: '冰冻军团 迅雷天罡 谭雅 娜塔莎 火箭天使 百合子',
        veh: '心神机甲 雅典娜炮 幻影 V4 天启 鬼王 波能坦克 祝融攻坚 祝融雷铳 白虎 菊花导弹车 郁金香自行迫击炮',
        air: '阿瑞斯 世纪 苏霍伊 伊尔 重明 金乌 樱花回天雷 鬼樱特攻机 鲁斯兰大型运输机 纤夫 维修天灯',
        sea: '波塞冬 光荣 太刀 玄冥 一式磁轨炮重巡',
    },
    4: {
        veh: '未来坦克X-1 特洛伊要塞 新旧联盟 鬼王X 破军金甲',
        air: '先锋炮艇机 基洛夫 摇光巡天炮 武装纤夫 中型维修天灯',
        sea: '航母 无畏 将军 玄武 超级要塞 忒提斯战列舰',
    },
    5: {
        sea: '青龙战斗核心舰 奥林匹斯级航空母舰 千鸟特攻母舰',
        veh: '东风洲际导弹发射车',
        air: '大型维修天灯',
    },
};

// 两栖：水陆都能刷（不在表里的一律按分组判定）
const AMPHIBIOUS = [
    'AlliedAntiInfantryVehicle',          // 激流 ACV 水面形态
    'CelestialAntiInfantryVehicle_B',     // 凌波护卫战车
    'AlliedLandingCraftAirCushion',       // 气垫登陆舰
    'SovietAntiNavyShipTech1',            // 磁爆快艇（陆地形态）
    'CelestialAntiAirShip',               // 磁弩防空系统（水陆两用）
    'CelestialAntiAirVehicle',            // 磁弩高射炮（同上，岸上形态）
    'SovietAntiAirShip',                  // 牛蛙战车（水陆两栖）
];

// 「各国X」展开成四个阵营的同名单位
const ALL_FACTIONS = {
    各国工程师: ['AlliedEngineer', 'SovietEngineer', 'JapanEngineer', 'CelestialEngineer'],
    各国采矿车: ['AlliedMiner', 'SovietMiner', 'JapanMiner', 'CelestialMiner'],
    各国基地车: ['AlliedMCV', 'SovietMCV', 'JapanMCV', 'CelestialMCV'],
};

const ALIAS = require('./pool-alias.js');

// 抽卡池里剔掉「打不了架」的单位（作者原话：除了龙船以外确实都无法战斗）。
// 龙船 = CelestialMCV（青龙战斗核心舰）保留，它是能打的。
const BLACKLIST = [
    'AlliedMCV', 'SovietMCV', 'JapanMCV',                 // 各国基地车
    'AlliedMiner', 'SovietMiner', 'JapanMiner', 'CelestialMiner',   // 各国采矿车
    'AlliedEngineer', 'SovietEngineer', 'JapanEngineer', 'CelestialEngineer',
    'CelestialForkLiftVehicle',      // 神州军用叉车
    'CelestialSaluteGun',            // 神州礼炮
    'SovietWeatherBalloon',          // 民用气象飞艇
    'SovietSurveyor',                // 史普尼克勘查车
    // 注：维修天灯 CelestialEngineerRepairDrone **不剔除** —— 作者明确要能抽到（场上维修很有用）
];

// 「档位钉死」（作者 2026-10）：这些类型**只允许出现在指定档**，别的档一律跳过。
//   · CelestialMCV = 青龙战斗核心舰，本质就是 T5 单位 —— 以前它跟着「各国基地车」被塞进
//     神州 T1 载具，于是抽卡会抽到基地车。现在只在 T5 出。
//   · 其余三家的基地车（AlliedMCV / SovietMCV / JapanMCV）在 BLACKLIST 里，永不进池。
const TIER_PIN = {
    CelestialMCV: 5,
};

const FACTION_BY_PREFIX = [
    [/^Allied/, 1], [/^prismtank/, 1], [/^RheinEntente/, 1],
    [/^Soviet/, 2], [/^VU/, 2], [/^WinterArmy/, 2], [/^Overlord/, 2],
    [/^Japan/, 3],
    [/^Celestial/, 4],
];

function normalize(s) {
    return String(s)
        .replace(/[\s　]/g, '')
        .replace(/[“”"'‘’]/g, '')
        .replace(/[（）()·、,，。.]/g, '')
        .replace(/[-—_]/g, '');
}

function readLines(file) {
    if (!fs.existsSync(file)) throw new Error(`找不到：${file}`);
    return fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').split('\n');
}

/** 字典 1：自定义抽卡池.txt 的「中文名<TAB>单位类型」 */
function parseTxtDict(lines) {
    const dict = new Map();
    for (const line of lines) {
        const m = /^(\d)\t([^\t]+)\t([A-Za-z][A-Za-z0-9_]*)\t/.exec(line);
        if (!m) continue;
        const key = normalize(m[2]);
        if (!dict.has(key)) dict.set(key, { type: m[3], zh: m[2] });
    }
    return dict;
}

/** 字典 2：NonProductionUnitTier 的 `类型 = 档,  -- 中文名` 注释 */
function parseNonProdDict(lines) {
    const dict = new Map();
    let inside = false;
    for (const line of lines) {
        if (!inside) {
            if (/HextechRune\.NonProductionUnitTier\s*=\s*\{/.test(line)) inside = true;
            continue;
        }
        if (/^\}/.test(line)) break;
        const m = /^\s*([A-Za-z0-9_]+)\s*=\s*(\d+)\s*,[^\-]*(--\s*(.+))?$/.exec(line);
        if (!m) continue;
        const type = m[1];
        const zh = m[4] ? m[4].replace(/[（(].*?[)）]/g, '') : '';
        if (zh) {
            const key = normalize(zh);
            if (!dict.has(key)) dict.set(key, { type, zh });
        }
    }
    return dict;
}

function factionOf(type) {
    for (const [re, f] of FACTION_BY_PREFIX) {
        if (re.test(type)) return f;
    }
    return 0;
}

function categoryOf(type, group) {
    if (AMPHIBIOUS.indexOf(type) >= 0) return 5;
    if (group === 'inf') return 1;
    if (group === 'veh') return 2;
    if (group === 'air') return 3;
    if (group === 'sea') return 4;
    return 0;
}

function main() {
    const txtDict = parseTxtDict(readLines(SRC_TXT));
    const npDict = parseNonProdDict(readLines(SRC_NONPROD));

    const unresolved = [];
    const ambiguousFaction = [];
    const fuzzyLog = [];
    const blacklisted = [];
const pinned = [];
    const perSide = { 1: new Map(), 2: new Map(), 3: new Map(), 4: new Map() };
    const t5 = [];
    const category = new Map();
    const zhToType = new Map();

    function addEntry(type, tier, group, zhLabel, source) {
        const ourTier = tier;               // 现在 T1~T5 各自独立，不再并档
        if (BLACKLIST.indexOf(type) >= 0) {
            blacklisted.push(`${zhLabel} → ${type}`);
            return false;
        }
        if (TIER_PIN[type] !== undefined && TIER_PIN[type] !== ourTier) {
            pinned.push(`${zhLabel} → ${type}（只留在 T${TIER_PIN[type]}，T${ourTier} 跳过）`);
            return false;
        }
        const faction = factionOf(type);
        if (faction < 1 || faction > 4) {
            ambiguousFaction.push(`${zhLabel} → ${type}`);
            return false;
        }
        const cat = categoryOf(type, group);
        category.set(type, cat);
        if (ourTier === 5) {
            // T5 = 全阵营共用一张表（作者要求）
            if (t5.indexOf(type) < 0) t5.push(type);
            return true;
        }
        if (!perSide[faction].has(ourTier)) perSide[faction].set(ourTier, []);
        const list = perSide[faction].get(ourTier);
        if (list.indexOf(type) < 0) list.push(type);
        return true;
    }

    for (const tierKey of Object.keys(USER_POOL).sort((a, b) => Number(a) - Number(b))) {
        const tier = Number(tierKey);
        const groups = USER_POOL[tierKey];
        for (const group of Object.keys(groups)) {
            for (const raw of groups[group].split(/\s+/).filter(Boolean)) {
                const key = normalize(raw);
                if (ALL_FACTIONS[key]) {
                    for (const type of ALL_FACTIONS[key]) {
                        if (!addEntry(type, tier, group, raw, 'allFactions')) {
                            // 个别阵营没有这个单位，忽略
                        }
                    }
                    continue;
                }
                let type = null;
                let source = '';
                // 优先级：DSA 池表（作者清单里的名字多数能精确对上）→ 非可生产单位表 → 手工 alias
                if (txtDict.has(key)) { type = txtDict.get(key).type; source = 'txt'; }
                else if (npDict.has(key)) { type = npDict.get(key).type; source = 'nonprod'; }
                else if (ALIAS[key]) { type = ALIAS[key]; source = 'alias'; }
                else {
                    // 唯一模糊匹配：短名（维护者 ↔ 维护者轰炸机）
                    const cands = [];
                    for (const [k, v] of txtDict) {
                        if (k.indexOf(key) >= 0 || key.indexOf(k) >= 0) cands.push({ k, v });
                    }
                    for (const [k, v] of npDict) {
                        if (k.indexOf(key) >= 0 || key.indexOf(k) >= 0) cands.push({ k, v });
                    }
                    const uniq = [];
                    const seenType = new Set();
                    for (const c of cands) {
                        if (!seenType.has(c.v.type)) { seenType.add(c.v.type); uniq.push(c); }
                    }
                    if (uniq.length === 1) {
                        type = uniq[0].v.type;
                        source = `fuzzy:${uniq[0].k}`;
                    } else if (uniq.length > 1) {
                        unresolved.push(`${raw}（T${tier}/${group}）歧义：` + uniq.map(c => `${c.k}=${c.v.type}`).join(' | '));
                        continue;
                    } else {
                        unresolved.push(`${raw}（T${tier}/${group}）`);
                        continue;
                    }
                }
                if (source !== 'txt' && source !== 'nonprod') fuzzyLog.push(`${raw} → ${type}   [${source}]`);
                zhToType.set(raw, type);
                addEntry(type, tier, group, raw, source);
            }
        }
    }

    // ---- 输出 ----
    const out = [];
    // ★ lua 头只留 3 行：ScriptsData.json 的 payload 会把注释一起算进节点体积（上限 64KB），
    //   详细说明留在本文件（JS 注释不进游戏），别写进生成的 lua。
    out.push('-- ============================================================');
    out.push('-- 抽卡卡池：自动生成勿手改，生成器 tools/build-pool.js（真源=作者《完整单位表》）');
    out.push('-- ============================================================');
    out.push('');
    out.push(`ChoukaDrawTierWeights = { ${TIER_WEIGHTS.join(', ')} }`);
    out.push('');
    out.push('-- 类型名 → 类别（1步兵 2载具 3空军 4海军 5两栖）');
    out.push('ChoukaUnitCategory = {');
    const byCat = { 1: [], 2: [], 3: [], 4: [], 5: [] };
    for (const [type, cat] of category) byCat[cat].push(type);
    for (const cat of [1, 2, 3, 4, 5]) {
        const names = { 1: '步兵', 2: '载具', 3: '空军', 4: '海军', 5: '两栖' }[cat];
        out.push(`    -- ${names}（${byCat[cat].length}）`);
        const chunk = byCat[cat].map(t => `${t} = ${cat},`);
        for (let i = 0; i < chunk.length; i += 3) out.push('    ' + chunk.slice(i, i + 3).join(' '));
    }
    out.push('}');
    out.push('');
    out.push('-- 分阵营卡池：[阵营][档] = { 类型名, ... }（T1~T4，T5 见下面单独一张表）');
    out.push('ChoukaDrawPoolBySide = {');
    const sideNames = { 1: '盟军', 2: '苏联', 3: '升阳', 4: '神州' };
    for (const side of [1, 2, 3, 4]) {
        const total = Array.from(perSide[side].values()).reduce((n, l) => n + l.length, 0);
        out.push(`    [${side}] = {   -- ${sideNames[side]}（${total} 种）`);
        for (const tier of Array.from(perSide[side].keys()).sort((a, b) => a - b)) {
            const list = perSide[side].get(tier);
            out.push(`        [${tier}] = {`);
            const chunk = list.map(t => `"${t}",`);
            for (let i = 0; i < chunk.length; i += 4) out.push('            ' + chunk.slice(i, i + 4).join(' '));
            out.push('        },');
        }
        out.push('    },');
    }
    out.push('}');
    out.push('');
    out.push('-- T5：**全阵营共用一张表**（作者要求"合为一张表，全阵营可出"）');
    out.push('ChoukaDrawPoolT5 = {');
    const t5chunk = t5.map(t => `"${t}",`);
    for (let i = 0; i < t5chunk.length; i += 4) {
        out.push('    ' + t5chunk.slice(i, i + 4).join(' '));
    }
    out.push('}');
    out.push('');

    fs.writeFileSync(OUT, out.join('\n'), 'utf8');

    console.log(`出：${OUT}  (${fs.statSync(OUT).size} B)`);
    for (const side of [1, 2, 3, 4]) {
        const total = Array.from(perSide[side].values()).reduce((n, l) => n + l.length, 0);
        const perTier = Array.from(perSide[side].keys()).sort((a, b) => a - b)
            .map(t => `T${t}:${perSide[side].get(t).length}`).join(' ');
        console.log(`  ${sideNames[side]}  ${total} 种   ${perTier}`);
    }
    console.log(`  类别：步兵 ${byCat[1].length} / 载具 ${byCat[2].length} / 空军 ${byCat[3].length} / 海军 ${byCat[4].length} / 两栖 ${byCat[5].length}`);
    if (ambiguousFaction.length) {
        console.log(`  ! 阵营判不出来的 ${ambiguousFaction.length} 个：`);
        for (const line of ambiguousFaction) console.log(`      ${line}`);
    }
    if (fuzzyLog.length) {
        console.log(`  · 非精确匹配（请核对）${fuzzyLog.length} 个：`);
        for (const line of fuzzyLog) console.log(`      ${line}`);
    }
    if (blacklisted.length) {
    if (pinned.length) {
        console.log(`  · 按 TIER_PIN 只留在指定档的 ${pinned.length} 个：`);
        console.log(`      ${pinned.join('、')}`);
    }
        console.log(`  · 按 BLACKLIST 剔除「不能打架」的 ${blacklisted.length} 个：`);
        console.log(`      ${blacklisted.join('、')}`);
    }
    if (unresolved.length) {
        console.log(`  ! 没能翻译成类型名的 ${unresolved.length} 个（补 ALIAS 即可）：`);
        for (const line of unresolved) console.log(`      ${line}`);
    }
}

main();
