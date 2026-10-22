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
│  ├─ lua/chouka/                       ← Lua 真源，按职责分 9 个子目录（另有 chouka/README.md）
│  │  ├─ 00_core/                         公共底座：每个节点都会拼在最前面
│  │  │  ├─ 00_alert.lua                  **诊断通道**（_LOG / _ALERT / 节点自检）
│  │  │  └─ 01_texts.lua                  **文案总表**：只放玩家看得见的（日志文案就地写在业务代码里）
│  │  ├─ 10_boot/                         启动与总调度
│  │  │  ├─ 00_selfcheck.lua              自检心跳：每 10 秒一行日志，排第一个节点
│  │  │  ├─ 03_start.lua                  **开局流程**：锁视角 + 全屏公告 + 房主配置 + 正式开始（照 DSA，无运镜）
│  │  │  ├─ 13_frame_loop.lua             每帧驱动 + 开局超时兜底
│  │  │  └─ 14_grant_draw.lua             发抽卡技能（单抽 + 十连，开局后才发）
│  │  ├─ 20_economy/                      经济与成长
│  │  │  ├─ 01_income.lua                 底薪 + 油井加成（开局后才结算；三国杀主公底薪 ×1.5）
│  │  │  ├─ 09_level.lua                  抽卡等级表（等级 → 各档概率 / 升级价 / 自动升级回合）
│  │  │  └─ 15_upgrades.lua               开局发放全部科技协议
│  │  ├─ 30_world/                        地图底座与中立点位
│  │  │  ├─ 00_init.lua                   地图级一次性别（全图视野/无限电/禁建造/资金兜底/倒计时初值）
│  │  │  ├─ 05_dog.lua                    保底单位（工程师，节点名仍叫"保底军犬"）
│  │  │  ├─ 06_center.lua                 中央油井争夺式占领（`centerOil1/2`）+ 中央钱箱每回合去重刷新
│  │  │  └─ 08_oilfield.lua               **中立油井重建**：中央/玩家油井被清场带走后原地重生中立无敌井（docs/12）
│  │  ├─ 40_draw/                         抽卡核心
│  │  │  ├─ 02a_crate_list.lua            **箱子种类表**：家里/中央刷什么箱子（权重表，改这一处）
│  │  │  ├─ 02_private_box.lua            每人两个私有箱子点（1 秒节点自己数秒，开局后才走）
│  │  │  ├─ 07_crates.lua                 **引擎随机箱清理**：除预设点位外不出现自然随机箱（照 DSA）
│  │  │  ├─ 10_puredraw_data.lua          抽卡数据（原生结果类型 / 白名单）
│  │  │  ├─ 11a_register.lua              整表登记出生事件 + onUnitCreateEvent
│  │  │  └─ 12_puredraw_replace.lua       截获后删整批 + 补 N 个 + 水陆判定（查 90_gen 的海/陆掩码）+ 阵营池范围
│  │  ├─ 50_ui/                           界面
│  │  │  ├─ 16_buttons.lua                顶部按钮栏 + 交易市场 + 氪金防御塔
│  │  │  └─ 20_hud.lua                    右上计分板 + 左下逐玩家四行
│  │  ├─ 60_ai/
│  │  │  └─ 17_ai.lua                     AI 对手（电脑每回合免费抽卡；中立单位加入 ATTACK 攻击队）
│  │  ├─ 70_bang/                         **三国杀模式**（docs/11）
│  │  │  ├─ 30_bang_mode.lua              身份核心：参战座位 / 身份表 / 洗牌 / 发身份 / 顶部情报按钮
│  │  │  ├─ 31_bang_alliance.lua          结盟：单向 / 双向 PLAYER_RELATES_PLAYER
│  │  │  ├─ 32_bang_pref.lua              身份偏好投票卡片（5 张卡 + 确认 + 180 秒超时）
│  │  │  └─ 33_bang_win.lua               胜负判定与结算（反贼 / 内奸 / 主公忠臣）
│  │  └─ 90_gen/                          **工具生成的数据，勿手改**
│  │     ├─ 09a_watermask.lua             海/陆掩码（build-watermask.js 从地图预览图提取）
│  │     ├─ gen_pool.lua                  卡池 135 种 / 五档权重（build-pool.js）
│  │     ├─ gen_allunits.lua              全部单位类型表 365 种
│  │     └─ gen_upgrades.lua              开局科技协议（build-upgrades.js）
│  └─ ScriptsData.json                 ← 生成物，给日冕 JSON 地编导入（21 个节点，含「自检」诊断节点）
├─ docs/
│  ├─ 01-抽卡海克斯地图方案.md
│  ├─ 02-抽卡hex底座对象与航点.md     ← 本次改造后的真实对象/航点/触发区数据
│  ├─ 03-抽卡hex改造-Lua与JSON地编.md  ← **主文档：新脚本设计 + 导入步骤 + 旧脚本处置**
│  ├─ 04-抽卡移植方案-PureDraw.md      ← DSA 抽卡（自定义卡池 + 截获原生结果）移植方案
│  ├─ 05-HUD移植方案.md                ← DSA 界面（计分板 / 自绘文字 / 计数器）移植方案
│  ├─ 06-开局流程-锁视角公告与房主配置.md ← **DSA 开局三段的拆解 + 本图实现 + 验收清单**
│  ├─ 07-随机箱清理.md                 ← **DSA 两段删箱器的拆解 + 本图实现（保留预设点位）**
│  ├─ 08-实测问题的定位与修复.md        ← **实测问题逐轮记录：中央钱箱 / 十连 / 海陆判定 / 保底工程师 / 卡池基地车 / 注释占体积**
│  ├─ 10-Lua注释存档.md                ← 从 lua 里搬出来的大段说明（构建不读它，只给人看；docs/08 §7.4）
│  ├─ 11-三国杀模式方案.md             ← **三国杀模式：规则、身份、偏好投票、结盟、胜负 + 逐文件改动清单**
│  └─ 12-中立油井重建.md               ← **阵亡者的油井变回中立无敌井：生成原语、无敌与清场的关系、空位判定**
├─ tools/
│  ├─ mcp-client/               Ra3MapEditor MCP 的 stdio 客户端（无依赖）
│  │                            ⚠️ **本地工具，不进 git**
│  ├─ sync-scriptsdata.js       lua/** → ScriptsData.json 的生成器（零依赖 node；读到 UTF-8 BOM 直接报错拦下）
│  ├─ build-watermask.js        地图预览图（蓝色=海）→ chouka/90_gen/09a_watermask.lua 水陆掩码（零依赖 node）
│  ├─ build-pool.js             作者《完整单位表》→ chouka/90_gen/gen_pool.lua 卡池与五档权重
│  ├─ build-upgrades.js         科技名单 → chouka/90_gen/gen_upgrades.lua 开局科技协议
│  ├─ import-dsa-pool.js        从 DSA 的 PureDraw/02_data.lua 导入卡池（零依赖 node）
│  ├─ extract-comments.js       lua 里 ≥4 行的大段纯注释 → docs/10（带代码指纹校验，误删会中止）
│  ├─ extract-texts.js          lua 里**玩家可见**的大段文本串 → chouka/00_core/01_texts.lua（只追加，跳过 _LOG）
│  ├─ split-log-texts.js        反向：只进日志的条目搬回代码
│  └─ lua-callsite.js           上面两个共用的"被哪个函数包着"判定

> ⚠ **玩家可见的文字别写死在业务代码里**：放 `scripts/lua/chouka/00_core/01_texts.lua`（`ChoukaT`），
> 新写的玩家文案跑一次 `node tools/extract-texts.js` 自动追加过去；`_LOG` 日志文案则**就地写**，不要进文案表（docs/08 §7.6）。
>
> ⚠ lua 里的注释**也占节点体积**（payload 是 lua 原文逐字节拼的，上限 64 KB）：纯说明性注释最多写 3 行，
> 更长的跑 `node tools/extract-comments.js` 搬到 `docs/10-Lua注释存档.md`（docs/08 §7.4）。
>
> ⚠ 改完 lua 先跑 node ../.dsh-tools/scratch/strip_bom.js 再去 sync：
> PowerShell 的 `Set-Content -Encoding utf8` 会偷偷加 UTF-8 BOM，而 BOM 会让该节点**静默不执行**（docs/08 §三④）。
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
| 中央岛七点 | ✅ `center` + `center1~6`。**作者 2026-10 把 `center1~6` 从中心小岛挪到了 6 条「玩家 ↔ 中心」的连接路上**（避免箱子全挤中间）；**七个点位（`center` + `center1~6`）每回合各刷 1 个钱箱**（点位已有箱子就跳过），箱子归属 = 离该点最近且起重机还活着的玩家。中央两座油井可争夺占领（docs/08） |
| 油井重建 | ✅ `08_oilfield.lua`：中央油井 / 玩家油井被"阵亡清场"带走后，原地重生一口**中立 + 无敌**的同名油井，可重新占领；占领者每秒 +40。不满 6 人的局，空位既无起重机也无油井 → **永不重建**（docs/12） |
| 开局秒判负问题 | ✅ 已解决（`power1~6` 不可摧毁 = 永远有归属物；见 docs/03） |
| 外侧海域连通 / 内部 6 块保持隔断 | ✅ 新版由作者重画 |
| map.xml / 预览图 / 支持文件 | ✅ 预览图带出生点蓝圈与顺时针编号（顶=6 → 右上=1 → 右下=2 → 底=3 → 左下=4 → 左上=5） |
| 玩法脚本实现 | ✅ Lua 源已写（docs/03），`ScriptsData.json` 共 **21 个节点**已生成，**待作者手动导入 + 进游戏验证** |
| 开局流程（照搬 DSA，去掉运镜） | ✅ `03_start.lua`：进游戏锁视角到 `center` + 全屏公告（作者四段正文）+ 中心黄字「请等待房主选择配置」→ 房主点「已阅读」开配置页 → 点「确认，开始游戏」→ 视角回自己出生点、解锁、写入抽卡范围、盲盒倒计时起步；`CHOUKA_GAME_STARTED` 门控收入/盲盒/军犬/中央/按钮，另有 3 分钟超时兜底（docs/06） |
| 抽卡系统（照搬 DSA） | ✅ 卡池 **135 种 / 五档权重 37-50-10-2.5-0.5**（作者《完整单位表》T1~T5，**T5 独立档**；**四家基地车都不进 T1~T4**（神州基地车=青龙战斗核心舰按 `TIER_PIN` 只留在 T5；矿车/工程师等不能打架的单位也剔除，维修天灯三形态保留）），截获原生抽卡结果转自定义单位，**100% 转自定义**、**原生结果几个就补几个**（单抽 1 / 十连 10，上限 10）；删除只针对"出生事件收上来的 id"；**按阵营分四池**（盟军36/苏联40/升阳26/神州33，抽卡范围由开局房主配置决定：只有自己阵营 / 全部阵营）；**按落点水陆过滤**（陆地不出船、水里不出步坦，空军与两栖例外；水陆四路判定见 docs/08 §二④） |
| 科技协议 | ✅ 开局把全部 **34 条**协议发给 `<All Players>`（含龙船全套 7 条升级），机制照双兵种 `GIVE_PLAYER_UPGRADE` |
| 界面（照搬 DSA） | ✅ 右上角计分板刷每人场上单位数 + 回合数；左下角五行：`回合数：N` / `盲盒刷新倒计时：mm:ss` / `抽卡等级：Lv.N` / `T1：x% T2：x% T3：x%` / `T4：x% T5：x%`（docs/09） |
| 抽卡等级 / 交易市场 | ✅ 顶栏按钮 3=交易市场、4=海克斯（禁用）：等级 1~8 决定各档概率，1000/2000/3000/5000/5000/10000/10000 买等级，第 5/10/15/20 回合自动升；同一市场可买防御塔 |
| 建造栏 | ✅ `PLAYER_DISABLE_BASE_CONSTRUCTION` 整条关闭；起重机保持可建造、**回收功能不受影响** |
| 箱子去重 | ✅ 点位半径 35 内已有箱子就跳过，不会堆箱子山 |
| 引擎随机箱清理（照搬 DSA） | ✅ `07_crates.lua`：第 1 帧删 `GenericCrateSpawner`（刷箱器）→ 第 45 帧清已落地的 `UnitCrateNew`/`UnitCrate`/`ShroudCrate`/`MoneyCrateMP`/`MoneyCrate` → 前 2 分钟每 10 秒兜底；**离 `boxN1/N2`、`center` + `center1~6` 预设点位 80 以内的箱子一律保留**，所以自家箱子不会被误删（docs/07） |
| map.str 文案 | ✅ 已重写：`jd1` 欢迎语、`jd2` 七条新规则（无基地车/不可建造/拆起重机判负/双轨收入/120 秒私人箱/2480 抽 1 个/全图视野+无限电），并补上 `SCRIPT:box` 倒计时文案 |
| 诊断通道 | ✅ `00_alert.lua`（构建时拼到每个节点最前面）：`_ALERT` 三路输出（`exPrintln` 日志 / `exMessageAppendToMessageArea` 左下消息区 / 公屏）+ `_LOG` 静默日志 + 「节点就绪」标记；新增 `抽卡hex/自检` 节点每 10 秒写一行心跳。日志在 `E:\CoronaLauncher\CoronaData\Logs\EnhancerCorona-*.dll.log`（docs/08 §三、§四11、docs/03 §9.5） |
| 电脑对手（AI） | ✅ `17_ai.lua`：① 每回合给每个电脑座位免费抽卡，**初始 1 个、每 5 回合 +1 个**（上限 5），每抽独立掷点，走同一套卡池/阵营池/水陆判定，概率按**自动升级**线（Lv.1~5），不跟玩家买等级挂钩；② 每 5 秒扫全场，把**非玩家阵营**（`PlyrCivilian`/`PlyrCreeps`）的单位塞进 `<阵营>/ATTACK` 攻击队（照 DSA `PureDrawJoinAIAttackTeam`），中立单位因此会主动打玩家（docs/03 §9.5） |
| 盲盒经济 / 海克斯符文 | 📝 docs/02 设计稿，玩法未接（本轮先实现"油井 + 底薪 + 私有箱 + 抽卡"） |

## 4 许可

本仓库 MIT（见 `LICENSE`）。

地图底座来自《[cor]每人一小块地(海域有限)2.0》，作者 **长安 / RBMK1000**，
其脚本内注明「欢迎二创并上传，注明改图来源即可」。
盲盒玩法参考《（cor）盲盒高原v1.6正式版》；海克斯符文系统设计参考《DSA_ggz自走棋》
（`E:\Ra3_AutoChess\DSA_ggz`，含 `analysis/自走棋海克斯系统/海克斯符文系统设计.md`）。
