# 10 · Lua 注释存档（从 lua 里搬出来的大段说明）

> **为什么要搬**：`ScriptsData.json` 的每个节点 payload 是 **lua 原文逐字节拼进去的**，
> 注释一样占字节，而单节点上限约 64 KB。所以"大段纯说明"只放在本文档，
> lua 里只留一行指针：`-- 详见 docs/10-Lua注释存档.md §<文件名>-<序号>`。
>
> 本文件由 `tools/extract-comments.js` 自动生成，重跑会整体覆盖（改文档请改 lua 后重跑）。
> 规则：连续 **≥4 行**的纯注释块才搬；块首/块尾的装饰线（`-- ====`）留在原处。

## 00_alert.lua

### §00_alert-1（原第 50~63 行）

```lua
-- 抽卡hex · 每帧驱动
--
-- 对应 ScriptsData.json 节点：抽卡hex / 帧循环
--   EvaluationInterval     = 0     （每帧求值）
--   DeactivateUponSuccess  = false （常驻）
--   条件                   = CONDITION_TRUE
--
-- 现在做两件事：
--   ① 开局兜底：进游戏 3 分钟还没开局（比如 03_start.lua 报错、房主掉线、没人点公告），
--      强制放行，免得收入/盲盒/按钮永远不启动（见 docs/06）
--   ② 消费帧延迟队列（ChoukaDelayCall 排的活）
--      —— 抽卡批次的"等几帧让引擎那一整批落地，再只删出生事件收上来的 id、
--      按原生结果个数补卡池单位（单抽 1 / 十连 10）"就在队列里跑（不按半径扫场，旧单位不会被误吞）
-- 以后要加每帧逻辑（飘字、单位计数缓存…）也挂这里。
```

## 00_init.lua

### §00_init-1（原第 2~28 行）

```lua
-- 抽卡hex · 开局初始化（一次性）
--
-- 对应 ScriptsData.json：抽卡hex / 初始化
--   EvaluationInterval     = 0     （每帧求值）
--   DeactivateUponSuccess  = true  （成功执行一次后自我停用）
--   条件                   = CONDITION_TRUE
--   动作                   = DEBUG_MESSAGE_BOX("#!ra3luabridge ...")
--                            ↑ 由 Lua 桥接管，游戏内不会弹窗
--
-- 做五件事：
--   1. 全图常亮 —— 参考 盲盒高原：开局 MAP_REVEAL_ALL_PERM
--      （本图没有建造场、不靠"有建造场才开视野"那套；起重机是视野与核心）
--   2. 基础电力 = 100000 —— "无限电量"
--      PLAYER_SET_BASE_POWER 设的是「虚空电力」（基础电力），不需要电厂，
--      电厂被拆、电厂断电都不影响，比堆电厂稳。
--   3. 关闭建造栏 —— 玩家不能造任何建筑。起重机保持**完全可用**（可建造、
--      回收功能正常），锁的是建造栏本身，不是起重机。
--      ✅ 实测正解：PLAYER_DISABLE_BASE_CONSTRUCTION(player)
--         （编辑器动作表 editorNumber 56，"玩家不允许建造建筑"）
--      ❌ 不要用 ALLOW_DISALLOW_ALL_BUILDINGS —— 它在动作表里属于
--         "Unused or Obsolete"（editorNumber 284），实测是空操作。
--      ❌ 也不要靠"把起重机设成不可建造"——那会连带废掉起重机的回收功能。
--   4. 开局资金兜底 —— 先给个 5096，房主确认开局时 03_start.lua 按选择重设
--   5. 盲盒倒计时的初值 —— 真正每秒推进倒计时的是 02_private_box.lua
--
-- ★ 本节点只管"地图级"的一次性设置，**不参与开局流程**：
--   锁视角 / 公告 / 房主配置 / 正式开始 全在 03_start.lua（见 docs/06）。
```

### §00_init-2（原第 47~51 行）

```lua
-- 箱子引擎计时器（只用来驱动"私有箱"节点的 120 秒节拍，**不在界面上显示**）
-- ★ 以前这里有 ExecuteAction("DISPLAY_COUNTDOWN_TIMER", "box", "SCRIPT:box")，
--   但引擎读不出 SET_MILLISECOND_TIMER 建的计时器，左下角那个圆框就永远显示 00:00。
--   作者要求去掉，所以这里不再显示；左下角倒计时由 HUD 自己画。
-- ★ 现在这个计时器只是个摆设（02_private_box.lua 自己数秒），留着是为了兼容旧日志。
```

### §00_init-3（原第 54~57 行）

```lua
-- HUD 左下角那个数字用**我们自己的秒计数**，不去读引擎计时器
-- （实测 exCounterGetByName("box") 读 SET_MILLISECOND_TIMER 建的计时器恒为 0）
-- ★ 开局流程（03_start.lua）会把 CHOUKA_GAME_STARTED 置 1，
--   在那之前收入/盲盒/军犬/中央油井/按钮全部按门控停着，这里只放好初值。
```

