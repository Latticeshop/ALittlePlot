# 07 · 抽卡hex 改造：Lua 脚本 + JSON 地编

> 做法照抄《日冕自走棋（DSA）》工程：**`lua/*.lua` 是唯一真源，`ScriptsData.json` 是生成物**，
> Lua 以 `#!ra3luabridge` payload 的形式挂在一条 `DEBUG_MESSAGE_BOX` 动作里，最后由日冕 **JSON 地编**导入地图。
> 本图**不用 MCP 写脚本**（MCP 只用来读数据），导入由你手动完成。

## 1 定稿规则

| 项 | 定稿 | 实现 |
|---|---|---|
| 基地车 / 建造场 | **全部不要** | 原图那套 MCV + 建造场脚本整套删除 |
| 起重机 `crane1~6` | **可摧毁 + 保持完全可用**（可建造、回收功能正常） | 摧毁 = 该玩家直接判负；⚠ 别再把它设成"不可建造"，那会连带废掉起重机的**回收**功能（实测） |
| 建造 | **建造栏整条关闭** | `PLAYER_DISABLE_BASE_CONSTRUCTION`（编辑器 56，"玩家不允许建造建筑"）；`ALLOW_DISALLOW_ALL_BUILDINGS` 属 "Unused or Obsolete"，实测空操作，已弃用 |
| 抽卡阵营 | **可选：箱子包括全部阵营（默认）/ 只有自己阵营** | 卡池按阵营切成四份：盟军 36 / 苏联 40 / 升阳 26 / 神州 33（共 135 种，按作者《完整单位表》T1~T5，**T5 在本图是独立档**）；阵营用 `PLAYER_HAS_PLAYER_TECH` 在首次抽卡时探测（第 0 帧探测会全判成盟军）；抽哪张池由开局房主配置的 `CHOUKA_DRAW_SCOPE` 决定（docs/08 §4） |
| 水陆适配 | **陆地不刷船、水里不刷陆地单位** | 每个类型带类别（步/载/空/海/两栖）。水陆判定只有一条链：**查地图掩码**（`09a_watermask.lua`，从地图预览图提取的"海/陆"死数据）；不靠高度、不看箱子、不用多路信号、不做兜底。旧写法② 贴图名含 wate度 vs 开局校准水位**；不再用多路信号凑、也不用空军兜底。详见 §9；旧写法（四路正票）② 贴图名含 water/sea/ocean ③ `exTerrainGetHeightByPos ≤ 30` ④ 落点 `z ≤ min(陆地参考/2, 40)`；**空军结果不拿 z 判**，**水里生成把 z 抬到 `CHOUKA_WATER_SURFACE_Z=0`**；空军与两栖不受限（docs/08 §二④） |
| 视野 | **开局全图常亮** | `MAP_REVEAL_ALL_PERM`（盲盒高原同款） |
| 电力 | **无限** | `PLAYER_SET_BASE_POWER = 100000`（虚空电力，不依赖电厂） |
| 建造 | **禁止** | ~~`ALLOW_DISALLOW_ALL_BUILDINGS = 0`~~ → 已改为 `PLAYER_DISABLE_BASE_CONSTRUCTION`（见上表第 2 行） |
| 收入 | **双轨：底薪 + 油井** | 底薪 40 + 油井 20 = 60 元/秒（≈41 秒够一次 2480 的日冕抽卡） |
| 箱子 | **只做私有箱，且不重复刷** | 每人 `boxN1` / `boxN2` 各一个 `moneycrate`，120 秒一轮；点位半径 35 内已有箱子就跳过 |
| 中央岛 `center` / `center1~6` | **中央争夺：占油井 + 刷钱箱** | 中央两座中性油井（真名 `centerOil1` / `centerOil2`，拿不到才按离 `center` 250 内的 `OilDerrick` 兜底找），站兵争夺、连续领先 3 次换归属（照双兵种 `Oil Capture.lua`）；每回合在 `center1~6` 各刷 1 个钱箱，点位已有箱子就跳过（docs/08 §二①③） |

## 2 十六个脚本节点

| 节点 | EvaluationInterval | 一次性 | 条件 | 做什么 | 源文件 |
|---|---|---|---|---|---|
| `抽卡hex/自检` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | **排第一个**：整局每 10 秒往日志写一行心跳（started / round / boxLeft / lv / hud / 已就绪节点），并给每个节点打「节点就绪」标记 —— 排查"流程断在哪"的第一现场 | `00_selfcheck.lua`（构建时自动拼上 `00_alert.lua`） |
| `抽卡hex/开局` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | **开局三段**：锁视角到 `center` + 全屏公告 + 中心提示 → 房主点「已阅读」开配置页（两个二选一：抽卡只有自己阵营 / 箱子包括全部阵营）→ 点「确认，开始游戏」后视角回出生点/解锁/写入 `CHOUKA_DRAW_SCOPE`/倒计时起步；并定义两个对话框回调的分发器（docs/06、docs/08 §4） | `03_start.lua` |
| `抽卡hex/随机箱清理` | 0（每帧） | ❌ 常驻 | `CONDITION_TRUE` | 照 DSA 的两段删除：第 1 帧删 `GenericCrateSpawner`（刷箱器）→ 第 45 帧清已落地的实体随机箱（离预设点位 80 以内放过）→ 前 2 分钟每 10 秒兜底补扫（docs/07） | `07_crates.lua` |
| `抽卡hex/初始化` | 0（每帧） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 抽卡等级表、全图常亮、基础电力、关闭建造栏、开局资金**兜底** 5096、倒计时初值 | `09_level.lua` + `00_init.lua` |
| `抽卡hex/收入` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 底薪 + 油井加成，顺手重设电力（**开局后才结算**） | `01_income.lua` |
| `抽卡hex/私有箱` | 1（≈1 秒，**自己数秒**） | ❌ 常驻 | `CONDITION_TRUE` | 每秒把 `CHOUKA_BOX_LEFT` 减 1，减到 0 才开新回合：每人两个点位各刷一个箱子（种类见 `02a_crate_list.lua`，已有箱子就跳过）+ 重置倒计时 + 回合数 +1（**开局后才走**） | `02_private_box.lua` |
| `抽卡hex/抽卡初始化` | 0（每帧） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 截获原版抽卡结果并转成卡池单位：**原生结果几个就补几个**（单抽 1 / 十连 10，上限 10），按阵营池 + 水陆筛选（docs/08 §2、§5） | `10_puredraw_data.lua` + `gen_pool.lua` + `11_puredraw_hook.lua` + `12_puredraw_replace.lua` |
| `抽卡hex/保底军犬` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | **只看玩家手上有没有苏联/盟军工程师**：为 0 时每 5 秒在「起重机→出生点 55% 处」补 1 个，有就一只都不多刷。补的种类是 **SovietEngineer / AlliedEngineer 随机**（随机取千分位奇偶 + **最多连续 2 次同一种**，保证两种都会出现；作者实测反馈过"只见到盟军工程师"）。这两种不会作为原生抽卡结果出现，所以不会被自己的抽卡系统误删；日志会打 `保底工程师：给 Player_N 投放 <类型>` | `05_dog.lua` |
| `抽卡hex/中央油井` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 中央两座油井（真名 `centerOil1`/`centerOil2`，拿不到才按离 `center` 250 内的 `OilDerrick` 兜底）：每 5 秒扫半径 200 按玩家计数，**连续领先 3 次**才换归属并真实转所有权；每回合在 `center1~6` 各刷 1 个钱箱（点位已有箱子就跳过）（docs/08 §1、§3） | `06_center.lua` |
| `抽卡hex/解锁科技` | 1（≈1 秒） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 开局把全部科技协议发给 `<All Players>`（含龙船全套升级） | `gen_upgrades.lua` + `15_upgrades.lua` |
| `抽卡hex/发技能` | 1（≈1 秒） | ❌ 常驻（脚本内只发一次） | `CONDITION_TRUE` | **开局后**给真人玩家发 `SpecialPower_LuckyUnitCrate`（单抽）+ `SpecialPower_LuckyUnitCrateX10`（十连）；`CHOUKA_DRAW_POWER_GRANTED` 保证只发一次。节点不能设一次性，否则会在开局前自我停用（docs/08 §2） | `14_grant_draw.lua` |
| `抽卡hex/按钮栏` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 顶部按钮栏：3=交易市场、4=海克斯（禁用），1/2/5/6 留空；脚本内分两次求值（先 Show、一秒后再设 Enable）；**开局后才建** | `16_buttons.lua` |
| `抽卡hex/AI对手` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | **电脑对手**：① 每回合给每个电脑座位免费抽卡，**初始 1 个、每 5 回合 +1 个**（上限 5），每次抽卡都独立掷点，走同一套卡池/阵营池/水陆判定，概率取"自动升级"那条线；② 每 5 秒扫全场，把**非玩家阵营**（`PlyrCivilian`/`PlyrCreeps`）的单位用 `UNIT_SET_TEAM` 塞进 `<阵营>/ATTACK` 攻击队（照 DSA `PureDrawJoinAIAttackTeam` 与 `DEFAULTATTCKTEAM`），中立单位因此会主动打玩家 | `17_ai.lua` |
| `抽卡hex/帧循环` | 0（每帧） | ❌ 常驻 | `CONDITION_TRUE` | 消费帧延迟队列（截获要"等 3 帧"再删整批）+ **开局 3 分钟超时兜底** | `13_frame_loop.lua` |
| `抽卡hex/HUD` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 右上角计分板刷每人场上单位数 + 回合数；左下角五行：回合数 / 盲盒刷新倒计时（只画，由私有箱节点推进）/ 抽卡等级 / 各档概率 | `20_hud.lua` |

