# 官渡之战「身份面板 + 结盟 UI」移植规格

> 代码考古对象：日冕（Corona）MOD 地图 `[COR]三国杀之官渡之战` 的 Lua 脚本。
> 本文件是**可直接照着写代码**的规格，保留全部原始 API 名、参数字面量、贴图全局名、坐标常量、索引号。
> 凡标注「实测」的结论均来自本仓库内已有的移植实践或官方文档；凡标注「未知」的是**没有证据**的部分，不要当成结论用。

---

## 0. 源文件对应关系

| 源文件 | 行数 | 内容 | 本规格章节 |
|---|---|---|---|
| `145_code.txt` | 1226 | 官渡之战游戏本体脚本：**身份面板 + 结盟 + 观战身份 + 计分板 + 开局流程**（本文档主体） | §1–§8 |
| `30_code.txt` | 74 | `AllegianceModule`（`set_allegiance_single_way` / `set_allegiance_both_way` / `get_player_relation`） | §6 |
| `66_code.txt` | 78 | `UIModule`（技能栏/协议按钮/输入开关/右上角 UI…）—— **与身份面板无关，面板一个函数都没用它** | §9.2 |
| `09_code.txt` | 61 | `PlayerEnum` / `PlayerStrEnum` —— **145 号脚本没有用它们**，全部用硬编码 `"Player_"..index` | §9.2 |
| `114–143_asset.txt` | 各 21 | 30 个 `exPackedTextureImageCreate` 贴图对象（base64 内嵌，全部 104×104 DXT5） | §2.1 |
| `84_code.txt` | 399 | LuaLib `CustomButtonModule`（含**点击事件签名**的定义处） | §5 |
| `85_code.txt` | 191 | LuaLib `CustomTextModule`（`create_text` / `update_text` / `update_pos` / `update_visibility`） | §3.1 |
| `26_code.txt` | 145 | LuaLib `ColorUtil` + `ColorEnum`（`ColorEnum.WHITE.dec_value` = 16777215） | §3.1 |
| `38_code.txt` | — | LuaLib `PlayerModule`：`get_player_nickname` **已被官方注释删除**（`:110` 注释「该功能已被删除」） | §8 |

> 每个 `.txt` 首行是 `#!ra3luabridge` 标记，尾部 `-- end of script, please ignore this line` 是填充，均须忽略。

---

## 1. 状态与数据结构

### 1.1 顶层标量（`145:2-3, 61-68`）

```lua
player_count = 5            -- ★ 座位数，全脚本唯一的人数开关；改地图就改这里
max_player_count = 12       -- 上限（BangGetPlayerName 支持到 AIPlayer06）
Roles = {}                  -- 建了但**从未被读取**（见附录 A）
player_preferences = {}     -- [seat] = "主公"/"忠臣"/"反贼"/"内奸"/"弃权"
player_status = {alive = {}, roles = {}, positions = {}}
player_alliances = {}       -- 有向邻接表，见 §1.6
sellwall = 0                -- 死变量
BangGameInitialized = nil   -- 只在 BangAfterRolesAssigned 里置 1，从未被读
BangDebugEnabled = 0        -- 0 关 1 开；开时 BangDebug 往公屏写 [BangDebug] 前缀，时长 20
BangDebugScoreReportCount = 0
lord_index = nil            -- 全局，BangAfterRolesAssigned 里赋值（主公座位号）
Lord_Transfered = nil       -- ★ 外部全局，本脚本内**无定义**；nil 使 :658 的条件恒假
```

### 1.2 角色表（`145:8-27`）

```lua
BangRoleCountsByPlayerCount = {
    [2]  = {lord = 1, loyalist = 0, rebel = 1, traitor = 0},
    [3]  = {lord = 1, loyalist = 1, rebel = 1, traitor = 0},
    [4]  = {lord = 1, loyalist = 0, rebel = 2, traitor = 1},
    [5]  = {lord = 1, loyalist = 1, rebel = 2, traitor = 1},
    [6]  = {lord = 1, loyalist = 1, rebel = 2, traitor = 2},
    [7]  = {lord = 1, loyalist = 2, rebel = 3, traitor = 1},
    [8]  = {lord = 1, loyalist = 2, rebel = 4, traitor = 1},
    [9]  = {lord = 1, loyalist = 3, rebel = 4, traitor = 1},
    [10] = {lord = 1, loyalist = 3, rebel = 4, traitor = 2},
    [11] = {lord = 1, loyalist = 3, rebel = 5, traitor = 2},
    [12] = {lord = 1, loyalist = 4, rebel = 5, traitor = 2}
}

BangRoleNames = {
    lord = "主公",
    loyalist = "忠臣",
    rebel = "反贼",
    traitor = "内奸"
}
```

`BangGetRoleCounts()`（`145:217-223`）：取 `BangRoleCountsByPlayerCount[player_count]`，**取不到就回退 `[5]`**。
`BangBuildRoles()`（`145:232-240`）：按 `lord → loyalist → rebel → traitor` 顺序用 `BangAppendRole`（`tinsert` count 次）铺成一个**有序数组**，这是后续发牌与 UI 里「角色图标」的数据源。

### 1.3 结盟有向邻接表 `player_alliances`（`145:409-432`）

初始化在 `BangInitPlayers()`：

```lua
player_alliances = {}
for i = 1, player_count do
    ...
    player_alliances[i] = {}
    for j = 1, player_count do
        player_alliances[i][j] = false
    end
end
```

**结构**：`player_alliances[from][to] = true|false`，**方向敏感**，`from` 对 `to` 单向结盟不影响 `to` 对 `from`。
`isAllied(from,to)` / `setAlliance` / `removeAlliance` 全部只读写这一层，见 §6。

### 1.4 `player_status`（`145:63`）

| 字段 | 类型 | 语义 | 写入点 |
|---|---|---|---|
| `alive[i]` | bool | 座位 i 是否存活（初始全 `true`；脚本内**没有**改成 false 的代码，死亡判定是外部/后续版本补的） | `BangInitPlayers` |
| `roles[i]` | string | 角色名（中文），`assignRoles()` 里整体替换 | `assignRoles` |
| `positions[i]` | number | 出生位置序号（主公固定 1，其余随机洗牌） | `BangAssignPositions` |

### 1.5 `BangUi` 状态表（`145:70-88`，逐字段）

```lua
BangUi = {
    identity_button_index     = 1101,   -- 常驻身份按钮（每个真人玩家一个）
    close_button_index        = 1102,   -- 面板关闭按钮
    back_button_index         = 1103,   -- 操作页「返回玩家列表」
    observer_button_index     = 1104,   -- 观战身份按钮（★ 全局按钮，不是 ForPlayer）
    player_button_index_start = 1110,   -- 玩家按钮段基数（实际用 1110+slot，见 §1.6）
    action_button_index_start = 1130,   -- 行动按钮段基数
    title_text_index          = 1151,   -- 标题文本槽
    hint_text_index           = 1152,   -- 副标题/提示文本槽
    player_label_index_start  = 1160,   -- 玩家名文本段基数
    action_label_index_start  = 1180,   -- 行动名文本段基数
    group_index               = 1100,   -- 所有按钮共用的 GroupIndex
    selected_target           = {},     -- [seat] = target_seat|nil   操作页当前目标
    panel_state               = {},     -- [seat] = "closed"|"players"|"actions"
    created_buttons           = nil,    -- ★ 表字面量里没有这个字段！
    button_can_update         = {},     -- [player_name][index] = 1|nil
    created_texts             = {},     -- [player_name][index] = 1
    previous_custom_button_click = nil, -- 被顶替的原 onCustomBtnClickEvent
    handlers_installed        = nil     -- 1 = 已挂钩
}
```

**`created_buttons` 陷阱**：`BangUi` 字面量里只有 `button_can_update` 和 `created_texts`，`created_buttons` 是 `BangUiCreateTrackedButtonForPlayer` 里懒创建的。因此 `BangUiSetButtonVisible` / `BangUiRemoveButtonForPlayer` 开头的 `if BangUi.created_buttons == nil then return end` 在「还没有任何按钮被 tracked 创建」时是真的会提前返回的。

### 1.6 ★ 索引编号分配规则（移植时最容易搞错的地方）

| 用途 | 公式 | 取值范围（`player_count`=5 / =12） | 空间 |
|---|---|---|---|
| 身份按钮 | `identity_button_index` = **1101** 定值 | 1101 | 按钮 |
| 关闭按钮 | `close_button_index` = **1102** 定值 | 1102 | 按钮 |
| 返回按钮 | `back_button_index` = **1103** 定值 | 1103 | 按钮 |
| 观战身份按钮 | `observer_button_index` = **1104** 定值 | 1104 | 按钮（全局） |
| 玩家按钮 | `player_button_index_start + slot` = `1110 + i`，`i = 1..player_count` | 1111–1115 / 1111–1122 | 按钮 |
| 行动按钮 | `action_button_index_start + slot` = `1130 + i`，`i = 1..getn(BangActions)` | 1131–1137 | 按钮 |
| 标题文本 | `title_text_index` = **1151** 定值 | 1151 | 文本 |
| 提示文本 | `hint_text_index` = **1152** 定值 | 1152 | 文本 |
| 玩家名文本 | `player_label_index_start + i` = `1160 + i` | 1161–1165 / 1161–1172 | 文本 |
| 行动名文本 | `action_label_index_start + i` = `1180 + i` | 1181–1187 | 文本 |

**分段规则总结（按钮 index 与文本 index 是两套完全独立的命名空间）**：

- **按钮** `11xx`：`1100`（GroupIndex）→ `1101–1104`（固定按钮）→ `1110+i`（玩家槽，最多 12）→ `1130+i`（行动槽，7 个）。
- **文本** `115x`：`1151/1152` 是「标题/提示」两个公共槽，**不按玩家分段**，靠 `(player_name, index)` 二元组隔离。
- **文本** `116x/118x`：`1160+i` 玩家名标签、`1180+i` 行动名标签。
- 段基数本身**不可用**：点击路由用严格大于（`index > 1110`），所以 `1110`、`1130`、`1160`、`1180` 这几个基数是空号（见 §5）。

取值辅助函数（`145:765-779`）：

```lua
function BangUiGetPlayerButtonIndex(slot) return BangUi.player_button_index_start + slot end
function BangUiGetActionButtonIndex(slot) return BangUi.action_button_index_start + slot end
function BangUiGetPlayerLabelIndex(slot)  return BangUi.player_label_index_start + slot end
function BangUiGetActionLabelIndex(slot)  return BangUi.action_label_index_start + slot end
```

---

## 2. 顶部按钮 / 图标

### 2.1 ★ 重要更正：这里没有「贴图名字符串」

任务书假设贴图是字符串名（如 `"Button_AlliedAntiInfantryInfantry_on"`）。**官渡脚本不是这样**：

`114–143_asset.txt` 共 30 个文件，每个都把一张 **base64 内嵌图** 解成贴图对象，然后包成 `exPackedTextureImageCreate` 的返回对象存进一个**全局变量**，全部尺寸一致：

```lua
-- 以 131_asset.txt（BangRole_Lord）为例，30 个文件结构完全相同
if BangRole_Lord == nil then
    local compression = 'DXT5'
    local generateMips = 0
    local textureId = exTextureCreateFromBase64(base64, compression, generateMips)

    BangRole_Lord = exPackedTextureImageCreate({
        Texture = textureId,
        -- 贴图在纹理中的位置
        CoordsX = 1, CoordsY = 1,
        -- 贴图的尺寸
        DimensionsX = 104, DimensionsY = 104,
        -- 源纹理的尺寸
        TextureDimensionsX = 104, TextureDimensionsY = 104,
        -- 旋转角度
        Rotated = 0
    })
end
```