## 00_selfcheck.lua

### §00_selfcheck-1（原第 2~9 行）

```lua
-- 抽卡hex · 自检 / 心跳（第一个节点，1 秒一次，只写日志）
--
-- 作用：整局每 10 秒往日志里打一行，回答四个问题 ——
--   ① 脚本还活着吗（能打出来就是活着）
--   ② 开局门控过了吗（started=1）
--   ③ 回合/倒计时/等级有没有在动（round / boxLeft / lv）
--   ④ 哪些节点的 payload 真的跑起来了（节点就绪=...）
-- 日志位置：E:\CoronaLauncher\CoronaData\Logs\EnhancerCorona-<时间>.dll.log
```

## 01_income.lua

### §01_income-1（原第 2~8 行）

```lua
-- 抽卡hex · 持续收入（底薪 + 私油井 + 中央油井）
--
-- 对应 ScriptsData.json：抽卡hex / 收入 （interval 1，常驻）
--
-- 判负口径：起重机 craneN 活着 = 这个座位还在
-- 经济倍率：照 DSA 的 exModeGetCheatMultiplier()（0.5 / 1 / 1.5 / 2），
--           所有收入按它整体缩放，和自走棋的"经济倍率"设置项一致。
```

## 02_private_box.lua

### §02_private_box-1（原第 2~27 行）

```lua
-- 抽卡hex · 私有箱（每人两个点位，只做私有，不做中央）
--
-- 对应 ScriptsData.json：抽卡hex / 私有箱
--   EvaluationInterval     = 1     （约 1 秒一次，**本脚本自己数秒**）
--   DeactivateUponSuccess  = false
--   条件                   = CONDITION_TRUE
--
-- ★ 为什么改成"每秒节点自己数秒"（原来是 interval=120 一把梭）：
--   开局流程里房主要先选配置，真正开局的时间点是不确定的。
--   节点 interval 从**进游戏**开始算，和"开局"不对齐 —— 120 秒节点会在进游戏
--   第 120 秒刷第一轮，哪怕当时才开局 5 秒。所以改成每秒节点 + 自己数 CHOUKA_BOX_LEFT，
--   开局时由 03_start.lua 把倒计时重置成整轮，HUD 也直接读这个数，两边永远一致。
--
-- 每个还在场上的玩家，在自己那对点位各刷一个金钱箱，归属自己队伍：
--   Player_1 → box11 / box12      Player_4 → box41 / box42
--   Player_2 → box21 / box22      Player_5 → box51 / box52
--   Player_3 → box31 / box32      Player_6 → box61 / box62
--
-- ★ 箱子不重复刷：点位半径内已经有箱子（谁的都算）就跳过，等它被开掉/打掉
--   下一轮再补。这样点位永远不会堆成"箱子山"。
--
-- 用「未具名生成」而不是具名生成：箱子没人开就会留在场上，
-- 具名生成会因重名失败，未具名生成不会。
--
-- 箱子内容：moneycrate（金钱箱）—— 配合日冕「2480 一抽随机单位」的抽卡消耗。
-- 想改成单位箱就把 CHOUKA_CRATE 换成 "unitcratenew"（盲盒高原用的就是这个）。
```

## 03_start.lua

### §03_start-1（原第 2~39 行）

```lua
-- 抽卡hex · 开局（锁视角 + 公告 + 房主配置 + 正式开始）
--
-- 对应 ScriptsData.json 节点：抽卡hex / 开局
--   EvaluationInterval     = 1     （约 1 秒一次）
--   DeactivateUponSuccess  = false （常驻：回调函数要靠它一直重定义）
--   条件                   = CONDITION_TRUE
--
-- 流程照《DSA 自走棋》（日冕地图lua例子/DSA_ggz自走棋）的开局三段：
--   ① 锁视角 + 弹公告
--      DSA：text/0 动作 MOVE_CAMERA_TO(CAM0,0,0,0,0)（瞬间把全体相机钉到地图中心），
--           text/Update 动作 exShowLongTextDialog(...)（全屏长文本公告，按钮「已阅读」），
--           cams/starts 动作 LOCK_CAMERA(1) / DISABLE_INPUT() / HIDE_UI()。
--      本图：MOVE_CAMERA_TO("center") + LOCK_CAMERA(1) + LOCK_CAMERA_SCROLL(1)，
--           公告用 exShowLongTextDialog（长文本对话框，3 个按钮传空串就隐藏）。
--   ② 房主选择配置
--      DSA：所有人都点过「已阅读」后，text/close_Update 用
--           ObjectPlayerScriptName("<1st Human Player>") 那一套认房主，
--           然后 BtnChoiceDialogEventFunc_ShowGameModeDialog 只给房主开选择对话框，
--           房主点「确认」后 exEnableWBScript("readyForStartCam") 才往下走。
--      本图：房主点「已阅读」→ 只给房主开选择对话框（exShowCustomBtnChoiceDialogForPlayer），
--           点「确认，开始游戏」→ ChoukaStartConfirm = 1，下一次求值收尾。
--   ③ 正式开始
--      视角回自己出生点（PLAYER_CAMERA_MOVE_TO(Player_N, "Player_N_Start", 0,...)），
--      解相机锁、开输入、发开局资金、盲盒倒计时从整轮开始走。
--      ⚠ DSA 中间那段运镜（cams/cam1~cam4 + 淡入淡出）作者要求**不要**，本文件没有。
--
-- 两个"没有现成案例可以照搬"的地方，按日冕自家教程（日冕地图lua例子/教程.lua）写的：
--   · 地图中间那行「请等待房主选择配置」用 exShowTextAtPos（教程:516
--     "在指定地点显示任意内容的漂浮文字"）。DSA 那种 NAMED_SHOW_INFOBOX 必须挂在一个
--     **具名物体**上（TextDoActionLocalized("NAMED_SHOW_INFOBOX","HOME","SCRIPT:learn",...)），
--     而本图 center 只是个航点、附近没有具名物体，所以走 exShowTextAtPos：
--     漂浮文字会自己消失，因此每秒重刷一次，观感上是常驻的。
--   · 相机锁用 LOCK_CAMERA（DSA 同款）+ LOCK_CAMERA_SCROLL（动作表 387 / 435），
--     开局时成对解锁，不会把玩家相机永久锁死。
--
-- 门控开关（别的脚本都看它）：
--   CHOUKA_GAME_STARTED = 0  开局流程没走完：收入/盲盒/军犬/中央油井/按钮全都不动
--   CHOUKA_GAME_STARTED = 1  房主点过确认：一切照常
```