判定口径（**关键：原来的脚本一律靠"有建造场"判定，本图永远不成立，必须换判据**）：

- **起重机 = 核心**：`GetObjectByScriptName("crane" .. i)` 活着才算这名玩家还在场上，才有收入。
  起重机被拆 → 断收入（唯一的经济软肋，建议把 `crane1~6` 在编辑器里设成不可摧毁 + 不可出售）。
- **油井加成**：`PLAYER_HAS_COMPARISON_UNIT_TYPE_IN_TRIGGER_AREA(player, 4, 0, "OilDerrick", "Total")`
  （`4` = ">"，与地编里原 `Money` 脚本同一枚举；自己的 `oilN` 是 `objectIndestructible`，稳定生效）。
- **私有箱归属**：队伍字符串 `Player_N/teamPlayer_N`（本图 22 支队伍里 `teamPlayer_1~6` 的 owner 就是 `Player_1~6`）。
  用**未具名生成** `CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT`，箱子没人开也不会因为重名而刷不出来。

## 3 文件与生成

```
ALittlePlot/
├─ scripts/
│  ├─ lua/chouka/00_alert.lua          ← 真源：**诊断通道**（_LOG / _ALERT / 节点自检；构建时拼到每个节点最前面）
│  ├─ lua/chouka/00_selfcheck.lua      ← 真源：**自检心跳**（每 10 秒一行日志，排第一个节点）
│  ├─ lua/chouka/01_texts.lua           ← **文案总表**（所有玩家可见文本 + 日志文案，tools/extract-texts.js 生成）
│  ├─ lua/chouka/03_start.lua           ← 真源：**开局流程**（锁视角+公告+房主配置+正式开始，docs/06）
│  ├─ lua/chouka/07_crates.lua          ← 真源：**引擎随机箱清理**（除预设点位外不出现自然随机箱，docs/07）
│  ├─ lua/chouka/00_init.lua            ← 真源：地图级一次性别（视野/电力/禁建造/资金兜底/倒计时初值）
│  ├─ lua/chouka/01_income.lua          ← 真源：收入
│  ├─ lua/chouka/02a_crate_list.lua     ← **箱子种类表**（家里 boxN1/2 + 中央 center1~6 刷什么箱子，改权重只改这）
│  ├─ lua/chouka/02_private_box.lua     ← 真源：私有箱（含去重 + 回合数自增，1 秒节点自己数秒）
│  ├─ lua/chouka/09_level.lua           ← 真源：抽卡等级表（等级 → 各档概率 / 升级价）
│  ├─ lua/chouka/05_dog.lua             ← 真源：保底单位（工程师，节点名仍叫"保底军犬"）
│  ├─ lua/chouka/06_center.lua          ← 真源：中央油井占领（真名优先 + 几何兜底 + 争夺式）+ 中央钱箱每回合去重刷新 + `_ALERT` 诊断（docs/08 §二①②③）
│  ├─ lua/chouka/10_puredraw_data.lua   ← 真源：抽卡数据（原生结果类型 / 白名单 / 状态）
│  ├─ lua/chouka/gen_pool.lua           ← **生成物**：卡池 + 阵营池 + 类别表（tools/build-pool.js）
│  ├─ lua/chouka/gen_allunits.lua       ← 生成物：全部单位类型表（日冕单位信息汇总.txt 全表）
│  ├─ lua/chouka/11a_register.lua       ← 真源：整表登记出生事件 + onUnitCreateEvent
│  ├─ lua/chouka/12_puredraw_replace.lua← 真源：删整批 + 补 N 个（单抽 1 / 十连 10）+ 帧延迟队列 + 水陆筛选 + 阵营池范围
│  ├─ lua/chouka/17_ai.lua             ← 真源：AI 对手（电脑每回合免费抽卡，初始 1 个每 5 回合 +1；中立单位加入 ATTACK 攻击队）
│  ├─ lua/chouka/13_frame_loop.lua      ← 真源：每帧驱动 + 开局超时兜底
│  ├─ lua/chouka/gen_upgrades.lua       ← **生成物**：要解锁的科技协议名单（tools/build-upgrades.js）
│  ├─ lua/chouka/15_upgrades.lua        ← 真源：开局 GIVE_PLAYER_UPGRADE 全发
│  ├─ lua/chouka/14_grant_draw.lua      ← 真源：发抽卡技能（单抽 + 十连，开局后才发）
│  ├─ lua/chouka/16_buttons.lua         ← 真源：顶部按钮栏 + 交易市场 + 氪金防御塔
│  ├─ lua/chouka/20_hud.lua             ← 真源：计分板 + 左下角回合数/倒计时
│  └─ ScriptsData.json                  ← 生成物（给 JSON 地编导入）
└─ tools/
   ├─ sync-scriptsdata.js               ← 生成器（零依赖 node；支持一个节点拼多个 lua）
   ├─ build-pool.js                     ← 卡池生成器（读作者《完整单位表》+ 两份中文字典）
   ├─ pool-alias.js                     ← 中文名→类型名 的简称对照表
   ├─ build-upgrades.js                 ← 科技协议名单生成器（读双兵种 / DSA 三处清单）
   ├─ build-watermask.js                ← 从地图预览图提取"海/陆"死数据 → 09a_watermask.lua
   ├─ extract-comments.js               ← 把 lua 里的大段纯注释搬到 docs/10-Lua注释存档.md
   ├─ extract-texts.js                   ← 把 lua 里**玩家可见**的大段文本串搬到 chouka/01_texts.lua（只追加，跳过 _LOG）
   ├─ split-log-texts.js                  ← 反向：把"其实只进 _LOG"的条目搬回代码（文案表只留玩家看得见的）
   └─ lua-callsite.js                     ← 上面两个共用的"这个字符串被哪个函数包着"判定（认得出跨行 _LOG(format(...))）
```