所以 `exCreateCustomButtonForPlayer` 的 `TextureName` 字段**实际收到的是贴图对象句柄，不是字符串**（原生 API 名字叫 `TextureName` 但接受对象）。移植时：要么把这 30 个 base64 资产整体搬过去，要么换成原生字符串贴图名（教程 `:609` 用的是 `"Button_AlliedAntiInfantryInfantry_on"`）——**两者不能混用**。

**全局变量名 ↔ 资产文件对照表**（全部 `104 × 104`、`DXT5`、`generateMips = 0`、`Rotated = 0`）：

| 全局名 | 资产文件 | 被谁引用 |
|---|---|---|
| `Unknown` | `128_asset.txt` | `BangGetDefaultIcon()`（默认兜底） |
| `X` | `125_asset.txt` | `BangGetCloseIcon()`（优先） |
| `Exit_icon` | `117_asset.txt` | `BangGetCloseIcon()` 兜底、`BangGetBackIcon()` |
| `BangRole_Lord` | `131_asset.txt` | `BangGetRoleIcon("主公")` |
| `BangRole_Loyalist` | `134_asset.txt` | `BangGetRoleIcon("忠臣")` |
| `BangRole_Rebel` | `121_asset.txt` | `BangGetRoleIcon("反贼")` |
| `BangRole_Traitor` | `129_asset.txt` | `BangGetRoleIcon("内奸")` |
| `Action_Alliance` | `123_asset.txt` | `BangActions[1].icon` |
| `Action_Attack` | `122_asset.txt` | `BangActions[2].icon` |
| `Action_Under_Attack` | `138_asset.txt` | `BangActions[3].icon` |
| `Action_Prepare_Attack` | `143_asset.txt` | `BangActions[4].icon` |
| `Action_Group_Attack` | `116_asset.txt` | `BangActions[5].icon` |
| `Action_Protect` | `135_asset.txt` | `BangActions[6].icon` |
| `Action_Truce` | `132_asset.txt` | `BangActions[7].icon` |
| `Color_Blue` | `120_asset.txt` | `BangGetColorIconByName("蓝色")` |
| `Color_Cyan` | `130_asset.txt` | `BangGetColorIconByName("青色")` |
| `Color_Green` | `114_asset.txt` | `BangGetColorIconByName("绿色")` |
| `Color_Orange` | `139_asset.txt` | `BangGetColorIconByName("橙色")` |
| `Color_Purple` | `136_asset.txt` | `BangGetColorIconByName("紫色")` |
| `Color_Red` | `142_asset.txt` | `BangGetColorIconByName("红色")` |
| `Color_Yellow` | `115_asset.txt` | `BangGetColorIconByName("黄色")` |
| `Shop_icon` / `Ally` / `Set_icon` / `Ceasefire` / `Attack` / `Underattack` / `Lordunderattack` / `Protect` / `Attacktogether` | `118/124/126/127/137/119/133/140/141_asset.txt` | **本脚本未引用**（上一版遗留） |

**两个未定义的全局（活证据）**：`BangGetColorIconByName` 里还引用了 `Orange` 和 `Color_purple`（小写 p），
但 30 个资产文件里**没有这两个全局**，全仓库也搜不到定义 ⇒ 它们在运行时是 `nil`，
`BangGetTexture` 的兜底链会把它们跳过，最终落到 `BangGetDefaultIcon()`（即 `Unknown`）。
「橙色」「紫色」两个色块图标因此**实际显示为 Unknown 默认图**，不是 Orange/Purple 图。

### 2.2 各 `BangGet*` 贴图函数（`145:29-59, 386-407`）

```lua
function BangGetTexture(texture_value, fallback)
    if texture_value ~= nil then
        return texture_value
    end
    return fallback
end

function BangGetDefaultIcon()
    return Unknown
end

function BangGetCloseIcon()
    return BangGetTexture(X, Exit_icon)      -- 优先 X；X 为 nil 时用 Exit_icon
end

function BangGetBackIcon()
    return Exit_icon                          -- 返回键固定 Exit_icon
end

function BangGetRoleIcon(role)
    if role == "主公" then
        return BangRole_Lord
    elseif role == "忠臣" then
        return BangRole_Loyalist
    elseif role == "反贼" then
        return BangRole_Rebel
    elseif role == "内奸" then
        return BangRole_Traitor
    end
    return BangGetDefaultIcon()
end
```

```lua
function BangGetColorIconByName(color_name)
    if color_name == "蓝色" then
        return BangGetTexture(Color_Blue, BangGetDefaultIcon())
    elseif color_name == "青色" then
        return BangGetTexture(Color_Cyan, BangGetDefaultIcon())
    elseif color_name == "绿色" then
        return BangGetTexture(Color_Green, BangGetDefaultIcon())
    elseif color_name == "橙色" then
        return BangGetTexture(Color_Orange, BangGetTexture(Orange, BangGetDefaultIcon()))
    elseif color_name == "紫色" then
        return BangGetTexture(Color_Purple, BangGetTexture(Color_purple, BangGetDefaultIcon()))
    elseif color_name == "红色" then
        return BangGetTexture(Color_Red, BangGetDefaultIcon())
    elseif color_name == "黄色" then
        return BangGetTexture(Color_Yellow, BangGetDefaultIcon())
    end
    return BangGetDefaultIcon()
end

function BangGetPlayerColorIcon(index)
    return BangGetColorIconByName(ColorForPlayer[index])
end
```

### 2.3 `BangMakeColorName` 颜色映射表（`145:374-384`）

**只取 R 通道**（`color[1]`，来自 `exPlayerGetColor` 的第 1 个返回值），精确相等匹配：

| `red` 值 | 返回名字 |
|---|---|
| `50` | `"蓝色"` |
| `230` | `"红色"` |
| `237` | `"黄色"` |
| `225` | `"橙色"` |
| `20` | `"绿色"` |
| `125` | `"紫色"` |
| `102` | `"青色"` |
| 其他 | `"未知"` |

```lua
function BangMakeColorName(color)
    local red = color[1]
    if red == 50 then return "蓝色" end
    if red == 230 then return "红色" end
    if red == 237 then return "黄色" end
    if red == 225 then return "橙色" end
    if red == 20 then return "绿色" end
    if red == 125 then return "紫色" end
    if red == 102 then return "青色" end
    return "未知"
end
```

`ColorForPlayer` 的构建（`145:448-457`）：

```lua
ColorForPlayer = {}
function BangInitColors()
    local i
    for i = 1, player_count do
        local color, count = exPlayerGetColor(BangGetPlayerName(i))   -- 第 2 个返回值 count 被丢弃
        ColorForPlayer[i] = BangMakeColorName(color)
    end
end
BangInitColors()
```

> 注意 `ColorForPlayer` 存的是**中文颜色名**（`"红色"`），不是 RGB。它在 UI 里被当**文字**直接拼进 label / 标题 / 计分板，又被 `BangGetPlayerColorIcon` 当**查表键**去取色块图标。

---

## 3. UI 建面板（API 层）

### 3.1 依赖的原生 API 与参数表（原样）

**创建按钮 —— `exCreateCustomButtonForPlayer(playerName, config)`**（`84_code.txt:77`；参数表 `145:790-799`）：

```lua
button_id = exCreateCustomButtonForPlayer(player_name, {
    Index = index,
    TextureName = texture,      -- ★ 传的是贴图对象（见 §2.1），不是字符串
    Desc = desc,
    X = x,
    Y = y,
    GroupIndex = BangUi.group_index,
    AlignX = "left",
    AlignY = "top"
})
```

- 教程 `:596` 明确：**自定义按钮每个按钮大小是 50（50×50 像素）**。
- 教程 `:606`：**后续创建同一个 index 的按钮会销毁之前的按钮再新建**。
- 返回值：`button_id`，失败为 `0`；本脚本按 `nil / 0 / 正数` 三态区分（见 §3.3）。
- `AlignX ∈ {"left","right"}`、`AlignY ∈ {"top","bottom"}`，都传了才是相对屏幕边距（已考虑黑边），不传是绝对坐标（教程 `:598-604`）。

**创建按钮（全局版）—— `exCreateCustomButton(config)`**（`84_code.txt:84`；唯一调用点 `145:1156-1165`，不带 `player_name`）。

**创建文本 —— `exCreateCustomTextForPlayer(playerName, config)`**（`85_code.txt:79`；参数表 `145:830-839`）：

```lua
exCreateCustomTextForPlayer(player_name, {
    Index = index,
    Content = text,
    X = x,
    Y = y,
    Color = BangUiGetWhiteTextColor(),   -- ★ 数字（十进制颜色值），不是 Color 表
    Size = size,
    AlignX = "left",
    AlignY = "top"
})
```

其中（`145:812-817`）：

```lua
function BangUiGetWhiteTextColor()
    if ColorEnum ~= nil and ColorEnum.WHITE ~= nil and ColorEnum.WHITE.dec_value ~= nil then
        return ColorEnum.WHITE.dec_value
    end
    return 16777215                       -- = 0xFFFFFF 兜底
end
```

**文本更新三件套**（全部原生、全部 `ForPlayer`）：

| 用途 | 原生 API | 调用处 |
|---|---|---|
| 改文字 | `exCustomTextUpdateTextForPlayer(player_name, index, text)` | `145:918`（经 `CustomTextModule.update_text`） |
| 改位置 | `exCustomTextUpdatePosForPlayer(player_name, index, x, y, "left", "top")` | `145:929`（经 `CustomTextModule.update_pos`） |
| 改可见性 | `exCustomTextUpdateVisibilityForPlayer(player_name, index, visible)` | `145:904`（**直接调原生，绕过模块**） |

**按钮删除 / 可见性**：

| 用途 | 原生 API | 调用处 |
|---|---|---|
| 删按钮（逐玩家） | `exCustomBtnRemoveForPlayer(player_name, index)` | `145:847` |
| 删按钮（全局兜底） | `exCustomBtnRemove(index)` | `145:849`、`145:1152` |
| 设按钮可见（逐玩家） | `exCustomBtnSetVisibilityForPlayer(player_name, index, 1)` | `145:880`、`145:899`、`145:1143` |

> `exCustomBtnRemoveForPlayer` 官方教程里没有，但 DSA 自走棋地图用了 31 处，**确认可用**（见 `ALittlePlot/docs/11-三国杀模式方案.md:780`）。
> **注意降级路径**：`exCustomBtnRemoveForPlayer` 若不存在会退化为 `exCustomBtnRemove(index)` —— 那是**全局删除**，会把这个 index 上所有玩家的按钮一起删掉。移植时别留这个兜底。

**用到但不在 UI 层的原生 API**（结盟/身份相关）：`ExecuteAction("PLAYER_RELATES_PLAYER", a, b, rel)`、`exPlayerGetRelationShip(a, b)`、`exPlayerGetColor(name)`、`SetWorldBuilderThisPlayer(n)`、`exAddTextToPublicBoard(msg, sec)`、`exAddTextToPublicBoardForPlayer(name, msg, sec)`、`exScoreBoardSetVisibilityForPlayer / SetTitleForPlayer / SetTextForPlayer`。

**用到的 LuaLib 模块方法**：