### §03_start-2（原第 63~68 行）

```lua
-- 房主能选的配置：两个二选一的按钮（**默认第 1 个 = 箱子包括全部阵营**）
--   1 = 箱子包括全部阵营（默认，带 √）→ CHOUKA_DRAW_SCOPE = 0   ← 作者 2026-10 指定默认值
--   2 = 抽卡只有自己阵营             → CHOUKA_DRAW_SCOPE = 1
-- 理由：大伙更习惯"箱子什么都能出"，四阵营卡池合并成一个池子；
--       想玩"只有自己阵营"的房主仍然可以点第 2 个（实测就是这么测的）。
-- ★ 开局资金不再由房主选：固定走 00_init.lua 的 BASE_MONEY（5096 = 2 抽）
```

### §03_start-3（原第 84~88 行）

```lua
-- 0. 对话框回调分发器
--    ⚠ 引擎只认固定名字的两个全局函数：onUserBtnChoiceDialogEvent /
--      onUserLongTextDialogEvent。本图有多个脚本要用（开局配置、交易市场），
--      谁最后定义就谁生效 —— 所以在**每个**用到的节点里都重复定义同一份分发器，
--      各脚本只负责把自己的处理函数注册进 ChoukaXxxHandlers。
```

### §03_start-4（原第 140~143 行）

```lua
-- 房主 = 第一个真人玩家（<1st Human Player>）。认不出来先按 Player_1 顶着，
-- 但**不锁定**，下次求值/下次回调还会重认（玩家席位就绪有先后）。
-- 一旦真认出来就锁住（ChoukaStartHostLocked = 1），免得中途返回空把房主换人、
-- 让人家已经开着的配置窗口失效。
```

## 05_dog.lua

### §05_dog-1（原第 2~18 行）

```lua
-- 抽卡hex · 保底工程师（独立节点，避免和中央油井互相拖累）
--
-- 口径（作者 2026-10 第五次实测后确定）：
--   **只看这个玩家手上还有没有"苏联工程师 / 盟军工程师"**。
--     · 没有（一开始就没有，或者工程师死了）→ 5 秒后补 1 只；
--     · 有 → 一个都不多刷。
--   补的种类：苏联 / 盟军工程师**随机**来一只。
--
-- ★ 为什么只认这两种工程师：
--   1. 它们**不在出生事件登记表里**（gen_allunits.lua 生成时已剔除），
--      所以脚本自己刷出来的工程师出生时根本不会触发抽卡钩子，
--      绝不可能被自己的抽卡系统当成"原生抽卡结果"删掉换成随机单位。
--   2. 工程师能走能碰箱子，是"没单位就死局"的兜底最佳选择。
--      （旧版用军犬 AlliedScoutInfantry，它在登记表里 → 会被自己删掉，已废弃。）
--
-- ★ 兜底位置："起重机 → 出生点"这段路的 55% 处，别压在起重机 footprint 上
--   （压住了会生成失败）。
```

### §05_dog-2（原第 27~31 行）

```lua
-- 兜底单位：苏联 / 盟军工程师**随机**
-- ★ 作者 2026-10 实测反馈"只见到盟军工程师"，所以这里做了两件事：
--   ① 取随机的方式改成"千分位奇偶"，不用浮点直接比 0.5（避免随机数口径不同时永远落一边）；
--   ② **最多连续 2 次同一种**：连续两次都抽到盟军时，第三只强制换苏联（反之亦然）。
--      这样整体仍是各 50% 的随机，但玩家一定能看到两种工程师，不会出现"怎么老是盟军"。
```

