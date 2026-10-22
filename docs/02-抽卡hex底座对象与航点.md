# 05 · 抽卡hex 底座数据：对象 / 航点 / 触发区

> 数据来源：Ra3MapEditor MCP 实测（`ra3map_describe_map` / `ra3map_list_objects{includeProps:true}` / `ra3map_get_areas`），
> 落盘在 `tools/mcp-client/out/v2_full.txt`。对象名取的是 `props.objectName`（航点另取 `waypointName`），
> 这跟 `uniqueID`（`SovietCrane 1061` 这种默认序号）不是一回事，别混。
> 世界坐标→格：`格 = 世界/10 + border(40)`；反推：`世界 = (格 − 40) × 10`。

## 1 地图本体

| 项 | 值 |
|---|---|
| 文件 | `[cor]每人一小块地抽卡hex.map`（RefPack，231,136 B） |
| 尺寸 | 690 × 690 格，border **40** 格 → 可玩区 **610 × 610** 格 |
| 对象数 | **1089**（上一版 1053 → 本次 +36） |
| 玩家条目 | 20（`Player_1`…`Player_6` 实际排在 **index 12…17**，见 §2） |
| 触发区 | 3（`Total` / `DieAreaBUG` / `规范方框`） |
| 航点 | 86 个（含本次新增 12 个 box + 7 个 center） |

## 2 玩家条目的 index（踩坑点：`Player_N` 不在 1..6）

| index | playerName | 人类 | 模板 |
|---|---|---|---|
| 0 | （空） | | |
| 1 | PlyrNeutral | 是 | PlayerTemplate:Neutral |
| 2 | PlyrCivilian | 否 | FactionCivilian |
| 3 | SkirmishNull | 否 | Null |
| 4 | SkirmishObserver | 否 | Observer |
| 5 | SkirmishJapan | 否 | Japan |
| 6 | SkirmishCommentator | 否 | Commentator |
| 7 | SkirmishAllies | 否 | Allies |
| 8 | SkirmishNeutral | 否 | Neutral |
| 9 | SkirmishCivilian | 否 | Civilian |
| 10 | SkirmishRandom | 否 | Random |
| 11 | SkirmishSoviet | 否 | Soviet |
| **12** | **Player_5** | 否 | FactionCivilian |
| **13** | **Player_6** | 否 | FactionCivilian |
| **14** | **Player_3** | 否 | FactionCivilian |
| **15** | **Player_4** | 否 | FactionCivilian |
| **16** | **Player_1** | 否 | FactionCivilian |
| **17** | **Player_2** | 否 | FactionCivilian |
| 18 | PlyrAllies | 是 | Allies |
| 19 | SkirmishYuriko | 否 | Yuriko |

> 每人的脚本列表是挂在 **对名字** 上的（`Player_1` 那条列表的 playerIndex = 16、`Player_5` = 12），
> 名字与脚本一一对应，只是顺序被洗过；用 `ra3map_script_detail` 必须给对 `playerIndex`。

## 3 每人一份的基地物件（本次新增）

| 玩家 | 起重机 `craneN` | 油井 `oilN` | 电厂 `powerN` | 箱子点 | 出生点 | 高空点 |
|---|---|---|---|---|---|---|
| Player_1 | `crane1` (5043, 4218) idx 28 | `oil1` (5179, 4020) idx 1077 | `power1` (7, −339) idx 805 | `box11` (5066, 4310) / `box12` (5136, 4245) | (4927, 4110) | (4988, 4171) |
| Player_2 | `crane2` (5050, 1838) idx 29 | `oil2` (5184, 2031) idx 1076 | `power2` (120, −339) idx 804 | `box21` (5146, 1822) / `box22` (5066, 1739) | (4932, 1947) | (4991, 1884) |
| Player_3 | `crane3` (3048, 640) idx 30 | `oil3` (3047, 525) idx 1079 | `power3` (230, −343) idx 803 | `box31` (3148, 621) / `box32` (2945, 619) | (3047, 863) | (3034, 586) |
| Player_4 | `crane4` (1047, 1834) idx 31 | `oil4` (920, 2072) idx 1080 | `power4` (351, −342) idx 802 | `box41` (1019, 1733) / `box42` (947, 1809) | (1151, 1946) | (1089, 1881) |
| Player_5 | `crane5` (1046, 4220) idx 26 | `oil5` (940, 3987) idx 1081 | `power5` (458, −345) idx 801 | `box51` (952, 4241) / `box52` (1031, 4312) | (1152, 4111) | (1087, 4180) |
| Player_6 | `crane6` (3044, 5402) idx 27 | `oil6` (3028, 5506) idx 1082 | `power6` (587, −348) idx 800 | `box61` (2961, 5450) / `box62` (3126, 5443) | (3044, 5193) | (3018, 5312) |

物件属性（实测）：

| 物件 | 类型 | 归属 | 血 | 不可摧毁 | 不可出售 | 备注 |
|---|---|---|---|---|---|---|
| `crane1`~`crane6` | `SovietCrane` | `Player_N/teamPlayer_N` | 100 | 否 | 否 | ✅ 归属已修好（作者实测 `crane5` 归 `Player_5/teamPlayer_5`）。旧记录说 `crane5` 归 `Player_4` —— **那是过时信息，已作废** |
| `oil1`~`oil6` | `OilDerrick` | `Player_N/teamPlayer_N` | 100 | **是** | **是** | 每人 1 个，都在自己岛上 |
| `power1`~`power6` | `AlliedPowerPlant` | `Player_N/teamPlayer_N` | 100 | **是** | **是** | 位置仍在可玩区**外的 border 横条**（y≈−340，格 y=6） |

