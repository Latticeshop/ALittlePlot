# 08 · 抽卡移植方案：照搬 DSA 的 PureDraw（每次 1 个）

> 目标：把《DSA_ggz自走棋》的「完整自定义卡池 + 截获原版抽卡结果」搬到 `[cor]每人一小块地抽卡hex`，
> **但每次召唤固定 1 个单位**，不要十连、不要空投、不要基地车、不要建造场。
> 本文只给方案与 API，不写实现代码；所有引用都是 DSA 源码的**只读**位置（DSA 目录未改动）。
> 路径简写：`PD/` = `日冕地图lua例子\DSA_ggz自走棋\lua\GAME\PureDraw\`。

## 0 结论速览

| 问题 | 结论 |
|---|---|
| 随机在哪一环 | **引擎/mod 侧**。箱子对象自带产出表，被拾取后引擎直接生成**一整批**同型单位；Lua 拿不到"抽到了什么"的决策，只能**事后**看到"结果单位被创建" |
| 截获钩子 | `exObjectRegisterCreateEvent(类型名)` + `g_UnitCreateEventFunc[FastHash(类型名)] = 回调`（DSA 包成 `RegisterUnitCreateCallback`，`UnitCreate.lua:7`）；回调签名 **`(createdObjId, createdObjInstanceId, ownerPlayerName)`** |
| 替换动作 | `ExecuteAction("NAMED_DELETE", 对象)` 删整批 + `UNIT_SPAWN_NAMED_LOCATION_ORIENTATION(名, 类型, 队伍, {X,Y,Z}, 0)` 生成 1 个（`PD/04_draw.lua:233-257`） |
| 固定 1 个怎么做 | 卡池条目**删掉 `CustomDrawCount` 字段**即可 —— 原代码 `local spawnCount = info.CustomDrawCount or 1`（`PD/04_draw.lua:238`） |
| 能不能整包搬 | **不能**。DSA 把 6 个 PureDraw 文件拼成**一个** payload，实测 **61,421 / 65,536 字符**（`analysis/tools/sync_utils_lucky_crate.py:17-24`），只剩 ~4 KB 余量 |
| 我们的最小子集 | **3 个 lua 文件 → 1 个一次性节点 + （可选）1 个每帧节点**，见 §8 |
| 截获失败的后果 | 原版单位**留在场上不被替换**，游戏不崩 —— 风险是经济/平衡失控，不是崩图（详见 §9.1） |

## 1 原生抽卡：随机发生在哪

1. **抽卡入口对象是箱子本体，不是"抽卡结果"**。日冕「幸运单位箱子」技能直接创建可拾取的
   `LuckyUnitCrateSeed`，没有第二段 `UnitCrateNew` 物理箱 —— 见 `analysis/地图注释说明文档.md:1124-1129`（附录 A.5.2）。
   所以 DSA 的入口钩子是 `RegisterUnitCreateCallback("LuckyUnitCrateSeed", ...)`（`PD/06_init_mcv.lua:331`）。
2. **产出表在 mod 的对象定义里**。DSA 只维护了一份**镜像表**用于显示/回收计价：
   `g_CrateUnitsTemplate = { [1]=步兵, [2]=载具, [3]=空军, [4]=海军 }`（`lua/GAME/RecycleUnit.lua:306`），
   条目里的 `Count` 就是"原版一次开出几个"，例如
   `{ Type = "CelestialWheeledAssaultVehicle", Count = 4 }`（`RecycleUnit.lua:312`）、
   `{ Type = "Overlordtank", Count = 1 }`（`RecycleUnit.lua:352`）。
   → **数量是 mod 侧决定的，Lua 改不了，只能"删掉整批 + 自己补 1 个"**。
3. **Lua 侧能拿到什么**：只有三个参数
   - `createdObjId`：对象 id（`ObjectGetId` 同一个东西）
   - `createdObjInstanceId`：**模板名的哈希**（用 `FastHash(类型名)` 比对，`PD/02_data.lua:238`）；
     拿不到模板名字符串，要名字得用 `g_UnitNameToUnitIndex[instanceId]` 反查（`PD/04_draw.lua:339`）
   - `ownerPlayerName`：`"Player_3"` 这种
4. **一次是一批**：引擎同帧生成同型、坐标相邻的一群，所以 DSA 用
   `batchInstanceId / batchUnitIndex` + 半径 **260** 做"整批删除"（`PD/04_draw.lua:283-348`）。

## 2 替换流程（照这个顺序写就不会刷两个）

```
① 开局：对"原版箱子可能开出的所有类型"注册 create 事件
② 回调里先做 3 个排除（脚本生成 / 有生产者 / 白名单）
③ delay N 帧再判断（等这一批生成完）
④ 取坐标 → ⑤ 整批删 → ⑥ 在自己队伍生成 1 个自定义单位
```

**① 注册（名单现成的）**
```lua
-- PD/06_init_mcv.lua:350-376 的三段循环，名单来源 lua/LUABOX/UNITCOUNTERINI_0.lua:137/161/169
for i = 1, getn(g_GroundCrateUnits), 1 do RegisterUnitCreateCallback(g_GroundCrateUnits[i], 回调) end
-- g_AirCrateUnits / g_SeaCrateUnits 同理
```
我们图直接抄这三张名单（陆地 22 种 / 海上 6 种 / 空中 3 种），再补自己的卡池类型。

**② 三个排除条件（缺一个就会误删正常单位）**
```lua
g_PureDrawScriptCreatedUnitIds[createdObjId]   -- 自己脚本生成的
ObjectGetProducerObject(createdObjId) ~= nil   -- 有生产者的（生产栏造的）
g_PureDrawAlwaysKnownUnitHashes[createdObjInstanceId] -- 白名单（PD/02_data.lua:228-241：工程师 + 各型 MCV）
```

**③ 延迟**：`SchedulerModule.delay_call(回调, 帧数, {参数, …})`，**帧数单位是帧，15 帧 = 1 秒**
（`lua/baselib/ScheduleModule.lua:164`）。DSA 删批时用 2 帧并重试 8 次（`PD/04_draw.lua:486-491`）。

**④⑤ 取坐标 + 整批删**
```lua
local x, y, z = ObjectGetPosition(createdObjId)   -- 返回 3 个值，不是表（PD/04_draw.lua:421）
-- 半径 260 内、同玩家、无生产者、未登记、同批类型 → 全删
ExecuteAction("NAMED_DELETE", unit)               -- PD/04_draw.lua:345
```

**⑥ 生成 1 个（归属/不重复/不进池 全靠这三行）**
```lua
-- PD/04_draw.lua:240-245
g_PureDrawCustomSpawnSerial = g_PureDrawCustomSpawnSerial + 1
local unitName = format("PureDrawCustom_%d", g_PureDrawCustomSpawnSerial)
g_PureDrawScriptCreatedUnitIds[GetNextObjectId()] = true          -- 防递归：新单位不进 ②的观察队列
ExecuteAction("UNIT_SPAWN_NAMED_LOCATION_ORIENTATION", unitName, info.Type,
    format("%s/team%s", playerName, playerName), { X = x, Y = y, Z = z }, 0)
