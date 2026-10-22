"use strict";
// 生成本图自定义 UI 贴图（scripts/lua/chouka/95_assets/）。
// 用法：node tools/build-ui-assets.js
//
// 两类来源：
//   ① 官渡之战的打包贴图（7 张操作图标 + 兜底）：直接从提取出来的 corpus 搬，原样不动。
//   ② 本图自己的 UI 图片：
//        - E:/Ra3_CenterChess/images/ui/*.png  → ffmpeg 转 WebP → base64
//        - 玩家颜色纯色块：**代码生成**（ffmpeg 的 color 源），不需要任何图片文件
//
// 为什么要转 WebP：官渡那 30 张贴图解出来全是 RIFF/WEBP（不是 DDS）。
// 也就是说 exTextureCreateFromBase64(base64, 'DXT5', 0) 吃的是 WebP 容器，
// 'DXT5' 只是"上传到显卡时压成什么格式"的参数。所以 PNG 必须先变 WebP。
//
// 想加新按钮（海克斯系统以后要复用）：往 BUTTON_IMAGES 里加一行就行。
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const CORPUS = "E:/Ra3_CenterChess/.dsh-tools/mcpwork/out/guanu_lua";
const IMAGES = "E:/Ra3_CenterChess/images/ui";
const OUTDIR = path.join(__dirname, "..", "scripts", "lua", "chouka", "95_assets");
const TMP = path.join(require("os").tmpdir(), "chouka-ui-assets");

// ---------- ffmpeg ----------
const FFMPEG_CANDIDATES = [
  "ffmpeg",
  "E:/ffmpeg-master-latest-win64-gpl-shared/bin/ffmpeg.exe",
];

function ffmpegBin() {
  for (const c of FFMPEG_CANDIDATES) {
    // 注意：只探测能否启动，不抓 stdout（沙箱下 piped stdio 会被拒绝）
    const r = spawnSync(c, ["-version"], { stdio: "ignore" });
    if (r.error === undefined && r.status === 0) return c;
  }
  throw new Error("找不到 ffmpeg，无法把 PNG 转成 WebP");
}

const FFMPEG = ffmpegBin();

function run(args) {
  const r = spawnSync(FFMPEG, ["-v", "error", "-y"].concat(args), { stdio: "ignore" });
  if (r.error) throw new Error("ffmpeg 启动失败: " + r.error.message);
  if (r.status !== 0) throw new Error("ffmpeg 失败(" + r.status + "): " + args.join(" "));
}

// ---------- ① 官渡的打包贴图 ----------
const GUANU_GROUPS = [
  { file: "00_action_a.lua", names: ["Action_Alliance", "Action_Attack", "Action_Under_Attack"] },
  { file: "01_action_b.lua", names: ["Action_Prepare_Attack", "Action_Group_Attack", "Action_Protect"] },
  { file: "02_action_c.lua", names: ["Action_Truce", "Unknown"] },
];

// ---------- ② 本图 UI 图片 ----------
// png → 全局名。加新图就加一行；缺文件会在生成时报错，不会静默跳过。
const BUTTON_IMAGES = [
  { png: "hextechUndoButton.png", global: "ChoukaUiBtnUndo", note: "返回（面板返回上一页）" },
  { png: "hextechUndoButtonHover.png", global: "ChoukaUiBtnUndoHover", note: "返回-悬停" },
  { png: "hextechUndoButtonPressed.png", global: "ChoukaUiBtnUndoPressed", note: "返回-按下" },
  { png: "hextechUndoButtonDisabled.png", global: "ChoukaUiBtnUndoDisabled", note: "返回-禁用" },
  { png: "hextechRemoveButton.png", global: "ChoukaUiBtnRemove", note: "关闭（面板关闭）" },
  { png: "hextechRemoveButtonHover.png", global: "ChoukaUiBtnRemoveHover", note: "关闭-悬停" },
  { png: "hextechRemoveButtonPressed.png", global: "ChoukaUiBtnRemovePressed", note: "关闭-按下" },
  { png: "hextechRemoveButtonDisabled.png", global: "ChoukaUiBtnRemoveDisabled", note: "关闭-禁用" },
];

