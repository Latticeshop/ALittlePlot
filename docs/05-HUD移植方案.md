# 09 · HUD 移植方案（DSA → 抽卡hex）

> 目标：把 DSA 自走棋的 **① 左下角实时倒计时 + 回合数**、**② 右上方场上单位数量** 搬到
> `[cor]每人一小块地抽卡hex`，形态仍是「Lua 源 + ScriptsData.json 经日冕 JSON 地编导入」。
> API 签名均已在 DSA 源码 / 官方教程核对，行号可查。

## 0 结论先行

| 要的东西 | DSA 实际用什么 | 我们照搬用什么 | 坑 |
|---|---|---|---|
| 右上角单位数量 | 引擎**计分板** `exScoreBoardSetText(text,row,col)`，每秒刷 | 同左，数据源换成"扫场存活" | DSA 的数是**兵池累计**，不是场上存活 |
| 左下角回合数 | **公屏** `exAddTextToPublicBoard(text,time)` 事件播报（≤30 秒自消失） | 同左；要常驻用自绘文字 | 公屏是消息流，文字**不能原地改** |
| 左下角实时倒计时 | **DSA 没做在左下角**：只有顶部按钮 overlay + 公屏提示；读数靠 `exCounterGetByName("start")` | ①引擎 `DISPLAY_COUNTDOWN_TIMER`（`00_init.lua` 已用）②**自绘文字**每秒刷 | ①不能定位，②要自己管坐标 |

**一句话**：右上角单位数 = **计分板**；左下角常驻数字 = **自绘文字 CustomText**；回合/倒计时读数 = **地编计数器**（`lvc`/`start`），不是引擎计时器控件。

## 1 这两块界面到底是什么

### 1.1 左下角 = 公屏/消息区（public board），**不是**可定位文字

官方签名（`教程.lua:258-264`）：

```
-- 公屏最多16行
exAddTextToPublicBoard(string content, float time)      -- time=显示秒数, 最多30秒
exAddTextToPublicBoardForPlayer(playerName, string content, float time)
```

补充：`\n` 拆成多行、`$p1Name`…`$p6Name` 替换成 `Player_1~6` 昵称（`教程.lua:410`）；`exSetPublicBoardColor(color)` 设整块公屏颜色（`:436`）；`exMessageAppendToMessageArea("文本")` 无时长、偏调试用（`:40-41`）。

> ⚠ **第二个参数是"显示多少秒"，不是"第几行槽位"。** DSA 源码里满天飞的 `(msg,10)`/`(msg,30)`/`(msg,15)` 全是秒数。
> 公屏是滚动消息流，一行写进去改不了，只能等消失或再发一条 —— 所以"每秒刷新的倒计时"用公屏做不到。

DSA 的用法全是**事件播报**：`huihe/spawn_0.lua:89` 每回合播 `round.begin`（10 秒）、`:91-92` 播阵型（20 秒）、`CenterTopBtnFunc.lua:237,247` 投降播报（10/30 秒）。没有常驻数字。

### 1.2 右上角 = 引擎计分板（scoreboard），7 行 × 3 列

官方签名（`教程.lua:420-433`，标题与文字都支持昵称替换）：

```
exScoreBoardSetVisibility(visible)                    -- 1 常驻显示 / 0 隐藏
exScoreBoardSetTitle(title)
exScoreBoardSetText(text, row, col)                   -- row 1~7, col 1~3
exScoreBoardSetVisibilityForPlayer / SetTitleForPlayer / SetTextForPlayer(playerName, …)
```

DSA 实现只有 31 行，`lua/LUABOX/boardini_0.lua`：

- `:8` `exScoreBoardSetVisibility(1)` — 让板子**常驻**（否则要按住 Tab）
- `:10` `exScoreBoardSetTitle(Localization.get("board.title.troop_count"))`
- `:14-16` 行 1~6 列 1 = 玩家昵称 `"$p1Name:"`…；`:17` 行 7 列 2 = 标题"当前回合"
- `:22` 行 1~6 列 2 = **单位数量**：`exScoreBoardSetText("   "..ANYUNITCOUNT[i], i, 2)`
- `:24` 行 7 列 3 = **回合数**：`exScoreBoardSetText(""..counterValue, 7, 3)`
- `:25-30` 列 3 = 身份（天使/恶魔）—— 列宽靠前置空格凑，不是引擎能力