## 06_center.lua

### §06_center-1（原第 2~17 行）

```lua
-- 抽卡hex · 中央钱箱 + 中央油井占领
--
-- ★★ 本轮实测反馈修正（很重要，别再犯）：
--   ① 中央油井**真的叫 `centerOil1` / `centerOil2`**（docs/02 那张对象表已过时，
--      上面写的"两座都叫 Center2"是老数据）。现在先按真名找，找不到才退回几何搜索。
--   ② 上一版把"占点"写在了"刷箱"前面，占点里任何一句调用不存在/报错，
--      整个节点当帧就中断 → **中央钱箱也跟着不刷了**。
--      现在**刷箱永远排在最前面**，且占点里每个可选 API 都做了 type() 判断。
--   ③ 加了 `_ALERT()` 播报（DSA 的写法：往公屏打一行），先把"到底发生了啥"打出来：
--      定位结果、每口油井的领先者/各玩家计数、占领变化、每回合刷了几个箱。
--      定位完把 `CHOUKA_CENTER_DEBUG` 改成 0 就不吵了。
--
-- 占点规则照《双兵种作战-狭路相逢》Troop Selection/Oil Capture.lua 的成功做法：
--   每 5 秒扫一次半径 200 内"能打的单位"，按玩家计数；
--   **领先方连续领先 3 次（≈15 秒）才算占领**（所有者驻守或无人时挑战进度回落，
--   换个人来挑战进度从 1 重数），占领时把油井所有权真的转给占领者并公播。
```

## 07_crates.lua

### §07_crates-1（原第 2~44 行）

```lua
-- 抽卡hex · 引擎随机箱清理
--
-- 对应 ScriptsData.json：抽卡hex / 随机箱清理
--   EvaluationInterval     = 0     （每帧：靠自己的帧计数决定哪一帧干活）
--   DeactivateUponSuccess  = false （不能一次性停用：第 45 帧还要再扫一次）
--   条件                   = CONDITION_TRUE
--
-- 效果：除了本图自己在预设点位刷的箱子（boxN1/boxN2、center1~center6），
--       场上**不会出现任何引擎自然刷新的随机箱子**。
--
-- 实现照抄《DSA 自走棋》lua/GAME/PureDraw/06_init_mcv.lua 第 43-79 行（作者原名
-- UtilsLuckyCrate，编进地图节点 GAME/UtilsLuckyCrate，int=0 一次性）：
--   ① 第  1 帧：只找 GenericCrateSpawner（引擎的随机箱子**生成器**物件）全删
--               → 生成器没了，之后引擎不再往图上刷箱子。
--               作者注释原文（analysis/地图注释说明文档.md:2051）：
--               「箱子模式：只允许抽卡，不允许在地图上刷随机箱子（万一被 AI 捡了太麻烦）」
--   ② 第 45 帧：再扫一遍，把生成器之外**已经刷出来的实体箱子**也清掉
--               （UnitCrateNew / ShroudCrate / MoneyCrateMP）——
--               这就是"玩家全程看不到引擎随机箱"的关键：第 1 帧删生成器只能阻止
--               *之后*的刷新，开局那一批实体箱子得靠第二遍扫。
--
-- 与本图的差别（两处，都是为了不误删自家箱子）：
--   · DSA 是"见到就删"；本图多了「保留点位」判断 —— 离预设刷箱点位
--     CHOUKA_CRATE_KEEP_RANGE 以内的箱子一律不动（那是 02_private_box.lua /
--     06_center.lua 刷出来的自家箱）。
--   · 第 45 帧之后再加每 CHOUKA_CRATE_SWEEP_EVERY 帧一次的兜底扫描，
--     只扫到 CHOUKA_CRATE_SWEEP_UNTIL 帧为止，防止某些箱子比开局动画还晚落地。
--
-- 清的是这些类型：
--   GenericCrateSpawner  引擎的随机箱子生成器（不是箱子，是刷箱子的东西）→ **永远删**
--   UnitCrateNew         原版单位箱（随机箱的主要实体）
--   UnitCrate            原版单位箱（旧模板名）
--   ShroudCrate          迷雾箱
--   MoneyCrateMP         原版金钱箱
--   MoneyCrate           原版金钱箱（旧模板名）
--   前 4 个（生成器 + UnitCrateNew/ShroudCrate/MoneyCrateMP）是 DSA 的原表，
--   后两个是同一个箱子族里的旧模板名，一并当自然箱处理。
-- ⚠ **不**在这张表里的两种，绝对不能加进来：
--   LuckyUnitCrateSeed   = 抽卡技能扔出来的那个可拾取箱子（本图抽卡入口）
--   moneycrate           = 本图自己的金钱箱（大小写不敏感时可能与 MoneyCrate 同名，
--                          所以才要"保留点位"兜底）
--   万一实测发现自家某个箱子被误删：把它从下面这张表里去掉，或者把它所在的航点
--   加进 CHOUKA_CRATE_KEEP_WPS。
```