```powershell
cd E:\Ra3_CenterChess\ALittlePlot
node tools/build-pool.js                # 重建卡池 → gen_pool.lua（会自动打印按 TIER_PIN / BLACKLIST 被剔除的条目）
node tools/build-upgrades.js            # 重建科技协议名单 → gen_upgrades.lua
node tools/sync-scriptsdata.js          # 生成 scripts/ScriptsData.json
node tools/sync-scriptsdata.js --check  # 只算 payload 体积，不写文件
node tools/extract-comments.js          # 把 lua 里 ≥4 行的纯注释搬到 docs/10（含代码指纹校验）
node tools/extract-texts.js             # 把**玩家可见**的大段文本串追加进 01_texts.lua（_LOG 里的自动跳过）
node tools/split-log-texts.js           # 反过来：把只进日志的条目搬回代码
```

当前产物（16 个节点，全部远低于 64 KB 单条上限；每个节点都自动多拼了 `00_alert.lua`）：

```
  抽卡hex/自检          4019 B (余 61517 B)  interval=1
  抽卡hex/开局         20845 B (余 44691 B)  interval=1
  抽卡hex/随机箱清理    11884 B (余 53652 B)  interval=0
  抽卡hex/初始化        10028 B (余 55508 B)  interval=0
  抽卡hex/收入          5132 B (余 60404 B)  interval=1
  抽卡hex/私有箱        9020 B (余 56516 B)  interval=1
  抽卡hex/单位登记      18359 B (余 47177 B)  interval=0
抽卡hex/抽卡初始化    52297 B (余 13239 B)  interval=0
  抽卡hex/保底军犬      9944 B (余 55592 B)  interval=1
  抽卡hex/中央油井     15181 B (余 50355 B)  interval=1
  抽卡hex/解锁科技      6314 B (余 59222 B)  interval=1
  抽卡hex/发技能        4350 B (余 61186 B)  interval=1
  抽卡hex/按钮栏       17483 B (余 48053 B)  interval=1
  抽卡hex/AI对手       15379 B (余 50157 B)  interval=1
  抽卡hex/帧循环        4481 B (余 61055 B)  interval=0
  抽卡hex/HUD          11542 B (余 53994 B)  interval=1
```

- 单个 payload 上限 **65536 B**，超了 WorldBuilder 会截断，游戏内报 `last token read: '<eof>'`；
  生成器直接报错拦下，不会写出坏包。
- `私有箱` 节点现在是 **1 秒节点、自己数秒**（`CHOUKA_BOX_LEFT`），间隔不再从 `BOX_SECONDS` 读：
  因为真正开局要等房主确认，节点间隔从"进游戏"算起会和开局时间点对不齐（docs/06 §2.5）。

## 4 手动导入步骤

1. **备份** `[cor]每人一小块地抽卡hex.map`。
2. 日冕 **JSON 地编** → 导入 `ALittlePlot/scripts/ScriptsData.json`。
   - 若工具是**整树替换**：导入后旧脚本会整体消失 —— 正好，旧脚本本来就该全删。
   - 若是**合并**：导入后按 §5 清单手动删旧的。
3. 脚本树里确认出现 `文件夹「抽卡hex」`，下面 **8 条**脚本（名字、interval、一次性标记见 §2）。
4. `map.str` 追加箱子倒计时文案（不想显示倒计时就把 `00_init.lua` 最后两行删掉）：
   ```
   SCRIPT:box = 下一次盲盒
   SCRIPT:box?chinese = 下一次盲盒
   ```
5. 进游戏验证（见 §7）。

## 5 旧脚本处置清单（原 88 条）

| 旧脚本 | 处置 | 理由 |
|---|---|---|
| 根 `欢迎二创`（默认停用） | 可留可删 | 纯作者注释 |
| 根 `MUSIC` | **留** | 背景音乐 |
| 根组 `油田重铸`（默认停用） | **删** | 引用中央油井的旧名、并把航点写成大写 `Center`，启用就失效 |
| 根组 `修复基地车脚本人机BUG` | **删** | 没有基地车可修；而且 `计时1秒` 每秒清 `DieAreaBUG`，那个区正好包着 `power1~6` |
| 根组 `地图介绍` TL1~TL4 | 留（文案重写）或删 | 现在讲的还是"展开 MCV 获取视野 / +$8 每秒"，与新版完全不符 |
| 每人 `AI直接给基地__N` | **删** | 名字骗人，它只负责"启用出场动画组" |
| 每人 `Money` | **删** | 判据是"有建造场/MCV"，本图永假 → 永不发钱；已由 `抽卡hex/收入` 取代 |
| 每人 `View Get` / `View Lost` | **删** | 互相激活的视野开关，本图永假；已由开局常亮取代 |
| 每人组 `根据阵营给旗帜__N` | **删** | 靠建造场判阵营，永假 |
| 每人组 `游戏开始：出场动画__N`（4 条 MCV + `授权AI__N`） | **删** | 5 条动作全要求"你已经有建造场"；`授权AI__N` 是**无条件** `TEAM_AI_TRANSFER teamPlayer_N → 1`，把队伍直接交给 AI，留着很危险 |

删完这张图的脚本树只剩：`欢迎二创`（可选）+ `MUSIC` +（可选）`地图介绍` + 新的 `抽卡hex` 三件套。

## 6 调参表