### 1.3 想把数字"贴在左下角常驻" → 自绘文字（CustomText）

官方无文档，签名从用法反推，字段最全的样本在 `GAME/PurchaseTechMode_Logic.lua:67-76`：

```
exCreateCustomText({
    Index=1, Content="第3回合", X=10, Y=10,
    Color=16711680,          -- 0xRRGGBB 十进制；ARGB 用 HexToInt32("0xFF800000")
    Size=15,                 -- 字号
    AlignX="left",           -- 可选 "left"/"right"：X = 距左/右黑边内缘像素
    AlignY="top",            -- 可选 "top"/"bottom"：Y = 距上/下边像素
    GroupIndex=1,            -- 可选，成群统一设置
})
exCustomTextUpdateText(Index, content)            -- 原地改文字
exCustomTextUpdateVisibility(Index, visible)      -- 1/0
exCustomTextUpdatePos(Index, X, Y)
-- 玩家特化：函数名后加 ForPlayer，playerName 作第一个参数
-- 例：BtnChoiceDialogEventFunc.lua:1476  exCustomTextUpdateTextForPlayer(playerName, Index, content)
```

- AlignX/AlignY 语义同自定义按钮（`教程.lua:598-604`）：**不给 Align 就是屏幕绝对坐标，容易出屏**。
- **左下角 = `AlignX="left", AlignY="bottom"` + 适当留白**。DSA 只在"升本模式"用它显示科技等级/电厂上限，三个文字 `AlignX="left" AlignY="top"`、X=10/0/0、Y=10/30/50、Size=15（`PurchaseTechMode_Logic.lua:67-98`）。
- 要背景板：`exCreateCustomImage({Index,TextureName,X,Y,SizeX,SizeY,...})`（`text/Update_0.lua:93-102` 用 `AptWhiteBox`）+ `exCustomImageGroupSetColor`。

## 2 倒计时与回合数

### 2.1 DSA 的真实机制：地编计数器 + 毫秒计时器，Lua 只读

全跑在**原生脚本**里（不是 Lua）：

| 计数器 | 含义 | 谁写 |
|---|---|---|
| `lvc` | 回合数 | `SET_COUNTER(lvc,0)`（`/m0` 初始化）；每回合 `INCREMENT_COUNTER(1,lvc)`（`/huihe/spawn`） |
| `start` | 回合倒计时 | `SET_MILLISECOND_TIMER(start,60)`（`/huihe/start`、`/huihe/start324`）；加时 `STOP_TIMER` + `ADD_TO_MSEC_TIMER(1,start)`（`/huihe/lvcadd`） |
| `zero` | 界面显示用 | `/huihe/spawn`：`SET_COUNTER(zero,0)` + `DISPLAY_COUNTER(zero,)` |

回合推进是**事件驱动**：`/huihe/spawn` 条件即 `TIMER_EXPIRED(start)` —— 归零 → 回合 +1 → 重设 60 秒 → 重新启用一批子脚本。

Lua 侧只读不写：

```lua
local round = exCounterGetByName("lvc")          -- CenterTopBtnFunc.lua:553,981,1021
local cv    = exCounterGetByName("lvc")          -- boardini_0.lua:20
local remain= exCounterGetByName("start")        -- ExtraCommand / UtilsLuckyCrate / BtnChoiceDialogEventFunc 都这么读
```

计数器 API（`教程.lua:34-38`）：`exCounterSetByName("名", 100)`（不存在会自动建）、`exCounterGetByName("名")`。

> **实测：DSA 全图 436 个脚本节点里没有任何一处用 `DISPLAY_COUNTDOWN_TIMER`。**
> 全量扫过动作名含 `TIMER`/`COUNTDOWN` 的节点，只出现 `SET_MILLISECOND_TIMER`/`STOP_TIMER`/`ADD_TO_MSEC_TIMER`/`TIMER_EXPIRED`/`PLAYER_SET_SPECIAL_POWER_COUNTDOWN`。引擎那个倒计时控件 DSA 一次没用。