## 09_level.lua

### §09_level-1（原第 2~18 行）

```lua
-- 抽卡hex · 抽卡等级（决定各档概率）
--
-- 等级 1~8，每级一张概率表；"购买等级"花钱升，或到指定回合自动升。
-- 作者定的表（见 日冕地图lua例子/抽卡hex地图说明.txt:40-49）：
--   等级   T1    T2    T3    T4   T5    升到该级的价格   自动升级
--   1级   100%    0%    0%    0%   0%   开局自带         —
--   2级    90%   10%    0%    0%   0%   500             第 5 回合后
--   3级    75%   25%    0%    0%   0%   1000            第 10 回合后
--   4级    55%   30%   15%    0%   0%   2000            第 15 回合后
--   5级    45%   33%   20%    2%   0%   3000            第 20 回合后
--   6级    30%   40%   25%    5%   0%   5000            —
--   7级    16%   30%   43%   10%   1%   10000           —
--   8级    15%   20%   34%   30%   1%   10000           —
--
-- ⚠ 简化为**全场共用一级**：这张图只有 6 个小格，等级做成公共进度，
--   任何人买都会推进全场等级（和左下角 HUD 显示的读数是同一个数）。
--   自动升级只在"当前等级更低"时生效，"不覆盖更高等级"自然成立。
```

## 10_puredraw_data.lua

### §10_puredraw_data-1（原第 2~9 行）

```lua
-- 抽卡hex · 抽卡系统「数据层」
--
-- 照搬《DSA_ggz自走棋》PureDraw 的做法：
--   原版抽卡的随机发生在引擎/mod 侧 —— 箱子被拾取后引擎直接生成**一整批**同型单位，
--   Lua 拿不到"抽到了什么"的决策，只能事后看到"结果单位被创建"。
--   所以我们做的是：拦截这批原生结果 → 整批删掉 → 在自己队伍生成 1 个卡池单位。
--
-- 本文件只放数据与状态；钩子在 11，替换逻辑在 12，每帧驱动在 13。
```

### §10_puredraw_data-2（原第 58~61 行）

```lua
-- 白名单：这些类型即使没有生产者，也**绝不能**当成"原版抽卡结果"删掉。
-- 照抄 DSA 的工程师 + 各型 MCV（DSA 原表见 PureDraw/02_data.lua:228-236）。
-- ⚠ 日冕的协议/技能召唤物同样"没有生产者"，如果实测发现它们被误删，
--   把对应类型名加进这张表即可（这是唯一需要维护的地方）。
```

### §10_puredraw_data-3（原第 89~92 行）

```lua
-- ---------------- 玩家阵营（1=盟军 2=苏联 3=升阳 4=神州） ----------------
-- 照 DSA 的做法（lua/GAME/PlayerSide.lua：用 PLAYER_HAS_PLAYER_TECH 探四个基础科技）。
-- ⚠ 但**不能在第 0 帧探测**：那时科技树可能还没就绪，会全部误判成盟军。
--   所以第一次抽卡时（最早也要 40 秒后）再探测，结果缓存起来。
```

### §10_puredraw_data-4（原第 128~131 行）

```lua
-- ---------------- 原生结果的海/陆/空属性（水陆判定的第一路信号） ----------------
-- 上面 ChoukaNativeResultTypes 是按「陆地 22 / 海上 6 / 空中 3」分组写的，
-- 这里照搬那个分组：引擎在**水面上**开箱只会吐海上单位，在陆地上只会吐陆地单位，
-- 所以"原生结果是什么类别"就是引擎自己给出的水陆答案，比我们自己猜地形可靠得多。
```

## 11a_register.lua

### §11a_register-1（原第 2~23 行）

```lua
-- 抽卡hex · 单位出生事件登记（节点「单位登记」，整局只跑一次）
--
-- 引擎侧：exObjectRegisterCreateEvent(类型名) 把该模板登记为"要通知出生事件"，
-- 之后每次该模板有单位出生，引擎调用全局函数
--     onUnitCreateEvent(createdObjId, createdObjInstanceId, ownerPlayerName)
-- createdObjInstanceId 是**模板名的哈希**（拿不到名字，用 FastHash 比对）。
-- 这与 DSA 的 lua/GAME/UnitCreate.lua:1377 是同一个入口名，不能改名。
--
-- ★★ 登记口径（作者 2026-10 实测确定）：
--   **以「日冕单位信息汇总.txt」的全部单位表为准整表登记**（见 gen_allunits.lua）。
--   以前只登记"卡池里的名字"，结果原生箱子吐出来的**变体模板**全部漏网：
--     机枪悍马 AlliedHumveeVehicle / AlliedHumveeVehicle_Ranger
--     旧联盟   Overlordtank / Overlordtank_SpitfireEngineer
--     ACV 变体 AlliedAntiInfantryVehicle_Ground / _Transport / AlliedChronoBeacon_Riptide
--     迅雷变体 JapanLightTransportVehicle_AntiTank / _Kamikaze
--     基地车变体 AlliedMCV_Naval / JapanMCV_Enhanced / AlliedChronoBeacon_MCV …
--   这些名字跟卡池里的名字不是同一个模板，出生事件根本不会通知到我们。
--
-- ★ 剔除两种类型（生成表时已剔除）：
--   AlliedEngineer / SovietEngineer —— 保底工程师用的类型，登记了会被自己的抽卡系统删掉。
--
-- 注意：桥是 Lua 4.0，闭包拿不到外层 local，所以全部用全局表。
```