| 想改 | 改哪 | 注意 |
|---|---|---|
| 底薪 | `01_income.lua` 的 `BASE_INCOME` | 改完跑一次生成器 |
| 每座油井加成 | `01_income.lua` 的 `OIL_INCOME` | 本图每人 1 座，想"多油井多收益"就直接加座 |
| 开局资金 | `00_init.lua` 的 `BASE_MONEY` | `PLAYER_GIVE_MONEY` 是**在**酒馆初始资金上叠加 |
| 基础电力 | 两个文件的 `BASE_POWER` | 给到 100000 已经远远超过任何建筑消耗 |
| 箱子间隔 | `02_private_box.lua` 的 `BOX_SECONDS` | 节点 interval 自动跟随；`00_init.lua` 里同名常量只影响倒计时显示，一起改 |
| 登神盲盒半径 / 幅度 | `02_private_box.lua` 的 `CHOUKA_ASCEND_RADIUS` / `CHOUKA_ASCEND_MIN` / `CHOUKA_ASCEND_MAX` | 96 世界单位（= 家里 box11↔box12 间距 95.5）/ 25%~50%；种类概率 血量40 伤害30 攻速20 射程10（docs/07 §5.1）|
| 箱子类型 / 权重 | `02a_crate_list.lua` 的 `CHOUKA_CENTER_CRATE_TABLE`（中央）/ `CHOUKA_BOX_CRATE_TABLE`（家里） | 中央：现金 45/大现金 5/治疗 10/经验 10/神秘 10/部队 5/属性 15；家里：现金 45/大现金 15/经验 10/神秘 10/部队 5/属性 15（治疗箱只在中央）；写 0 就关掉那种（docs/07 §5）|
| 卡池内容 / 各档权重 | 别手改 `gen_pool.lua`（生成物）；改 `tools/build-pool.js` | 权重合计必须是 100 |
| 截获后等几帧再结算 | `10_puredraw_data.lua` 的 `CHOUKA_BATCH_FRAMES` | 引擎同帧出一整批，等太少只收到第一个 |
| 自定义抽卡概率 | `10_puredraw_data.lua` 的 `CHOUKA_CUSTOM_CHANCE` | 100 = 全部自定义（当前）；调小就是"有概率保留原版结果" |
| 左下角两行文字 | `20_hud.lua` 顶部 `CHOUKA_HUD_TEXT_X` / `CHOUKA_HUD_ROUND_Y` / `CHOUKA_HUD_COUNTDOWN_Y` / `*_COLOR` / `CHOUKA_HUD_TEXT_SIZE` | `AlignY="bottom"` 时 Y 从底边往上量；颜色是十进制 RGB（黄 `16776960`、橙 `16744448`） |
| 卡池内容 / 阵营归属 / 水陆类别 | 别手改 `gen_pool.lua`；改 `tools/build-pool.js`（`USER_POOL` 作者清单、`AMPHIBIOUS` 两栖名单、`TIER_WEIGHTS` 权重）和 `tools/pool-alias.js`（中文名→类型名） | 改完跑 `node tools/build-pool.js && node tools/sync-scriptsdata.js`，生成器会把没翻译出来的名字全部打印出来 |
| 对玩家显示的文本 | **集中在 `scripts/lua/chouka/01_texts.lua`（`ChoukaT` 表，35 条）**，代码里只写 `ChoukaT.<key>` | 它被拼进**每个节点**的 payload 公共前缀（和 `00_alert.lua` 一样），任何节点都能直接用 |
| 日志文案（`_LOG`） | **就地写在业务代码里，不进文案表** | 作者要求"玩家的"和"开发的"分开，混在一起不好认（docs/08 §7.6） |
| lua 里的注释 | 只写 1~3 行的短注释指路；**超过 3 行的纯说明搬到 `docs/10-Lua注释存档.md`** | payload 是把 lua 原文逐字节拼进 JSON 的，注释一样占节点体积（单节点上限 64 KB）。跑 `node tools/extract-comments.js` 自动搬（会校验代码指纹，误删代码会直接中止） |
| 抽卡剔除哪些单位 | `tools/build-pool.js` 的 `BLACKLIST` | 默认剔除基地车/矿车/工程师等"不能打架"的单位；**四家基地车全都不进 T1~T4** |
| 只在某一档出现的单位 | `tools/build-pool.js` 的 `TIER_PIN` | 现在只有一条：`CelestialMCV`（青龙战斗核心舰，本质是 T5 单位）只留在 **T5**，以前它跟着「各国基地车」被塞进神州 T1，导致抽卡会抽到基地车 |
| 要解锁哪些科技协议 | `tools/build-upgrades.js` 的三个来源清单 / 末尾 `DENY` | 改完跑 `node tools/build-upgrades.js && node tools/sync-scriptsdata.js` |
| 界面刷新频率 | 节点 `抽卡hex/HUD` 的 `EvaluationInterval` | 现在是 1（≈1 秒）；改 0 会每帧刷，没必要 |
| 回合口径 | `02_private_box.lua` 末尾的 `CHOUKA_ROUND` 自增 | 作者定稿：**刷一轮箱子 = 1 回合** |

## 7 风险与验证清单

1. **`ALLOW_DISALLOW_ALL_BUILDINGS` 可能要回退**：脚本目录里它被归类为 *Unused or Obsolete*。
   进游戏后先按住 F 看能不能拉出建造栏：
   - 拉不出来 → 成功，起重机已是"不可建造"；
   - 还能造 → 退回逐建筑禁用 `ALLOW_DISALLOW_ONE_BUILDING(player, 建筑类型, 0)`，
     名单我可以按编辑器物体库（`object-catalog.json` 里 774 个 STRUCTURE）＋日冕增量生成一份 lua。
2. **`moneycrate` 是否存在于日冕**：盲盒高原（同为 cor 图）用的就是 `moneycrate` / `unitcratenew`，
   大概率可用；若开箱不给钱，换 `unitcratenew` 或日冕自己的金钱箱类名。
3. **`EvaluationInterval` 单位 ≈ 秒**（DSA 文档口径："每约 1 秒由 EvaluationInterval=1 的触发器调用"）。
   首次进游戏看倒计时是否约 120 秒，对不上就把它当"帧"重新折算。
4. **比较枚举**：`4` = ">"，`2` = "="（原图 `Money` 用 4，`View Lost` 用 2 判"=0 座建造场"）。
   若油井加成不生效，先怀疑这一条。
5. **起重机已被作者改成可摧毁**（实测：摧毁 = 该玩家直接判负），所以"拆起重机断收入"这条不用再防。
   ⚠️ 但要注意：`power1~6` 是 `objectIndestructible = true` 的界外隐形电厂，理论上会让玩家在失去起重机后仍不被消灭。
   既然实测已经判负，说明这条链路上不构成存活物；**将来若又想保留不可摧毁的电厂，务必复测"拆起重机是否仍然判负"**。
6. **AI 玩家**：禁建造对 AI 同样生效，AI 会呆在原地不做事 —— 本图建议只开真人局。
7. **箱子不会堆了**：`02_private_box.lua` 每轮先按点位半径 35（世界单位）搜一遍，已有箱子就跳过。
   两个点相距约 70 单位，半径别调大，否则会互相误判成"占用"。

## 8 Lua 桥的硬约束（DSA 踩过的坑，别踩第二遍）

- payload 必须以 `#!ra3luabridge` 开头，正文用 **CRLF**；单条 **≤ 64 KB**。
- **绝对不许有 UTF-8 BOM（EF BB BF）** —— 2026-10 实测量到的头号杀手：
  Windows PowerShell 的 `Set-Content -Encoding utf8`（PS 5.1）会**自动写 BOM**，
  BOM 拼进 payload 后落在 `#!ra3luabridge` 之后，Lua 4.0 把 `EF BB BF` 当非法 token
  → **整个节点的 payload 解析失败 → 该节点静默不执行**，游戏里不报错、不弹窗、什么都不发生。
  一晚上一次废掉 10 个节点（开局公告/房主配置/私有箱/中央油井/按钮栏/AI/帧循环全没了，
  只有没被 BOM 污染的收入/解锁科技/发技能/HUD 还活着）。
  防线：① `tools/sync-scriptsdata.js` 读到 BOM 直接报错拦下；② 用 `node .dsh-tools/scratch/strip_bom.js`
  批量去 BOM；③ **改 Lua 一律用 Node 脚本或编辑器存「UTF-8 无 BOM」，不要用 PowerShell `Set-Content`**。
- 只能写 **Lua 4.0**：没有 `#t`（用 `getn(t)`）、没有 `string.format`（用全局 `format`）、
  字符串不能 `s:sub()`、泛型 `for` 必须写两个变量。
- **闭包拿不到外层的 local**：需要跨调用保留的状态一律挂全局表。
- 注释会原样进 payload、占 64 KB 预算（但注释不影响执行）。
- `lua/*.lua` 是文档与真源，`ScriptsData.json` 永远是生成物 —— 不要手改 JSON 里的 payload。
- 排错第一现场：`E:\CoronaLauncher\CoronaData\Logs\EnhancerCorona-<时间>.dll.log`（`exPrintln` 的去处），
  配合 `抽卡hex/自检` 节点的心跳行与各节点的「节点就绪：xxx」标记，能直接看出哪个节点没跑（见 §9.5）。

## 9 抽卡系统与 HUD（照搬 DSA）

完整推导见 `08-抽卡移植方案-PureDraw.md` 与 `09-HUD移植方案.md`，这里只记落地口径。

