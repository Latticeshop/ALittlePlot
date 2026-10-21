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
| 抽卡阵营 | **每人只抽自己阵营的单位** | 卡池按阵营切成四份：盟军 36 / 苏联 40 / 升阳 26 / 神州 33（共 135 种，按作者《完整单位表》T1~T5，**T5 在本图是独立档**）；阵营用 `PLAYER_HAS_PLAYER_TECH` 在首次抽卡时探测（第 0 帧探测会全判成盟军） |
| 水陆适配 | **陆地不刷船、水里不刷陆地单位** | 每个类型带类别（步/载/空/海/两栖），落点地形用 `exTerrainGetHeightByPos` 判（≤0.5 视为水面）；空军与两栖不受限 |
| 视野 | **开局全图常亮** | `MAP_REVEAL_ALL_PERM`（盲盒高原同款） |
| 电力 | **无限** | `PLAYER_SET_BASE_POWER = 100000`（虚空电力，不依赖电厂） |
| 建造 | **禁止** | ~~`ALLOW_DISALLOW_ALL_BUILDINGS = 0`~~ → 已改为 `PLAYER_DISABLE_BASE_CONSTRUCTION`（见上表第 2 行） |
| 收入 | **双轨：底薪 + 油井** | 底薪 40 + 油井 20 = 60 元/秒（≈41 秒够一次 2480 的日冕抽卡） |
| 箱子 | **只做私有箱，且不重复刷** | 每人 `boxN1` / `boxN2` 各一个 `moneycrate`，120 秒一轮；点位半径 35 内已有箱子就跳过 |
| 中央岛 `center` / `center1~6` | 本轮**先不刷** | 点位已就位，等中央争夺玩法定了再加 |

## 2 九个脚本节点

| 节点 | EvaluationInterval | 一次性 | 条件 | 做什么 | 源文件 |
|---|---|---|---|---|---|
| `抽卡hex/初始化` | 0（每帧） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 抽卡等级表、全图常亮、基础电力、关闭建造栏、开局资金 **5096（=2 抽，直接 SET）**、箱子倒计时 | `09_level.lua` + `00_init.lua` |
| `抽卡hex/收入` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 底薪 + 油井加成，顺手重设电力 | `01_income.lua` |
| `抽卡hex/私有箱` | 120（≈120 秒） | ❌ 常驻 | `CONDITION_TRUE` | 每人两个点位各刷一个金钱箱（点位已有箱子就跳过）+ 重置倒计时 + 回合数 +1 | `02_private_box.lua` |
| `抽卡hex/抽卡初始化` | 0（每帧） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 截获原版抽卡结果并转成卡池单位（每次 1 个，按阵营 + 水陆筛选） | `10_puredraw_data.lua` + `gen_pool.lua` + `11_puredraw_hook.lua` + `12_puredraw_replace.lua` |
| `抽卡hex/解锁科技` | 1（≈1 秒） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 开局把全部科技协议发给 `<All Players>`（含龙船全套升级） | `gen_upgrades.lua` + `15_upgrades.lua` |
| `抽卡hex/发技能` | 1（≈1 秒） | ✅ 成功即自我停用 | `CONDITION_TRUE` | 给真人玩家发 `SpecialPower_LuckyUnitCrate`（不发十连） | `14_grant_draw.lua` |
| `抽卡hex/按钮栏` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 顶部按钮栏：3=交易市场、4=海克斯（禁用），1/2/5/6 留空；脚本内分两次求值（先 Show、一秒后再设 Enable） | `16_buttons.lua` |
| `抽卡hex/帧循环` | 0（每帧） | ❌ 常驻 | `CONDITION_TRUE` | 消费帧延迟队列（截获要"等 3 帧"再删整批） | `13_frame_loop.lua` |
| `抽卡hex/HUD` | 1（≈1 秒） | ❌ 常驻 | `CONDITION_TRUE` | 右上角计分板刷每人场上单位数 + 回合数；左下角五行：回合数 / 盲盒刷新倒计时 / 抽卡等级 / 各档概率 | `20_hud.lua` |

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
│  ├─ lua/chouka/00_init.lua            ← 真源：开局初始化
│  ├─ lua/chouka/01_income.lua          ← 真源：收入
│  ├─ lua/chouka/02_private_box.lua     ← 真源：私有箱（含去重 + 回合数自增）
│  ├─ lua/chouka/10_puredraw_data.lua   ← 真源：抽卡数据（原生结果类型 / 白名单 / 状态）
│  ├─ lua/chouka/gen_pool.lua           ← **生成物**：卡池 + 阵营池 + 类别表（tools/build-pool.js）
│  ├─ lua/chouka/11_puredraw_hook.lua   ← 真源：出生事件钩子 onUnitCreateEvent
│  ├─ lua/chouka/12_puredraw_replace.lua← 真源：删整批 + 补 1 个 + 帧延迟队列 + 水陆筛选
│  ├─ lua/chouka/13_frame_loop.lua      ← 真源：每帧驱动
│  ├─ lua/chouka/gen_upgrades.lua       ← **生成物**：要解锁的科技协议名单（tools/build-upgrades.js）
│  ├─ lua/chouka/15_upgrades.lua        ← 真源：开局 GIVE_PLAYER_UPGRADE 全发
│  ├─ lua/chouka/14_grant_draw.lua      ← 真源：发抽卡技能（不发十连）
│  ├─ lua/chouka/20_hud.lua             ← 真源：计分板 + 左下角回合数/倒计时
│  └─ ScriptsData.json                  ← 生成物（给 JSON 地编导入）
└─ tools/
   ├─ sync-scriptsdata.js               ← 生成器（零依赖 node；支持一个节点拼多个 lua）
   ├─ build-pool.js                     ← 卡池生成器（读作者《完整单位表》+ 两份中文字典）
   ├─ pool-alias.js                     ← 中文名→类型名 的简称对照表
   └─ build-upgrades.js                 ← 科技协议名单生成器（读双兵种 / DSA 三处清单）
