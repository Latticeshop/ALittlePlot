"use strict";
// 轻量 Lua 4.0 块平衡检查：先剥掉注释和字符串，再统计开块/闭块 token。
// 用法：node tools/lua-balance.js [目录]
// 开块：function / if...then / for...do / while...do / 独立 do
// 闭块：end / until ；elseif 不另开块
const fs = require("fs");
const path = require("path");

const root = process.argv[2] || path.join(__dirname, "..", "scripts", "lua", "chouka");

function strip(src) {
  let out = "";
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    const d = src[i + 1];
    if (c === "-" && d === "-") {
      // 注释：--[[ ]] 长注释或 -- 行注释
      if (src[i + 2] === "[") {
        const close = src.indexOf("]]", i + 3);
        i = close < 0 ? n : close + 2;
      } else {
        while (i < n && src[i] !== "\n") i++;
      }
      out += " ";
      continue;
    }
    if (c === '"' || c === "'") {
      const q = c;
      i++;
      while (i < n && src[i] !== q) {
        if (src[i] === "\\") i++;
        i++;
      }
      i++;
      out += " STR ";
      continue;
    }
    if (c === "[" && (d === "[" || d === "=")) {
      // 长字符串 [[ ]] / [=[ ]=]
      const m = /^\[(=*)\[/.exec(src.slice(i));
      if (m) {
        const closeTok = "]" + m[1] + "]";
        const close = src.indexOf(closeTok, i + m[0].length);
        i = close < 0 ? n : close + closeTok.length;
        out += " STR ";
        continue;
      }
    }
    out += c;
    i++;
  }
  return out;
}

function check(file) {
  const src = fs.readFileSync(file, "utf8");
  const code = strip(src);
  const toks = code.match(/[A-Za-z_]\w*/g) || [];
  let depth = 0;
  let fnCount = 0;
  for (let k = 0; k < toks.length; k++) {
    const t = toks[k];
    if (t === "function") { depth++; fnCount++; }
    else if (t === "if") { depth++; }
    else if (t === "then") { /* if 已计 */ }
    else if (t === "elseif") { /* 不另开块，且它后面没有额外 then 计数 */ }
    else if (t === "do") {
      // for/while 的 do 已由 for/while 计数；独立 do 块本仓库没用过，这里也不计
    }
    else if (t === "while") { depth++; }
    else if (t === "for") { depth++; }
    else if (t === "repeat") { depth++; }
    else if (t === "end") { depth--; }
    else if (t === "until") { depth--; }
  }
  return { depth, fnCount, bytes: Buffer.byteLength(src, "utf8") };
}

const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith(".lua")) files.push(p);
  }
})(root);

let bad = 0;
for (const f of files) {
  const r = check(f);
  if (r.depth !== 0) {
    bad++;
    console.log("  [不平衡 " + r.depth + "] " + path.relative(root, f));
  }
}
console.log("检查 " + files.length + " 个文件，不平衡 " + bad + " 个" + (bad === 0 ? " ✓" : ""));
