// ============================================================
// 把"只用于日志"的文案从 01_texts.lua 拆回业务代码，并给剩下的玩家可见文案改成好认的名字
//
// 用法：node tools/split-log-texts.js [--dry]
//
// 判定规则：
//   · 某条文案的**所有**引用点都在 _LOG(...) 里 → 日志文案，搬回代码原地；
//   · 只要有一处用在 _ALERT / 对话框 / 公屏 / 飘字 / 计分板 / 按钮文字 → 玩家可见，留在 ChoukaT。
//   · 少数"先赋给变量再进日志"的（format 结果赋给 group.whyWater 之类）用 FORCE_LOG 手工点名。
//
// ★ 搬回代码时用的是 01_texts.lua 里**现在的文字**（你在那里手改过的内容会原样搬回代码，不会丢）。
// ============================================================
const fs = require('fs');
const path = require('path');
const callsite = require('./lua-callsite.js');

const ROOT = path.resolve(__dirname, '..');
const LUA_DIR = path.join(ROOT, 'scripts', 'lua', 'chouka');
const TEXTS = path.join(LUA_DIR, '01_texts.lua');
const DRY = process.argv.indexOf('--dry') >= 0;

// 手工点名：虽然外层不是 _LOG，但实质上只进日志
const FORCE_LOG = ['start8', 'pdr6', 'start1', 'pdr1'];

// 剩下的玩家可见文案 → 语义化 key（两边同时改）
const RENAME = {
    box1: 'boxRefreshed',
    start1: 'waitHost',
    start5: 'scopeAll',
    start6: 'scopeOwn',
    start7: 'hostDialogTitle',
    start9: 'hostTip',
    dog3: 'dogTip',
    ctr1: 'centerCrateRefreshed',
    ctr2: 'centerOilLocate',
    ctr3: 'centerOilCaptured',
    ctr4: 'centerOilProgress',
    crate1: 'crateCleaned',
    lv1: 'levelAutoUp',
    lv2: 'levelMax',
    lv3: 'levelNoMoney',
    lv4: 'levelUp',
    frame1: 'frameTimeout',
    btn1: 'btnMarket',
    btn2: 'btnHextech',
    btn3: 'btnLevelMax',
    btn4: 'btnLevelPrice',
    btn5: 'btnTowerPrice',
    btn6: 'btnTowerNoMoney',
    btn7: 'towerSlotsFull',
    btn8: 'towerBadPos',
    btn9: 'towerSpawnFail',
    btn10: 'towerBought',
    ai1: 'aiPersona',
    ai2: 'aiDetected',
    ai3: 'aiDrawInfo',
    ai4: 'aiAttackQueue',
    hud3: 'hudTitle',
    hud5: 'hudCountdown',
};

const files = fs.readdirSync(LUA_DIR).filter(f => f.endsWith('.lua') && f !== '01_texts.lua');

// ---------- ① 解析 01_texts.lua ----------
const textSrc = fs.readFileSync(TEXTS, 'utf8').replace(/\r\n/g, '\n');
const entries = [];
{
    const lines = textSrc.split('\n');
    let i = 0;
    while (i < lines.length) {
        const m = /^ChoukaT\.([A-Za-z0-9_]+)\s*=\s*(.*)$/.exec(lines[i]);
        if (!m) { i++; continue; }
        // 多行条目：值写在下面几行的（第一行以 = 结尾，后续行以 .. 结尾），要整块取到
        let j = i;
        while (j + 1 < lines.length && (/=\s*$/.test(lines[j]) || /\.\.\s*$/.test(lines[j]))) j++;
        entries.push({ key: m[1], raw: m[2].trim(), block: lines.slice(i, j + 1) });
        i = j + 1;
    }
}

// ---------- ② 引用点分类 ----------
const sources = new Map();
for (const f of files) sources.set(f, fs.readFileSync(path.join(LUA_DIR, f), 'utf8').replace(/\r\n/g, '\n'));

// 用共享实现判断"这个字符串是不是在 _LOG(...) 里"
const builtCache = new Map();
function outerCallName(src, pos) {
    if (!builtCache.has(src)) builtCache.set(src, callsite.buildCallStacks(src));
    return callsite.outerCallName(src, pos, builtCache.get(src));
}

const calls = new Map();     // key → Set(callName)
for (const e of entries) calls.set(e.key, new Set());
for (const [f, src] of sources) {
    const re = /ChoukaT\.([A-Za-z0-9_]+)/g;
    let m;
    while ((m = re.exec(src)) !== null) {
        const key = m[1];
        if (!calls.has(key)) { console.log(`! 代码里引用了未定义的 ChoukaT.${key}（${f}）`); continue; }
        calls.get(key).add(outerCallName(src, m.index) || '?');
    }
}