| 模块 | 方法 | 用途 |
|---|---|---|
| `CustomTextModule`（85） | `create_text(index, content, x, y, color_table, size, align_x, align_y, player_name)` | 建文本（`color_table` 要 `.dec_value`） |
| | `update_text(index, content, player_name)` | 改文本 |
| | `update_pos(index, x, y, align_x, align_y, player_name)` | 改位置 |
| `ColorEnum`（26） | `ColorEnum.WHITE`（`.dec_value` = 16777215） | 文本颜色 |
| `AllegianceModule`（30） | `set_allegiance_single_way` / `set_allegiance_both_way` | 结盟（见 §6） |
| `LoggerModule` | `error(where, msg)` | 各模块入参校验 |
| `SchedulerModule` | `delay_call(assignRoles, 150, {})` | 开局 150 tick 后发身份 |
| `RandomHelper` | `shuffle(list)` / `random_range_int(a, b)` | 洗牌发角色/位置 |
| `UnitHelper` | `get_unit_auto_name()` | 建基地车命名 |
| Lua 兼容全局 | `getn` / `tinsert` / `tremove` / `mod` / `floor` / `format` / `strsub` | Lua 4/5.0 风格，日冕环境自带；**移植到别的引擎要自己补** |

### 3.2 逐函数实现

#### `BangUiCreateButtonForPlayer(player_name, index, texture, desc, x, y)`（`145:781-810`，30 行）

```lua
function BangUiCreateButtonForPlayer(player_name, index, texture, desc, x, y)
    local button_id
    if texture == nil then
        BangDebug("button skipped nil texture player=" .. player_name .. " index=" .. index .. " desc=" .. BangDebugValue(desc))
        return
    end
    if desc == nil then
        desc = ""
    end
    button_id = exCreateCustomButtonForPlayer(player_name, {
        Index = index,
        TextureName = texture,
        Desc = desc,
        X = x,
        Y = y,
        GroupIndex = BangUi.group_index,
        AlignX = "left",
        AlignY = "top"
    })
    if button_id == nil then
        BangDebug("button create nil player=" .. player_name .. " index=" .. index .. " texture=" .. texture)
        return
    end
    if button_id == 0 then
        BangDebug("button created zero player=" .. player_name .. " index=" .. index .. " texture=" .. texture)
        return 1, nil
    end
    BangDebug("button created player=" .. player_name .. " index=" .. index .. " texture=" .. texture .. " id=" .. button_id)
    return 1, 1
end
```

**返回值契约（三态，移植必须照抄）**：

| 情况 | 返回 | 含义 |
|---|---|---|
| `texture == nil` | `nil, nil` | 没建 |
| 原生返回 `nil` | `nil, nil` | 建失败 |
| 原生返回 `0` | `1, nil` | **建出来了但不能更新属性**（`can_update = nil`） |
| 原生返回正数 id | `1, 1` | 建好且可更新 |

#### `BangUiCreateTextForPlayer(player_name, index, text, x, y, size)`（`145:819-843`，25 行）

```lua
function BangUiCreateTextForPlayer(player_name, index, text, x, y, size)
    if text == nil then
        text = ""
    end
    if CustomTextModule ~= nil and ColorEnum ~= nil and ColorEnum.WHITE ~= nil then
        BangDebug("text create module player=" .. player_name .. " index=" .. index)
        CustomTextModule.create_text(index, text, x, y, ColorEnum.WHITE, size, "left", "top", player_name)
        return 1
    end
    if exCreateCustomTextForPlayer ~= nil then
        BangDebug("text create raw player=" .. player_name .. " index=" .. index)
        exCreateCustomTextForPlayer(player_name, {
            Index = index,
            Content = text,
            X = x,
            Y = y,
            Color = BangUiGetWhiteTextColor(),
            Size = size,
            AlignX = "left",
            AlignY = "top"
        })
        return 1
    end
    BangDebug("text skipped no text api player=" .. player_name .. " index=" .. index)
end
```

**双通道设计**：优先走 `CustomTextModule`（带 `ColorEnum` 表），模块不可用时退回裸原生 API（把颜色摊平成数字）。两条路都必须能用，因为原生分支**拿不到创建结果**（无返回值），所以一律乐观返回 `1`。

#### `BangUiRemoveButtonForPlayer(player_name, index)`（`145:845-857`，13 行）

```lua
function BangUiRemoveButtonForPlayer(player_name, index)
    if exCustomBtnRemoveForPlayer ~= nil then
        exCustomBtnRemoveForPlayer(player_name, index)
    elseif exCustomBtnRemove ~= nil then
        exCustomBtnRemove(index)                  -- ★ 全局删除，会波及别的玩家
    end
    if BangUi.created_buttons ~= nil and BangUi.created_buttons[player_name] ~= nil then
        BangUi.created_buttons[player_name][index] = nil
    end
    if BangUi.button_can_update ~= nil and BangUi.button_can_update[player_name] ~= nil then
        BangUi.button_can_update[player_name][index] = nil
    end
end
```

#### `BangUiCreateTrackedButtonForPlayer(player_name, index, texture, desc, x, y)`（`145:859-884`，26 行）

```lua
function BangUiCreateTrackedButtonForPlayer(player_name, index, texture, desc, x, y)
    local created
    local can_update
    if BangUi.created_buttons == nil then BangUi.created_buttons = {} end
    if BangUi.button_can_update == nil then BangUi.button_can_update = {} end
    if BangUi.created_buttons[player_name] == nil then BangUi.created_buttons[player_name] = {} end
    if BangUi.button_can_update[player_name] == nil then BangUi.button_can_update[player_name] = {} end
    BangUiRemoveButtonForPlayer(player_name, index)          -- ★ 先删同 index 旧按钮
    created, can_update = BangUiCreateButtonForPlayer(player_name, index, texture, desc, x, y)
    if created == 1 then
        BangUi.created_buttons[player_name][index] = 1
        BangUi.button_can_update[player_name][index] = can_update
        if can_update == 1 then
            exCustomBtnSetVisibilityForPlayer(player_name, index, 1)
        end
    end
    return created, can_update
end
```

#### `BangUiSetButtonVisible(player_name, index, visible)`（`145:886-900`，15 行）

```lua
function BangUiSetButtonVisible(player_name, index, visible)
    if BangUi.created_buttons == nil then return end
    if BangUi.created_buttons[player_name] == nil or BangUi.created_buttons[player_name][index] ~= 1 then
        return
    end
    if BangUi.button_can_update == nil or BangUi.button_can_update[player_name] == nil or BangUi.button_can_update[player_name][index] ~= 1 then
        if visible == 0 or visible == false or visible == nil then
            BangUiRemoveButtonForPlayer(player_name, index)   -- 不可更新的按钮只能靠"删"来隐藏
        end
        return
    end
    exCustomBtnSetVisibilityForPlayer(player_name, index, visible)
end
```

#### `BangUiSetTextVisible(player_name, index, visible)`（`145:902-907`，6 行）

```lua
function BangUiSetTextVisible(player_name, index, visible)
    if exCustomTextUpdateVisibilityForPlayer ~= nil then
        exCustomTextUpdateVisibilityForPlayer(player_name, index, visible)   -- 传 0/1 数字
        return
    end
end
```

#### `BangUiSetText(player_name, index, text)`（`145:909-921`，13 行）

```lua
function BangUiSetText(player_name, index, text)
    if text == nil then text = "" end
    if CustomTextModule ~= nil then
        CustomTextModule.update_text(index, text, player_name)
        return
    end
    if exCustomTextUpdateTextForPlayer ~= nil then
        exCustomTextUpdateTextForPlayer(player_name, index, text)
        return
    end
end
```

#### `BangUiSetTextPos(player_name, index, x, y)`（`145:923-932`，10 行）

```lua
function BangUiSetTextPos(player_name, index, x, y)
    if CustomTextModule ~= nil then
        CustomTextModule.update_pos(index, x, y, "left", "top", player_name)
        return
    end
    if exCustomTextUpdatePosForPlayer ~= nil then
        exCustomTextUpdatePosForPlayer(player_name, index, x, y, "left", "top")
        return
    end
end
```

#### `BangUiEnsureTextForPlayer(player_name, index, text, x, y, size)`（`145:934-952`，19 行）

```lua
function BangUiEnsureTextForPlayer(player_name, index, text, x, y, size)
    local created
    if BangUi.created_texts == nil then BangUi.created_texts = {} end
    if BangUi.created_texts[player_name] == nil then BangUi.created_texts[player_name] = {} end
    if BangUi.created_texts[player_name][index] == 1 then
        BangUiSetText(player_name, index, text)        -- 已存在 → 只改文字
        BangUiSetTextPos(player_name, index, x, y)     -- + 改位置
        return 1
    end
    created = BangUiCreateTextForPlayer(player_name, index, text, x, y, size)
    if created == 1 then
        BangUi.created_texts[player_name][index] = 1
    end
    return created
end
```

> **注意**：`size` 只在新建时生效，**更新路径改不了字号**。所以标题槽 1151（size 22）和提示槽 1152（size 14）在 `BangUiCreateForPlayer` 里先建一次定死字号，后面全靠 `Ensure` 改字。

#### `BangUiCreateAll` / `BangUiForPlayer`（`145:977-1006`）

```lua
function BangUiCreateAll()
    local i
    BangUiInstallHandler()
    BangUi.created_buttons = {}
    BangUi.button_can_update = {}
    BangUi.created_texts = {}
    BangDebug("ui create all viewers=" .. BangGetHumanViewerCount() .. " identity_index=" .. BangUi.identity_button_index)
    for i = 1, BangGetHumanViewerCount() do
        BangDebug("ui create loop player=" .. BangGetPlayerName(i) .. " role=" .. BangDebugValue(player_status.roles[i]) .. " icon=" .. BangDebugIsSet(BangGetRoleIcon(player_status.roles[i])))
        BangUiCreateForPlayer(i)
    end
end

function BangUiCreateForPlayer(player_index)
    local player_name = BangGetPlayerName(player_index)
    local role = player_status.roles[player_index]
    local icon = BangGetRoleIcon(role)
    BangUi.created_buttons[player_name] = {}
    BangUi.button_can_update[player_name] = {}
    BangUi.created_texts[player_name] = {}
    BangDebugForPlayer(player_name, "ui create player=" .. player_name .. " role=" .. BangDebugValue(role) .. " icon=" .. BangDebugIsSet(icon) .. " Lord=" .. BangDebugIsSet(Lord) .. " Loyalist=" .. BangDebugIsSet(Loyalist) .. " Rebel=" .. BangDebugIsSet(Rebel) .. " Traitor=" .. BangDebugIsSet(Traitor) .. " Unkonwn=" .. BangDebugIsSet(Unkonwn))
    BangUiCreateTrackedButtonForPlayer(player_name, BangUi.identity_button_index, icon, "身份：" .. role .. "\n点击打开身份面板", 22, 96)
    BangUiSetButtonVisible(player_name, BangUi.identity_button_index, 1)
    BangUiEnsureTextForPlayer(player_name, BangUi.title_text_index, "身份面板", 120, 78, 22)
    BangUiEnsureTextForPlayer(player_name, BangUi.hint_text_index, "选择玩家，或选择行动。", 120, 104, 14)
    BangUiSetTextVisible(player_name, BangUi.title_text_index, 0)
    BangUiSetTextVisible(player_name, BangUi.hint_text_index, 0)
    BangUi.panel_state[player_index] = "closed"
    BangUi.selected_target[player_index] = nil
end
```