### 9.1 抽卡链路

```
玩家点「幸运单位箱」技能（日冕定价 2480/抽）
   → 箱子里生成 LuckyUnitCrateSeed（可拾取物件）
   → 玩家单位走过去拾取
   → 引擎在 mod 侧随机、直接生成**一整批**同型单位   ← 随机发生在引擎侧，Lua 拿不到决策
   → 我们的 onUnitCreateEvent 收到这批结果单位的出生事件（逐个收进"这一抽"的批次）
   → 等 3 帧让整批落地 → **只删出生事件收上来的那些 id**（不按半径扫场）→ 在自己队伍生成 **1 个**卡池单位
```

- 钩子：`exObjectRegisterCreateEvent(类型名)` + 全局函数 `onUnitCreateEvent(id, 模板名哈希, 玩家名)`
  （入口名与 DSA 一致，不能改名）。
- 卡池：`gen_pool.lua`，**135 种 / 五档**，权重 **37 / 50 / 10 / 2.5 / 0.5**，由 `tools/build-pool.js`
  按作者《完整单位表》生成（见下面"卡池构成"）。
- **每次只出 1 个**：卡池条目只剩类型名，没有 `CustomDrawCount` 字段 —— 原逻辑
  `spawnCount = info.CustomDrawCount or 1`，没字段就是 1。
- **全部自定义**：`10_puredraw_data.lua` 的 `CHOUKA_CUSTOM_CHANCE = 100`（0~100，按"一抽"掷一次）。
  100 = 原版结果必定转成自定义单位，不做半保留。
- **按阵营分池**：`gen_pool.lua` 里 `ChoukaDrawPoolBySide[1..4]` 各一份
  （盟军 36 / 苏联 40 / 升阳 26 / 神州 33，共 135 种），抽卡时按玩家阵营只在自己那份里抽。
  阵营探测照 DSA 的 `GAME/PlayerSide.lua`：`PLAYER_HAS_PLAYER_TECH` 查四个基础科技，
  但**放在首次抽卡时**做并缓存（第 0 帧科技树还没就绪，会全部误判成盟军）。
- **卡池构成**：以作者给的《完整单位表》为唯一真源（T1~T5，每档再按 **步兵｜载具｜空军｜海军** 分组），
  由 `tools/build-pool.js` 生成。中文名→类型名靠两份字典自动反查：
  `日冕地图lua例子/自定义抽卡池.txt`（作者抽卡池表，含精确类型名）与 DSA `HextechRune/05_ultimate_creature.lua`
  的 `NonProductionUnitTier` 注释；剩下的简称走 `tools/pool-alias.js`（每一条都用 `日冕单位信息汇总.txt` 的地编 ID 核对过）。
  五档权重 **37 / 50 / 10 / 2.5 / 0.5**（合计 100）；**T5 在本图是独立档**，不并入 T4，
  里面放超阶单位：青龙战斗核心舰、奥林匹斯级航空母舰、千鸟特攻母舰、东风洲际导弹发射车、大型维修天灯。
  每个条目都是 1 个。
  当前共 135 种：盟军 36 / 苏联 40 / 升阳 26 / 神州 33。
  不能打架的单位一律剔除（作者要求）：基地车（`AlliedMCV`/`SovietMCV`/`JapanMCV`）、
  采矿车、工程师、神州礼炮、神州军用叉车、民用气象飞艇、史普尼克勘查车。
  **龙船 `CelestialMCV`（青龙战斗核心舰）保留** —— 它是这些"非战斗单位"里唯一能打的；
  **维修天灯三个形态都保留，分别落在 T3 / T4 / T5**：
  小型 `CelestialEngineerRepairDrone`（T3）、中型 `...Lv2`（T4）、大型 `...Lv3`（T5）。
- **科技协议全解锁**：玩家不能造建筑，协议面板也进不去，所以开局直接把全部 34 条协议发给
  `<All Players>`（`ExecuteAction("GIVE_PLAYER_UPGRADE", "<All Players>", name)`，机制照
  双兵种 `Troop Selection/initialization.lua:126`）。名单由 `tools/build-upgrades.js` 合并三处：
  双兵种 `Tech_Upgrade` + `Enhanced_Tech_Upgrade`、DSA `lua/Upgrade.lua` 的 `upgrades`、
  双兵种 `lib/enums/UpgradeEnum.lua` 全量枚举。**含龙船全套 7 条**
  （`Upgrade_CelestialDragonShip_` 的 AAWeapons/AAWeapons02/AAWeapons03/MainWeapons/
  MissileWeapons/MissileWeapons02/PlasmaWeapons），对应自走棋"龙行天下"召唤的满科技龙船。
- **水陆适配（箱子落点在海里还是地上）**：`ChoukaUnitCategory` 给每个类型打了类别
  （1步兵 2载具 3空军 4海军 5两栖），抽卡时先判落点水陆再在该档里筛：
  海军只在水面出、步兵/载具只在陆地产、空军与两栖两边都能出（见 `ChoukaCategoryAllowed`）。
  **水陆判定（最终口径：直接查"从地图里提取的死数据掩码"，运行时不再猜）**：
  ① 数据来源：地图自带的预览图 `[cor]每人一小块地抽卡hex.tga`（实为 PNG，610×610），
     **蓝色 `rgb(68,94,106)` = 海**，其余 = 陆地；世界坐标↔图像素用预览图里 6 个出生点圆点
     对齐 `map.xml` 的 `Player_N_Start` 最小二乘拟合（`px = -0.90 + 0.09991x`，
     `py = 604.57 - 0.1y`，残差 < 1 像素）。
  ② 掩码产物：`chouka/09a_watermask.lua`（153×153 格、每格 40 世界单位、按行存陆地区间），
     由 `tools/build-watermask.js` 生成；换地图/改地形重跑它 + `sync-scriptsdata.js` 即可。
  ③ 运行时：`ChoukaTerrainAt(x, y)` → `ChoukaMaskIsWater(x, y)` 查表，返回 1=水 / 0=陆；
     水 → 只抽海军（+ 空军/两栖），陆 → 只抽步兵/载具（+ 空军/两栖）。
     **不做地形兜底**：生成失败只在同地形里换类型重试，绝不换地形、也不拿空军凑数。
  ④ 生成海军时把 z 抬到 `CHOUKA_WATER_SURFACE_Z`：这个"水面高度"是**第一次看到原生海军结果时
     从它的 z 自动学下来的**，不写死。
  离线验证过 21 个点位（6 出生点 + 中央 + 油井 + 上次日志抽卡点 应陆；四角/四面外海/岛间 应海），全通过。
  某档在当前地形下一个可选单位都没有时，自动摊到别的档，不会空抽。
- **不误伤旧单位**（实测修正）：首版照 DSA 用"半径 260 扫场删批"，在本图这种一小块地上会把玩家
  旁边的同类旧单位一起吞掉。现在删除目标**只来自出生事件收上来的 id**，旧单位不在集合里，永远碰不到。
- 白名单：`10_puredraw_data.lua` 的 `ChoukaAlwaysKnownTypes`（工程师 + 各型 MCV）。
  **日冕的协议/技能召唤物也没有生产者**，若实测发现被误删，把类型名加进这张表即可。
- 技能发放：`14_grant_draw.lua` 发**两个** —— `SpecialPower_LuckyUnitCrate`（单抽）和
  `SpecialPower_LuckyUnitCrateX10`（十连），十连不另写逻辑：**原生结果几个就补几个**（上限 10）。
  注意 `PLAYER_GRANT_SPECIAL_POWER` 的参数顺序是**（技能名, 玩家）**，与多数 `PLAYER_*` 动作相反。