// 玩家颜色块：代码生成，不依赖任何图片文件。
// 官渡的色块贴图是"边框 + 色块"（作者说比纯色块顺眼），所以这里也画成三层：
//   96×96 底 + 3px 浅色边框 + 深色内衬 + 居中的 66×66 色块（显示成 84×84 时色块约 58 px）
// 映射照官渡 BangMakeColorName（红色通道）在 chouka 面板里已经对齐，这里只给 RGB。
const SWATCH_SIZE = 96;
const SWATCH_FRAME = "#C9D3DE";
const SWATCH_BASE = "#101418";
const SWATCH_GAP = "#181C22";
const SWATCH_COLOR_BOX = 66;

function swatchChain(hex) {
  return [
    "drawbox=x=8:y=8:w=80:h=80:color=" + SWATCH_FRAME + "@1.0:t=3",
    "drawbox=x=11:y=11:w=74:h=74:color=" + SWATCH_GAP + "@1.0:t=fill",
    "drawbox=x=15:y=15:w=" + SWATCH_COLOR_BOX + ":h=" + SWATCH_COLOR_BOX + ":color=" + hex + "@1.0:t=fill",
  ].join(",");
}
const SOLID_COLORS = [
  { global: "ChoukaUiColorRed", hex: "#E63232", red: 230, note: "红" },
  { global: "ChoukaUiColorBlue", hex: "#2C6BE6", red: 50, note: "蓝" },
  { global: "ChoukaUiColorYellow", hex: "#E8D22C", red: 237, note: "黄" },
  { global: "ChoukaUiColorGreen", hex: "#33B34A", red: 20, note: "绿" },
  { global: "ChoukaUiColorCyan", hex: "#2CC3C3", red: 102, note: "青" },
  { global: "ChoukaUiColorPurple", hex: "#8A4FD1", red: 125, note: "紫" },
  { global: "ChoukaUiColorOrange", hex: "#E8802C", red: 225, note: "橙" },
];