const logKeys = [], showKeys = [];
for (const e of entries) {
    const cs = calls.get(e.key);
    const allLog = cs.size > 0 && Array.from(cs).every(c => c === '_LOG');
    if (allLog || FORCE_LOG.indexOf(e.key) >= 0) logKeys.push(e);
    else showKeys.push({ ...e, calls: Array.from(cs) });
}
console.log(`共 ${entries.length} 条：玩家可见 ${showKeys.length} 条（留在 01_texts.lua），纯日志 ${logKeys.length} 条（搬回代码）`);
for (const s of showKeys) console.log(`  ✔ ${s.key.padEnd(8)} [${s.calls.join('/')}]`);
for (const l of logKeys) console.log(`  → ${l.key.padEnd(8)} 日志`);

if (DRY) { console.log('\n【dry-run，未改文件】'); process.exit(0); }

// ---------- ③ 日志文案搬回代码 ----------
for (const e of logKeys) {
    for (const [f, src] of sources) {
        const re = new RegExp('ChoukaT\\.' + e.key + '\\b', 'g');
        if (src.search(re) >= 0) sources.set(f, src.replace(new RegExp('ChoukaT\\.' + e.key + '\\b', 'g'), e.raw));
    }
}

// ---------- ④ 玩家可见文案改名 ----------
const renames = [];
for (const s of showKeys) {
    const to = RENAME[s.key];
    if (!to || to === s.key) continue;
    renames.push([s.key, to]);
}
for (const [from, to] of renames) {
    for (const [f, src] of sources) {
        const re = new RegExp('ChoukaT\\.' + from + '\\b', 'g');
        if (src.search(re) >= 0) sources.set(f, src.replace(new RegExp('ChoukaT\\.' + from + '\\b', 'g'), 'ChoukaT.' + to));
    }
}
console.log(`\n改名 ${renames.length} 条：` + renames.map(([a, b]) => a + '→' + b).join('、'));

for (const [f, src] of sources) fs.writeFileSync(path.join(LUA_DIR, f), src.replace(/\n/g, '\r\n'), 'utf8');

// ---------- ⑤ 重建 01_texts.lua（只留可见文案，按模块分组） ----------
const drop = new Set(logKeys.map(e => e.key));
const renameMap = new Map(renames);
const moduleOf = (key) => {
    for (const [f, src] of sources) {
        if (new RegExp('ChoukaT\\.' + (renameMap.get(key) || key) + '\\b').test(src)) return f.replace(/\.lua$/, '');
    }
    return '';
};
const outLines = textSrc.split('\n').filter(() => true);
const kept = [];
{
    const lines = textSrc.split('\n');
    let i = 0;
    while (i < lines.length) {
        const m = /^ChoukaT\.([A-Za-z0-9_]+)\s*=/.exec(lines[i]);
        if (m) {
            let j = i;
            while (j + 1 < lines.length && (/=\s*$/.test(lines[j]) || /\.\.\s*$/.test(lines[j]))) j++;
            const key = m[1];
            if (!drop.has(key)) {
                const newKey = renameMap.get(key) || key;
                const block = lines.slice(i, j + 1);
                if (newKey !== key) block[0] = block[0].replace('ChoukaT.' + key, 'ChoukaT.' + newKey);
                kept.push({ key: newKey, block, module: moduleOf(key) });
            }
            i = j + 1;
            continue;
        }
        i++;
    }
}
// 按"玩家在哪看得见"分类，方便一眼分辨
const CATEGORY = {
    '公告 / 对话框（长文本窗口 + 房主配置页）': ['announce', 'readDone', 'scopeAll', 'scopeOwn', 'hostDialogTitle', 'waitHost'],
    '顶部按钮 / 交易市场': ['btnMarket', 'btnHextech', 'btnLevelMax', 'btnLevelPrice', 'btnTowerPrice', 'btnTowerNoMoney'],
    '左上/左下 HUD': ['hudTitle', 'hudCountdown'],
};
const head = [
    '-- ============================================================',
    '-- 文案总表：**只放玩家看得见的文字**',
    '--   日志文案（_LOG 里那些）不在这里，直接写在各自业务代码里，方便区分（docs/08 §7.6）',
    '--   改文字直接改本文件；新增中文长句跑 tools/extract-texts.js 自动搬进来',
    '-- ============================================================',
    '',
    'ChoukaT = ChoukaT or {}',
    '',
];
const body = [];
const used = new Set();
for (const catName of Object.keys(CATEGORY)) {
    const keys = CATEGORY[catName];
    const items = kept.filter(k => keys.indexOf(k.key) >= 0);
    if (!items.length) continue;
    body.push('-- ============================================================');
    body.push('-- ' + catName);
    body.push('-- ============================================================');
    for (const k of items) { for (const l of k.block) body.push(l); used.add(k.key); }
    body.push('');
}
const rest = kept.filter(k => !used.has(k.key));
if (rest.length) {
    body.push('-- ============================================================');
    body.push('-- 提示与播报（公屏 / 飘字 / 消息栏）');
    body.push('-- ============================================================');
    for (const k of rest) { for (const l of k.block) body.push(l); }
}
fs.writeFileSync(TEXTS, head.concat(body).join('\n').replace(/\n/g, '\r\n'), 'utf8');

console.log(`✔ 01_texts.lua 重建完成：${kept.length} 条玩家可见文案；${logKeys.length} 条日志文案已回写代码`);