```

```powershell
cd E:\Ra3_CenterChess\ALittlePlot
node tools/build-pool.js                # 重建卡池 → gen_pool.lua
node tools/build-upgrades.js            # 重建科技协议名单 → gen_upgrades.lua
node tools/sync-scriptsdata.js          # 生成 scripts/ScriptsData.json
node tools/sync-scriptsdata.js --check  # 只算 payload 体积，不写文件
```

当前产物（8 个节点，全部远低于 64 KB 单条上限）：

```
  抽卡hex/初始化        3177 B (余 62359 B)  interval=0
  抽卡hex/收入          2093 B (余 63443 B)  interval=1
  抽卡hex/私有箱        4452 B (余 61084 B)  interval=120
  抽卡hex/抽卡初始化   26808 B (余 38728 B)  interval=0
  抽卡hex/解锁科技      3931 B (余 61605 B)  interval=1
  抽卡hex/发技能        1218 B (余 64318 B)  interval=1
  抽卡hex/帧循环         835 B (余 64701 B)  interval=0
  抽卡hex/HUD           4841 B (余 60695 B)  interval=1
```

- 单个 payload 上限 **65536 B**，超了 WorldBuilder 会截断，游戏内报 `last token read: '<eof>'`；
  生成器直接报错拦下，不会写出坏包。
- `私有箱` 节点的 `EvaluationInterval` 是**从 `02_private_box.lua` 的 `BOX_SECONDS` 读的**，
  改间隔只改那一行再跑一次生成器即可（不用手工同步 JSON）。

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
| 根组 `油田重铸`（默认停用） | **删** | 引用已重名的 `Center2`、已改小写的 `center`，启用就失效 |
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
| 箱子类型 | `02_private_box.lua` 的 `CRATE_TYPE` | `moneycrate` = 金钱箱；`unitcratenew` = 单位箱（盲盒高原用法） |
| 卡池内容 / 各档权重 | 别手改 `gen_pool.lua`（生成物）；改 `tools/build-pool.js` | 权重合计必须是 100 |
| 截获后等几帧再结算 | `10_puredraw_data.lua` 的 `CHOUKA_BATCH_FRAMES` | 引擎同帧出一整批，等太少只收到第一个 |
| 自定义抽卡概率 | `10_puredraw_data.lua` 的 `CHOUKA_CUSTOM_CHANCE` | 100 = 全部自定义（当前）；调小就是"有概率保留原版结果" |
| 左下角两行文字 | `20_hud.lua` 顶部 `CHOUKA_HUD_TEXT_X` / `CHOUKA_HUD_ROUND_Y` / `CHOUKA_HUD_COUNTDOWN_Y` / `*_COLOR` / `CHOUKA_HUD_TEXT_SIZE` | `AlignY="bottom"` 时 Y 从底边往上量；颜色是十进制 RGB（黄 `16776960`、橙 `16744448`） |
| 卡池内容 / 阵营归属 / 水陆类别 | 别手改 `gen_pool.lua`；改 `tools/build-pool.js`（`USER_POOL` 作者清单、`AMPHIBIOUS` 两栖名单、`TIER_WEIGHTS` 权重）和 `tools/pool-alias.js`（中文名→类型名） | 改完跑 `node tools/build-pool.js && node tools/sync-scriptsdata.js`，生成器会把没翻译出来的名字全部打印出来 |
| 抽卡剔除哪些单位 | `tools/build-pool.js` 的 `BLACKLIST` | 默认剔除基地车/矿车/工程师等"不能打架"的单位；龙船 `CelestialMCV` 不在表里，保留 |
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
- 只能写 **Lua 4.0**：没有 `#t`（用 `getn(t)`）、没有 `string.format`（用全局 `format`）、
  字符串不能 `s:sub()`、泛型 `for` 必须写两个变量。