- 只给**真人玩家**建 UI：`BangGetHumanViewerCount()` = `min(player_count, 6)`（`145:637-642`）。
- 观众数另一条线：`BangGetScoreBoardViewerCount()` 恒等于 **6**（`145:644-646`），与上面不同名不同值，别搞混。
- 身份按钮：`index 1101`，贴图 `BangGetRoleIcon(role)`，`desc = "身份：" .. role .. "\n点击打开身份面板"`，坐标 **`(22, 96)`**。
- 标题/提示文本先建后**立刻隐藏**（`SetTextVisible(..., 0)`），等打开面板才显示。
- 注意 debug 串里引用了 `Lord / Loyalist / Rebel / Traitor / Unkonwn`（拼写错误）五个全局——**这些在 145 号脚本里都不存在**（角色图已改名 `BangRole_*`），所以那段只是永远打印 `nil`。

### 3.3 ★ 坐标 / 尺寸 / 字号 / 颜色总表

| 元素 | index | 坐标 `X, Y` | 尺寸或字号 | 贴图 | Desc |
|---|---|---|---|---|---|
| 身份按钮（常驻） | `1101` | **22, 96** | 50×50（引擎固定） | `BangGetRoleIcon(role)` | `"身份："..role.."\n点击打开身份面板"` |
| 观战身份按钮（全局） | `1104` | **22, 160** | 50×50 | `BangGetDefaultIcon()`（`Unknown`） | `BangObserverBuildDesc()` 多行串 |
| 关闭按钮 | `1102` | **650, 82** | 50×50 | `BangGetCloseIcon()` | `""` |
| 返回按钮 | `1103` | **590, 82** | 50×50 | `BangGetBackIcon()`（`Exit_icon`） | `""` |
| 标题文本 | `1151` | **120, 78** | 字号 **22** | — | 白色 `0xFFFFFF` |
| 提示文本 | `1152` | **120, 104** | 字号 **14** | — | 白色 `0xFFFFFF` |
| 玩家按钮 `i` | `1110+i` | `x = 120 + col*82`, `y = 140 + row*92`，`col = mod(i-1,6)`, `row = floor((i-1)/6)` | 50×50，列距 82、行距 92 | `BangGetPlayerColorIcon(i)` | `""` |
| 玩家名标签 `i` | `1160+i` | `x-4, y+56`（即按钮正下方左移 4px） | 字号 **12** | — | 白色 |
| 行动按钮 `i` | `1130+i` | `ax = 160 + col_action*116`, `ay = 170 + row_action*92`，`col_action = mod(i-1,4)`, `row_action = floor((i-1)/4)` | 50×50，列距 116、行距 92 | `BangActions[i].icon` | `""` |
| 行动名标签 `i` | `1180+i` | `ax-8, ay+56`（按钮下方左移 8px） | 字号 **12** | — | 白色 |

- 全部按钮 `GroupIndex = 1100`（`BangUi.group_index`），`AlignX = "left"`、`AlignY = "top"`。
- 全部文本 `AlignX = "left"`、`AlignY = "top"`、`Color = ColorEnum.WHITE.dec_value (= 16777215)`。
- 日冕逻辑分辨率 **1366×768**（见 `DSA_ggz自走棋` 注释），所以 `650` / `160+3*116=508` 这些值都落在屏幕内。换分辨率要重算。

---

## 4. 面板两个页面

### 4.1 玩家列表页 `BangUiShowPlayerList(player_index)`（`145:1044-1068`，25 行）

```lua
function BangUiShowPlayerList(player_index)
    local player_name = BangGetPlayerName(player_index)
    local i
    if not player_status.alive[player_index] then
        return                                  -- ★ 死人开不了面板
    end
    BangUiClearDynamicButtons(player_index)
    BangUiEnsureTextForPlayer(player_name, BangUi.title_text_index, "身份面板：选择玩家", 120, 78, 22)
    BangUiEnsureTextForPlayer(player_name, BangUi.hint_text_index, "点击玩家后选择结盟或发送快捷语句。", 120, 104, 14)
    BangUiSetTextVisible(player_name, BangUi.title_text_index, 1)
    BangUiSetTextVisible(player_name, BangUi.hint_text_index, 1)
    BangUiCreateTrackedButtonForPlayer(player_name, BangUi.close_button_index, BangGetCloseIcon(), "", 650, 82)
    for i = 1, player_count do
        local zero = i - 1
        local col = mod(zero, 6)
        local row = floor(zero / 6)
        local x = 120 + col * 82
        local y = 140 + row * 92
        local label = BangGetPlayerNickname(i) .. "　　　" .. "\n" .. ColorForPlayer[i] .. "\n" .. BangGetDisplayStatus(i, player_index)
        BangUiEnsureTextForPlayer(player_name, BangUiGetPlayerLabelIndex(i), label, x - 4, y + 56, 12)
        BangUiSetTextVisible(player_name, BangUiGetPlayerLabelIndex(i), 1)
        BangUiCreateTrackedButtonForPlayer(player_name, BangUiGetPlayerButtonIndex(i), BangGetPlayerColorIcon(i), "", x, y)
    end
    BangUi.panel_state[player_index] = "players"
end
```

**本页内容清单**：

| 元素 | index | 内容/贴图 | 坐标 |
|---|---|---|---|
| 标题 | `1151` | `"身份面板：选择玩家"`，字号 22 | 120, 78 |
| 提示 | `1152` | `"点击玩家后选择结盟或发送快捷语句。"`，字号 14 | 120, 104 |
| 关闭按钮 | `1102` | `BangGetCloseIcon()` | 650, 82 |
| 玩家按钮 × `player_count` | `1111..1110+player_count` | `BangGetPlayerColorIcon(i)`（颜色块） | `120+col*82, 140+row*92` |
| 玩家名标签 × `player_count` | `1161..1160+player_count` | `昵称 .. "　　　" .. "\n" .. 颜色名 .. "\n" .. 状态`，字号 12 | `x-4, y+56` |

- 布局是 **6 列 × N 行**（`player_count`=12 时两行）。
- 标签里的 `"　　　"` 是 **3 个全角空格**（U+3000），用来把按钮和文字挤开；`\n` 是真换行，即标签是**三行**：昵称 / 颜色名 / 状态。
- 玩家按钮 `desc = ""`：点了没有任何悬停说明，全靠下面的文字标签。
- 按钮数：**1 + player_count**。

### 4.2 操作页 `BangUiShowActionList(player_index, target_index)`（`145:1070-1097`，28 行）

```lua
function BangUiShowActionList(player_index, target_index)
    local player_name = BangGetPlayerName(player_index)
    local i
    if target_index == player_index then
        exAddTextToPublicBoardForPlayer(player_name, "不能选择自己作为目标", 5)
        return                                   -- ★ 选自己：公屏提示，页面不切换
    end
    BangUi.selected_target[player_index] = target_index
    BangUiClearDynamicButtons(player_index)
    BangUiEnsureTextForPlayer(player_name, BangUi.title_text_index, "目标：" .. BangGetPlayerNickname(target_index) .. "/" .. ColorForPlayer[target_index], 120, 78, 22)
    BangUiEnsureTextForPlayer(player_name, BangUi.hint_text_index, "状态：" .. BangGetDisplayStatus(target_index, player_index), 120, 104, 14)
    BangUiSetTextVisible(player_name, BangUi.title_text_index, 1)
    BangUiSetTextVisible(player_name, BangUi.hint_text_index, 1)
    BangUiCreateTrackedButtonForPlayer(player_name, BangUi.close_button_index, BangGetCloseIcon(), "", 650, 82)
    BangUiCreateTrackedButtonForPlayer(player_name, BangUi.back_button_index, BangGetBackIcon(), "", 590, 82)
    for i = 1, getn(BangActions) do
        local zero_action = i - 1
        local col_action = mod(zero_action, 4)
        local row_action = floor(zero_action / 4)
        local ax = 160 + col_action * 116
        local ay = 170 + row_action * 92
        local label = BangUiGetActionLabel(player_index, target_index, i)
        BangUiEnsureTextForPlayer(player_name, BangUiGetActionLabelIndex(i), label, ax - 8, ay + 56, 12)
        BangUiSetTextVisible(player_name, BangUiGetActionLabelIndex(i), 1)
        BangUiCreateTrackedButtonForPlayer(player_name, BangUiGetActionButtonIndex(i), BangActions[i].icon, "", ax, ay)
    end
    BangUi.panel_state[player_index] = "actions"
end
```

**本页内容清单**：

| 元素 | index | 内容/贴图 | 坐标 |
|---|---|---|---|
| 标题 | `1151` | `"目标：" .. 昵称 .. "/" .. 颜色名`，字号 22 | 120, 78 |
| 提示 | `1152` | `"状态：" .. BangGetDisplayStatus(target, viewer)`，字号 14 | 120, 104 |
| 关闭按钮 | `1102` | `BangGetCloseIcon()` | 650, 82 |
| 返回按钮 | `1103` | `BangGetBackIcon()` | 590, 82 |
| 行动按钮 × 7 | `1131..1137` | `BangActions[i].icon` | `160+col*116, 170+row*92`（4 列 × 2 行） |
| 行动名标签 × 7 | `1181..1187` | `BangUiGetActionLabel(...)`，字号 12 | `ax-8, ay+56` |

**按钮数：2 + 7 = 9**。

**`BangActions` 全表（`145:91-99`）——每个 action 的文字、图标、语义、广播文案**：

| action | `text` | `icon` 全局 | 语义 | `BangBroadcastAction` 广播文案 |
|---|---|---|---|---|
| 1 | `"结盟/解除"` | `Action_Alliance` | **不广播**，走 `BangToggleAlliance` 真实改变关系（§6） | —（由 `BangToggleAlliance` 自己播） |
| 2 | `"我要进攻他"` | `Action_Attack` | 我宣布要打某人 | `"玩家"..name1.."宣布：我要进攻玩家"..name2` |
| 3 | `"他在进攻我"` | `Action_Under_Attack` | 我警告某人正在打我 | `"玩家"..name1.."警告：玩家"..name2.."正在进攻我"` |
| 4 | `"他准备进攻主公"` | `Action_Prepare_Attack` | 提醒全场此人要打主公 | `"玩家"..name1.."提醒全场：玩家"..name2.."准备进攻主公"` |
| 5 | `"一起进攻他"` | `Action_Group_Attack` | 请求集火某人 | `"玩家"..name1.."请求一起进攻玩家"..name2` |
| 6 | `"请求护主"` | `Action_Protect` | 请求大家保护主公（并提防某人） | `"玩家"..name1.."请求大家保护主公，注意玩家"..name2` |
| 7 | `"停战发育"` | `Action_Truce` | 提议停战 | `"玩家"..name1.."向玩家"..name2.."提议停战发育"` |

**`BangUiGetActionLabel(player_index, target_index, action_index)`（`145:967-975`）** —— 唯一动态文案：

```lua
function BangUiGetActionLabel(player_index, target_index, action_index)
    if action_index == 1 then
        if isAllied(player_index, target_index) then
            return "解除结盟"
        end
        return "发起结盟"
    end
    return BangActions[action_index].text
end
```

即按钮 1 的标签在 `"发起结盟"` / `"解除结盟"` 之间切换（判据是 **我→他** 的单向关系，不含反向）。
**注意**：只换文字标签，**按钮贴图永远是 `Action_Alliance`**，不区分状态。

### 4.3 `BangUiClearDynamicButtons` / `BangUiHidePanel` / `BangUiToggle`

`BangUiClearDynamicButtons(player_index)`（`145:1008-1027`，20 行）——「清场」原语，两个页面开头都先调它：

