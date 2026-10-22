# chouka 目录说明

本目录是这张地图**全部 Lua 真源**。这些 `.lua` 不会直接进游戏 —— `tools/sync-scriptsdata.js`
把它们按节点拼成 `#!ra3luabridge` payload，写进 `scripts/ScriptsData.json`，再由 JSON 地编导入地图。

> 改动流程：改 lua → `node tools/sync-scriptsdata.js` → 导入 `ScriptsData.json`。
> 只想知道体积：`node tools/sync-scriptsdata.js --check`（不写文件）。

## 目录分工

按**职责**分 9 个子目录；文件名前面的数字只表示阅读顺序，跨目录也保持递增。

| 目录 | 职责 | 什么时候会来看它 |
|---|---|---|
| `00_core/` | 公共底座。**每个**节点的 payload 都会先拼上这两个文件 | 想加日志 / 改玩家可见文案 |
| `10_boot/` | 启动与总调度：自检心跳、开局三段（锁视角→公告→房主配置→正式开始）、帧循环、发抽卡技能 | 改开局流程、改超时兜底 |
| `20_economy/` | 经济与成长：底薪与油井收入、抽卡等级表、开局科技协议 | 调收益、调等级曲线 |
| `30_world/` | 地图底座与中立点位：一次性初始化、保底工程师、中央油井争夺、中立油井重建 | 改中立资源、改视野/电力 |
| `40_draw/` | 抽卡核心：箱子种类表、私有箱计时、引擎随机箱清理、抽卡数据、单位登记、截获替换 | 99% 的手感调整都在这里 |
| `50_ui/` | 界面：顶部按钮栏（交易市场/情报）、计分板与左下四行 | 加按钮、改 HUD |
| `60_ai/` | AI 对手：电脑免费抽卡、中立单位加入攻击队 | 调 AI 强度 |
| `70_bang/` | **三国杀模式 + 结盟面板**（见 `docs/11`、`docs/13`） | 改身份/结盟/胜负规则、改结盟面板 |
| `90_gen/` | **工具生成的数据，勿手改**。改了会被下次生成覆盖 | 只想引用常数时读它 |
| `95_assets/` | **生成的贴图，勿手改**：官渡的 7 张操作图标 + hextech 按钮图 + 代码生成的纯色块。由 `tools/build-ui-assets.js` 生成 | 换/加图标时改那个工具再重跑（见 `docs/14`） |

## 节点 ↔ 文件对照

一个节点 = 一段 payload = 若干 lua 按顺序拼接。节点顺序即执行顺序（`NODES` 数组）。

| 节点名 | EvaluationInterval | 组成文件 |
|---|---|---|
| 自检 | 1 | `10_boot/00_selfcheck.lua` |
| 开局 | 1 | `10_boot/03_start.lua` |
| 随机箱清理 | 0（每帧） | `40_draw/07_crates.lua` |
| 初始化 | 0（一次性） | `20_economy/09_level.lua` + `30_world/00_init.lua` |
| 收入 | 1 | `20_economy/01_income.lua` |
| 私有箱 | 1 | `40_draw/02a_crate_list.lua` + `40_draw/02_private_box.lua` |
| 单位登记 | 0（一次性） | `90_gen/gen_allunits.lua` + `40_draw/11a_register.lua` |
| 抽卡初始化 | 0（一次性） | `90_gen/09a_watermask.lua` + `40_draw/10_puredraw_data.lua` + `90_gen/gen_pool.lua` + `40_draw/12_puredraw_replace.lua` |
| 保底军犬 | 1 | `30_world/05_dog.lua` |
| 中央油井 | 1 | `30_world/06_center.lua` |
| 油井重建 | 1 | `30_world/08_oilfield.lua` |
| 解锁科技 | 1（一次性） | `90_gen/gen_upgrades.lua` + `20_economy/15_upgrades.lua` |
| 发技能 | 1 | `10_boot/14_grant_draw.lua` |
| 按钮栏 | 1 | `50_ui/16_buttons.lua` |
| AI对手 | 1 | `60_ai/17_ai.lua` |
| 帧循环 | 0（每帧） | `10_boot/13_frame_loop.lua` |
| HUD | 1 | `50_ui/20_hud.lua` |
| 三国杀-身份 | 1 | `70_bang/30_bang_mode.lua` |
| 三国杀-结盟 | 1 | `70_bang/31_bang_alliance.lua` |
| 三国杀-偏好 | 1 | `70_bang/32_bang_pref.lua` |
| 三国杀-胜负 | 1 | `70_bang/33_bang_win.lua` |
| 结盟面板 | 1 | `70_bang/35_ally_panel.lua` |
| 贴图-操作A | 1（只建一次） | `95_assets/00_action_a.lua` |
| 贴图-操作B | 1（只建一次） | `95_assets/01_action_b.lua` |
| 贴图-操作C | 1（只建一次） | `95_assets/02_action_c.lua` |
| 贴图-按钮与颜色 | 1（只建一次） | `95_assets/03_ui.lua`（hextech 按钮 + 纯色块） |