## 12_puredraw_replace.lua

### §12_puredraw_replace-1（原第 2~15 行）

```lua
-- 抽卡hex · 抽卡系统「替换层」+ 每帧结算
--
-- 一次抽卡的完整流程：
--   ① 引擎在 mod 侧随机，生成**一整批**同型单位（随机发生在引擎侧，Lua 拿不到决策）
--   ② 每个结果单位的出生事件都进 onUnitCreateEvent（11a_register.lua，整表登记）
--   ③ 逐个收进「这一抽」的批次（按玩家分开），等 CHOUKA_BATCH_FRAMES 帧让整批落地
--   ④ 结算：只删**收上来的那些 id** → 补**同样个数**的卡池单位（单抽 1 / 十连 10）
--
-- ⚠ 关键修正：绝不按半径扫场删。首版照 DSA 用半径 260 扫，在本图这种一小块地上
--   会把玩家旁边的同类旧单位一起吞掉。现在删除的目标只来自"出生事件收上来的 id"，
--   旧单位不在集合里，永远碰不到。
--
-- 概率闸门：CHOUKA_CUSTOM_CHANCE（0~100）。100 = 这一抽必定转成自定义单位（当前设定）。
--   闸门在**结算时按"一抽"掷一次**，不是按单位掷，所以不会出现半批转换。
```

### §12_puredraw_replace-2（原第 43~46 行）

```lua
-- 把一个"疑似原版抽卡结果"的单位收进当前批次（同玩家合批）
-- instanceId = 模板名哈希（引擎给的），用来判断"引擎抽到的是海/陆/空"
-- ★ 现在每个单位都连**落点**一起记：结算时按落点分组，
--   一个箱子里吐出来的"运兵车 + 车里 5 个兵"落点在同一个地方 → 算**一次**抽卡结果。
```

### §12_puredraw_replace-3（原第 103~107 行）

```lua
-- ---------------- 按落点分组：一箱 = 一次抽卡结果 ----------------
-- 实测（2026-10 作者反馈）：一个原生箱子可能一次吐出"迅雷车 + 5 个坦克杀手"、
-- "运兵车 + 若干步兵"。以前是按**单位个数**结算（5 个兵 → 生成 5 次），
-- 车还留在原地。正确口径是"**一只箱子 = 一次抽卡结果**"，
-- 所以按落点把这一批聚成群：同一群（距离 ≤ CHOUKA_GROUP_RADIUS）= 一次结果。
```

### §12_puredraw_replace-4（原第 377~390 行）

```lua
-- 水陆判定（作者 2026-10 第八次口径：**地图是死的，就用死数据判**）
--
-- 判定只看一件事：抽卡落点 (x, y) 在地图的水里还是陆地上。
-- 这个答案由 09a_watermask.lua 里的掩码给出 —— 它直接从地图自带的预览图提取：
--     蓝色 rgb(68,94,106) = 海，其余像素 = 陆地（作者确认）。
--
-- 为什么不用高度 / 不用箱子 Z：
--   · 水底和陆地是连通的同一套高度体系（作者在地编里放水底标记，Z 显示就是 0），
--     所以高度阈值天然会把"水底"和"低地"混在一起；
--   · 箱子是浮在水面的，箱子的 Z 反映的是水面而不是地形。
--   既然地图是静态的，就别在运行时猜 —— 直接把地图的海陆抄下来查表。
--
-- 判定结果怎么用：水 → 只抽海军（+ 空军/两栖）；陆 → 只抽步兵/载具（+ 空军/两栖）。
-- 不做任何地形兜底：生成失败只在水上单位里换类型重试，绝不跨地形。
```

### §12_puredraw_replace-5（原第 639~642 行）

```lua
    -- ★★ 生成口（作者 2026-10 第六次实测要求）：
    --   **不做任何地形兜底**。判定是水就只抽水上单位，是陆就只抽陆地单位；
    --   生成失败只换"同一地形里的另一个随机类型"重试，绝不换地形，
    --   也不拿空军/两栖凑数（那会把"判定错了"掩盖掉，作者要的是判定本身正确）。
```

## 13_frame_loop.lua

### §13_frame_loop-1（原第 2~15 行）

