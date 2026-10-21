# ALittlePlot

> 以 **《[cor]每人一小块地(海域有限)2.0》** 为地图模板，
> 缝合 **《（cor）盲盒高原v1.6正式版》** 的**盲盒/抽卡**经济，
> 与 **《DSA_ggz自走棋》** 的**海克斯符文**系统的实验性地图。
>
> 状态：**脚本改造已落地**（Lua 源 + `ScriptsData.json`，用日冕 JSON 地编手动导入后进游戏验证）。
> 地图底座改造已完成：每人一座岛 + 起重机 / 油井 / 电厂 / 两个箱子点位 + 中央七点。

---

## 1 目录结构

```
ALittlePlot/
├─ Maps/
│  └─ [cor]每人一小块地抽卡hex/  ← **只有这张进仓库**
│     ├─ [cor]每人一小块地抽卡hex.map   地图本体（690×690，1089 对象）
│     ├─ [cor]每人一小块地抽卡hex.tga   预览图（610×610 PNG + 出生点蓝圈与编号）
│     ├─ [cor]每人一小块地抽卡hex_art.tga  小地图渲染（610×610，1px = 1 可玩格）
│     ├─ map.xml / overrides.xml
│     └─ map.str / map.ini              仍是模板原件，待重做（缺 SCRIPT:box）
├─ scripts/
│  ├─ lua/chouka/00_init.lua            ← 真源：开局全图视野/无限电/禁止建造/开局资金
│  ├─ lua/chouka/01_income.lua          ← 真源：底薪 + 油井加成
│  ├─ lua/chouka/02_private_box.lua     ← 真源：每人两个私有箱子点（点位有箱不叠加）
│  ├─ lua/chouka/10_puredraw_data.lua   ← 真源：抽卡数据（原生结果类型 / 白名单）
│  ├─ lua/chouka/gen_pool.lua           ← 生成物：卡池 135 种 / 五档权重（作者完整单位表）
│  ├─ lua/chouka/11_puredraw_hook.lua   ← 真源：单位出生事件钩子
│  ├─ lua/chouka/12_puredraw_replace.lua← 真源：截获后删整批 + 补 1 个
│  ├─ lua/chouka/13_frame_loop.lua      ← 真源：每帧驱动
│  ├─ lua/chouka/14_grant_draw.lua      ← 真源：发抽卡技能（不发十连）
│  ├─ lua/chouka/20_hud.lua             ← 真源：右上台单位数 + 左下回合/倒计时
│  └─ ScriptsData.json                  ← 生成物，给日冕 JSON 地编导入（6 个节点）
├─ docs/
│  ├─ 01-三张源地图机制拆解.md
│  ├─ 02-缝合方案（讨论稿）.md
│  ├─ 03-开局判负与保命建筑对照.md   ← 为什么"没基地车秒判负"、盲盒高原怎么绕
│  ├─ 05-抽卡hex底座对象与航点.md     ← 本次改造后的真实对象/航点/触发区数据
│  ├─ 06-现有脚本清单.md              ← 地图上原 88 条脚本的逐条展开（自动生成）
│  ├─ 07-抽卡hex改造-Lua与JSON地编.md  ← **主文档：新脚本设计 + 导入步骤 + 旧脚本处置**
│  ├─ 08-抽卡移植方案-PureDraw.md      ← DSA 抽卡（自定义卡池 + 截获原生结果）移植方案
│  └─ 09-HUD移植方案.md                ← DSA 界面（计分板 / 自绘文字 / 计数器）移植方案
└─ tools/
   ├─ mcp-client/               Ra3MapEditor MCP 的 stdio 客户端（无依赖）
   │                            ⚠️ **本地工具，不进 git**
   ├─ sync-scriptsdata.js       lua/** → ScriptsData.json 的生成器（零依赖 node）
   └─ import-dsa-pool.js        从 DSA 的 PureDraw/02_data.lua 导入卡池（零依赖 node）
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
| 地图重做（作者手动） | ✅ → `[cor]每人一小块地抽卡hex`（当前版本，1089 对象，**仓库里只有这张**） |
| 每人一座岛的基地物件 | ✅ 作者已放：`crane1~6`（起重机）/ `oil1~6`（油井）/ `power1~6`（界外隐形电厂，与起重机绑定）/ `boxN1~N2`（两个箱子点） |
| 中央岛七点 | ✅ `center` + `center1~6`（六边形环，半径 ≈7 格），本轮先不刷箱子 |
| 开局秒判负问题 | ✅ 已解决（`power1~6` 不可摧毁 = 永远有归属物；见 docs/03） |
| 外侧海域连通 / 内部 6 块保持隔断 | ✅ 新版由作者重画 |
| map.xml / 预览图 / 支持文件 | ✅ 预览图带出生点蓝圈与顺时针编号（顶=6 → 右上=1 → 右下=2 → 底=3 → 左下=4 → 左上=5） |
| 玩法脚本实现 | ✅ Lua 六节点已写（docs/07），`ScriptsData.json` 已生成，**待作者手动导入 + 进游戏验证** |
| 抽卡系统（照搬 DSA） | ✅ 卡池 **135 种 / 五档权重 37-50-10-2.5-0.5**（作者《完整单位表》T1~T5，**T5 独立档**；剔除基地车/矿车/工程师等不能打架的单位，龙船与天灯三形态保留），截获原生抽卡结果转自定义单位，**每次固定 1 个、100% 转自定义**；删除只针对"出生事件收上来的 id"；**按阵营分四池**（盟军36/苏联40/升阳26/神州33）；**按落点水陆过滤**（陆地不出船、水里不出步坦，空军与两栖例外）（docs/08） |
| 科技协议 | ✅ 开局把全部 **34 条**协议发给 `<All Players>`（含龙船全套 7 条升级），机制照双兵种 `GIVE_PLAYER_UPGRADE` |
| 界面（照搬 DSA） | ✅ 右上角计分板刷每人场上单位数 + 回合数；左下角五行：`回合数：N` / `盲盒刷新倒计时：mm:ss` / `抽卡等级：Lv.N` / `T1：x% T2：x% T3：x%` / `T4：x% T5：x%`（docs/09） |
| 抽卡等级 / 交易市场 | ✅ 顶栏按钮 3=交易市场、4=海克斯（禁用）：等级 1~8 决定各档概率，1000/2000/3000/5000/5000/10000/10000 买等级，第 5/10/15/20 回合自动升；同一市场可买防御塔 |
| 建造栏 | ✅ `PLAYER_DISABLE_BASE_CONSTRUCTION` 整条关闭；起重机保持可建造、**回收功能不受影响** |
| 箱子去重 | ✅ 点位半径 35 内已有箱子就跳过，不会堆箱子山 |
| map.str 文案 | ✅ 已重写：`jd1` 欢迎语、`jd2` 七条新规则（无基地车/不可建造/拆起重机判负/双轨收入/120 秒私人箱/2480 抽 1 个/全图视野+无限电），并补上 `SCRIPT:box` 倒计时文案 |
| 盲盒经济 / 海克斯符文 | 📝 docs/02 设计稿，玩法未接（本轮先实现"油井 + 底薪 + 私有箱 + 抽卡"） |

## 4 许可

本仓库 MIT（见 `LICENSE`）。

地图底座来自《[cor]每人一小块地(海域有限)2.0》，作者 **长安 / RBMK1000**，
其脚本内注明「欢迎二创并上传，注明改图来源即可」。
盲盒玩法参考《（cor）盲盒高原v1.6正式版》；海克斯符文系统设计参考《DSA_ggz自走棋》
（`E:\Ra3_AutoChess\DSA_ggz`，含 `analysis/自走棋海克斯系统/海克斯符文系统设计.md`）。
