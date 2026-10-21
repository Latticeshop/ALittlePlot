// ============================================================
// 把 lua 里"大段纯文本注释"搬到 docs/10-Lua注释存档.md，lua 里只留一行指针
//
// 用法（在 ALittlePlot 目录下）：
//     node tools/extract-comments.js           真干活
//     node tools/extract-comments.js --dry     只报告，不改文件
//
// 规则：
//   · 只处理「连续 >=4 行、每行都以 -- 开头」的块（纯注释块）；
//   · 块首/块尾如果是装饰线（只有 - 和 =），保留下来，视觉结构不散；
//   · 生成的标记：`-- 详见 docs/10-Lua注释存档.md §<文件名>-<序号>`（一行）；
//   · 生成的 lua（gen_pool / gen_upgrades / gen_allunits / 09a_watermask）默认跳过，
//     它们的头注释由各自的生成器控制，改了会被下次生成覆盖。
//
// ★★ 安全阀（2026-10 踩过一次，务必留着）：
//   第一版按"块升序"依次 splice，却没有修正后面的行号偏移 —— 2 个块以上的文件
//   从第 2 个块开始就切错位置，删掉的是真实代码（5 个文件被毁，靠 ScriptsData.json
//   里抽取前的 payload 才恢复回来）。现在两重保险：
//     ① 块从后往前替换（后面的替换不影响前面的行号）；
//     ② 落盘前比对"代码指纹"（去掉所有纯注释行后的内容哈希），不一致就整体中止、不写任何文件。
// ============================================================
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const LUA_DIR = path.join(ROOT, 'scripts', 'lua', 'chouka');
const DOC = path.join(ROOT, 'docs', '10-Lua注释存档.md');
const DRY = process.argv.indexOf('--dry') >= 0;

// 生成物：注释由生成器写，跳过（避免下次生成又回来）
const GENERATED = ['gen_pool.lua', 'gen_upgrades.lua', 'gen_allunits.lua', '09a_watermask.lua'];

const MIN_BLOCK = 4;                    // 超过 3 行才搬
const isComment = (l) => /^\s*--/.test(l);
const isDeco = (l) => /^\s*--\s*[-=]{3,}\s*$/.test(l);
const POINTER = (tag) => `-- 详见 docs/10-Lua注释存档.md §${tag}`;

/** 代码指纹：只留"非纯注释、非空行"，这样搬走注释不会改变指纹。 */
function codeFingerprint(lines) {
    const kept = lines.filter(l => !isComment(l) && l.trim() !== '');
    return crypto.createHash('sha1').update(kept.join('\n'), 'utf8').digest('hex');
}

const files = fs.readdirSync(LUA_DIR).filter(f => f.endsWith('.lua') && GENERATED.indexOf(f) < 0).sort();

const doc = [];
doc.push('# 10 · Lua 注释存档（从 lua 里搬出来的大段说明）');
doc.push('');
doc.push('> **为什么要搬**：`ScriptsData.json` 的每个节点 payload 是 **lua 原文逐字节拼进去的**，');
doc.push('> 注释一样占字节，而单节点上限约 64 KB。所以"大段纯说明"只放在本文档，');
doc.push('> lua 里只留一行指针：`-- 详见 docs/10-Lua注释存档.md §<文件名>-<序号>`。');
doc.push('>');
doc.push('> 本文件由 `tools/extract-comments.js` 自动生成，重跑会整体覆盖（改文档请改 lua 后重跑）。');
doc.push('> 规则：连续 **≥4 行**的纯注释块才搬；块首/块尾的装饰线（`-- ====`）留在原处。');
doc.push('');

let totalBefore = 0, totalAfter = 0, movedBlocks = 0, movedBytes = 0;
const report = [];
const pending = [];        // 待落盘（指纹校验通过才写）