// ---------- 工具 ----------
function cleanGuanu(txt) {
  let t = txt.replace(/^#!ra3luabridge[^\n]*\n/, "");
  t = t.replace(/--\s*end of script, please ignore this line/g, "");
  t = t.replace(/\u0000+/g, "");
  return t.trimEnd() + "\n";
}

function pngSize(file) {
  const b = fs.readFileSync(file);
  if (b[0] !== 0x89 || b.toString("ascii", 1, 4) !== "PNG") throw new Error(file + " 不是 PNG");
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

// 生成一段 lua：WebP → base64 → exTextureCreateFromBase64 → exPackedTextureImageCreate
function luaAsset(globalName, b64, w, h) {
  return [
    "-- " + globalName,
    'local base64 = "' + b64 + '"',
    "",
    "if " + globalName + " == nil then",
    "    local compression = 'DXT5'",
    "    local generateMips = 0",
    "    local textureId = exTextureCreateFromBase64(base64, compression, generateMips)",
    "",
    "    " + globalName + " = exPackedTextureImageCreate({",
    "        Texture = textureId,",
    "        CoordsX = 1, CoordsY = 1,",
    "        DimensionsX = " + w + ", DimensionsY = " + h + ",",
    "        TextureDimensionsX = " + w + ", TextureDimensionsY = " + h + ",",
    "        Rotated = 0",
    "    })",
    "end",
  ].join("\n") + "\n";
}

// ---------- 主流程 ----------
fs.mkdirSync(OUTDIR, { recursive: true });
fs.mkdirSync(TMP, { recursive: true });

// 清掉旧的生成文件
const generated = new Set(GUANU_GROUPS.map((g) => g.file).concat(["03_ui.lua"]));
for (const f of fs.readdirSync(OUTDIR)) {
  if (f.endsWith(".lua") && !generated.has(f)) {
    fs.unlinkSync(path.join(OUTDIR, f));
    console.log("  删除旧文件 " + f);
  }
}

// ① 官渡贴图
const byName = new Map();
for (const f of fs.readdirSync(CORPUS)) {
  if (!/_asset\.txt$/.test(f)) continue;
  const txt = fs.readFileSync(path.join(CORPUS, f), "utf8");
  const m = /(\w+)\s*=\s*exPackedTextureImageCreate/.exec(txt);
  if (m) byName.set(m[1], cleanGuanu(txt));
}

let total = 0;
for (const g of GUANU_GROUPS) {
  const parts = [];
  for (const n of g.names) {
    const body = byName.get(n);
    if (body === undefined) throw new Error("找不到官渡贴图 " + n);
    parts.push("-- 官渡之战： " + n + "\n" + body);
    total += Buffer.byteLength(body, "utf8");
  }
  fs.writeFileSync(path.join(OUTDIR, g.file), parts.join("\n"), "utf8");
  const sz = fs.statSync(path.join(OUTDIR, g.file)).size;
  console.log(g.file.padEnd(18) + " 官渡贴图  " + String(sz).padStart(6) + " B");
}

// ② PNG 按钮 → WebP
const uiParts = [];
let uiBytes = 0;
for (const img of BUTTON_IMAGES) {
  const src = path.join(IMAGES, img.png);
  if (!fs.existsSync(src)) throw new Error("缺图片: " + src);
  const out = path.join(TMP, img.global + ".webp");
  // -lossless 1：UI 按钮必须像素级还原，不能有压缩噪点
  run(["-i", src, "-c:v", "libwebp", "-lossless", "1", out]);
  const webp = fs.readFileSync(out);
  const { w, h } = pngSize(src);
  const b64 = webp.toString("base64");
  uiParts.push(luaAsset(img.global, b64, w, h));
  uiBytes += b64.length;
  console.log(("  " + img.global).padEnd(18) + " " + img.png.padEnd(32) + w + "x" + h +
    "  webp " + String(webp.length).padStart(5) + " B → base64 " + String(b64.length).padStart(5));
}

// ③ 颜色块（代码生成：边框 + 内衬 + 色块）
for (const c of SOLID_COLORS) {
  const out = path.join(TMP, c.global + ".webp");
  run(["-f", "lavfi", "-i", "color=c=" + SWATCH_BASE + ":s=" + SWATCH_SIZE + "x" + SWATCH_SIZE,
    "-vf", swatchChain(c.hex), "-frames:v", "1", "-c:v", "libwebp", "-lossless", "1", out]);
  const webp = fs.readFileSync(out);
  const b64 = webp.toString("base64");
  uiParts.push(luaAsset(c.global, b64, SWATCH_SIZE, SWATCH_SIZE));
  uiBytes += b64.length;
  console.log(("  " + c.global).padEnd(22) + "代码生成 " + c.hex.padEnd(10) + "红通道 " +
    String(c.red).padStart(3) + "  webp " + String(webp.length).padStart(4) + " B");
}

const uiFile = path.join(OUTDIR, "03_ui.lua");
fs.writeFileSync(uiFile, uiParts.join("\n"), "utf8");
const uiSize = fs.statSync(uiFile).size;
console.log("");
console.log("03_ui.lua".padEnd(18) + " 按钮+颜色 " + String(uiSize).padStart(6) + " B" +
  "（base64 合计 " + Math.round(uiBytes / 1024) + " KB）");
console.log("官渡贴图合计 " + Math.round(total / 1024) + " KB，UI 图 " + BUTTON_IMAGES.length +
  " 张 + 颜色 " + SOLID_COLORS.length + " 种");
