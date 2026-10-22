// ============================================================
// 把 lua 里的"玩家可见的大段文本"搬进 chouka/01_texts.lua（ChoukaT 表）
//
// 用法：node tools/extract-texts.js [--dry]
//
// 只搬「玩家看得见」的字符串：
//   · 中文且 ≥24 字节，或任意 ≥60 字节；
//   · **跳过 _LOG(...) 里的文字**（日志文案就留在各自业务代码里，好和玩家文案区分，docs/08 §7.6）；
//   · 短标签（"√"、单位类型名、Player_1 这类脚本名）不动。
//
// ★ 只做"追加"，绝不重写已有条目：已经在 01_texts.lua 里的文案原样保留（你手改过的文字不会丢）；
//   如果某段文字和已有条目完全相同，直接复用那个 key。
// ============================================================
const fs = require('fs');
const path = require('path');
const callsite = require('./lua-callsite.js');

const ROOT = path.resolve(__dirname, '..');
const LUA_DIR = path.join(ROOT, 'scripts', 'lua', 'chouka');
// 文案总表在 00_core（与 00_alert.lua 同目录，两个文件都是每个节点都会拼上的公共底座）
const OUT = path.join(LUA_DIR, '00_core', '01_texts.lua');
const DRY = process.argv.indexOf('--dry') >= 0;

const GENERATED = ['01_texts.lua', 'gen_pool.lua', 'gen_upgrades.lua', 'gen_allunits.lua', '09a_watermask.lua'];
const PREFIX = {
    '00_alert.lua': 'al', '00_init.lua': 'in', '00_selfcheck.lua': 'sc',
    '01_income.lua': 'inc', '02_private_box.lua': 'box', '03_start.lua': 'start',
    '05_dog.lua': 'dog', '06_center.lua': 'ctr', '07_crates.lua': 'crate',
    '09_level.lua': 'lv', '10_puredraw_data.lua': 'pdd', '11a_register.lua': 'reg',
    '12_puredraw_replace.lua': 'pdr', '13_frame_loop.lua': 'frame',
    '14_grant_draw.lua': 'grant', '15_upgrades.lua': 'upg',
    '16_buttons.lua': 'btn', '17_ai.lua': 'ai', '20_hud.lua': 'hud',
    '30_bang_mode.lua': 'bang', '31_bang_alliance.lua': 'ally',
    '32_bang_pref.lua': 'pref', '33_bang_win.lua': 'win',
};
const MIN_CJK = 24;
const MIN_ANY = 60;

// ---------- 已有条目（key → 原文，值 → key） ----------
const existing = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8').replace(/\r\n/g, '\n') : '';
const existingKeys = new Set([...existing.matchAll(/ChoukaT\.([A-Za-z0-9_]+)\s*=/g)].map(m => m[1]));
const valueToKey = new Map();
for (const m of existing.matchAll(/ChoukaT\.([A-Za-z0-9_]+)\s*=\s*("(?:[^"\\]|\\.)*")/g)) valueToKey.set(m[2], m[1]);

/** 找出 pos 处最外层调用的函数名（跳过 format/type 包装） */
// 用共享实现判断"这个字符串是不是在 _LOG(...) 里"
const builtCache = new Map();
function outerCallName(src, pos) {
    if (!builtCache.has(src)) builtCache.set(src, callsite.buildCallStacks(src));
    return callsite.outerCallName(src, pos, builtCache.get(src));
}

/** 递归列出 chouka 下所有 lua（已按职责分 9 个子目录）；返回 { rel, name } */
function listLuaFiles(dir, prefix) {
    const out = [];
    const entries = fs.readdirSync(dir, { withFileTypes: true })
        .sort((a, b) => a.name.localeCompare(b.name));
    for (const ent of entries) {
        const rel = prefix ? prefix + '/' + ent.name : ent.name;
        if (ent.isDirectory()) out.push(...listLuaFiles(path.join(dir, ent.name), rel));
        else if (ent.name.endsWith('.lua')) out.push({ rel, name: ent.name });
    }
    return out;
}

const files = listLuaFiles(LUA_DIR, '').filter(x => GENERATED.indexOf(x.name) < 0);
const added = [];
const changes = [];
let skippedLog = 0;

for (const entry of files) {
    const f = entry.rel;
    const src = fs.readFileSync(path.join(LUA_DIR, f), 'utf8').replace(/\r\n/g, '\n');
    const prefix = PREFIX[entry.name] || 'x';
    let seq = 0;
    let out = '';
    let i = 0;
    const n = src.length;
    while (i < n) {
        const c = src[i];
        if (c === '-' && src[i + 1] === '-') {                 // 注释整行原样保留
            const nl = src.indexOf('\n', i);
            const end = nl < 0 ? n : nl + 1;
            out += src.slice(i, end);
            i = end;
            continue;
        }
        if (c === '"' || c === "'") {
            const q = c;
            const start = i;
            i++;
            while (i < n) {
                if (src[i] === '\\') { i += 2; continue; }
                if (src[i] === q) { i++; break; }
                i++;
            }
            const raw = src.slice(start, i);
            const inner = raw.slice(1, -1);
            const bytes = Buffer.byteLength(raw, 'utf8');
            const hasCJK = /[\u4e00-\u9fff]/.test(inner);
            const candidate = (hasCJK && bytes >= MIN_CJK) || bytes >= MIN_ANY;
            if (!candidate) { out += raw; continue; }
            // 日志文案：留在原处
            if (outerCallName(src, start) === '_LOG') { skippedLog++; out += raw; continue; }
            // 已经有同名条目 → 直接复用
            const reused = valueToKey.get(raw);
            if (reused) { out += 'ChoukaT.' + reused; continue; }
            seq++;
            let key = prefix + seq;
            while (existingKeys.has(key)) { seq++; key = prefix + seq; }
            existingKeys.add(key);
            valueToKey.set(raw, key);
            added.push({ key, raw, file: f, line: src.slice(0, start).split('\n').length });
            out += 'ChoukaT.' + key;
            continue;
        }
        out += c;
        i++;
    }
    changes.push({ file: f, out });
}

console.log(`新增可搬运的玩家可见文案 ${added.length} 条（跳过日志文案 ${skippedLog} 处）`);
for (const a of added) console.log(`  + ${a.file}:${a.line} → ChoukaT.${a.key}  ${JSON.stringify(a.raw.slice(0, 50))}`);

if (!added.length) { console.log('没有需要搬的，什么都没改。'); process.exit(0); }
if (DRY) { console.log('【dry-run，未改文件】'); process.exit(0); }

for (const c of changes) fs.writeFileSync(path.join(LUA_DIR, c.file), c.out.replace(/\n/g, '\r\n'), 'utf8');

// 追加到文案表末尾（不动已有条目）
const tail = ['', '-- ============================================================',
    '-- 新增（extract-texts.js 自动搬运，可自行改名/挪到上面合适的分组）',
    '-- ============================================================'];
for (const a of added) tail.push(`ChoukaT.${a.key} = ${a.raw}`);
fs.writeFileSync(OUT, (existing.replace(/\s+$/, '') + '\n' + tail.join('\n')).replace(/\n/g, '\r\n') + '\r\n', 'utf8');
console.log(`✔ 已改写 ${changes.length} 个 lua，并把 ${added.length} 条追加到 01_texts.lua`);