```
- **归属正确**：靠第 3 个参数队伍字符串 `Player_N/teamPlayer_N`（本图 22 支队伍里 `teamPlayer_N` 的 owner 就是 `Player_N`）。
- **不刷两个**：`state.CustomResultSpawned` 一次性标志（`PD/04_draw.lua:482-485`）。
- **原单位不算进单位池**：删之前先 `PureDrawRemoveKnownPlayerUnit(id)`（`PD/04_draw.lua:344-345`）。
  我们图没有 UNITCOUNT 池，所以"删掉即完事"；将来接限造/回收就必须照做。
- 生成后用 `GetObjectByScriptName(unitName)` 回读，若 `ObjectGetId` 与 `GetNextObjectId()` 不一致要把标记搬过去（`PD/04_draw.lua:246-255`）。

## 3 卡池格式 + 怎么砍成"每次 1 个"

**配置**（`PD/02_data.lua:4-14`）
```lua
g_PureDrawConfig = {
    ProductionQuota = 5,          -- 生产配额（我们不用，见 §4）
    RefreshRounds = 3,            -- 每 3 回合刷新配额（不用）
    CustomDrawChance = 0.50,      -- 箱子结果有 50% 换成自定义抽卡（我们改成 1.0）
    TierWeights = { 37, 50, 10, 3 },  -- 四档权重，合计必须 100
    AirdropChance = 0.05,         -- 十连概率（删）
}
```

**卡池**（`PD/02_data.lua:16` 起）：**数组下标就是科技层 = 权重档位**
```lua
g_PureDrawBuildableUnitPool = {
    [1] = { { Type = "AlliedScoutInfantry", CustomDrawCount = 5 }, … },
    [2] = { { Type = "SovietHeavyAntiVehicleInfantry", CustomDrawCount = 3 }, … },
    …
}
```
条目可选字段：`CustomDrawCount`（这次开几个）、`ProductionUnlockRound`、`NoNavyProductionUnlockRound`、
`Sea`、`IsBigShip`、`LockPlayerProduction`。**没有稀有度字段**，稀有度完全靠 tier 权重表达。

**抽选算法**（`PD/04_draw.lua:208-231`）—— 两次 `GetRandomNumber()`（返回 `[0,1)`）：
```lua
local roll = GetRandomNumber() * 100            -- 第一次：按 TierWeights 累加选档
… local index = floor(GetRandomNumber() * getn(eligible)) + 1   -- 第二次：档内均匀
```

**改成"每次 1 个"只做两件事**：
1. 卡池条目**全部去掉 `CustomDrawCount`** → `info.CustomDrawCount or 1` 自动就是 1
   （也可以把 `PD/04_draw.lua:238-256` 的 `for spawnIndex = 1, spawnCount, 1` 整段换成"生成一次"）。
2. `CustomDrawChance = 1.0`（我们图 100% 走自定义池，不留原版结果）。

卡池本身也可以压成**单层**：全部塞 `[1]`，`TierWeights` 只留一档 —— 少一层就少一堆分支。

## 4 配额 / 限造（`PD/03_quota.lua`）留什么

| 函数 | 处置 | 理由 |
|---|---|---|
| `PureDrawIsHumanPlayer`（:3-5） | **留**（一行） | 判断是不是真人，后面很多地方要用 |
| `PureDrawCanEnableUnit`（:66-101） | 砍 | 它是"生产栏这个兵种能不能出现在建造栏"的过滤器 |
| `PureDrawSetPlayerBuildability` / `PureDrawRefreshQuota` / `PureDrawReapplyExhaustedQuotaAfterProduction`（:103-141） | 砍 | 全是生产栏开关；我们图已 `ALLOW_DISALLOW_ALL_BUILDINGS = 0`，生产栏本来就不存在 |
| `PureDrawGetBuildCost` / `PureDrawTryConsumeProductionQuota`（:143-202） | 砍 | 消费配额靠 create 事件 + `ObjectGetProducerObject`；不接生产栏就没有配额可扣 |
| `PureDrawSpawnQuotaWall` / `PureDrawCreateQuotaDisplay` / `PureDrawGetQuotaDisplayDirection`（:7-64） | 砍 | 用 `AlliedWallPiece` 在基地旁摆一排"剩余次数"实体墙，纯界面 |

> 想保留"每人一局只能抽 N 次"的话，**不要搬配额墙**，自己维护 `g_DrawLeft[playerIndex]`，
> 抽一次减 1、到 0 就把抽卡技能收回（`PLAYER_SPECIAL_POWER_AVAILABILITY`）或删箱子。

## 5 十连 / 空投（`04_draw.lua` + `05_crate_airdrop.lua`）砍什么

| 函数 / 数据 | 位置 | 处置 |
|---|---|---|
| `PureDrawSpawnAirdrop` / `PureDrawAirdropCheck` / `PureDrawSpawnAirdropCrate` / `PureDrawRegisterAirdropPoint` / `PureDrawIsNearAirdropPoint` | `PD/05:160-230`、`PD/04:382-394` | **整段删** |
| `g_PureDrawAirdropFormations`（十连阵型：圆圈/菱形…） | `PD/02_data.lua:254-…` | 整段删 |
| `PureDrawOnAIUnitBorn` / `PureDrawJoinAIAttackTeam` / `PureDrawScanNewAIUnitsNearAirdrops` / `PureDrawStartAirdropAIUnitScan` / `PureDrawContinueAirdropAIUnitScan` | `PD/04:495-621` | **整段删**（全是给空投/AI 单位补编队） |
| `PureDrawReplaceNativeBanned*` + `PureDrawChooseNativeAllowedUnit` + `PureDrawApplyNativeBannedReplace` | `PD/05:59-147` | 删（我们不禁兵，卡池自己就是白名单） |
| `PureDrawOnRoundBeginRefreshQuota` / `PureDrawRegisterRoundBeginRefresh` | `PD/05:242-264` | 删（回合制概念） |
| `PureDrawTrackCustomCrate`（箱子生命周期跟踪） | `PD/04:368-378` | 删（只为"这个箱子是不是被捡走了"服务；我们简化为"看到无主单位就换"） |
| `PureDrawOnCrateSeedBorn` / `PureDrawOnPhysicalCrateBorn` | `PD/05:3-56` | **保留但简化**：只记录"有个箱子出生了"（可选），把 `UseCustomDraw` 常量改成 `true` |

**结论**：`05_crate_airdrop.lua` 基本可以整份不要，只借它的两个箱子回调思路；
`04_draw.lua` 只留 `PureDrawChooseWeightedUnit` + `PureDrawSpawnCustomUnit` + 截获删批那一段。

## 6 开局那套（`PD/06_init_mcv.lua`）留什么

| 内容 | 位置 | 处置 |
|---|---|---|
| `RegisterUnitCreateCallback("LuckyUnitCrateSeed", …)` | `:331` | **必须留**（抽卡入口对象） |
| 原生结果类型的三段注册循环 | `:337-376` | **必须留**（截获的前提） |
| 授予抽卡技能 `PLAYER_GRANT_SPECIAL_POWER SpecialPower_LuckyUnitCrate` | `PD/01:55-56` | **必须留**（否则玩家没有抽卡按钮）；**`...X10` 那行删掉** |
| `PureLuckyCrateMode_Setting`：删玩家开局船厂、`PureDrawBackupSpawnTransports`、开局清箱子 | `:11-79` | 砍（我们图没有船厂、没有随机箱子生成器、不需要模拟出兵） |
| `NoMCVInCenter`（每 30 帧扫 MCV 击杀、扫 AI 禁用兵） | `:275-329` | **整段砍**（我们压根不给 MCV） |
| `PureDrawGetOutpostSideName` / `PureDrawGetOutpostDropPosition`（中央前哨站空投落点） | `:82-168` | 砍 |
| 开局给每个真人一个抽卡工程师（`JapanEngineer` + 加速 Modifier + 提示） | `PD/01:44-82` | 砍（我们没有建造系统，工程师没意义） |
| `g_PureDrawAlwaysKnownUnitHashes` 里的 MCV 白名单 | `PD/02:228-241` | **改留工程师那 4 个即可**，MCV 名可以删（但留着无害，多几条白名单更安全） |

> 一句话：`06_init_mcv.lua` 里**只留"注册钩子 + 授予技能"**，其余（MCV/船厂/空投/前哨站）全部不要。

## 7 依赖清单：必须移植 / 可以砍

| 依赖 | 作用 | 判断 |
|---|---|---|
| `baselib/SchedulerModule.lua`（节点 `baselib/SchedulerModule`，interval=0，deact=**True**） | `delay_call` 帧延迟、`call_every_x_frame` | **必须移植**：删批必须"等 2 帧再看"，否则只删掉同批的第一个 |
| `GAME/mainloop` 节点（interval=0，deact=**False**） | 每帧调 `SchedulerModule.__runner_function()` | 移植 SchedulerModule 就必须有 |
| `g_PlayerNameToIndex` / `P[]`（`BasicVar1.lua:21`、`UNITCOUNTERINI_0.lua:9`） | 玩家名↔序号、玩家对象句柄（`ObjectFindObjects(P[i], …)`） | **必须**（我们自建 6 行即可） |
| `g_UnitNameToUnitIndex` / `FastHash` | 模板名→兵种索引、类型哈希 | **必须**（`FastHash` 是引擎全局；索引表可选） |
| `UNITCOUNT` / `LUABOX/UNITCOUNTERINI`（单位池计数、限造、`CRATEUNITCOUNT`） | 每人限造与回收计价 | **可砍**（不接限造就不需要） |
| `BanMode` 禁兵体系（`BanModeIsNameBanned` 等） | 抽卡剔除被禁兵种 | **可砍**（卡池即白名单） |
| `Localization` + `exAddTextToPublicBoardForPlayer` + `TextDoActionLocalizedOnce` | 抽卡提示飘字 | **只影响界面**，可砍或换成 `map.str` 的 tutorial 文案 |
| `ButtonManager` / `CenterTopBtnFunc` / `BtnChoiceDialogEventFunc` | 抽卡模式选择按钮、回收按钮、配额刷新按钮 | **可砍**（我们的规则写死，不需要房主选模式） |
| `RecycleUnit.lua`（46 KB，单位回收 UI） | 回收单位换钱 | **待确认**：你说"起重机主要用来回收单位"——如果那个回收走的是这套 UI，就得单独移植；如果只是"卖进起重机"的引擎功能，则与本系统无关 |
| 空投阵型数据 / AI 编队扫描 | 十连 | **砍** |
| 地图侧 `LuckyUnitCrateSeed` 类型存在性 | 抽卡入口对象 | **必须先实测**（见 §9.6） |

## 8 最小可运行子集（我们图的落地）

**3 个 lua 文件**（放 `ALittlePlot/scripts/lua/chouka/`，由现有 `tools/sync-scriptsdata.js` 生成 JSON）：

| 文件 | 内容 | 预估 |
|---|---|---|
| `10_puredraw_data.lua` | `g_PlayerNameToIndex`、卡池 `DrawPool`（单层或四层 + 权重）、`AlwaysKnown` 白名单、原生结果类型名单（`g_GroundCrateUnits` 等三张表）、全局状态表 | ~4 KB |
| `11_puredraw_hook.lua` | `exObjectRegisterCreateEvent` + `g_UnitCreateEventFunc[FastHash(t)] = 回调` 的批量注册（箱子 + 原生结果类型） | ~1 KB |
| `12_puredraw_replace.lua` | 回调三排除 → `delay_call` → 取坐标 → 整批 `NAMED_DELETE` → `UNIT_SPAWN_NAMED_LOCATION_ORIENTATION` 生成 1 个 | ~3 KB |

**ScriptsData.json 节点**（照 DSA 的接法，`interval=0` 表示每帧求值）：

| 节点 | EvaluationInterval | DeactivateUponSuccess | payload |
|---|---|---|---|
| `抽卡hex/PureDraw初始化` | 0 | **True**（只跑一次） | `10 + 11` 拼接 +（可选）授予技能那两行 |
| `baselib/SchedulerModule` | 0 | True | 原样搬 DSA 的 9 KB |
| `抽卡hex/mainloop` | 0 | **False**（常驻） | 一行 `SchedulerModule.__runner_function()` |

> 若不想引 SchedulerModule：把 `12` 里"要删的东西"推进全局队列 `g_PendingReplace`，
> 由现有的 `收入` 节点（每 tick 跑一次）末尾消费队列。**代价**是替换延迟最多 1 个 tick，
> 手感上"箱子开了之后单位晚一下下才出来"，可接受；**收益**是少一个 9 KB payload 和一个每帧节点。

**先后顺序（每一步都能单独进游戏验证）**
1. `11` 只注册 `LuckyUnitCrateSeed`，回调里只 `exMessageAppendToMessageArea("crate born")` → 验证**能收到箱子出生事件**。
2. 注册原生结果类型，回调里打印 `createdObjInstanceId` → 验证**能收到原版抽卡结果**，并核对哈希对不对得上。
3. `12` 只做"删 + 生成一个写死的 `Type`" → 验证**删得干净（半径 260 内不留残余）、生成归属正确、不重复刷**。
4. 接完整卡池 + 权重。
5. 最后再加"抽卡次数限制 / 起重机回收联动"。

## 9 风险点

1. **截获失败 = 原版单位留在场上**（不替换、不崩图）。表现是"玩家抽到了原版随机单位，只是没走你的卡池"。
   所以调试期可以放心上线：最坏是平衡失控，不是坏图。**反之更危险的是误删**（见下条）。
2. **误删保护三条缺一不可**：脚本生成标记、`ObjectGetProducerObject(id) ~= nil`、`AlwaysKnown` 白名单。
   我们图虽然没有超级武器，但日冕的**协议/技能召唤物**同样"没有生产者"，一定要进白名单，否则玩家开协议出来的单位会被当成抽卡结果删掉。
3. **批次窗口**：同一批单位在同一帧生成，删早了会漏。DSA 用 `delay_call(…, 2, …)` + 最多重试 8 次（每 2 帧）覆盖到"这一批完全落地"。
4. **payload 64 KB 硬顶**：DSA 的 PureDraw 单节点已 **61,421 B**；我们只搬子集，目标 **< 10 KB**，别把注释也带进 payload（DSA 的同步脚本会剥注释，我们的生成器目前不剥，文件写小一点即可）。
5. **Lua 4.0 限制**（DSA 反复踩过）：没有 `#`（用 `getn(t)`）、没有 `string.format`（用全局 `format`）、
   字符串不能 `s:sub()`、泛型 `for` 必须两个变量、**闭包拿不到外层 local**
   （`analysis/地图注释说明文档.md:1136-1137`）→ 所有状态挂全局表，`delay_call` 只传"标量参数表"。