```lua
function BangUiClearDynamicButtons(player_index)
    local player_name = BangGetPlayerName(player_index)
    local i
    BangUiRemoveButtonForPlayer(player_name, BangUi.close_button_index)      -- 1102
    BangUiRemoveButtonForPlayer(player_name, BangUi.back_button_index)       -- 1103
    for i = 1, player_count do
        BangUiRemoveButtonForPlayer(player_name, BangUiGetPlayerButtonIndex(i))   -- 1110+i
        BangUiSetText(player_name, BangUiGetPlayerLabelIndex(i), "")              -- 1160+i 清空
        BangUiSetTextVisible(player_name, BangUiGetPlayerLabelIndex(i), 0)        -- 并隐藏
    end
    for i = 1, getn(BangActions) do
        BangUiRemoveButtonForPlayer(player_name, BangUiGetActionButtonIndex(i))   -- 1130+i
        BangUiSetText(player_name, BangUiGetActionLabelIndex(i), "")              -- 1180+i 清空
        BangUiSetTextVisible(player_name, BangUiGetActionLabelIndex(i), 0)        -- 并隐藏
    end
    BangUiSetText(player_name, BangUi.title_text_index, "")                   -- 1151 清空
    BangUiSetText(player_name, BangUi.hint_text_index, "")                    -- 1152 清空
    BangUiSetTextVisible(player_name, BangUi.title_text_index, 0)
    BangUiSetTextVisible(player_name, BangUi.hint_text_index, 0)
end
```

**它清理什么、不清理什么**（关键）：

| 清理 | 不清理 |
|---|---|
| `1102` 关闭、`1103` 返回 | **`1101` 身份按钮**（永远留着） |
| `1111..1110+player_count` 玩家按钮 + 对应标签文本（清空并隐藏） | **`1104` 观战按钮**（全局按钮，不走 ForPlayer） |
| `1131..1137` 行动按钮 + 对应标签文本（清空并隐藏） | |
| `1151` / `1152` 标题与提示（清空并隐藏） | |

**文本是"清空 + 隐藏"，不是删除**（文本没有删除 API，只能复用 index 改内容）。按钮是**真删除**。

```lua
function BangUiHidePanel(player_index)          -- 145:1038-1042
    BangUiClearDynamicButtons(player_index)
    BangUi.panel_state[player_index] = "closed"
    BangUi.selected_target[player_index] = nil
end

function BangUiToggle(player_index)             -- 145:1099-1105
    if BangUi.panel_state[player_index] == "closed" or BangUi.panel_state[player_index] == nil then
        BangUiShowPlayerList(player_index)
    else
        BangUiHidePanel(player_index)
    end
end
```

`BangUiToggle` 是**二态开关**：只要不是 `"closed"`/`nil`（也就是 `"players"` 或 `"actions"`）都当"打开"处理 → 隐藏。所以**在操作页点身份按钮是直接关面板，不是返回上一页**。

`BangUiHandleAction(player_index, action_index)`（`145:1107-1119`，13 行）：

```lua
function BangUiHandleAction(player_index, action_index)
    local target_index = BangUi.selected_target[player_index]
    if target_index == nil then
        BangUiShowPlayerList(player_index)      -- 兜底：没有目标就回列表页
        return
    end
    if action_index == 1 then
        BangToggleAlliance(player_index, target_index)     -- 真实改关系
    else
        BangBroadcastAction(player_index, target_index, action_index)  -- 只广播
    end
    BangUiShowActionList(player_index, target_index)       -- ★ 原地重绘本页
end
```

### 4.4 `BangUiInstallHandler`（`145:1029-1036`，8 行）—— 事件钩子的接管

```lua
function BangUiInstallHandler()
    if BangUi.handlers_installed ~= nil then
        return
    end
    BangUi.previous_custom_button_click = onCustomBtnClickEvent
    onCustomBtnClickEvent = BangOnCustomBtnClickEvent
    BangUi.handlers_installed = 1
end
```

**链式接管**：把别人（可能地图里另一个脚本）设置的 `onCustomBtnClickEvent` 存起来，自己顶上；没处理的分支再转发回去（§5）。这是**同一张图多个 UI 脚本共存**的必备手法，移植时务必保留。

---

## 5. 点击路由 `BangOnCustomBtnClickEvent(player_name, index, left_mouse_down)`

### 5.1 全文（`145:1176-1202`，27 行）

```lua
function BangOnCustomBtnClickEvent(player_name, index, left_mouse_down)
    local player_index = BangGetPlayerIndex(player_name)
    local handled = nil
    if left_mouse_down == 0 then
        handled = 1                                   -- ★ 非左键：吞掉，不做任何事
    elseif player_index ~= nil then
        if index == BangUi.identity_button_index then                 -- 1101
            BangUiToggle(player_index)
            handled = 1
        elseif index == BangUi.close_button_index then                -- 1102
            BangUiHidePanel(player_index)
            handled = 1
        elseif index == BangUi.back_button_index then                 -- 1103
            BangUiShowPlayerList(player_index)
            handled = 1
        elseif index > BangUi.player_button_index_start and index <= BangUi.player_button_index_start + player_count then
            BangUiShowActionList(player_index, index - BangUi.player_button_index_start)
            handled = 1
        elseif index > BangUi.action_button_index_start and index <= BangUi.action_button_index_start + getn(BangActions) then
            BangUiHandleAction(player_index, index - BangUi.action_button_index_start)
            handled = 1
        end
    end
    if handled == nil and BangUi.previous_custom_button_click ~= nil then
        BangUi.previous_custom_button_click(player_name, index, left_mouse_down)
    end
end
```

### 5.2 分支表

| 条件 | 动作 | 说明 |
|---|---|---|
| `left_mouse_down == 0` | `handled = 1`，**什么都不做** | 见 §5.3：0 = 非左键。右键被**静默吞掉**，也不转发给上一个 handler |
| `index == 1101` | `BangUiToggle(player_index)` | 身份按钮：开/关面板 |
| `index == 1102` | `BangUiHidePanel(player_index)` | 关闭 |
| `index == 1103` | `BangUiShowPlayerList(player_index)` | 返回列表页 |
| `1110 < index <= 1110 + player_count` | `BangUiShowActionList(player_index, index - 1110)` | **选了第 `index-1110` 个玩家** → 进操作页 |
| `1130 < index <= 1130 + getn(BangActions)` | `BangUiHandleAction(player_index, index - 1130)` | **执行第 `index-1130` 个 action** |
| 其他（含 `player_index == nil`，即观察者点按钮） | 转发 `previous_custom_button_click` | `handled` 仍为 `nil` |

**index 段 ↔ 语义**：
- `1101/1102/1103`：**开关面板**（toggle / close / back）。
- `1111–1110+N`：**选了第几个玩家**（`slot = index - 1110`）。
- `1131–1137`：**执行第几个 action**（`slot = index - 1130`）。
- `1104`（观战按钮）**故意不在路由里** → 点它永远转发给上游，面板不响应。

**边界细节**：两处都用严格 `>` 比较基数，所以 `1110`、`1130` 本身是空号；上界用 `<=`，`1110+player_count`、`1130+7` 都是合法的。

### 5.3 `left_mouse_down` 的语义与陷阱

- LuaLib 源码自带注释（`84_code.txt:395-396`）：
  > `自定义按钮点击事件函数 新增鼠标左键是否按下的参数isLeftMouse  1表示鼠标左键按下了，0表示鼠标左键没有按下`
- 官方教程（`教程.lua:759`）只写了 **两个参数** `function onCustomBtnClickEvent(playerName, index)`，**第三个参数是日冕扩展、官方文档没写**。
- **陷阱**：`CustomButtonModule.register_click_event(func)`（`84_code.txt:376-392`）会把原生数字参数**包装成布尔**再转给回调：

  ```lua
  globals().onCustomBtnClickEvent = function(player_name, index, left_mouse_down)
      local is_left_mouse_down = false
      if left_mouse_down == 1 then
          is_left_mouse_down = true
      end
      %func(player_name, index, is_left_mouse_down)
  end
  ```

  官渡脚本是**裸赋值** `onCustomBtnClickEvent = BangOnCustomBtnClickEvent`（`145:1034`），拿到的是数字 `0/1`，
  所以 `left_mouse_down == 0` 能正确识别右键。
  **如果你的移植体走了 `register_click_event` 包装，回调收到的是 `false`，`false == 0` 为假 → 右键会被当作左键处理**（面板会响应右键）。这是移植时最隐蔽的一个坑。

- 语义上 `0` 不只是"右键"：它是「左键没有按下」→ 也可能涵盖其它触发路径。官渡的做法是**一律静默吞掉**（`handled = 1`，阻断向上一级转发）。

---

## 6. 结盟核心

### 6.1 底层：`PLAYER_RELATES_PLAYER`（`30_code.txt`，74 行全文要点）

```lua
AllegianceEnum = {
    ENEMY = "Enemy",
    NEUTRAL = "Neutral",
    FRIEND = "Friend",
}

--- 设置玩家单向关系 (78)
AllegianceModule.set_allegiance_single_way = function(player_name1, player_name2, allegiance)
    -- 三个参数都做 type ~= "string" 校验，失败 LoggerModule.error 后 return
    ExecuteAction("PLAYER_RELATES_PLAYER", player_name1, player_name2, allegiance)
end

--- 设置玩家双向关系
AllegianceModule.set_allegiance_both_way = function(player_name1, player_name2, allegiance)
    -- 同样的参数校验
    AllegianceModule.set_allegiance_single_way(player_name1, player_name2, allegiance)
    AllegianceModule.set_allegiance_single_way(player_name2, player_name1, allegiance)
end

--- 获取玩家关系
AllegianceModule.get_player_relation = function(player_name1, player_name2)
    local ret = exPlayerGetRelationShip(player_name1, player_name2)
    if ret == 0 then
        return AllegianceEnum.ENEMY
    elseif ret == 1 then
        return AllegianceEnum.NEUTRAL
    elseif ret == 2 then
        return AllegianceEnum.FRIEND
    else
        LoggerModule.error("AllegianceModule.get_player_relation", "invalid player relation")
        return nil
    end
end
```

**方向性结论（源码级）**：`PLAYER_RELATES_PLAYER` 本身是**单向**的——`ExecuteAction("PLAYER_RELATES_PLAYER", A, B, X)` 只改「A 如何看待 B」。双向就是正反各调一次。引擎原生支持单向关系，不需要额外模拟。

### 6.2 `setAlliance` / `isAllied` / `removeAlliance`（`145:307-326`）

```lua
function setAlliance(from_player, to_player)
    player_alliances[from_player][to_player] = true
    local previous = SetWorldBuilderThisPlayer(1)
    AllegianceModule.set_allegiance_single_way(BangGetPlayerName(from_player), BangGetPlayerName(to_player), AllegianceEnum.NEUTRAL)
    SetWorldBuilderThisPlayer(previous)
end

function isAllied(from_player, to_player)
    if player_alliances[from_player] == nil then
        return false
    end
    return player_alliances[from_player][to_player]
end

function removeAlliance(from_player, to_player)
    player_alliances[from_player][to_player] = false
    local previous = SetWorldBuilderThisPlayer(1)
    AllegianceModule.set_allegiance_single_way(BangGetPlayerName(from_player), BangGetPlayerName(to_player), AllegianceEnum.ENEMY)
    SetWorldBuilderThisPlayer(previous)
end
```

**三个必须注意的点**：