### 2.2 引擎计时器控件（`00_init.lua` 已在用，最省事）

```
SET_MILLISECOND_TIMER(box, 120)                -- 建/重置 120 秒计时器
DISPLAY_COUNTDOWN_TIMER(box, "SCRIPT:box")     -- 让引擎画在屏幕上
HIDE_COUNTER(box)                              -- 隐藏（DSA /GAME/HidePowerCounter 用）
```

**位置由引擎决定、不能挪到左下角** —— 这是它 vs 自绘文字的核心取舍。需要 `map.str` 里有 `SCRIPT:box` 键。

### 2.3 自绘文字倒计时（要"左下角"就选这条）

每个 int=1 节点：① `exCounterGetByName("lvc")` + `exCounterGetByName("start")` ② 拼串 ③ `exCustomTextUpdateText(idx, "第"..round.."回合  剩余"..remain.."秒")`；隐藏用 `exCustomTextUpdateVisibility(idx,0)`。
**回合数只由地编加**（`INCREMENT_COUNTER`），Lua 不要自己加，两边都改必然错位。

## 3 右上角单位数量

### 3.1 DSA 的三张表（`LUABOX/UNITCOUNTERINI_0.lua`）

```
:5-10   UNITCOUNT = {}       -- 分兵种数量（限造/回收用）
:6      CRATEUNITCOUNT = {}  -- 箱子来源计数，回收时区别对待
:9-13   P = {}; P[i] = GetObjectByScriptName("P"..i)   -- 地图上摆的 P1~P6，当"玩家锚点"
:10,14  ANYUNITCOUNT = {}; ANYUNITCOUNT[i] = 0         -- 不分兵种总数（界面显示的就是它）
```

### 3.2 统计口径：**不是"场上存活"，是"入池累计"**（最易照搬错的地方）

- 驱动：`/LUABOX/unitregenerate`（**EvaluationInterval=5**）→ `unitgenerate()`（`:752`）
- 取数：`CopyPlayerRegisteredObjectSet("Player_"..playindex, "UNITS")`（`:757`）取"已登记对象池"
- 累加：`unitgetcountanddelet(playindex)`（`:625`）按兵种累加进 `UNITCOUNT`/`ANYUNITCOUNT`（`:674-675`）
- **随后实体被删**：`ExecuteAction("NAMED_DELETE", TAR[i])`（`:695`）

即自走棋的兵是"池子里的数"，`ANYUNITCOUNT` = 累计获得的战斗单位数；减项来自回收/吸星等（`RecycleUnit.lua:485`、`15_drain.lua:99`、`05_ultimate_creature.lua:321`）。

### 3.3 刷到右上角

`/LUABOX/boardini__1`（**EvaluationInterval=1**）→ `boardact()`（`boardini__1_0.lua:1-3`）→ `exScoreBoardSetText("   "..ANYUNITCOUNT[i], i, 2)`（`boardini_0.lua:22`）。

### 3.4 我们这张图怎么做（关键差异）

本图无兵池，要显示**场上存活单位数**，用已验证的扫描 API（`封装宝典.lua:183/214/909` 等数十处）：

```lua
local units, count = ObjectFindObjects(源对象, 区域名或nil, filter)
```

- `源对象`：与"统计谁"同阵营的锚点。DSA 用 `P1~P6`；**我们直接用 `crane1~crane6`**（各玩家自有，已有）
- `filter` **必须建在全局作用域**：

```lua
-- BasicVar1.lua:85-90（作者注释：LuaBridge 全局函数不能捕获外层 local，过滤器必须放全局）
g_HudUnitFilter = CreateObjectFilter({
    Rule="ANY", Relationship="SAME_PLAYER", Include="SELECTABLE", Exclude="STRUCTURE" })
```

- 结果直接 `exScoreBoardSetText(""..count, i, 2)`；要排除特定单位就在 filter 加 `Exclude`。

## 4 刷新频率与开销