- **抽卡范围可配**：`CHOUKA_DRAW_SCOPE`（开局房主配置页写入）= 0 全部阵营（默认，配置页第 1 项）/ 1 只有自己阵营（第 2 项）；
  0 时用 `ChoukaAllSidePool(tier)` 把四阵营同档合并（T5 仍是共用表）。

### 9.2 抽卡等级 / 概率 / 交易市场

- **等级表**在 `09_level.lua`：等级 1~8，每级一张概率表（`ChoukaLevelWeights`）、
  升级价格（`ChoukaLevelPrice`：**Lv1 开局自带 / 1000 / 2000 / 5000 / 10000 / 20000 / 50000 / 50000**，作者 2026-10 定稿）、
  自动升级回合（`ChoukaAutoLevelRound`：第 5 / 10 / 15 / 20 回合 → Lv.2 / 3 / 4 / 5；Lv6~8 只能买）。
  概率表（T1~T5，%）：
  Lv1 100/0/0/0/0、Lv2 90/10、Lv3 75/25、Lv4 55/30/15、Lv5 45/33/20/2、
  Lv6 30/40/25/5、Lv7 16/30/43/10/1、Lv8 15/20/34/30/1。
- 抽卡时 `ChoukaChooseUnit` 先按**当前等级的概率表**掷档，再档内均匀取，再按阵营 + 水陆收窄。
- **等级是全场共用的一个进度**（这张图只有 6 个小格，做成公共进度；任何人买都会推进全场）。
- **交易市场**（顶部按钮 3）里两项：`购买等级`（按 `ChoukaLevelPrice` 扣钱升级）、
  `购买防御塔`（`ChoukaTowerPriceByTier` 扣钱：**T1 ￥500 / T2 ￥2000 / T3 ￥7500 / T4 ￥20000**，
  在自家 `towerN1~towerN4` 生成随机塔；塔池见 `16_buttons.lua` 的 `ChoukaTowerPoolByTier`）。
- **【已关闭·备用】购买神州机场1200**：代码整套留着，开关是 `16_buttons.lua` 的
  `CHOUKA_AIRPORT_ENABLED`（默认 **0 = 不显示入口**）。关闭原因（作者实测后定）：
  ① 本图没禁用空军建造栏 → 机场能直接造飞机，不符合"抽卡出单位"的设计；
  ② 飞机弹药已由「每回合自动补满弹药」解决（见 §9.3），不需要机场了。
  想重开就把它改成 1 —— 入口、购买流程、六条文案、占位判定都还是现成的
  （`CHOUKA_AIRPORT_PRICE` = 1200，在自家 `airportN` 航点生成 `CelestialAirfield`）。
  机场有三道闸：**没这个航点** → 提示补航点；**点位上已有神州机场**（台账 + 按类型名 `ObjectFindObjects` 扫 200 半径）
  → 拒绝、不扣钱；**钱不够** → 提示。生成失败自动退款（和防御塔同一套写法）。
  扣钱用 `PLAYER_GIVE_MONEY` 的**负值**（动作表里没有 TAKE_MONEY，GIVE 的中文说明就是"增加或减少"）；
  余额用 `exPlayerGetCurrentMoney` 查。
- **建筑怎么生成**（照 `DSA_ggz自走棋/lua/GAME/GiveFreeStructure__2.lua` 的现成写法）：
  ````lua
  ExecuteAction("CREATE_NAMED_ON_TEAM_AT_WAYPOINT_WITH_ORIENTATION",
      "ChoukaAirport_1_1", "CelestialAirfield", "Player_1/teamPlayer_1", "airport1", -3.1415926/4)
  ````
  生成前用 `GetNextObjectId()` 先把这个 id 记进 `ChoukaScriptCreated`，免得新建筑触发
  `onUnitCreateEvent` 被抽卡系统当成"原版结果"拦走（和 `ChoukaTrySpawnOne` 同一套防呆）。
- **按钮栏 API**（以 `教程.lua:284-332` 为准，**不是** DSA 内部那套名字）：
  `exCenterTopBtnsChangeVisibilityForPlayer(玩家, 1)` 开区域、
  `exCenterTopBtnShowForPlayer(玩家, 序号, textureName, desc)`、
  `exCenterTopBtnSetEnableForPlayer(玩家, 序号, 0/1)`；
  点击回调**固定名** `onCenterTopBtnClickEvent(playerName, btnIndex)`。
  ⚠ 教程原文：`Show` 之后要**等 1 或 2 帧**才能调其它 ui 函数 —— 所以启用放在节点下一次求值
  （`ChoukaBtnStage` 0→1→2），节点不能设"成功即停用"。
  对话框 `exShowCustomBtnChoiceDialogForPlayer(玩家, 对话框ID, 标题, 选项1..7)`（**固定 10 个参数**，
  用 `call(函数, {参数表})` 传）、选择回调 `onUserBtnChoiceDialogEvent(playerName, btnIndex, dialogId)`。
  图标 ID：交易市场 `Button_PlayerPower_FreeTrade`、海克斯 `Button_SovietChiefScientist`。

### 9.3 每回合给飞机补满弹药（`02_private_box.lua`）

作者要求：**每回合开始给所有飞机补满弹药，不要播报**（播报太多会刷屏，所以只写日志）。

- 时机：`02_private_box.lua` 的回合推进里，刷完箱子 + 播报「第 N 回合开始」**之后**调 `ChoukaRefillAircraftAmmo()`。
  放在最后是有意的：这个接口万一报错，也挡不住上面已经做完的刷箱、回合数 +1 和播报。
- 接口（《日冕 Lua.lua》[[34]]「获取以及设置单位武器的弹药量」）：

  ````lua
  -- 参数：单位, WeaponSlot 的 ID, 武器 Ordering, 该 Ordering 里的武器序号
  ObjectGetWeaponSetUpdateWeaponMaxAmmoCount(obj, slot, ord, idx)      -- 最大弹药量
  ObjectSetWeaponSetUpdateWeaponCurrentAmmoCount(obj, slot, ord, idx, n) -- 设成 n
  ````

  Ordering：`PRIMARY=1 SECONDARY=2 TERTIARY=3 QUATERNARY=4 QUINARY=5`；
  ⚠ **「WeaponSlot 的 ID」不是槽位序号**。按《日冕 Lua.lua》的维护者轰炸机例子，飞机武器都在 `ID=1` 的槽里、
  同一 Ordering 下有 6 个武器（序号 1~6），所以默认扫：槽 1~2 × Ordering 1~5 × 序号 1~6。
- 找飞机：`CreateObjectFilter({ Rule="ANY", Relationship="ENEMIES NEUTRAL ALLIES", Include="AIRCRAFT" })`
  + `ObjectFindObjects(nil, { X=0,Y=0,Z=0, Radius=20000, DistType="EXTENTS_3D" }, 过滤器)`，一次抓全图。
  抄的是《LUA封装宝典》`SetAmmoForUnits` / 日冕 BUFF 的 `IncludeThing` 用法。
- 补法：先取**最大弹药量**，`> 0` 才把当前弹药设成最大值（没有弹药概念的武器/挂点直接跳过）。
  **不猜固定数值**——写死一个 999 会让只有 2 发的轰炸机能连投 999 颗。
- 调参（都在 `02_private_box.lua` 开头）：