- **闭包拿不到外层的 local**：需要跨调用保留的状态一律挂全局表。
- 注释会原样进 payload、占 64 KB 预算（但注释不影响执行）。
- `lua/*.lua` 是文档与真源，`ScriptsData.json` 永远是生成物 —— 不要手改 JSON 里的 payload。

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
  （1步兵 2载具 3空军 4海军 5两栖），抽卡时先判落点地形再在该档里筛：
  海军只在水面出、步兵/载具只在陆地产、空军与两栖两边都能出（见 `ChoukaCategoryAllowed`）。
  判定用 `exTerrainGetHeightByPos(x, y)`：本图地形采样 min=0 / avg≈132、全局水位（反射面）=0，
  所以"高度 ≤ `CHOUKA_WATER_MAX_HEIGHT`（0.5）"即水面。某档在当前地形下一个可选单位都没有时，
  自动摊到别的档，不会空抽。
- **不误伤旧单位**（实测修正）：首版照 DSA 用"半径 260 扫场删批"，在本图这种一小块地上会把玩家
  旁边的同类旧单位一起吞掉。现在删除目标**只来自出生事件收上来的 id**，旧单位不在集合里，永远碰不到。
- 白名单：`10_puredraw_data.lua` 的 `ChoukaAlwaysKnownTypes`（工程师 + 各型 MCV）。
  **日冕的协议/技能召唤物也没有生产者**，若实测发现被误删，把类型名加进这张表即可。
- 技能发放：`14_grant_draw.lua` 只发 `SpecialPower_LuckyUnitCrate`，不发 `...X10`。
  注意 `PLAYER_GRANT_SPECIAL_POWER` 的参数顺序是**（技能名, 玩家）**，与多数 `PLAYER_*` 动作相反。

### 9.3 抽卡等级 / 概率 / 交易市场

- **等级表**在 `09_level.lua`：等级 1~8，每级一张概率表（`ChoukaLevelWeights`）、
  升级价格（`ChoukaLevelPrice`：1000 / 2000 / 3000 / 5000 / 5000 / 10000 / 10000）、
  自动升级回合（`ChoukaAutoLevelRound`：第 5 / 10 / 15 / 20 回合 → Lv.2 / 3 / 4 / 5）。
- 抽卡时 `ChoukaChooseUnit` 先按**当前等级的概率表**掷档，再档内均匀取，再按阵营 + 水陆收窄。
- **等级是全场共用的一个进度**（这张图只有 6 个小格，做成公共进度；任何人买都会推进全场）。
- **交易市场**（顶部按钮 3）里两项：`购买等级`（按 `ChoukaLevelPrice` 扣钱升级）、
  `购买防御塔`（`CHOUKA_TOWER_PRICE` 扣钱，在自己起重机位置生成 `CHOUKA_TOWER_TYPE`）。
  扣钱用 `PLAYER_GIVE_MONEY` 的**负值**（动作表里没有 TAKE_MONEY，GIVE 的中文说明就是"增加或减少"）；
  余额用 `exPlayerGetCurrentMoney` 查。
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

### 9.4 HUD

