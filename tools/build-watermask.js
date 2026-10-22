// ============================================================
// 从地图自带的预览图生成"水陆掩码" Lua（抽卡hex 用）
//
// 用法（在 ALittlePlot 目录下）：
//     node tools/build-watermask.js
// 产物：scripts/lua/chouka/90_gen/09a_watermask.lua  → 再跑 node tools/sync-scriptsdata.js
//
// 原理：地图文件夹里的 [cor]每人一小块地抽卡hex.tga 其实是 PNG（610×610），
//       其中蓝色 rgb(68,94,106) = 海，其余像素 = 陆地；
//       世界坐标↔图像素 的线性关系用预览图里 6 个出生点圆点 + map.xml 的
//       Player_1..6_Start 做最小二乘拟合（残差 < 1 像素 = 10 世界单位）。
//       换地图/改了地形后重跑本脚本即可，不用动任何判定代码。
// ============================================================
// 生成水陆掩码：每行陆地区间（成对），并把查表函数一起写进 Lua
const fs = require('fs');
const zlib = require('zlib');

function decodePNG(buf) {
    let off = 8, w = 0, h = 0, colorType = 0; const idat = [];
    while (off < buf.length) {
        const len = buf.readUInt32BE(off);
        const type = buf.slice(off + 4, off + 8).toString('ascii');
        const data = buf.slice(off + 8, off + 8 + len); off += 12 + len;
        if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); colorType = data[9]; }
        else if (type === 'IDAT') idat.push(data);
        else if (type === 'IEND') break;
    }
    const raw = zlib.inflateSync(Buffer.concat(idat));
    const ch = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
    const stride = w * ch; const out = Buffer.alloc(h * stride); let pos = 0;
    for (let y = 0; y < h; y++) {
        const f = raw[pos++]; const line = raw.slice(pos, pos + stride); pos += stride;
        const cur = out.slice(y * stride, (y + 1) * stride);
        const prev = y > 0 ? out.slice((y - 1) * stride, y * stride) : Buffer.alloc(stride);
        for (let x = 0; x < stride; x++) {
            const a = x >= ch ? cur[x - ch] : 0, b = prev[x], c = x >= ch ? prev[x - ch] : 0;
            let v = line[x];
            if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
            else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
            cur[x] = v & 0xff;
        }
    }
    const rgb = Buffer.alloc(w * h * 3);
    for (let i = 0; i < w * h; i++) {
        const s = i * ch, d = i * 3;
        if (colorType === 6 || colorType === 2) { rgb[d] = out[s]; rgb[d + 1] = out[s + 1]; rgb[d + 2] = out[s + 2]; }
        else { rgb[d] = rgb[d + 1] = rgb[d + 2] = out[s]; }
    }
    return { w, h, rgb };
}

const img = decodePNG(fs.readFileSync('E:/Ra3_CenterChess/ALittlePlot/Maps/[cor]每人一小块地抽卡hex/[cor]每人一小块地抽卡hex.tga'));
const { w, h, rgb } = img;
const land = new Uint8Array(w * h);
for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 3;
    land[y * w + x] = (rgb[i] === 68 && rgb[i + 1] === 94 && rgb[i + 2] === 106) ? 0 : 1;
}

const CELL_PX = 4;
const gw = Math.ceil(w / CELL_PX), gh = Math.ceil(h / CELL_PX);
const grid = new Uint8Array(gw * gh);
for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) {
    let n = 0, c = 0;
    for (let py = gy * CELL_PX; py < Math.min(h, (gy + 1) * CELL_PX); py++)
        for (let px = gx * CELL_PX; px < Math.min(w, (gx + 1) * CELL_PX); px++) { n++; if (land[py * w + px]) c++; }
    grid[gy * gw + gx] = (n && c * 2 > n) ? 1 : 0;
}

const PX_A = -0.90, PX_B = 0.09991, PY_A = 604.57, PY_B = -0.10000;