```lua
-- 抽卡hex · 每帧驱动
--
-- 对应 ScriptsData.json 节点：抽卡hex / 帧循环
--   EvaluationInterval     = 0     （每帧求值）
--   DeactivateUponSuccess  = false （常驻）
--   条件                   = CONDITION_TRUE
--
-- 现在做两件事：
--   ① 开局兜底：进游戏 3 分钟还没开局（比如 03_start.lua 报错、房主掉线、没人点公告），
--      强制放行，免得收入/盲盒/按钮永远不启动（见 docs/06）
--   ② 消费帧延迟队列（ChoukaDelayCall 排的活）
--      —— 抽卡批次的"等几帧让引擎那一整批落地，再只删出生事件收上来的 id、
--      按原生结果个数补卡池单位（单抽 1 / 十连 10）"就在队列里跑（不按半径扫场，旧单位不会被误吞）
-- 以后要加每帧逻辑（飘字、单位计数缓存…）也挂这里。
```

## 14_grant_draw.lua

### §14_grant_draw-1（原第 2~22 行）

```lua
-- 抽卡hex · 发放抽卡技能（单抽 + 十连）
--
-- 照 DSA（lua/GAME/PureDraw/01_crate_event.lua:55-56）：两个技能都发。
--   SpecialPower_LuckyUnitCrate      单抽（箱子开出来 N=1 个原生结果）
--   SpecialPower_LuckyUnitCrateX10   十连（箱子开出来 N=10 个原生结果）
--
-- ★ 十连怎么实现：**不另写一套逻辑**。原生结果有多少个，就在结算时补多少个卡池单位
--   （12_puredraw_replace.lua 的 ChoukaResolveBatch：spawnCount = 原生结果个数，上限 10）。
--   所以单抽/十连走的是同一条链路，只是 N 不同。
--   钱的消耗由日冕的技能自身处理（和 DSA 一样），脚本这边不重复扣。
--
-- ★ 开局门控（所以本节点**不能**设成一次性）：
--   房主点「确认，开始游戏」之前不发技能 —— 否则公告期间就能点抽卡按钮白嫖单位。
--   发过一次就置 CHOUKA_DRAW_POWER_GRANTED，之后空转。
--
-- 参数顺序（已按地编动作表核对，editorNumber 528）：
--   PLAYER_GRANT_SPECIAL_POWER( specialpower, Player )
--   注意是"先技能名、后玩家"，和大部分 PLAYER_* 动作相反。
--
-- "<All Human Players>" = 只给真人玩家，AI/中立不占按钮。
-- SetWorldBuilderThisPlayer 的保存/还原照 DSA 的写法，避免污染后续动作的执行身份。
```

## 15_upgrades.lua

### §15_upgrades-1（原第 2~17 行）

```lua
-- 抽卡hex · 开局解锁全部科技协议
--
-- 对应 ScriptsData.json 节点：抽卡hex / 解锁科技
--   EvaluationInterval    = 1   （等一秒，科技表就绪）
--   DeactivateUponSuccess = true
--
-- 为什么直接发：
--   本图建造栏被 PLAYER_DISABLE_BASE_CONSTRUCTION 整条关掉，玩家既不能造建筑，
--   也进不了协议/升级面板 —— 科技协议留着也买不到，不如开局全给。
--
-- 机制照 双兵种作战/Troop Selection/initialization.lua:126：
--   ExecuteAction("GIVE_PLAYER_UPGRADE", "<All Players>", "Upgrade_XXX")
-- 名单由 tools/build-upgrades.js 从下面三处现成清单合并而来（见 gen_upgrades.lua）：
--   · 双兵种 Tech_Upgrade / Enhanced_Tech_Upgrade（玩家可购买的科技协议，含龙船全套）
--   · DSA lua/Upgrade.lua 的 upgrades 列表
--   · 双兵种 lib/enums/UpgradeEnum.lua 全量枚举
```

## 16_buttons.lua

### §16_buttons-1（原第 2~21 行）

```lua
-- 抽卡hex · 顶部按钮栏 + 交易市场 + 氪金防御塔
--
-- 对应 ScriptsData.json 节点：抽卡hex / 按钮栏
--
-- API 以 教程.lua:284-332 为准：
--   区域可见：exCenterTopBtnsChangeVisibilityForPlayer(playerName, visible)
--   建/改按钮：exCenterTopBtnShowForPlayer(playerName, index, textureName, desc)
--   启用：  exCenterTopBtnSetEnableForPlayer(playerName, index, enable)
--   ⚠ Show 之后要**等 1 或 2 帧**再调其它 ui 函数，所以启用放在下一次求值。
--   点击回调固定名：function onCenterTopBtnClickEvent(playerName, btnIndex)
--
-- 按钮位置（作者定）：1、2 留空，3 = 交易市场，4 = 海克斯，5、6 留空。
--
-- 交易市场两页：
--   第一页：1 购买下一抽卡等级：<价格>   2 购买防御塔   3 关闭
--   第二页：1 购买随机T1防御塔：500     2 …T2：2000
--           3 …T3：5000               4 …T4：10000      5 返回
--
-- 防御塔只落在自己的四个预设点位 tower<玩家号>1~4（点位名 tower11 ~ tower64），
-- 按 1→4 顺序填，一格一塔不可堆叠；没有空位时只给自己发提示。
```