| 位置 | 手段 | 内容 |
|---|---|---|
| 右上角 | 引擎**计分板** `exScoreBoardSetVisibility(1)` + `exScoreBoardSetText(文本, 行1~7, 列1~3)` | 行 1~6：`$p1Name:`…`$p6Name:` + 场上单位数（列 2）；行 7：`回合` + 回合数（列 3） |
| 左下角 | 两条**自绘文字** `exCreateCustomText({...AlignX="left",AlignY="bottom"})`，之后每秒 `exCustomTextUpdateText` 原地改 | 上：`回合数：3`（亮黄 18px）；下：`盲盒刷新倒计时：01:47`（亮橙 18px，mm:ss） |

- 文案格式照 DSA 升本模式那一套"名称：值"（DSA 是 `下一回合开始：xxx` / `最大电厂数量：x`）。
- 公屏 `exAddTextToPublicBoard` **没有**用来做常驻数字：它的第二参数是"显示多少秒"，是滚动消息流，刷倒计时会刷屏。
- 回合数来源 `CHOUKA_ROUND`（私有箱每轮 +1）；倒计时用**我们自己数的秒** `CHOUKA_BOX_LEFT`
  （`00_init` / `02_private_box` 置成 `BOX_SECONDS`，HUD 每秒减 1）。
  ⚠ 实测：`exCounterGetByName("box")` 读 `SET_MILLISECOND_TIMER` 建的计时器**恒为 0**，这条路已废弃。
- 左下角文字位置是 `20_hud.lua` 顶部的 `CHOUKA_HUD_TEXT_X` / `CHOUKA_HUD_TEXT_Y`
  （`AlignY="bottom"` 时 Y 从屏幕**底边往上**量；默认 250，嫌靠下就加大）。
- 引擎自带的倒计时控件（`00_init.lua` 里的 `DISPLAY_COUNTDOWN_TIMER("box","SCRIPT:box")`）用的是 `map.str` 里的 `SCRIPT:box` 文案，
  **已经补上**（`下一次盲盒` / `Next crate`）。计分板与自绘文字写中文是直接写字面量，不需要动 `map.str`。
- 单位数口径：以 `craneN` 当"本方锚点"（`ObjectFindObjects` 第一参数传任意物体，过滤器 `Relationship="SAME_PLAYER"` 按它的主人算），
  过滤 `Include="SELECTABLE"` / `Exclude="STRUCTURE"`，并排除各类箱子。

### 9.3 导入后的验证顺序

1. **先验箱子还在不在**：开局 120 秒后各点位应出现金钱箱，点位已有箱时下一轮不叠加。
2. **验界面**：右上角计分板常驻、六行单位数会变；左下角文字每秒钟跳。
3. **验抽卡能不能开**：点幸运箱技能 → 场上出现可拾取箱子 → 派单位去捡。
4. **验截获**：捡完后场上应该**只有 1 个**卡池单位，没有原版那一批残留。
5. **验误删**：故意在旁边放一个同类型的自造单位，确认它没被删（有生产者就会被排除）。
6. **验建造栏**：开一局看侧边建造栏是否整条被关掉；起重机的**回收功能必须还能用**。
7. **验阵营**：四个阵营各开一局（或四个玩家混编），确认抽出来的单位都属于各自阵营。
8. **验水陆**：在陆地上抽几发，确认不出船；在水面/岸边抽几发，确认不出步兵和坦克（空军、两栖例外）。

已修掉的实测问题（别再改回去）：
- `exWaypointGetPos` 返回**数组**（`p[1]/p[2]/p[3]`）。写成 `p.X` 会让"私有箱"整个脚本抛错中断，
  表现是"倒计时走完不刷箱子、回合数也不加"。
- `exCounterGetByName("box")` 读 `SET_MILLISECOND_TIMER` 建的计时器**恒为 0**，倒计时改成自己数秒。
- `ALLOW_DISALLOW_ALL_BUILDINGS` 是空操作（动作表里属 "Unused or Obsolete"），改用
  `PLAYER_DISABLE_BASE_CONSTRUCTION`。
- 半径 260 扫场删批会吞掉附近同类旧单位，改成只删出生事件收上来的 id。

⚠ 两处仍是**未实测**的推断，进游戏第一件事请核对：
- `LuckyUnitCrateSeed` 在日冕当前版本是否仍可拾取（DSA 是同 mod 的图，理论上一样）；
- `EvaluationInterval` 到底是"秒"还是"帧"（DSA 内部说法不一致）。若发现收入/界面跳得比预期快 15 倍，
  就把 `抽卡hex/收入`、`抽卡hex/HUD` 的 interval 从 1 改成 15。