1. **「结盟」写的是 `NEUTRAL`，不是 `FRIEND`**。解除写 `ENEMY`。也就是说 UI 上的"结盟"实际是**互不攻击的中立**（不共享视野/不共同作战），不是真正友军。
2. **`SetWorldBuilderThisPlayer(1)` 包夹**：`ExecuteAction` 需要"当前世界建造者玩家"上下文，这里切到 1 号（第一个真人玩家）执行，再切回 `previous`。**没有这层包夹，结盟可能对 UI 操作者以外的玩家不生效**。这是纯原生 API，不在 LuaLib 里。
3. `isAllied` 返回的是**表里存的原始值**（`true` / `false` / `nil`），不是严格布尔：没初始化过的会返回 `nil`（falsy 但 `== false` 为假）。

### 6.3 `BangToggleAlliance(from_index, to_index)`（`145:328-348`，21 行，全文）

```lua
function BangToggleAlliance(from_index, to_index)
    local name1 = getPlayerDisplayName(from_index)
    local name2 = getPlayerDisplayName(to_index)
    local was_reverse = isAllied(to_index, from_index)
    if isAllied(from_index, to_index) then
        removeAlliance(from_index, to_index)
        if was_reverse then
            BangBroadcast("玩家" .. name1 .. "解除了对玩家" .. name2 .. "的结盟，双向结盟已解除")
        else
            BangBroadcast("玩家" .. name1 .. "解除了对玩家" .. name2 .. "的单向结盟")
        end
    else
        setAlliance(from_index, to_index)
        if was_reverse then
            BangBroadcast("玩家" .. name1 .. "和玩家" .. name2 .. "已经双向结盟")
        else
            BangBroadcast("玩家" .. name1 .. "对玩家" .. name2 .. "发起单向结盟")
        end
    end
    BangUpdateAllScoreBoards()
end
```

**逻辑要点**：

- **只动「我→他」一个方向**。别人对我的关系不受影响。
- `was_reverse = isAllied(to_index, from_index)` 在切换**之前**取，用来区分播报文案（单向 / 双向）。
- 判定「双向」= 我→他 **且** 他→我（见 `BangGetDisplayStatus` §7.1）。所以**双向是两次单向的巧合结果**，没有独立字段。
- 结尾 `BangUpdateAllScoreBoards()` 刷新全场计分板。

**单双向的实现路径总结**：

| 目标 | 实现 |
|---|---|
| 单向结盟 A→B | `setAlliance(A,B)` = `ExecuteAction("PLAYER_RELATES_PLAYER","Player_A","Player_B","Neutral")` |
| 双向结盟 A↔B | `setAlliance(A,B)` + `setAlliance(B,A)`（两次单向，UI 上要两个玩家各点一次） |
| 解除单向 A→B | `removeAlliance(A,B)` = 同上但 `"Enemy"` |
| 解除双向 | 同样要点两次（一次解除 A→B，一次解除 B→A） |
| 读实际关系 | `AllegianceModule.get_player_relation(a,b)` → `exPlayerGetRelationShip` → 0/1/2 |
| 读 UI 记录 | `isAllied(a,b)`（读 Lua 表，**可能与引擎真实关系不一致**，见 §6.4） |

### 6.4 ★ `player_alliances` 与引擎真实关系是两套账

- `BangInitPlayers()` 把 `player_alliances` 全部置 `false`，但**没有任何代码执行「把全场玩家两两设为 Enemy」的初始化**。
  只有开场三段，而且**全是对 `PlyrCreeps`（中立怪）**，玩家两两之间一次都没设：
  ① 所有玩家↔`PlyrCreeps` 双向 `ENEMY`（`145:459-461`）；
  ② `LoadSetting(lord_index)`：主公↔`PlyrCreeps` 双向 `FRIEND`（`145:1210-1212`）；
  ③ `LoyalistSetting(第一个忠臣)`：`PlyrCreeps`→忠臣 单向 `FRIEND`（`145:1214-1216`）。
- 也就是说：**开场时玩家的两两真实关系由地图编辑器（WorldBuilder）的 Player 关系决定**，而 Lua 表里一律记 `false`。
  如果地图默认把 1-6 号设为队友，那 UI 显示"未结盟"但实际是友军 —— 两边不一致。
- 移植时必须**显式做一次真实关系初始化**（按身份阵营刷一遍 `PLAYER_RELATES_PLAYER`），否则 UI 状态和战场行为会对不上。
  （本仓库 `ALittlePlot/docs/11-三国杀模式方案.md:470-517` 给出了严格阵营的初始关系表，可参照。）

### 6.5 `BangBroadcastAction`（`145:350-372`，23 行，全文）

```lua
function BangBroadcastAction(from_index, to_index, action_index)
    local name1 = getPlayerDisplayName(from_index)
    local name2 = getPlayerDisplayName(to_index)
    local text = BangActions[action_index].text
    if text == nil then
        return
    end
    if action_index == 2 then
        BangBroadcast("玩家" .. name1 .. "宣布：我要进攻玩家" .. name2)
    elseif action_index == 3 then
        BangBroadcast("玩家" .. name1 .. "警告：玩家" .. name2 .. "正在进攻我")
    elseif action_index == 4 then
        BangBroadcast("玩家" .. name1 .. "提醒全场：玩家" .. name2 .. "准备进攻主公")
    elseif action_index == 5 then
        BangBroadcast("玩家" .. name1 .. "请求一起进攻玩家" .. name2)
    elseif action_index == 6 then
        BangBroadcast("玩家" .. name1 .. "请求大家保护主公，注意玩家" .. name2)
    elseif action_index == 7 then
        BangBroadcast("玩家" .. name1 .. "向玩家" .. name2 .. "提议停战发育")
    else
        BangBroadcast("玩家" .. name1 .. "对玩家" .. name2 .. "发送：" .. text)
    end
end
```

`BangBroadcast`（`145:303-305`）：

```lua
function BangBroadcast(message)
    exAddTextToPublicBoard(message, 10)     -- 公屏，显示 10 秒
end
```

> action 1（结盟）不会走到这里（`BangUiHandleAction` 已经分流给 `BangToggleAlliance`）；`else` 分支是防御性兜底。

---

## 7. 身份展示（观战 / 身份查看）

### 7.1 `BangGetDisplayStatus(index, viewer_index)`（`145:262-288`，27 行，全文）

```lua
function BangGetDisplayStatus(index, viewer_index)
    if viewer_index == nil then
        if player_status.alive[index] then
            return player_status.roles[index] .. "/存活"
        end
        return player_status.roles[index] .. "/死亡"
    end
    if player_status.roles[index] == "主公" then
        if player_status.alive[index] then
            return "主公/存活"
        end
        return "主公/死亡"
    end
    if not player_status.alive[index] then
        return player_status.roles[index] .. "/死亡"
    end
    if index == viewer_index then
        return "你:" .. player_status.roles[index]
    end
    if isAllied(viewer_index, index) and isAllied(index, viewer_index) then
        return "双向盟友"
    end
    if isAllied(viewer_index, index) then
        return "单向盟友"
    end
    return "存活"
end
```

**判定优先级（严格按序，先命中先返回）**：

1. `viewer_index == nil`（观战视角）→ `角色/存活` 或 `角色/死亡`，**信息全公开**
2. 目标是主公 → `主公/存活` 或 `主公/死亡`（主公身份永远公开）
3. 目标已死 → `角色/死亡`（死后身份公开 —— 这是三国杀的标准规则）
4. 目标是查看者自己 → `你:角色`
5. `我→他` **且** `他→我` → `"双向盟友"`
6. 只有 `我→他` → `"单向盟友"`
7. 其他 → `"存活"`（**不暴露身份**）

**注意 5/6 的方向语义**：显示"单向盟友"的条件是**「我→他」有记录**（我看他像盟友）。所以**别人对我单向结盟时，我看不到任何标记**，只有我自己能看到我把谁当盟友。这是天然的信息不对称设计。

### 7.2 `lorddeathdisplay` / `getPlayerDisplayName`（`145:290-301`，全文）

```lua
function lorddeathdisplay(player_id)
    if player_status.roles[player_id] == "主公" then
        return "（主公）"
    elseif not player_status.alive[player_id] then
        return "（死亡）"
    end
    return ""
end

function getPlayerDisplayName(pid)
    return BangGetPlayerNickname(pid) .. "/" .. ColorForPlayer[pid] .. lorddeathdisplay(pid)
end
```

`getPlayerDisplayName` 是**广播用的一行式名字**：`昵称/颜色名（主公）`，如 `$p1Name/红色（主公）`。

### 7.3 `RolesShow(player)`（`145:751-763`，13 行，全文）

```lua
function RolesShow(player)
    local player_id = BangGetPlayerIndex(player)
    local i
    if player_id == nil then
        return
    end
    if player_status.alive[player_id] then
        exAddTextToPublicBoardForPlayer(player, "你的身份是：" .. player_status.roles[player_id], 10)
    end
    for i = 1, player_count do
        exAddTextToPublicBoardForPlayer(player, BangGetPlayerNickname(i) .. "/" .. ColorForPlayer[i] .. "：" .. BangGetDisplayStatus(i, player_id), 10)
    end
end
```

**这是「私密身份播报」**：给 `player` 一个人推 `1 + player_count` 行公屏（`exAddTextToPublicBoardForPlayer`，各 10 秒）。
第一行是自己的身份（活着才发），后面每行是全场某人对他而言的可见状态。调用点：`BangAfterRolesAssigned` 里对 `1..player_count` 逐个调（`145:595-597`）。

### 7.4 观战身份按钮（`145:1121-1174`）

注释是原作者留的实测结论，**原文照抄**：

```lua
-- 观察者身份按钮：用全局(非ForPlayer)按钮，把全场身份信息直接写进 Desc。
-- 按钮默认对所有玩家(含观察者)可见，再对玩家1-6用ForPlayer隐藏，将其"取消"。
-- 因为 Desc 似乎无法实时更新，所以在玩家死亡时删除旧按钮并重建以刷新身份信息。
```

```lua
function BangObserverBuildDesc()                    -- 145:1124-1135，12 行
    local result = "观察者身份信息："
    local i
    for i = 1, player_count do
        local state = "存活"
        if not player_status.alive[i] then
            state = "死亡"
        end
        result = result .. "\n" .. BangGetPlayerNickname(i) .. "/" .. ColorForPlayer[i] .. "/" .. player_status.roles[i] .. "/" .. state
    end
    return result
end

function BangObserverHideButtonForPlayers()         -- 145:1137-1147，11 行
    local i
    for i = 1, 6 do
        if i <= player_count then
            local name = BangGetPlayerName(i)
            if exCustomBtnSetVisibilityForPlayer ~= nil then
                exCustomBtnSetVisibilityForPlayer(name, BangUi.observer_button_index, 0)
            end
        end
    end
end

function BangObserverCreateButton()                 -- 145:1149-1169，21 行
    -- 先删除旧按钮(同index再次创建会替换，这里显式删除更稳妥)
    if exCustomBtnRemove ~= nil then
        exCustomBtnRemove(BangUi.observer_button_index)
    end
    -- 全局按钮：先对所有玩家(含观察者)可见
    if exCreateCustomButton ~= nil then
        exCreateCustomButton({
            Index = BangUi.observer_button_index,
            TextureName = BangGetDefaultIcon(),
            Desc = BangObserverBuildDesc(),
            X = 22,
            Y = 160,
            GroupIndex = BangUi.group_index,
            AlignX = "left",
            AlignY = "top"
        })
    end
    -- 再对玩家1-6隐藏全局按钮(取消他们的按钮)，只留观察者可见
    BangObserverHideButtonForPlayers()
end

function BangObserverRefresh()                      -- 145:1171-1174，4 行
    -- 玩家死亡等需要刷新身份信息时，删除旧按钮并重建
    BangObserverCreateButton()
end
```

**设计模式（很有价值，值得照抄）**：