6. **`LuckyUnitCrateSeed` 是否存在**：DSA 是 (cor) 图，用的就是这个类型，理论上同 mod 一定有；
   但**必须实测**（场上丢一个箱子，看能否拾取并开出兵）。不存在时的退路：用我们现有的 `unitcratenew`
   箱子 + 同一套 create 事件截获，逻辑一行不用改。
7. **条件在 Lua 里的等价写法**：`PLAYER_HAS_COMPARISON_UNIT_TYPE_IN_TRIGGER_AREA` 可直接
   `EvaluateCondition("PLAYER_HAS_COMPARISON_UNIT_TYPE_IN_TRIGGER_AREA", playerName, 4, 0, "OilDerrick", "Total")`
   （`4` = `>`，`2` = `=`）；或 `ObjectFindObjects(P[i], nil, filter)` 自己数。
8. **两个取值 API 别混**：`ObjectGetPosition(id)` 返回 **3 个值**（`PD/04_draw.lua:421`）；
   `exWaypointGetPos(名字)` 返回**数组**（`PD/01_crate_event.lua:61-63` 用 `p[1..3]`）。
9. **`EvaluationInterval` 的单位存疑**：`ScheduleModule.lua:164` 注释写"15 帧 = 1 秒"，
   而文档说 `EvaluationInterval=1` 的触发器"每约 1 秒"跑一次（`地图注释说明文档.md:636`）。
   → **时序一律用 `delay_call` 的帧数表达**，不要依赖节点间隔来推算秒数。
10. **`GetRandomNumber()` 返回 `[0,1)`**，取整用 `floor(r * n) + 1` 并夹到 `n`（`PD/04_draw.lua:226-229`）；
    Lua 4.0 里 `floor` 是全局函数，不是 `math.floor`。