| 层 | DSA 实际 | 证据 |
|---|---|---|
| 扫场统计 | **每 5 秒** | `/LUABOX/unitregenerate`，int=5 |
| 刷界面 | **每 1 秒**，无条件重写 7×3 全格 | `/LUABOX/boardini__1`，int=1；`boardini_0.lua:19-30` 无差异判断 |
| 回合/倒计时 | **事件驱动**（`TIMER_EXPIRED`），不轮询 | `/huihe/spawn`、`/huihe/start` |
| 公屏播报 | 事件驱动 | `spawn_0.lua:89` |
| "没变就不重刷"优化 | **没有** | `boardact()` 每秒照写 |

照搬注意：① **别改成 int=0（每帧）**，UI 写入是引擎侧最贵的操作之一，DSA 严格 int≥1；② 本图可把扫场+刷板合成**同一个 int=1 节点**（6 名玩家 × `ObjectFindObjects` 开销可忽略）；③ 想省就加"count 与上次相同则跳过 `exScoreBoardSetText`"的自缓存（成本为零）；④ 创建 UI 后**首帧不刷新**，要等 1~2 帧（`教程.lua:296`）；⑤ 建板可延后 2~3 秒：DSA 是开局 15 秒后建（`/cams/cam4` 的 `SET_MILLISECOND_TIMER(BOARD,15)` → `boardini` 条件 `TIMER_EXPIRED(BOARD)`），我们无过场可从简。

## 5 依赖清单

| 基础设施 | 判定 | 理由 |
|---|---|---|
| 计分板 `exScoreBoard*` | **必须** | 右上角唯一实现方式 |
| 计数器 `exCounterGet/SetByName` | **必须** | 回合数与倒计时读数都来自这里 |
| 地编动作 `SET_COUNTER`/`INCREMENT_COUNTER`/`SET_MILLISECOND_TIMER`/`TIMER_EXPIRED` | **必须** | 回合驱动本体，Lua 只读 |
| `ObjectFindObjects` + `CreateObjectFilter` | **必须** | 单位数；锚点用 `crane1~6` |
| 自绘文字 `exCreateCustomText`/`exCustomTextUpdate*` | 只有"左下角常驻数字"必须要 | 用 `DISPLAY_COUNTDOWN_TIMER` 可整块砍 |
| 公屏 `exAddTextToPublicBoard` | 只要播报就要 | 零依赖，一行 |
| Localization 文案系统 | **只影响观感**（可砍） | 可砍：直接写中文字面量；留着才有统一改词/多语言 |
| ButtonManager | **可砍** | 那是自定义按钮点击路由（`RegisterCustomButtonHandler`），本方案不点按钮 |
| ScheduleModule | **可砍** | 用 int=1 地编节点代替 `call_every_x_frame`/`delay_call`（`baselib/ScheduleModule.lua:37,166`） |
| 单位创建/死亡事件注册 | **可砍** | 老接口官方注明"因 bug 不可用"（`教程.lua:452-464`）；替代品 `RegisterUnitCreateCallback`/`RegisterUnitDieCallback`（`GAME/UnitCreate.lua:7`、`GAME/UnitDie.lua:6`）。我们走轮询绕开 |
| `mainloop()` + `SchedulerModule.__runner_function` | **不需要** | 仅按帧调度才要（`GAME/mainloop.lua:1-3`） |
| `HexToInt32`/`exSetPublicBoardColor` | **只影响观感** | 配色用 |

## 6 最小可运行子集

3 个 lua 文件 / 3 个地编节点，挂在根列表 `PlayerName=""` 下（可与现有 `抽卡hex` 三件套同级）：

| # | 文件 | 节点名 | EvaluationInterval | DeactivateUponSuccess | 条件 | 职责 |
|---|---|---|---|---|---|---|
| 1 | `hud_init.lua` | `HUD初始化` | 0 | **true**（只跑一次） | `CONDITION_TRUE` | `exScoreBoardSetVisibility(1)`+标题+行1~6列1昵称+行7列2标题；建两条自绘文字（或把 `DISPLAY_COUNTDOWN_TIMER` 搬来） |
| 2 | `hud_tick.lua` | `HUD刷新` | **1** | false | `CONDITION_TRUE` | 读 `lvc`/`start` → `exCustomTextUpdateText`；`ObjectFindObjects(craneN,…)` → `exScoreBoardSetText(count,i,2)` |
| 3 | `hud_round.lua` | `HUD回合播报` | 0 | false | `TIMER_EXPIRED(start)` | `exAddTextToPublicBoard("第"..lvc.."回合开始", 10)` |