for (const f of files) {
    const p = path.join(LUA_DIR, f);
    const raw = fs.readFileSync(p, 'utf8');
    const before = Buffer.byteLength(raw, 'utf8');
    const lines = raw.replace(/\r\n/g, '\n').split('\n');

    // ---- 找出所有"纯注释块" ----
    const blocks = [];
    let i = 0;
    while (i < lines.length) {
        if (isComment(lines[i])) {
            let j = i;
            while (j < lines.length && isComment(lines[j])) j++;
            if (j - i >= MIN_BLOCK) {
                let s = i, e = j - 1;
                if (isDeco(lines[s]) && s < e) s++;          // 装饰线留在 lua 里
                if (isDeco(lines[e]) && e > s) e--;
                while (s <= e && /^\s*--\s*$/.test(lines[s])) s++;
                while (e >= s && /^\s*--\s*$/.test(lines[e])) e--;
                if (e >= s && (e - s + 1) >= MIN_BLOCK) blocks.push({ start: s, end: e });
            }
            i = j;
        } else i++;
    }
    if (!blocks.length) { report.push([f, before, before, 0]); continue; }

    // ---- 从后往前替换（★ 关键：反过来切，前面的行号才不会错位） ----
    const fileBase = f.replace(/\.lua$/, '');
    const outLines = lines.slice();
    const docBlocks = [];
    for (let k = blocks.length - 1; k >= 0; k--) {
        const b = blocks[k];
        const tag = `${fileBase}-${k + 1}`;
        docBlocks.unshift({ tag, from: b.start + 1, to: b.end + 1, text: lines.slice(b.start, b.end + 1) });
        outLines.splice(b.start, b.end - b.start + 1, POINTER(tag));
    }
    for (const b of docBlocks) {
        movedBlocks++;
        movedBytes += b.text.reduce((n, l) => n + Buffer.byteLength(l, 'utf8') + 1, 0);
    }

    // ---- 安全阀：代码指纹必须不变 ----
    const fpBefore = codeFingerprint(lines);
    const fpAfter = codeFingerprint(outLines);
    if (fpBefore !== fpAfter) {
        // 只允许差在指针行上（指针本身是注释，指纹里不含），所以这里不相等就是 bug
        console.log(`✗ ${f}：代码指纹变了（${fpBefore.slice(0, 8)} → ${fpAfter.slice(0, 8)}），中止`);
        process.exit(2);
    }

    const out = outLines.join('\n').replace(/\n/g, '\r\n');
    const after = Buffer.byteLength(out, 'utf8');
    totalBefore += before;
    totalAfter += after;
    report.push([f, before, after, docBlocks.length]);
    pending.push({ p, out });

    doc.push(`## ${f}`);
    doc.push('');
    for (const b of docBlocks) {
        doc.push(`### §${b.tag}（原第 ${b.from}~${b.to} 行）`);
        doc.push('');
        doc.push('```lua');
        for (const l of b.text) doc.push(l);
        doc.push('```');
        doc.push('');
    }
}

doc.push('---');
doc.push('');
doc.push(`统计：搬走 ${movedBlocks} 段、共 ${movedBytes} B；lua 总体 ${totalBefore} B → ${totalAfter} B（省 ${totalBefore - totalAfter} B）。`);
doc.push('');

console.log('文件'.padEnd(28) + '改前'.padStart(8) + '改后'.padStart(8) + '省'.padStart(8) + '搬了几段'.padStart(9));
for (const [f, b, a, n] of report) {
    if (b === a && !n) continue;
    console.log(f.padEnd(28) + String(b).padStart(8) + String(a).padStart(8) + String(b - a).padStart(8) + String(n).padStart(9));
}
console.log(`\n合计：搬走 ${movedBlocks} 段 ${movedBytes} B；lua 总体 ${totalBefore} B → ${totalAfter} B，省 ${totalBefore - totalAfter} B`);

if (DRY) {
    console.log('【dry-run，未改任何文件】');
} else {
    for (const x of pending) fs.writeFileSync(x.p, x.out, 'utf8');
    fs.writeFileSync(DOC, doc.join('\n').replace(/\n/g, '\r\n'), 'utf8');
    console.log(`✔ 已改写 ${pending.length} 个 lua，并生成 docs/10-Lua注释存档.md`);
}