let lua = '';
lua += '-- ============================================================\n';
lua += '-- 水陆掩码：从地图预览图提取的死数据（自动生成勿手改，生成器 tools/build-watermask.js）\n';
lua += '-- ============================================================\n\n';
lua += 'CHOUKA_MASK_GW = ' + gw + '\n';
lua += 'CHOUKA_MASK_GH = ' + gh + '\n';
lua += 'CHOUKA_MASK_CELL_PX = ' + CELL_PX + '\n';
lua += 'CHOUKA_MASK_PX_A = ' + PX_A + '\n';
lua += 'CHOUKA_MASK_PX_B = ' + PX_B + '\n';
lua += 'CHOUKA_MASK_PY_A = ' + PY_A + '\n';
lua += 'CHOUKA_MASK_PY_B = ' + PY_B + '\n\n';
lua += '-- 每行陆地的格子区间（起点,终点 成对出现）\n';
lua += 'ChoukaLandSpans = {\n';
let totalSpans = 0;
for (let gy = 0; gy < gh; gy++) {
    const spans = [];
    let start = -1;
    for (let gx = 0; gx <= gw; gx++) {
        const v = gx < gw ? grid[gy * gw + gx] : 0;
        if (v && start < 0) start = gx;
        if (!v && start >= 0) { spans.push(start + ',' + (gx - 1)); start = -1; }
    }
    totalSpans += spans.length;
    lua += spans.length ? `  {${spans.join(',')}},\n` : '  {},\n';
}
lua += '}\n\n';
lua += '-- 世界坐标 (x, y) 是不是水：1 = 水，0 = 陆\n';
lua += 'function ChoukaMaskIsWater(x, y)\n';
lua += '    if x == nil or y == nil then\n';
lua += '        return 1                         -- 坐标无效：按水处理（宁可不放陆地单位到海里）\n';
lua += '    end\n';
lua += '    local px = CHOUKA_MASK_PX_A + CHOUKA_MASK_PX_B * x\n';
lua += '    local py = CHOUKA_MASK_PY_A + CHOUKA_MASK_PY_B * y\n';
lua += '    local gx = floor(px / CHOUKA_MASK_CELL_PX)\n';
lua += '    local gy = floor(py / CHOUKA_MASK_CELL_PX)\n';
lua += '    if gx < 0 or gy < 0 or gx >= CHOUKA_MASK_GW or gy >= CHOUKA_MASK_GH then\n';
lua += '        return 1                         -- 出图 = 地图边角外海\n';
lua += '    end\n';
lua += '    local row = ChoukaLandSpans[gy + 1]\n';
lua += '    if row == nil then\n';
lua += '        return 1\n';
lua += '    end\n';
lua += '    for i = 1, getn(row), 2 do\n';
lua += '        if gx >= row[i] and gx <= row[i + 1] then\n';
lua += '            return 0                     -- 落在陆地区间里\n';
lua += '        end\n';
lua += '    end\n';
lua += '    return 1\n';
lua += 'end\n';
fs.writeFileSync('E:/Ra3_CenterChess/ALittlePlot/scripts/lua/chouka/90_gen/09a_watermask.lua', lua, 'utf8');
console.log(`✔ 09a_watermask.lua  ${Buffer.byteLength(lua)} B，网格 ${gw}x${gh}，陆地区间 ${totalSpans} 个`);

// 验证
const worldToCell = (x, y) => [Math.floor((PX_A + PX_B * x) / CELL_PX), Math.floor((PY_A + PY_B * y) / CELL_PX)];
const isLandWorld = (x, y) => {
    const [gx, gy] = worldToCell(x, y);
    if (gx < 0 || gy < 0 || gx >= gw || gy >= gh) return 0;
    return grid[gy * gw + gx];
};
const mustLand = [
    ['Player_1', 4927, 4110], ['Player_2', 4932, 1947], ['Player_3', 3047, 863],
    ['Player_4', 1151, 1946], ['Player_5', 1152, 4111], ['Player_6', 3044, 5193],
    ['center', 3044, 3029], ['中央油井A', 2859, 3026], ['中央油井B', 3227, 3025],
    ['日志抽卡点1', 3240, 4786], ['日志抽卡点3', 3296, 5149],
];
const mustSea = [
    ['左上角', 300, 300], ['右上角', 5900, 300], ['左下角', 300, 5800], ['右下角', 5900, 5800],
    ['正上外海', 3044, 5900], ['正下外海', 3044, 150], ['左外海', 150, 3027], ['右外海', 5900, 3027],
    ['两岛之间', 2200, 3027], ['另一处', 3900, 3027],
];
let ok = 0;
for (const [n, x, y] of mustLand) { const v = isLandWorld(x, y); ok += v ? 1 : 0; if (!v) console.log(`   ✗ 应陆却是海：${n} (${x},${y})`); }
console.log(`   应陆点位 ${ok}/${mustLand.length} 通过`);
ok = 0;
for (const [n, x, y] of mustSea) { const v = isLandWorld(x, y); ok += v ? 0 : 1; if (v) console.log(`   ✗ 应海却是陆：${n} (${x},${y})`); }
console.log(`   应海点位 ${ok}/${mustSea.length} 通过`);