## 4 出生点周围的辅助航点

每人都有一整套（`N` = 玩家号）：

| 航点 | 作用（承接原图脚本） | 例：Player_1 |
|---|---|---|
| `Player_N_Start` | 出生点，脚本里生成基地车/物品的落点 | (4927, 4110) |
| `Player_N_Start_High` | 高空落点，神州"龙船闪亮登场"专用 | (4988, 4171) |
| `boxN1` / `boxN2` | **本次新增**：两个箱子刷新点，一人一对 | (5066, 4310) / (5136, 4245) |
| `airportN` | **作者 2026-10 新增**：家里的机场点位，一人一个。原本用于交易市场「购买神州机场」，**该入口现已关闭（备用）**，点位保留不改 | `airport1` |
| `Center_pN` / `Center_pNB` | 从自己岛指向中心的路径点（原图 AI 寻路/视野用） | (4551, 3899) / (4918, 4111) |
| `FlagPN` / `FlagPNB` | 阵营旗帜落点（原图"根据阵营给旗帜"用） | (4523, 4110) / (4927, 4513) |
| `P1-1` … `P5-1` | 岛与岛之间的中立路径点 | — |

## 5 中央岛

> ⚠️ **2026-10 作者改动：`center1~6` 已不在中心小岛上了。**
> 为避免箱子全挤在中间、中央收益过大，这 6 个航点被挪到了 6 条「玩家 ↔ 中心」的连接路上（路中途）。
> **下表 `center1~6` 的坐标是挪动前的旧值，只作历史参考。**
>
> 代码侧不受影响：全部按航点**名字**取坐标（`06_center.lua` 刷箱 / `07_crates.lua` 保留点位 /
> `03_start.lua` 锁视角），挪位置对脚本完全透明。唯一跟着改的是**中央箱子归属**：
> 从"按中央油井归属交替分两堆"改成"分给离该点位最近、且起重机还活着的玩家"（`docs/12` §7）。
>
> `center` 与 `centerOil1/2`（两座油井）**没有动**。

| 名字 | 坐标 | 类型 | 说明 |
|---|---|---|---|
| `center` | (3044, 3029) | 航点 | 中心点（**注意：原图脚本里写的是大写 `Center`，本次已改成小写 `center`**） |
| `center1` ~ `center6` | *（已挪到 6 条连接路中途，旧值见 git 历史）* | 航点 | 中央钱箱刷新点，每回合各刷 1 个。原先是以中心为圆心、半径 ≈70 世界单位的正六边形环。**`center` 本身也刷一个 → 共 7 个点位** |
| `centerOil1` / `centerOil2` | (2859, 3026) / (3227, 3025) | `OilDerrick`（中性 `/team`，不可摧毁） | ⚠️ **本行曾写成"两座都叫 `Center2`"，已过时** —— 作者 2026-10 实测：地图里就是 `centerOil1` / `centerOil2`，脚本按真名取即可（`06_center.lua` 仍保留了几何兜底） |
| `规范方框` | 六边形 (3041,3155)(3168,3031)(3043,2905)(2912,3031) | 触发区 | 中心岛范围 |

## 6 触发区

| 名字 | 顶点 | 用途 |
|---|---|---|
| `Total` | (−173,6238) (−209,−290) (6366,−246) (6292,6267) | 覆盖全图，原图 `Money` / `View Get` 用"在 Total 区内有 N 个某单位"来判定 |
| `DieAreaBUG` | (−111,−291) (705,−289) (708,−391) (−111,−399) | 边界外的横条，**正好盖住 `power1`~`power6`**；原图 `计时1秒` 每秒对 `<All Players>` 清空这个区 |
| `规范方框` | 六边形，中心岛 | 中心岛判定范围 |

## 7 现在这套数据里的 4 个坑（其中 2 条已作废）

1. ~~**`crane5` 归属错**~~（**已修好，本条作废**）：旧记录称 `originalOwner = Player_4/teamPlayer_4`，
   作者实测现在归 `Player_5/teamPlayer_5`，六个座位各一台，不存在"Player_4 有两台、Player_5 一台都没有"。
   → 这个结论现在是干净的：**"活着的起重机数量"就等于真实参战座位数**（见 `docs/11-三国杀模式方案.md` §4）。
2. **`power1`~`power6` 在可玩区外、且在 `DieAreaBUG` 里 —— 这是设定，不是 bug**：
   它们与 `crane1`~`crane6` 一一绑定，是"隐形电厂 + 存在证明"（`objectIndestructible=true`），
   所以位置不动。要处理的只有旧脚本 `修复基地车脚本人机BUG/计时1秒`（每帧 `UNIT_KILL_ALL_IN_AREA <All Players> DieAreaBUG`）——
   新设计里没有 AI 基地车可修，这条要停用/删除。
3. ~~**`Center2` 重名**~~（已作废）：作者实测中央两座油井是 `centerOil1` / `centerOil2`，不存在重名。原图 `油田重铸` 用的哨兵名另算，本图脚本不依赖它。
4. **`center` 改名**：原图 `油田重铸/rebuild2` 里生成油井用的是航点 `Center`（大写），现在地图上是 `center`（小写）→ 该组一旦启用就会找不到航点。

## 8 复现命令

```powershell
node tools/mcp-client/mcp.js cmd_v2_full.json "E:\Ra3_CenterChess\ALittlePlot\Maps\[cor]每人一小块地抽卡hex\[cor]每人一小块地抽卡hex.map"
```

`cmd_v2_full.json` 里 5 条：`describe_map` → `list_objects{includeProps:true, limit:1500}` →
`get_areas` → `get_scripts` → `export_scripts_xml`（写 `out/scripts_v2.xml`）。