1. 用**全局按钮** `exCreateCustomButton`（不带 `player_name`）→ 默认对**所有**玩家 + 观察者可见。
2. 再对**玩家 1–6** 逐个 `exCustomBtnSetVisibilityForPlayer(name, 1104, 0)` **关掉**。
3. 净效果：**只剩观察者/非玩家视角能看到这个按钮** —— 用「全局创建 + 逐玩家关闭」实现了「只给观察者」的靶向 UI（因为原生 API 没有「给观察者建按钮」的通道）。
4. Desc 是**多行静态串**（`\n` 分隔，共 `1 + player_count` 行）：`昵称/颜色/角色/存活|死亡`，**一次性写入**。
5. 因为 Desc 改不了，刷新 = **删掉重建**（`BangObserverRefresh` → `BangObserverCreateButton`）。
6. 图标用 `BangGetDefaultIcon()`（`Unknown`），坐标 `(22, 160)` —— 就在身份按钮 `(22, 96)` 正下方 64px。

**`BangAfterRolesAssigned` 里的挂载顺序（`145:569-598`）**：

```lua
    BangGameInitialized = 1
    BangUiCreateAll()            -- 先建 1101-1104 之外的面板按钮
    BangObserverCreateButton()   -- 再建全局观战按钮并给 1-6 关掉
    BangUpdateAllScoreBoards()
    for i = 1, player_count do
        RolesShow(BangGetPlayerName(i))
    end
```

---

## 8. 玩家名字显示与 `$p<N>Name` 占位符

### 8.1 `BangGetPlayerName` / `BangGetPlayerIndex` / `BangGetPlayerTeam` / `BangGetPlayerNickname`（`145:184-215`，全文）

```lua
function BangGetPlayerName(index)          -- 座位号 → 引擎玩家脚本名
    if index <= 6 then
        return "Player_" .. index
    end
    local ai_index = index - 6
    if ai_index < 10 then
        return "AIPlayer0" .. ai_index     -- 7→AIPlayer07 ... 9→AIPlayer09
    end
    return "AIPlayer" .. ai_index          -- 10→AIPlayer10 ... 12→AIPlayer12
end

function BangGetPlayerIndex(player_name)   -- 反查，只扫 1..player_count，找不到返回 nil
    local i
    for i = 1, player_count do
        if BangGetPlayerName(i) == player_name then
            return i
        end
    end
    return nil
end

function BangGetPlayerTeam(index)          -- 团队名约定：<玩家名>/team<玩家名>
    local player_name = BangGetPlayerName(index)
    return player_name .. "/team" .. player_name
end

function BangGetPlayerNickname(index)      -- ★ 关键：占位符
    if index <= 6 then
        return "$p" .. index .. "Name"     -- 座位 1-6 → "$p1Name".."$p6Name"
    end
    return BangGetPlayerName(index)        -- 座位 7-12 → "AIPlayer07"（无昵称通道）
end
```

### 8.2 ★ 全脚本「把玩家名字写进 UI / 文本」的地方，按通道分类

**A. 用 `"$p"..index.."Name"` 占位符的**（都是经 `BangGetPlayerNickname`）：

| 位置 | 行 | 通道 | 写法 |
|---|---|---|---|
| 玩家列表页 · 玩家名标签 | `1062` | `exCreateCustomTextForPlayer` 的 **`Content`**（经 `BangUiEnsureTextForPlayer`→`CustomTextModule.create_text`） | `BangGetPlayerNickname(i) .. "　　　" .. "\n" .. ColorForPlayer[i] .. "\n" .. 状态` |
| 操作页 · 标题 | `1079` | 同上（`Content`） | `"目标：" .. BangGetPlayerNickname(target_index) .. "/" .. ColorForPlayer[target_index]` |
| 观战按钮 · `Desc` | `1132` | `exCreateCustomButton` 的 **`Desc`**（全局按钮） | `昵称 .. "/" .. 颜色 .. "/" .. 角色 .. "/" .. 存活状态` |
| 计分板 · 玩家名列 | `707` | `exScoreBoardSetTextForPlayer(..., row, 1)` | `BangGetPlayerNickname(idx)` |
| 计分板 · 双列模式 | `665`（`BangScoreCellText`）、`725/727` | 同上 | `昵称 .. "/" .. 颜色 .. "/" .. 状态` |
| 计分板 · 结盟摘要 | `678`（`BangAllianceSummary`） | 同上 | `昵称i .. "-" .. 昵称j` |
| 公屏 · 身份私密播报 | `761`（`RolesShow`） | `exAddTextToPublicBoardForPlayer` | `昵称 .. "/" .. 颜色 .. "：" .. 状态` |
| 公屏 · 结盟/行动播报 | `329-330, 351-352`（经 `getPlayerDisplayName`） | `exAddTextToPublicBoard` | `昵称/颜色（主公）` |

**B. 不是占位符的**（写的是别的东西）：

| 位置 | 行 | 内容 |
|---|---|---|
| 身份按钮 `Desc` | `998` | `"身份：" .. role .. "\n点击打开身份面板"` —— 只有角色名，**没有玩家名** |
| 关闭/返回/玩家按钮/行动按钮 `Desc` | `1055, 1065, 1083, 1084, 1094` | 全部 `""` 空串 |
| 标题/提示文本 | `1000-1001, 1051-1052, 1080` | 固定中文文案 + 颜色名 + 状态，**没有玩家名**（操作页标题除外，见 A） |
| 玩家名标签里的颜色 | `1062` | `ColorForPlayer[i]` = `"红色"` 等**中文颜色名**，不是玩家名 |
| 角色名 | `998, 1062(状态串), 1132` | `"主公"/"忠臣"/"反贼"/"内奸"` |
| 座位 7-12 的"昵称" | `214` | 直接返回 `"AIPlayer07"` 字符串 —— **AI 座位没有昵称**，占位符和脚本名一致 |
| debug 串 | `575, 984, 997` | `BangGetPlayerName(i)`（脚本名，不是昵称） |

### 8.3 ★ 各通道能否替换 `$p<N>Name` —— 有证据的结论

| 通道 | API | 是否替换 | 证据 |
|---|---|---|---|
| 左下消息区 / 公屏 | `exAddTextToPublicBoard` / `exAddTextToPublicBoardForPlayer` / `exMessageAppendToMessageArea` | **✅ 替换** | `日冕地图lua例子\教程.lua:410`：「左下角消息区,公屏区 新增 支持显示玩家昵称支持昵称，`$p1Name`…`$p6Name` 将被自动替换为对应的玩家昵称（对应 `Player_1`~`Player_6` 的昵称）」 |
| 右上角计分板 | `exScoreBoardSetText` / `exScoreBoardSetTextForPlayer` / `exScoreBoardSetTitle` | **✅ 替换** | `教程.lua:420`：「计分版有 7 行 3 列，标题和文字都支持昵称，`$p1Name`…`$p6Name` 将被自动替换」 |
| **顶部/自定义按钮 `Desc`（悬浮框）** | `exCreateCustomButton` / `exCreateCustomButtonForPlayer` 的 `Desc` | **❌ 不替换**（原样显示 `$p6Name`） | `ALittlePlot/scripts/lua/chouka/00_core/00_alert.lua:74`：「顶部按钮悬浮框 / 对话框 desc 用：这些通道**不替换** `$p<N>Name`（**实测原样显示 `$p6Name`**）」；同结论见 `ALittlePlot/scripts/lua/chouka/70_bang/30_bang_mode.lua:255`：「★ 悬浮框 desc 不替换 `$p<N>Name`（实测原样显示 `$p6Name`）」 |
| **自定义文本 `Content`** | `exCreateCustomTextForPlayer` 的 `Content` | **⚠️ 未知，无实测证据** | 全仓库没有这条通道的昵称实测记录。这是移植时**风险最高的一处**：官渡的玩家列表/操作页标题全靠它显示昵称 |

**取真实昵称的接口现状**：

- 原生 `exGetPlayerNickNameByScriptName(player_name)` 存在，但 LuaLib 的封装 **已被官方删除**：
  `38_code.txt:110-120` 整段被注释，注释语「-- 该功能已被删除」。
- 本仓库移植体的做法（`00_alert.lua:63-101`）：`ChoukaPlayerPlainName(seat)` ——
  优先 `exGetPlayerNickNameByScriptName("Player_"..seat)`，若返回 `nil` / `""` / 以 `"$p"` 开头
  （说明接口退化成了占位符回显）就**缓存 0 并退化成座位号显示**；公屏/计分板那侧则退回 `format("$p%dName", seat)`（那些通道会替换）。

**给官渡移植者的直接建议**：

1. **所有玩家列表页/操作页的玩家名文字，若落在 `Content` 通道且实测不替换，就必须换成真实昵称或座位号**。
2. 保险做法：写一个 `BangUiPlayerLabel(seat)` 统一出口 —— 能拿到真名用真名，拿不到用 `"6 号位"` 这类可读兜底，
   **绝不要把 `$p<N>Name` 直接塞进 Desc**（那里 100% 露出来）。
3. 判据要写死：字符串前两字节是 `"$p"` 就视为"不可用"（`strsub(name, 1, 2) == "$p"`），
   因为接口可能"成功返回"一个占位符而不是 `nil`。

---

## 9. 移植清单

### 9.1 必须带的函数（按体积排序，行号对应 `145_code.txt`）