| 常量 | 默认 | 含义 |
|---|---|---|
| `CHOUKA_AMMO_REFILL` | 1 | 1 = 每回合补满；改 0 整个关掉 |
| `CHOUKA_AMMO_SLOTS` | 2 | 扫几个 WeaponSlot（ID 1~2；飞机一般只用 1）|
| `CHOUKA_AMMO_ORDERS` | 5 | PRIMARY~QUINARY |
| `CHOUKA_AMMO_INDEX` | 6 | 每个 Ordering 里最多几个武器 |
| `CHOUKA_AMMO_RADIUS` | 20000 | 找飞机的半径（够包住整张图）|

- 日志（只在日志文件，不进游戏界面）：`补弹药：第3回合，飞机 4 架，补满武器 8 处`；
  场上没飞机时写 `补弹药：第3回合，场上没有飞机`；mod 没这个函数时写一行"跳过"。
- 未实测点：`Include="AIRCRAFT"` 与 `ObjectGetWeaponSetUpdateWeaponMaxAmmoCount` 在**本 mod 版本**下是否都可用。
  如果日志里一直写"场上没有飞机"但其实有飞机在飞 → 说明过滤器没匹配上，改成 `IncludeThing = { 具体飞机类型名 }` 列表；
  如果日志里出现 Lua 报错 → 把报错发我，说明该 mod 的 WeaponSetUpdate 组件接口不一样。

### 9.4 HUD

> ⚠ **2026-10 实测修正**：旧版 HUD 用的是 `exCreateCustomText` / `exCustomTextUpdateText`，
> 日冕这个 mod **没有这两个函数**（`教程.lua` 的 API 表里只有 `*ForPlayer` 版本），
> 一调用就报错，而 `ChoukaHudReady` 又在建文字**之前**就置了 1 → 整个 HUD 永远不再重试，
> 左下角一行字都没有。现在的写法见下（细节见 `docs/08 §三①`）。

| 位置 | 手段 | 内容 |
|---|---|---|
| 右上角 | 引擎**计分板** `exScoreBoardSetVisibility(1)` + `exScoreBoardSetTitle` + `exScoreBoardSetText(文本, 行, 列)`（教程里就有的老 API，最稳） | 行 1~6：`$p1Name:`…`$p6Name:` + 场上单位数（列 2）；行 7 回合；行 8 倒计时；行 9 抽卡等级；行 10 各档概率 |
| 左下角 | 逐玩家自绘文字 `exCreateCustomTextForPlayer(playerName, {Index, Content, X, Y, Color, Size, AlignX="left", AlignY="bottom", GroupIndex=1})`，之后每秒 `exCustomTextUpdateTextForPlayer(playerName, Index, 文本)` 原地改（照 `目标血条UI显示模板.lua:119/151/159`） | 四行：`回合数：3`（亮黄）/ `盲盒刷新倒计时：01:47`（亮橙 mm:ss）/ `抽卡等级：Lv.3`（青）/ `T1 75% T2 25% …`（绿），字号 12 |

- 文案格式照 DSA 升本模式那一套"名称：值"（DSA 是 `下一回合开始：xxx` / `最大电厂数量：x`）。
- 只给**真人**玩家建文字（`EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", "Player_N", "Human")`），AI 座位没有客户端。
- 每个 `ex*` 调用都套 `type(...) == "function"`；哪个玩家建失败就下秒重试，不会因为一次失败永久废掉。
- 回合数来源 `CHOUKA_ROUND`（私有箱每轮 +1）；倒计时用**我们自己数的秒** `CHOUKA_BOX_LEFT`
  （`00_init` / `02_private_box` 置成 `BOX_SECONDS`，`02_private_box` 每秒减 1，HUD 只读）。
  ⚠ 实测：`exCounterGetByName("box")` 读 `SET_MILLISECOND_TIMER` 建的计时器**恒为 0**，这条路已废弃。
- 左下角文字位置是 `20_hud.lua` 顶部的 `CHOUKA_HUD_TEXT_X` / `CHOUKA_HUD_*_Y`（屏幕坐标按 1024x768 估，
  `AlignY="bottom"` 时 Y 越大越靠上，默认 690/664/638/612）。**这套坐标还没实测过**：位置偏了就调这几个数。
- 引擎自带的倒计时控件（`00_init.lua` 里的 `DISPLAY_COUNTDOWN_TIMER("box","SCRIPT:box")`）用的是 `map.str` 里的 `SCRIPT:box` 文案，
  **已经补上**（`下一次盲盒` / `Next crate`）。计分板与自绘文字写中文是直接写字面量，不需要动 `map.str`。
- 单位数口径：以 `craneN` 当"本方锚点"（`ObjectFindObjects` 第一参数传任意物体，过滤器 `Relationship="SAME_PLAYER"` 按它的主人算），
  过滤 `Include="SELECTABLE"` / `Exclude="STRUCTURE"`，并排除各类箱子。

### 9.5 排错：日志怎么看（`00_alert.lua`）

所有节点构建时都会在最前面拼上 `00_alert.lua`，它提供三个东西：

| 函数 | 干什么 | 玩家能看到吗 |
|---|---|---|
| `_LOG(msg)` | 只写日志文件（节点自检 / 心跳 / 节点就绪，不刷屏） | ❌ 只在日志里 |
| `_ALERT(msg)` | 三路全打：日志 + 左下角消息区 `exMessageAppendToMessageArea` + 公屏 `exAddTextToPublicBoard(msg,10)` | ✅ |
| `ChoukaMarkNodeReady("节点名")` | 每个节点 payload 跑到就记一次，写进日志 | ❌ 只在日志里 |

**日志文件**：`E:\CoronaLauncher\CoronaData\Logs\EnhancerCorona-<日期时间>.dll.log`（`教程.lua:29-30` 写明的官方通道，
`exPrintln` 的输出去处）。每次开一局会新生成一个，取最新那个看。

日志里能看到：

```
[抽卡hex] 节点就绪：自检
[抽卡hex] 节点就绪：开局
[抽卡hex] 心跳 tick=1 started=0 round=nil boxLeft=nil lv=nil hud=no 节点就绪=自检,开局
[抽卡hex] 心跳 tick=10 started=1 round=0 boxLeft=118 lv=1 hud=yes 节点就绪=自检,开局,随机箱清理,…
```

- 「节点就绪」里**没列出来**的节点 = payload 跑都没跑起来（或一进去就报错），就是断点。
- 「心跳」每 10 秒一行，看 `round` / `boxLeft` 有没有在动就能判断回合系统活没活。


### 9.6 电脑对手（AI）

参考 DSA 自走棋 `lua/GAME/PureDraw/04_draw.lua:495 PureDrawJoinAIAttackTeam` 与 `DEFAULTATTCKTEAM`，
新增独立节点 `抽卡hex/AI对手`（`17_ai.lua`，1 秒节点，常驻）。它干两件事：

**① 电脑在抽卡（模拟）**：每回合给每个电脑座位免费抽卡 ——

| 回合 | 每个电脑每回合抽几个 | 概率表 |
|---|---|---|
| 0~4 | 1 个 | Lv.1（100% T1） |
| 5~9 | 2 个 | Lv.2（90/10） |
| 10~14 | 3 个 | Lv.3（75/25） |
| 15~19 | 4 个 | Lv.4（55/30/15） |
| 20+ | 5 个 | Lv.5（45/33/20/2） |

- 数量公式：`1 + floor(回合 / 5)`，上限 `CHOUKA_AI_DRAW_MAX = 5`
  （和"自动升级到 Lv.5 封顶"对齐；想不封顶就把常量改大）。
- **每个单位都独立掷点**，所以同一回合这 X 个各是随机的；走的是和玩家完全同一套
  `ChoukaSpawnUnit` → 卡池（阵营池/全部阵营由房主配置决定）→ 水陆判定 → 落点散开。