`00_core/` 的两个文件不计入上表 —— 它们被拼进**每一个**节点。

## 三国杀模式的节点接力

四个三国杀节点**不靠先后顺序**（引擎不保证同帧内的节点顺序），靠全局标志位接力：

```
03_start 房主确认且玩法=三国杀
   └→ 32 建偏好卡片，数 180 秒 → ChoukaBangPrefDone = 1
      └→ 30 洗牌发身份，私发 + 顶部情报按钮 → ChoukaBangRolesReady = 1
         └→ 31 设初始关系（四遍覆盖）→ ChoukaBangRelationsApplied = 1
            └→ 03_start 正式开局（CHOUKA_GAME_STARTED = 1）→ ChoukaBangStartApplied = 1
               └→ 33 每秒判胜负 → 结算时 CHOUKA_BANG_ENDED = 1
```

任何一个节点报错（payload 解析失败会让**整个节点**静默不执行）都不会卡死整局：
`03_start` 在调用不到 `ChoukaBangBeginPreference` 时会自己把 `ChoukaBangPrefDone` 置 1 直接随机发身份。

## 硬规则（踩过的坑，别重犯）

1. **日冕的 Lua 是 4.0**：没有 `%`（用 `mod()`）、没有 `#`（用 `getn()`）、没有 `pcall`、
   函数拿不到外层 `local`（所以状态一律写成全局）、`return` 必须是所在块的最后一句。
2. **存成 UTF-8 无 BOM**。BOM 拼进 payload 后落在 `#!ra3luabridge` 之后，Lua 4.0 当非法 token
   → 该节点**静默不执行**，游戏里什么都不发生也不报错。`sync-scriptsdata.js` 会读出来直接报错拦下。
3. **别自己写 `#!ra3luabridge` 前缀**，生成器会加。
4. 单个 payload 上限 **65536 B**，超过 64512 B 会告警。超了就拆文件、拆节点。
5. **玩家可见的文字**放 `00_core/01_texts.lua` 的 `ChoukaT` 表；`_LOG` 的日志文案**就地写**，
   不要进文案表（便于区分）。
6. lua 里的注释**也占体积**：纯说明性注释最多 3 行，更长的跑 `node tools/extract-comments.js`
   搬到 `docs/10-Lua注释存档.md`，lua 里只留一行 `-- 详见 docs/10-Lua注释存档.md §<文件名>-<序号>`。

## 相关文档

- `docs/03-抽卡hex改造-Lua与JSON地编.md` —— 主文档：脚本设计 + 地编导入步骤
- `docs/06-开局流程-锁视角公告与房主配置.md` —— 开局三段 + 房主配置页
- `docs/07-随机箱清理.md` —— 为什么场上不出现自然随机箱
- `docs/08-实测问题的定位与修复.md` —— 实测踩坑逐轮记录
- `docs/10-Lua注释存档.md` —— 从 lua 里搬出来的大段说明
- `docs/11-三国杀模式方案.md` —— 三国杀模式：规则、身份、偏好投票、结盟、胜负
- `docs/12-中立油井重建.md` —— 阵亡者的油井变回中立无敌井：生成原语、无敌与清场的关系、空位判定