| # | 函数 | 行区间 | 行数 | 层级 | 移植必要性 |
|---|---|---|---|---|---|
| 1 | `BangOnCustomBtnClickEvent` | 1176–1202 | 27 | 路由 | **必须** |
| 2 | `BangGetDisplayStatus` | 262–288 | 27 | 状态 | **必须** |
| 3 | `BangUiShowActionList` | 1070–1097 | 28 | 页面 | **必须** |
| 4 | `BangUiCreateButtonForPlayer` | 781–810 | 30 | API 层 | **必须** |
| 5 | `BangUiCreateTrackedButtonForPlayer` | 859–884 | 26 | API 层 | **必须** |
| 6 | `BangUiCreateTextForPlayer` | 819–843 | 25 | API 层 | **必须** |
| 7 | `BangUiShowPlayerList` | 1044–1068 | 25 | 页面 | **必须** |
| 8 | `BangInitPlayers` | 409–432 | 24 | 状态 | **必须** |
| 9 | `BangBroadcastAction` | 350–372 | 23 | 播报 | **必须** |
| 10 | `BangToggleAlliance` | 328–348 | 21 | 结盟 | **必须** |
| 11 | `BangObserverCreateButton` | 1149–1169 | 21 | 观战 | **必须** |
| 12 | `BangUiClearDynamicButtons` | 1008–1027 | 20 | 页面 | **必须** |
| 13 | `BangUiEnsureTextForPlayer` | 934–952 | 19 | API 层 | **必须** |
| 14 | `BangGetColorIconByName` | 386–403 | 18 | 贴图 | **必须** |
| 15 | `BangUiCreateForPlayer` | 990–1006 | 17 | 建面板 | **必须** |
| 16 | `BangUiSetButtonVisible` | 886–900 | 15 | API 层 | **必须** |
| 17 | `BangUiCreateAll` | 977–988 | 12 | 建面板 | **必须** |
| 18 | `BangGetRoleIcon` | 48–59 | 12 | 贴图 | **必须** |
| 19 | `BangUiRemoveButtonForPlayer` | 845–857 | 13 | API 层 | **必须** |
| 20 | `BangUiSetText` | 909–921 | 13 | API 层 | **必须** |
| 21 | `BangUiHandleAction` | 1107–1119 | 13 | 页面 | **必须** |
| 22 | `RolesShow` | 751–763 | 13 | 身份 | **必须** |
| 23 | `BangObserverBuildDesc` | 1124–1135 | 12 | 观战 | **必须** |
| 24 | `BangMakeColorName` | 374–384 | 11 | 贴图 | **必须** |
| 25 | `BangObserverHideButtonForPlayers` | 1137–1147 | 11 | 观战 | **必须** |
| 26 | `BangUiSetTextPos` | 923–932 | 10 | API 层 | **必须** |
| 27 | `BangGetPlayerName` | 184–193 | 10 | 名字 | **必须** |
| 28 | `BangGetPlayerIndex` | 195–203 | 9 | 名字 | **必须** |
| 29 | `BangUiGetActionLabel` | 967–975 | 9 | 页面 | **必须** |
| 30 | `BangUiInstallHandler` | 1029–1036 | 8 | 路由 | **必须** |
| 31 | `lorddeathdisplay` | 290–297 | 8 | 身份 | **必须** |
| 32 | `BangGetPlayerNickname` | 210–215 | 6 | 名字 | **必须**（注意 §8.3） |
| 33 | `BangGetPlayerTeam` | 205–208 | 4 | 名字 | 建基地才用 |
| 34 | `setAlliance` | 307–312 | 6 | 结盟 | **必须** |
| 35 | `isAllied` | 314–319 | 6 | 结盟 | **必须** |
| 36 | `removeAlliance` | 321–326 | 6 | 结盟 | **必须** |
| 37 | `BangBroadcast` | 303–305 | 3 | 播报 | **必须** |
| 38 | `getPlayerDisplayName` | 299–301 | 3 | 名字 | **必须** |
| 39 | `BangGetTexture` | 29–34 | 6 | 贴图 | **必须** |
| 40 | `BangUiGetWhiteTextColor` | 812–817 | 6 | API 层 | **必须** |
| 41 | `BangUiSetTextVisible` | 902–907 | 6 | API 层 | **必须** |
| 42 | `BangGetDefaultIcon` | 36–38 | 3 | 贴图 | **必须** |
| 43 | `BangGetCloseIcon` | 40–42 | 3 | 贴图 | **必须** |
| 44 | `BangGetBackIcon` | 44–46 | 3 | 贴图 | **必须** |
| 45 | `BangGetPlayerColorIcon` | 405–407 | 3 | 贴图 | **必须** |
| 46 | `BangObserverRefresh` | 1171–1174 | 4 | 观战 | **必须** |
| 47 | `BangUiHidePanel` | 1038–1042 | 5 | 页面 | **必须** |
| 48 | `BangUiToggle` | 1099–1105 | 7 | 页面 | **必须** |
| 49 | `BangUiGetPlayerButtonIndex` / `GetActionButtonIndex` / `GetPlayerLabelIndex` / `GetActionLabelIndex` | 765–779 | 15 | 索引 | **必须** |
| 50 | 数据表：`BangRoleCountsByPlayerCount` / `BangRoleNames` / `BangActions` / `BangUi` | 8–27, 70–99 | ~50 | 数据 | **必须** |
| 51 | 索引/发角色辅助：`BangGetRoleCounts` / `BangAppendRole` / `BangBuildRoles` / `BangContainsValue` / `BangRemoveValue` | 217–260 | 40 | 开局 | 视需要 |
| 52 | `BangInitColors` + `ColorForPlayer` | 448–457 | 10 | 状态 | **必须**（颜色是 UI 的骨架） |
| 53 | debug 工具：`BangDebug` / `BangDebugForPlayer` / `BangDebugIsSet` / `BangDebugBool` / `BangDebugValue` | 101–132 | 32 | 调试 | 可选（**建议保留**，排障全靠它） |
| 54 | 计分板：`BangInitScoreBoard` / `BangGetScoreBoardViewerCount` / `BangGetScoreBoardDisplayViewerIndex` / `BangScoreCellText` / `BangAllianceSummary` / `BangUpdateScoreBoardForPlayer` / `BangUpdateAllScoreBoards` | 627–749 | ~120 | 面板外 | 视需要（`BangToggleAlliance` 强制依赖 `BangUpdateAllScoreBoards`） |
| 55 | 开局流程：`assignRoles` / `BangAfterRolesAssigned` / `BangAssignPositions` / `showPreferenceDialog` / `onUserBtnChoiceDialogEvent` | 512–625 | ~110 | 面板外 | 视需要 |

**核心 UI 部分（1–50 行）合计约 480 行**（含注释与空行）。加上计分板和开局流程，整个文件 1226 行。

### 9.2 外部依赖清单

**A. LuaLib 模块（必须同时搬）**

| 模块 | 必需方法 | 备注 |
|---|---|---|
| `AllegianceModule.lua`（`30_code.txt`） | `set_allegiance_single_way` / `set_allegiance_both_way` / `get_player_relation` | 74 行，纯封装，可整段抄 |
| `CustomTextModule.lua`（`85_code.txt`） | `create_text` / `update_text` / `update_pos` | 191 行；不搬也行，代码里两条路会自动降级到裸原生 |
| `ColorUtil.lua` → `ColorEnum`（`26_code.txt`） | `ColorEnum.WHITE.dec_value`（= `16777215`） | 只为一处颜色；可以直接写死 `16777215` 省掉整个模块 |
| `LoggerModule.lua` | `error(where, msg)` | 上面三个模块的入参校验都调它 |
| `SchedulerModule.lua` | `delay_call(assignRoles, 150, {})` | 开局发牌用；纯 UI 移植不需要 |
| `RandomHelper.lua`（文件实为 `RamdomHelper.lua`） | `shuffle` / `random_range_int` | 发角色/位置用 |

**B. 原生 API（引擎侧，LuaLib 之外）**

| 分组 | API |
|---|---|
| 按钮 | `exCreateCustomButton`、`exCreateCustomButtonForPlayer`、`exCustomBtnRemove`、`exCustomBtnRemoveForPlayer`、`exCustomBtnSetVisibilityForPlayer` |
| 文本 | `exCreateCustomTextForPlayer`、`exCustomTextUpdateTextForPlayer`、`exCustomTextUpdatePosForPlayer`、`exCustomTextUpdateVisibilityForPlayer` |
| 结盟 | `ExecuteAction("PLAYER_RELATES_PLAYER", a, b, rel)`、`exPlayerGetRelationShip(a, b)` |
| 上下文 | `SetWorldBuilderThisPlayer(n)`（**结盟必需**，成对调用） |
| 颜色 | `exPlayerGetColor(playerName)` → `(R, G, B)` |
| 文本播报 | `exAddTextToPublicBoard(msg, sec)`、`exAddTextToPublicBoardForPlayer(name, msg, sec)` |
| 计分板 | `exScoreBoardSetVisibilityForPlayer`、`exScoreBoardSetTitleForPlayer`、`exScoreBoardSetTextForPlayer` |
| 贴图 | `exTextureCreateFromBase64(base64, compression, generateMips)`、`exPackedTextureImageCreate({Texture, CoordsX, CoordsY, DimensionsX, DimensionsY, TextureDimensionsX, TextureDimensionsY, Rotated})` |
| 名字（不稳定） | `exGetPlayerNickNameByScriptName(playerName)`（LuaLib 封装已被删，见 §8.3） |

**C. Lua 兼容全局（日冕环境自带，换引擎要补）**

`getn` / `tinsert` / `tremove` / `mod` / `floor` / `max` / `min` / `format` / `strsub` / `globals()`（Lua 4/5.0 风格）。官渡脚本大量使用 `mod`、`floor`、`getn`。

**D. 贴图资产（30 个 base64，必须一起搬）**

见 §2.1 对照表，`114_asset.txt` ~ `143_asset.txt`。**没有字符串贴图名可替代**，除非整体换成教程里的原生贴图名。

**E. 地图侧前提**

| 项 | 说明 |
|---|---|
| 玩家座位 | `Player_1`~`Player_6` 真人；`Player_7`~`Player_12` → `AIPlayer07`~`AIPlayer12`（脚本 `BangGetPlayerName` 的约定） |
| 团队名 | `<玩家名>/team<玩家名>`（`BangGetPlayerTeam`） |
| 分辨率 | 1366×768（`X=650`、`Y=170+92=262` 等坐标基于此） |
| 初始关系 | 地图编辑器里的 Player 两两关系会决定真实战场行为，**Lua 表默认全 `false`，两边必须显式对齐**（§6.4） |
| `PlyrCreeps` | 被用来当"中立怪"：全员对其 `ENEMY`（`145:459-461`），主公对其 `FRIEND`（`LoadSetting`），忠臣被其 `FRIEND`（`LoyalistSetting`） |

---

## 附录 A：死代码 / 幽灵引用（别照抄，抄了会困惑）

| 符号 | 行 | 状况 |
|---|---|---|
| `Sentence`（4 组 × 9 句台词表） | `134-182`（49 行） | **全脚本零引用**，纯遗留。移植可整体删除 |
| `BangUiGetVisibleIcon(index, viewer_index)` | `954-965`（12 行） | **零调用**。设计意图是"按可见性选图标"，实际 `BangUiCreateForPlayer` 直接用 `BangGetRoleIcon(role)` |
| `Roles` | `61, 418` | 赋值 `BangBuildRoles()` 后**从未被读** |
| `sellwall` | `65` | 零引用 |
| `BangGameInitialized` | `66, 591` | 只写不读 |
| `Lord_Transfered` | `658` | 外部全局，本文件无定义 → 条件恒假 |
| `Lord` / `Loyalist` / `Rebel` / `Traitor` / `Unkonwn` | `997`（debug 串） | 本文件不存在的全局（已被 `BangRole_*` 取代），永远打印 `nil`；`Unkonwn` 还拼错了 |
| `Orange` / `Color_purple` | `394, 396` | 30 个资产文件里**没有这两个全局** → 运行时 `nil`，"橙色/紫色"色块图实际显示 `Unknown` |

> 顺带一条版本漂移证据：同地图旧版 `[COR]三国杀之官渡之战[2.74]` 的 `BangGetRoleIcon` 返回的是 `Lord/Loyalist/Rebel/Traitor`（无 `BangRole_` 前缀）。说明贴图全局名在版本间改过，**移植时以 `145_code.txt` 的 `BangRole_*` 为准**。

## 附录 B：一页速查

```
按钮 index：1101 身份 | 1102 关 | 1103 返回 | 1104 观战 | 1110+i 玩家 | 1130+i 行动
文本 index：1151 标题 | 1152 提示 | 1160+i 玩家名 | 1180+i 行动名
按钮尺寸：50×50，GroupIndex = 1100，AlignX="left"，AlignY="top"
文本：白色 16777215，AlignX="left"，AlignY="top"；标题 22 号，提示 14 号，标签 12 号
身份按钮 22,96 | 观战按钮 22,160 | 标题 120,78 | 提示 120,104 | 关 650,82 | 返回 590,82
玩家网格：x=120+mod(i-1,6)*82, y=140+floor((i-1)/6)*92；标签 x-4,y+56
行动网格：x=160+mod(i-1,4)*116, y=170+floor((i-1)/4)*92；标签 x-8,y+56
点击：left_mouse_down==0 吞掉；1101 开/关；1102 藏；1103 回列表；1110<i<=1110+N 选玩家；1130<i<=1137 执行 action
结盟：单向=ExecuteAction("PLAYER_RELATES_PLAYER",A,B,"Neutral")；解除="Enemy"；双向=两次单向
状态：角色/存活|死亡；主公永远公开；自己=「你:角色」；双向盟友/单向盟友/存活
```