- 概率取**自动升级**那条线（`ChoukaAutoLevelForRound`，第 5/10/15/20 回合升到 2/3/4/5 级），
  **不跟玩家花钱买的等级挂钩** —— 玩家买等级不会顺带把电脑喂强（`ChoukaChooseUnit` 多了个可选 `level` 参数就是为这个）。
- 落点：`Player_N_Start`（读不到就用 `craneN`），按序号在小圆环上散开，避免叠在一个点。
- 电脑抽到的单位**照规矩先登记 `ChoukaScriptCreated`**，所以不会被抽卡钩子当成"原生结果"删掉。

**② AI 攻击队列（中立单位会咬人）**：

- 每 5 秒扫全场（以航点 `center` 为圆心、半径 8000，覆盖全图；过滤 `Include="SELECTABLE"`、
  `Exclude="STRUCTURE"`，并剔掉钱箱/抽卡箱），凡是**非玩家阵营**（`ObjectPlayerScriptName` 不是
  `Player_1~6`，即 `PlyrCivilian` / `PlyrCreeps` 之类）的单位，
  就 `ExecuteAction("UNIT_SET_TEAM", unit, "<阵营名>/ATTACK")` —— 和 DSA 的
  `DEFAULTATTCKTEAM[7]="PlyrCivilian/ATTACK"`、`[8]="PlyrCreeps/ATTACK"` 是同一个机制：
  引擎把 `ATTACK` 队当成进攻部队，于是这些原本站着不动的中立单位会主动来打玩家。
- 已经处理过的对象 id 记在 `ChoukaAIJoinedIds`，不会每轮重复 `SET_TEAM`。
- `CHOUKA_AI_NEUTRAL_LEVELUP = 1` 时还会按自动等级给它们升星（DSA 也这么干），默认关。
- **电脑自己的兵不塞 ATTACK 队**：电脑座位本来就有引擎 AI 指挥、会自动进攻；
  真遇到"电脑只挨打不还手"，把 `CHOUKA_AI_FORCE_PLAYER_ATTACK` 改成 1。

**电脑座位怎么认**（`ChoukaAIIsComputer`）：

1. 作者可在 `17_ai.lua` 文件头写死 `CHOUKA_AI_SLOTS = { [2]=1, [4]=1 }`（最稳，推荐用于正式对局）；
2. 否则问引擎：`EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", "Player_N", "Human")` 为真 → 真人；
3. 再问一次参数 `"AI"`（支持就直接采信）；
4. 万一这个参数不被支持，退回"非人类 + `craneN` 活着 + `exPlayerGetCurrentMoney` 读得到钱"
   （空座位读不到钱，所以不会给空座位凭空刷兵）。

诊断播报（`CHOUKA_AI_DEBUG = 1` 时，定位完改 0）：

```
AI对手：人格参数"AI"不可用，改用"非人类 + 有起重机 + 有钱"判定电脑
AI对手：Player_2 是电脑，将每回合自动抽 1 个单位
AI对手：第5回合，每个电脑抽 2 个（合计 2 个，概率按 Lv.2）
AI攻击队列：3 个非玩家阵营单位已加入攻击队
```

⚠ 顺序上"免费抽卡"写在"扫场入队"**前面**：扫描那段万一报错（过滤器写法/API 不支持），
电脑抽卡也照样工作 —— 这是"中央钱箱被占点代码拖死"那次的教训（docs/08 §二③）。

### 9.7 导入后的验证顺序

0. **先验开局流程**（docs/06 §3 + docs/08 §7 有逐条清单）：锁视角→公告→中心黄字→房主配置（两个二选一，无资金档）→确认后回出生点、解锁、倒计时起步。
1. **再验箱子还在不在**：**开局后** 120 秒各点位应出现金钱箱，点位已有箱时下一轮不叠加。
   （注意：不是"进游戏 120 秒"，开局时间点以房主点确认为准。）
2. **验中央**：`center1~6` 每回合各刷 1 个钱箱且不叠加；站兵 15 秒左右能占下中央两座油井（公屏播报）。
3. **验界面**：右上角计分板常驻、六行单位数会变；左下角文字每秒钟跳。
4. **验抽卡能不能开**：顶部应有**单抽 + 十连两个**技能按钮 → 场上出现可拾取箱子 → 派单位去捡。
5. **验截获**：单抽捡完后场上应该**只有 1 个**卡池单位；十连捡完后是 **10 个**，没有原版那一批残留。
6. **验误删**：故意在旁边放一个同类型的自造单位，确认它没被删（有生产者就会被排除）。
7. **验建造栏**：开一局看侧边建造栏是否整条被关掉；起重机的**回收功能必须还能用**。
8. **验阵营**：什么都不点（默认「箱子包括全部阵营」）→ 确认四阵营的单位都可能出现；
   再点第 2 项「抽卡只有自己阵营」→ 四个阵营各开一局（或四个玩家混编），确认抽出来的单位都属于各自阵营。
9. **验水陆**：在陆地上抽几发，确认不出船；**用船在海上抽几发，确认出的是海上单位**（空军、两栖例外）。
10. **验电脑**：带一个电脑开一局 → 公屏应出现 `Player_N 是电脑`；每回合结束电脑家里会自己冒出单位
    （第 1 回合 1 个，第 5 回合起 2 个……公屏有 `每个电脑抽 N 个` 的播报）；电脑的兵会主动来打你。
    地图上若有中立单位，出现 `AI攻击队列：N 个非玩家阵营单位已加入攻击队` 后它们也会来咬人。

已修掉的实测问题（别再改回去）：
- `exWaypointGetPos` 返回**数组**（`p[1]/p[2]/p[3]`）。写成 `p.X` 会让"私有箱"整个脚本抛错中断，
  表现是"倒计时走完不刷箱子、回合数也不加"。
- `exCounterGetByName("box")` 读 `SET_MILLISECOND_TIMER` 建的计时器**恒为 0**，倒计时改成自己数秒。
- `ALLOW_DISALLOW_ALL_BUILDINGS` 是空操作（动作表里属 "Unused or Obsolete"），改用
  `PLAYER_DISABLE_BASE_CONSTRUCTION`。
- 半径 260 扫场删批会吞掉附近同类旧单位，改成只删出生事件收上来的 id。
- 中央油井**就叫** `centerOil1` / `centerOil2`（作者 2026-10 实测；docs/02 曾误记成"两座都叫 `Center2`"）：
  所以按真名取，拿不到才退回"离 `center` 250 内的 `OilDerrick`"（docs/08 §二①）。
- 中央钱箱的刷箱代码必须排在占点代码**前面**：占点里任何一句报错都会中断整个节点，
  连带钱箱也不刷（docs/08 §二③）。
- 水陆判定先后试过"单地形高度""四路正票 + 空军/两栖兜底""箱子位置 + 采样校准水位"，都不稳（水底与陆地高度体系连通、箱子浮在水面）。最终定稿为**地图掩码查表**（数据从地图预览图的蓝色区域提取），详见 §9；并修掉"船生成在海床上失败"和坑（docs/08 §二④）。

⚠ 两处仍是**未实测**的推断，进游戏第一件事请核对：
- `LuckyUnitCrateSeed` 在日冕当前版本是否仍可拾取（DSA 是同 mod 的图，理论上一样）；
- `EvaluationInterval` 到底是"秒"还是"帧"（DSA 内部说法不一致）。若发现收入/界面跳得比预期快 15 倍，
  就把 `抽卡hex/收入`、`抽卡hex/HUD` 的 interval 从 1 改成 15。
