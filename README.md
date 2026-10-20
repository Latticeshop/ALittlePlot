# ALittlePlot

> 以 **《[cor]每人一小块地(海域有限)2.0》** 为地图模板，
> 缝合 **《（cor）盲盒高原v1.6正式版》** 的**盲盒/抽卡**经济，
> 与 **《DSA_ggz自走棋》** 的**海克斯符文**系统的实验性地图。
>
> 状态：**方案讨论阶段**（不实现玩法逻辑）。地图底座改造已完成。

---

## 1 目录结构

```
ALittlePlot/
├─ Maps/
│  └─ [cor]每人一小块地抽卡hex/  ← **只有这张进仓库**
│     ├─ [cor]每人一小块地抽卡hex.map   地图本体（690×690，1053 对象）
│     ├─ [cor]每人一小块地抽卡hex.tga   预览图（610×610 PNG + 出生点蓝圈与编号）
│     ├─ [cor]每人一小块地抽卡hex_art.tga  小地图渲染（610×610，1px = 1 可玩格）
│     ├─ map.xml / overrides.xml
│     └─ map.str / map.ini              仍是模板原件，待重做
├─ docs/
│  ├─ 01-三张源地图机制拆解.md
│  └─ 02-缝合方案（讨论稿）.md   ← **主文档，待评审**
└─ tools/
   └─ mcp-client/               Ra3MapEditor MCP 的 stdio 客户端（无依赖）
                                ⚠️ **本地工具，不进 git**
```

> `Maps/ALittlePlot/`（第一版自动改造的底座）和 `tools/mcp-client/` 都**留在本地但不进仓库**，
> 见 `.gitignore`。
> ⚠️ 另外：`Maps/` 下两张图目录**不能同名，游戏会按目录名列图**，正式发布时只留一张。

## 2 怎么用

### 2.1 装进游戏

把整个 `Maps/[cor]每人一小块地抽卡hex` 目录拷到游戏的地图目录（通常是
`%USERPROFILE%\OneDrive\文档\Red Alert 3\Maps\`），游戏即可列出这张图。

### 2.2 用 MCP 改图

> 这几节用到的 `tools/mcp-client/` **只在本地，仓库里没有**。换机器要自己从
> `E:\Ra3_CenterChess\Ra3MapEditor\MCP工具手册.md` 重新搭一份。

```powershell
node tools/mcp-client/mcp.js --list
node tools/mcp-client/mcp.js tools/mcp-client/inspect-map.json "E:\...\Maps\[cor]每人一小块地抽卡hex\[cor]每人一小块地抽卡hex.map"
```

`mcp.js` 是零依赖的 stdio MCP 客户端：给一个 JSON 命令表 +（可选）先打开的地图路径，
逐条执行并把结果打成 `### 工具名` + JSON 行。参数说明见 `tools/mcp-client/README.md`。

### 2.3 看图和量图

`tools/mcp-client/` 里另有 `analyze*.js` / `ascii.js` / `verify.js`，
把高程图导出成 TGA 之后可以离线算水域连通块、岛屿分块、隔断厚度，
并打印成 ASCII 图（本项目的所有海况结论都是这么量出来的）。

## 3 当前进度

| 项 | 状态 |
|---|---|
| 地图克隆进项目 | ✅ `[cor]每人一小块地 2.0` → `ALittlePlot`（第一版，**已排除出仓库**） |
| 地图重做（作者手动） | ✅ → `[cor]每人一小块地抽卡hex`（当前版本，1053 对象，**仓库里只有这张**） |
| 矿场 / 油井移除 | ⚠️ 第一版删了 14 个；新版仍留 8 个 `OilDerrick`，**待确认是否要删** |
| 外侧海域连通（6 块并成 1 片共享外海） | ✅ 第一版 6 条水道；新版由作者重画 |
| 内部 6 块海域保持隔断 | ✅ |
| map.xml / 预览图 / 支持文件 | ✅ 预览图带出生点蓝圈与顺时针编号（顶=6 → 右上=1 → 右下=2 → 底=3 → 左下=4 → 左上=5） |
| 盲盒经济设计 | 📝 docs/02 待评审 |
| 海克斯系统设计 | 📝 docs/02 待评审 |
| 玩法脚本实现 | ⏸ 等方案定稿 |

## 4 许可

本仓库 MIT（见 `LICENSE`）。

地图底座来自《[cor]每人一小块地(海域有限)2.0》，作者 **长安 / RBMK1000**，
其脚本内注明「欢迎二创并上传，注明改图来源即可」。
盲盒玩法参考《（cor）盲盒高原v1.6正式版》；海克斯符文系统设计参考《DSA_ggz自走棋》
（`E:\Ra3_AutoChess\DSA_ggz`，含 `analysis/自走棋海克斯系统/海克斯符文系统设计.md`）。