### §16_buttons-2（原第 38~41 行）

```lua
-- 对话框回调分发器（和 03_start.lua 里那份**必须一字不差**）
--   ⚠ 引擎只认固定名字的 onUserBtnChoiceDialogEvent，谁最后定义谁生效。
--   本图两个节点都要用（开局配置、交易市场），所以两边都重复定义同一份分发器，
--   各脚本只往 ChoukaXxxHandlers 里注册处理函数。
```

## 17_ai.lua

### §17_ai-1（原第 2~25 行）

```lua
-- 抽卡hex · AI 对手（电脑）
--
-- 两块，都照 DSA 自走棋的做法：
--
-- ① 电脑在"抽卡"
--    每回合给每个电脑座位免费抽 1 个单位：走同一套卡池 + 阵营池 + 水陆判定，
--    概率取**自动升级**那条线（第 5/10/15/20 回合自动升到 2/3/4/5 级），
--    不跟玩家花钱买的等级挂钩 —— 这就是"模拟电脑在抽卡"。
--
-- ② AI 攻击队列
--    DSA 的 PureDrawJoinAIAttackTeam（lua/GAME/PureDraw/04_draw.lua:495）其实只干一件事：
--    把**非玩家阵营**（PlyrCivilian / PlyrCreeps）的单位用 UNIT_SET_TEAM 塞进
--    "<阵营名>/ATTACK" 队（DSA 里就是 DEFAULTATTCKTEAM[7]="PlyrCivilian/ATTACK"、
--    [8]="PlyrCreeps/ATTACK"）。引擎把 ATTACK 队当成"进攻部队"，
--    于是这些原本站着不动、不会主动寻敌的中立单位就会去打玩家。
--    本图原图遗留的中立单位就靠这个变成会咬人的野怪。
--    → 周期（默认 5 秒）扫全场，把新出现的非玩家阵营单位拉进攻击队。
--
-- ★★ 顺序很重要（沿用"中央钱箱被占点代码拖死"的教训）：
--    免费抽卡写在**前面**，扫场入队写在**最后**。这样即使扫描那段报错
--    （过滤器写法/API 不支持），电脑抽卡也照样在工作。
--
-- ⚠ 电脑自己的兵不需要塞 ATTACK 队：电脑座位本身就有引擎 AI 在指挥，会自动进攻。
--   万一实测发现"电脑只挨打不还手"，把 CHOUKA_AI_FORCE_PLAYER_ATTACK 改成 1。
```

### §17_ai-2（原第 97~100 行）

```lua
-- 这个座位是不是电脑。
--   ① 作者可以在文件头写死：CHOUKA_AI_SLOTS = { [2]=1, [4]=1 }
--   ② 否则先问 EvaluateCondition(..., "AI")；
--   ③ 这个参数不被支持时退回"不是人类 + 起重机活着 + 读得到钱"（空座位没有钱）。
```

## 20_hud.lua

### §20_hud-1（原第 2~24 行）

```lua
-- 抽卡hex · 界面
--
-- ★★ 2026-10 实测修正：整个 HUD 之前是**完全不显示**的。
--   根因：用了 `exCreateCustomText` / `exCustomTextUpdateText`（不带 ForPlayer 的版本），
--         日冕这个 mod 根本没有这两个函数（教程.lua 的 API 表里也没有），
--         一调用就报错；而 `ChoukaHudReady` 又是在**建文字之前**就置 1，
--         于是每秒都跳过、永远不再重试 → 左下角一行字都没有。
--   改法：
--     ① 逐玩家文字改用**真 API**：`exCreateCustomTextForPlayer` /
--        `exCustomTextUpdateTextForPlayer` / `exCustomTextUpdateVisibilityForPlayer`
--        （见 日冕地图lua例子\目标血条UI显示模板.lua:119/151/159 和 DSA 的海克斯选卡界面）
--     ② `ChoukaHudReady` 改成**建完之后**才置 1；某个玩家建失败就下次重试
--     ③ 每个 ex* 调用都套 `type(...) == "function"`，缺 API 也只丢一行日志，不中断节点
--     ④ 关键信息同时写进右上角**计分板**（`exScoreBoardSetText` 是教程里有的老 API，最稳），
--        这样就算逐玩家文字的位置不对，玩家也一定能在右上角看到回合/倒计时/等级/概率
--
-- 右上角计分板行分配：
--   1~6 行 = 六个座位各自场上单位数
--   7 行  = 回合数
--   8 行  = 盲盒刷新倒计时
--   9 行  = 抽卡等级
--   10 行 = 各档概率
-- 左下角（逐玩家文字，1~4 行）：回合数 / 倒计时 / 抽卡等级 / 概率
```

---

统计：搬走 34 段、共 32122 B；lua 总体 151090 B → 120357 B（省 30733 B）。