顺序与前置：① 先有**回合驱动**（`INCREMENT_COUNTER(1,lvc)` + `SET_MILLISECOND_TIMER(start,60)` + `TIMER_EXPIRED(start)` 循环节点），否则 `lvc`/`start` 永远为 0；② 再建 HUD（节点 1，更新函数依赖 textIndex 已存在）；③ 最后挂常驻刷新与播报。
**不要重复造计时器**：`00_init.lua` 已有 `box`（120 秒刷箱子），"下一箱"直接复用 `box`；只有"本回合剩余"才新加 `start`。

## 7 风险点

1. **单条 payload 64 KB 上限**：`CenterTopBtnFunc.lua` 已是 60 KB 级（DSA 用 `analysis/tools/lua_payload.py` 去注释 + `_tmp_map_payload_count.py` 监控）。HUD 只有几百字节，远没到；结论是**别把 HUD 逻辑塞进任何大文件**，一个功能一个文件一个节点。
2. **Lua 4.0**：没有 `#t`（用 `getn`）；字符串无方法（`strsub`/`format`）；泛型 for 要两变量；**闭包拿不到外层 local**（`BasicVar1.lua:85` 为此专门注释）。HUD 状态表一律挂全局。
3. **`nil` 拼串会炸**：`"   "..ANYUNITCOUNT[i]` 依赖表已填 0（`UNITCOUNTERINI_0.lua:14` 把 1~8 全置 0）。我们的 `g_HudCount[i]` 同理，初始化就填满。
4. **数字对齐靠空格**，不是引擎能力（`boardini_0.lua:22`）。
5. **`map.str` 只在两种情况要改**：用 `DISPLAY_COUNTDOWN_TIMER(名,"SCRIPT:xxx")`，或用 `Localization.get("键")`。计分板与自绘文字写字面量，**不用动 map.str**。
6. **计分板是全局的**：`exScoreBoardSetText` 六人共享一块板；要"只给自己看"必须换 `...ForPlayer`。单位数是公开信息，用全局版即可（DSA 也是全局版）。
7. **回合数只能有一个来源**：地编加、Lua 只读。

## 8 源码索引

| 文件:行 | 内容 |
|---|---|
| `教程.lua:258-264` / `:410` / `:435-436` | 公屏 API（≤16 行，time≤30 秒）/ 昵称替换 / 公屏配色 |
| `教程.lua:420-433` | 计分板 API（7 行 3 列） |
| `教程.lua:34-38` / `:296` / `:298-309` | 计数器 API / 创建后等 1~2 帧 / TimerOverlay 是百分比 0~99 不是秒 |
| `教程.lua:452-464` | 老的单位创建/死亡事件"因 bug 不可用" |
| `LUABOX/boardini_0.lua:8-30` + `boardini__1_0.lua:1-3` | 计分板全量实现（31 行）+ 每秒调 `boardact()` |
| `LUABOX/UNITCOUNTERINI_0.lua:5-14,625,674-675,695,752-763` | 三张表 / 入池累加+删实体 / `unitgenerate()` 每 5 秒扫全场 |
| `GAME/BasicVar1.lua:85-100` | filter 必须全局 + `ObjectFindObjects` 用法 |
| `GAME/PurchaseTechMode_Logic.lua:67-98` | `exCreateCustomText` 完整字段样本 |
| `text/Update_0.lua:93-111` | 自定义图片+文字+分组配色 |
| `LUABOX/BUTTON/CenterTopBtnFunc.lua:553,981,1021` | 读 `lvc` 做回合判定 |
| ScriptsData.json `/huihe/spawn`、`/huihe/start`、`/huihe/lvcadd`、`/LUABOX/unitregenerate`(int=5) | 回合驱动 / 倒计时 60 秒 / 加时 / 统计节拍 |
