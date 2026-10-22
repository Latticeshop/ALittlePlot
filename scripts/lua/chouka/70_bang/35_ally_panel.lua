-- ============================================================
-- 结盟面板（照搬官渡之战的 BangUi）→ 详情见 docs/13-结盟面板与身份面板.md
-- ============================================================

ChoukaMarkNodeReady("结盟面板")

-- ---------------- 索引段（照搬官渡 BangUi 的编号；操作页那几段本图不用，留空防冲突） ----------------

CHOUKA_PANEL_BTN_OPEN  = 5        -- 顶部第 5 个按钮 = 唯一入口：开面板，点色块直接结盟
CHOUKA_PANEL_GROUP     = 1100

CHOUKA_PANEL_I_CLOSE   = 1101
CHOUKA_PANEL_I_PLAYER  = 1110     -- +1..+6 玩家头像（点了直接结盟/解除）

CHOUKA_PANEL_T_TITLE   = 1151
CHOUKA_PANEL_T_HINT    = 1152
CHOUKA_PANEL_T_PLAYER  = 1160     -- +1..+6 玩家名字/状态

-- ---------------- 贴图：官渡之战的打包贴图 ----------------
-- 95_assets/ 下 4 个节点用 exPackedTextureImageCreate 把贴图建出来（官渡原图 + hextech 按钮 + 纯色块）。
-- 全部"有原图就用原图、没有就退回内置贴图名"，贴图节点没加载成功时按钮也只是不好看，不会变空白。

-- 关闭用本图自己的 hextech 按钮图（95_assets/03_ui.lua 里 exPackedTextureImageCreate 出来的）。
-- 万一贴图节点没跑起来，退回原版 JUA_TBuster_LeaveBurrow，按钮不会空白。
CHOUKA_PANEL_FB_CLOSE   = "JUA_TBuster_LeaveBurrow"

CHOUKA_PANEL_FB_UNKNOWN = "Button_CelestialInfiltrationInfantry"

-- 文字槽建成"宽盒子"：先用一串全角空格占位，后面再更新成真实内容。
-- 官渡也是靠名字后面补 　　　 把盒子撑开的，盒子一旦定型短内容就不会被折行。
CHOUKA_PANEL_PAD = "　　　　　　　　　　　　"

-- 常规混战局的第 5 个按钮：原版"盟军间谍"图标。三国杀模式这个位置由 30_bang_mode.lua
-- 换成岚影刺 + 身份说明，两边不会互相覆盖。
-- 图标 ID 来自 DSA 自走棋「九头蛇万岁」技能（dsa_lua/82_code.txt:87 CreateHydraButton）——
-- 之前写的 Button_AlliedInfantrySpy 在任何参考图里都不存在，所以按钮是空白的。
CHOUKA_PANEL_ICON_MELEE = "Button_AlliedInfiltrationInfantry_on"

function ChoukaPanelIconOpen()
    return CHOUKA_PANEL_ICON_MELEE
end

-- 关闭：images/ui/hextechRemoveButton.png
function ChoukaPanelIconClose()
    if ChoukaUiBtnRemove ~= nil then return ChoukaUiBtnRemove end
    return CHOUKA_PANEL_FB_CLOSE
end


function ChoukaPanelIconUnknown()
    if Unknown ~= nil then return Unknown end
    return CHOUKA_PANEL_FB_UNKNOWN
end

-- 玩家颜色 → 纯色贴图（照搬官渡 BangGetPlayerColorIcon：头像就是一块纯色，
-- 不是任何单位/身份图片）。贴图由 tools/build-ui-assets.js 代码生成，红色通道映射照抄 BangMakeColorName。
ChoukaPlayerColorCode = ChoukaPlayerColorCode or {}

function ChoukaPanelColorCode(seat)
    local cached = ChoukaPlayerColorCode[seat]
    if cached ~= nil then
        return cached
    end
    local code = 0
    if type(exPlayerGetColor) == "function" then
        local color = exPlayerGetColor(ChoukaPanelName(seat))
        if type(color) == "table" then
            if type(color[1]) == "number" then
                code = color[1]
            end
        end
    end
    ChoukaPlayerColorCode[seat] = code
    return code
end

function ChoukaPanelColorIcon(seat)
    local code = ChoukaPanelColorCode(seat)
    if code == 50 then
        if ChoukaUiColorBlue ~= nil then return ChoukaUiColorBlue end
    elseif code == 230 then
        if ChoukaUiColorRed ~= nil then return ChoukaUiColorRed end
    elseif code == 237 then
        if ChoukaUiColorYellow ~= nil then return ChoukaUiColorYellow end
    elseif code == 225 then
        if ChoukaUiColorOrange ~= nil then return ChoukaUiColorOrange end
    elseif code == 20 then
        if ChoukaUiColorGreen ~= nil then return ChoukaUiColorGreen end
    elseif code == 125 then
        if ChoukaUiColorPurple ~= nil then return ChoukaUiColorPurple end
    elseif code == 102 then
        if ChoukaUiColorCyan ~= nil then return ChoukaUiColorCyan end
    end
    return ChoukaPanelIconUnknown()
end


-- ---------------- 坐标（1366×768；AlignX=left / AlignY=top，X 从左、Y 从屏幕顶往下量） ----------------
-- 官渡原值（头像 104、列距 82、字号 12、三行字）实测被挤到换行：这里放宽列距行距、
-- 字号降一级、每个头像下面只留两行（名字 / 状态），身份交给头像图标和悬浮说明。

CHOUKA_PANEL_X_TITLE      = 120
CHOUKA_PANEL_Y_TITLE      = 76
CHOUKA_PANEL_X_HINT       = 120
CHOUKA_PANEL_Y_HINT       = 106
CHOUKA_PANEL_X_CLOSE      = 780     -- 作者指定位置（610 -> 660 -> 810 -> 770 -> 780）
CHOUKA_PANEL_Y_CLOSE      = 72
CHOUKA_PANEL_BTN_W        = 76      -- 关闭 / 返回按钮（hextech 图 76×46）
CHOUKA_PANEL_BTN_H        = 46
CHOUKA_PANEL_P_SIZE       = 84      -- 玩家头像
CHOUKA_PANEL_P_COL_STEP   = 168     -- 头像间距：留出 3~4 个字状态词的宽度，别让引擎折行
CHOUKA_PANEL_P_ROW_STEP   = 170
CHOUKA_PANEL_P_X          = 108
CHOUKA_PANEL_P_Y          = 146
CHOUKA_PANEL_PL_DX        = 6       -- 名字文字相对头像左边缘的内缩
CHOUKA_PANEL_PL_DY        = 90      -- 名字文字相对头像上边缘的偏移

CHOUKA_PANEL_TITLE_SIZE   = 20
CHOUKA_PANEL_HINT_SIZE    = 13
CHOUKA_PANEL_LABEL_SIZE   = 11
CHOUKA_PANEL_COLOR_WHITE  = 16777215

-- 顶部按钮连续自检的秒数（和身份按钮一样，防 16_buttons 重置整排按钮）
CHOUKA_PANEL_BTN_TICK_MAX = 30

-- ---------------- 状态 ----------------

ChoukaPanelState   = ChoukaPanelState or {}   -- playerName -> "open" / "closed"
ChoukaPanelSlots   = ChoukaPanelSlots or {}   -- playerName -> { [slot] = 座位号 }
ChoukaPanelTexts   = ChoukaPanelTexts or {}   -- playerName -> 1（文字槽已建好）
ChoukaPanelBtnTick = ChoukaPanelBtnTick or 0

-- 单向结盟记录：ChoukaAllyFrom["Player_1"]["Player_3"] = 1
ChoukaAllyFrom = ChoukaAllyFrom or {}


-- ============================================================
-- 小工具
-- ============================================================

function ChoukaPanelSeatOf(playerName)
    if type(playerName) ~= "string" then
        return nil
    end
    return tonumber(strsub(playerName, 8))
end

function ChoukaPanelName(seat)
    return "Player_" .. seat
end

-- 这个座位还在打吗（起重机 = 本图的"水晶"）
function ChoukaPanelSeatAlive(seat)
    if type(ChoukaBangSeatAlive) == "function" then
        if ChoukaBangSeatAlive(seat) == 1 then
            return 1
        end
        return 0
    end
    if type(GetObjectByScriptName) ~= "function" then
        return 1
    end
    local crane = GetObjectByScriptName("crane" .. seat)
    if crane == nil then
        return 0
    end
    if type(ObjectIsAlive) == "function" then
        if ObjectIsAlive(crane) then
            return 1
        end
        return 0
    end
    return 1
end

-- 面板里列出哪些座位：三国杀用参战座位，否则用"有起重机的座位"
function ChoukaPanelCollectSeats()
    local out = {}
    local i
    if CHOUKA_MODE == 1 and type(ChoukaBangSeats) == "table" and getn(ChoukaBangSeats) > 0 then
        for i = 1, getn(ChoukaBangSeats), 1 do
            tinsert(out, ChoukaBangSeats[i])
        end
        return out
    end
    for i = 1, 6, 1 do
        if type(GetObjectByScriptName) ~= "function" then
            tinsert(out, i)
        else
            if GetObjectByScriptName("crane" .. i) ~= nil then
                tinsert(out, i)
            end
        end
    end
    return out
end

-- 身份文字：**可见性规则与悬浮框一致**（docs/11 §6③），绝不能把别人的身份直接写出来。
--   能看见的只有三种：自己的身份 / 主公（公开）/ 已阵亡者的身份（阵亡即公开）。
function ChoukaPanelRoleText(viewerSeat, seat)
    if CHOUKA_MODE ~= 1 then
        return nil
    end
    if type(ChoukaBangRole) ~= "table" then
        return nil
    end
    local role = ChoukaBangRole[seat]
    if role == nil or role == ChoukaT.bangRoleAbstain then
        return nil
    end
    local visible = nil
    if seat == viewerSeat then
        visible = 1
    else
        if role == ChoukaT.bangRoleLord then
            visible = 1
        end
        if ChoukaPanelSeatAlive(seat) ~= 1 then
            visible = 1
        end
    end
    if visible ~= 1 then
        return nil
    end
    return format(ChoukaT.panelRole, role)
end

-- 关系短词（面板格子只有 ~118 px，长句会被引擎强制换行，所以全部压到 3~4 个字）
function ChoukaPanelRelationShort(viewerSeat, targetSeat)
    if targetSeat == viewerSeat then
        return ChoukaT.panelShortSelf
    end
    if ChoukaPanelSeatAlive(targetSeat) ~= 1 then
        return ChoukaT.panelShortDead
    end
    local vName = ChoukaPanelName(viewerSeat)
    local tName = ChoukaPanelName(targetSeat)
    local mine, theirs
    mine = 0
    theirs = 0
    if ChoukaAllyFrom[vName] ~= nil then
        if ChoukaAllyFrom[vName][tName] == 1 then
            mine = 1
        end
    end
    if ChoukaAllyFrom[tName] ~= nil then
        if ChoukaAllyFrom[tName][vName] == 1 then
            theirs = 1
        end
    end
    if mine == 1 and theirs == 1 then
        return ChoukaT.panelShortBoth
    end
    if mine == 1 then
        return ChoukaT.panelShortMine
    end
    if theirs == 1 then
        return ChoukaT.panelShortTheirs
    end
    return ChoukaT.panelShortNone
end


-- 面板格子里的名字：真名太长会换行，超过 6 个字截断；没有真名就用 $p<N>Name 占位符
-- （自定义文字通道会替换它，所以显示出来仍是真名；公屏那份兜底已按作者要求删掉）。
function ChoukaPanelPanelName(seat)
    local name = ChoukaPlayerDisplayName(seat)
    if strsub(name, 1, 2) == "$p" then
        return name
    end
    if strlen(name) > 6 then
        return strsub(name, 1, 6) .. "…"
    end
    return name
end


-- 面板格子：第一行名字（后面补全角空格把文字盒子撑开，防止折行），
-- 三国杀里主公多一行"主公"（官渡同款，方便一眼认出并优先选择），最后一行是关系状态。
function ChoukaPanelPlayerLabel(viewerSeat, targetSeat)
    local out
    out = ChoukaPanelPanelName(targetSeat) .. CHOUKA_PANEL_PAD
    if CHOUKA_MODE == 1 and type(ChoukaBangRole) == "table" then
        if ChoukaBangRole[targetSeat] == ChoukaT.bangRoleLord then
            out = out .. "\n" .. ChoukaT.panelLordMark
        end
    end
    out = out .. "\n" .. ChoukaPanelRelationShort(viewerSeat, targetSeat)
    return out
end


-- 头像贴图：玩家所属颜色（官渡玩家列表页就是这么渲染的，一眼能对上小地图颜色）
function ChoukaPanelPlayerIcon(seat)
    return ChoukaPanelColorIcon(seat)
end

-- ============================================================
-- 底层 UI：自定义文字 / 自定义按钮（照搬官渡的 BangUi* 写法）
-- ============================================================

function ChoukaPanelEnsureText(playerName, index, text, x, y, size)
    if type(exCreateCustomTextForPlayer) ~= "function" then
        return 0
    end
    exCreateCustomTextForPlayer(playerName, {
        Index      = index,
        Content    = text or "",
        X          = x,
        Y          = y,
        Color      = CHOUKA_PANEL_COLOR_WHITE,
        Size       = size,
        AlignX     = "left",
        AlignY     = "top",
        GroupIndex = CHOUKA_PANEL_GROUP,
    })
    return 1
end

-- 每个玩家只建一次：标题/提示 + 6 个玩家名 + 7 个操作名，全部先隐藏。
-- 坐标是**每格固定的**（与当前显示哪一页无关），所以建一次就够，之后只改文字和可见性。
function ChoukaPanelEnsureTexts(playerName)
    if ChoukaPanelTexts[playerName] == 1 then
        return 1
    end
    ChoukaPanelEnsureText(playerName, CHOUKA_PANEL_T_TITLE, "",
        CHOUKA_PANEL_X_TITLE, CHOUKA_PANEL_Y_TITLE, CHOUKA_PANEL_TITLE_SIZE)
    ChoukaPanelEnsureText(playerName, CHOUKA_PANEL_T_HINT, "",
        CHOUKA_PANEL_X_HINT, CHOUKA_PANEL_Y_HINT, CHOUKA_PANEL_HINT_SIZE)
    local i, col, row
    for i = 1, 6, 1 do
        col = mod(i - 1, 6)
        row = floor((i - 1) / 6)
        ChoukaPanelEnsureText(playerName, CHOUKA_PANEL_T_PLAYER + i, CHOUKA_PANEL_PAD,
            CHOUKA_PANEL_P_X + col * CHOUKA_PANEL_P_COL_STEP + CHOUKA_PANEL_PL_DX,
            CHOUKA_PANEL_P_Y + row * CHOUKA_PANEL_P_ROW_STEP + CHOUKA_PANEL_PL_DY,
            CHOUKA_PANEL_LABEL_SIZE)
    end

    ChoukaPanelTexts[playerName] = 1
    return 1
end

function ChoukaPanelSetText(playerName, index, text)
    if type(exCustomTextUpdateTextForPlayer) == "function" then
        exCustomTextUpdateTextForPlayer(playerName, index, text or "")
    end
end

function ChoukaPanelSetTextVisible(playerName, index, visible)
    if type(exCustomTextUpdateVisibilityForPlayer) == "function" then
        exCustomTextUpdateVisibilityForPlayer(playerName, index, visible)
    end
end

-- 只删"这个玩家的"这一格。刻意不退化到全局 exCustomBtnRemove(index)：
-- 那会连带删掉别的玩家同 index 的按钮（官渡那个兜底是个坑）。
function ChoukaPanelRemoveButton(playerName, index)
    if type(exCustomBtnRemoveForPlayer) == "function" then
        exCustomBtnRemoveForPlayer(playerName, index)
    end
end

-- 尺寸显式给（宽高分开）：官渡靠打包贴图自带的 104×104，我们统一成设计值，排版才可预测
function ChoukaPanelCreateButton(playerName, index, texture, desc, x, y, sx, sy)
    if texture == nil then
        return 0
    end
    if type(exCreateCustomButtonForPlayer) ~= "function" then
        return 0
    end
    ChoukaPanelRemoveButton(playerName, index)
    exCreateCustomButtonForPlayer(playerName, {
        Index       = index,
        TextureName = texture,
        Desc        = desc or "",
        X           = x,
        Y           = y,
        SizeX       = sx,
        SizeY       = sy,
        GroupIndex  = CHOUKA_PANEL_GROUP,
        AlignX      = "left",
        AlignY      = "top",
    })
    return 1
end

-- 把一页上所有动态按钮/文字清掉
function ChoukaPanelClear(playerName)
    ChoukaPanelRemoveButton(playerName, CHOUKA_PANEL_I_CLOSE)
    if ChoukaPanelTexts[playerName] ~= 1 then
        return
    end
    local i
    for i = 1, 6, 1 do
        ChoukaPanelRemoveButton(playerName, CHOUKA_PANEL_I_PLAYER + i)
        ChoukaPanelSetText(playerName, CHOUKA_PANEL_T_PLAYER + i, "")
        ChoukaPanelSetTextVisible(playerName, CHOUKA_PANEL_T_PLAYER + i, 0)
    end

    ChoukaPanelSetText(playerName, CHOUKA_PANEL_T_TITLE, "")
    ChoukaPanelSetText(playerName, CHOUKA_PANEL_T_HINT, "")
    ChoukaPanelSetTextVisible(playerName, CHOUKA_PANEL_T_TITLE, 0)
    ChoukaPanelSetTextVisible(playerName, CHOUKA_PANEL_T_HINT, 0)
end

-- ============================================================
-- 一页（列表上点了就直接结盟，不再有第二页）
-- ============================================================

function ChoukaPanelShowList(seat)
    local playerName = ChoukaPanelName(seat)
    local seats = ChoukaPanelCollectSeats()
    if getn(seats) == 0 then
        return 0
    end
    ChoukaPanelSlots[playerName] = seats
    ChoukaPanelEnsureTexts(playerName)
    ChoukaPanelClear(playerName)

    local title = ChoukaT.panelTitleMelee
    if CHOUKA_MODE == 1 then
        title = ChoukaT.panelTitleBang
    end
    ChoukaPanelSetText(playerName, CHOUKA_PANEL_T_TITLE, title)
    ChoukaPanelSetTextVisible(playerName, CHOUKA_PANEL_T_TITLE, 1)
    ChoukaPanelSetText(playerName, CHOUKA_PANEL_T_HINT, ChoukaT.panelHintList)
    ChoukaPanelSetTextVisible(playerName, CHOUKA_PANEL_T_HINT, 1)
    ChoukaPanelCreateButton(playerName, CHOUKA_PANEL_I_CLOSE, ChoukaPanelIconClose(),
        "", CHOUKA_PANEL_X_CLOSE, CHOUKA_PANEL_Y_CLOSE, CHOUKA_PANEL_BTN_W, CHOUKA_PANEL_BTN_H)

    local i, slot, targetSeat, col, row, x, y
    for i = 1, getn(seats), 1 do
        slot = i
        targetSeat = seats[i]
        col = mod(i - 1, 6)
        row = floor((i - 1) / 6)
        x = CHOUKA_PANEL_P_X + col * CHOUKA_PANEL_P_COL_STEP
        y = CHOUKA_PANEL_P_Y + row * CHOUKA_PANEL_P_ROW_STEP
        ChoukaPanelSetText(playerName, CHOUKA_PANEL_T_PLAYER + slot,
            ChoukaPanelPlayerLabel(seat, targetSeat))
        ChoukaPanelSetTextVisible(playerName, CHOUKA_PANEL_T_PLAYER + slot, 1)
        ChoukaPanelCreateButton(playerName, CHOUKA_PANEL_I_PLAYER + slot,
            ChoukaPanelPlayerIcon(targetSeat), "", x, y, CHOUKA_PANEL_P_SIZE, CHOUKA_PANEL_P_SIZE)
    end

    ChoukaPanelState[playerName] = "open"
    return 1
end


function ChoukaPanelHide(seat)
    local playerName = ChoukaPanelName(seat)
    ChoukaPanelClear(playerName)
    ChoukaPanelState[playerName] = "closed"
    return 1
end

function ChoukaPanelToggle(seat)
    local playerName = ChoukaPanelName(seat)
    local state = ChoukaPanelState[playerName]
    if state == nil or state == "closed" then
        return ChoukaPanelShowList(seat)
    end
    return ChoukaPanelHide(seat)
end

-- ============================================================
-- 结盟核心（照搬官渡 setAlliance / isAllied / removeAlliance / BangToggleAlliance）
--   单向记录 + PLAYER_RELATES_PLAYER：结盟设 Neutral（不主动打），解除设 Enemy
-- ============================================================

function ChoukaPanelTell(playerName, text)
    if type(exAddTextToPublicBoardForPlayer) == "function" then
        exAddTextToPublicBoardForPlayer(playerName, text, 8)
    end
    _LOG("结盟面板：" .. text .. "  -> " .. (playerName or "?"))
end

function ChoukaPanelRelate(fromSeat, toSeat, rel)
    if type(ExecuteAction) ~= "function" then
        return 0
    end
    -- 官渡用 SetWorldBuilderThisPlayer 包一层，改关系才生效
    local previous
    if type(SetWorldBuilderThisPlayer) == "function" then
        previous = SetWorldBuilderThisPlayer(1)
    end
    ExecuteAction("PLAYER_RELATES_PLAYER", ChoukaPanelName(fromSeat), ChoukaPanelName(toSeat), rel)
    if previous ~= nil and type(SetWorldBuilderThisPlayer) == "function" then
        SetWorldBuilderThisPlayer(previous)
    end
    return 1
end

function ChoukaPanelIsAllied(fromSeat, toSeat)
    local fromName = ChoukaPanelName(fromSeat)
    if ChoukaAllyFrom[fromName] == nil then
        return 0
    end
    if ChoukaAllyFrom[fromName][ChoukaPanelName(toSeat)] == 1 then
        return 1
    end
    return 0
end

-- 三国杀：只有同阵营能结盟（主公/忠臣算同一阵营）
function ChoukaPanelCanAlly(fromSeat, toSeat)
    if CHOUKA_MODE ~= 1 then
        return 1
    end
    if type(ChoukaBangRole) ~= "table" then
        return 1
    end
    local roleA = ChoukaBangRole[fromSeat]
    local roleB = ChoukaBangRole[toSeat]
    if roleA == nil or roleB == nil then
        return 1
    end
    if roleA == roleB then
        return 1
    end
    if type(ChoukaBangIsLordSide) == "function" then
        if ChoukaBangIsLordSide(roleA) and ChoukaBangIsLordSide(roleB) then
            return 1
        end
    end
    return 0
end

function ChoukaPanelAllyToggle(fromSeat, toSeat)
    local fromName = ChoukaPanelName(fromSeat)
    local toName = ChoukaPanelName(toSeat)

    if ChoukaPanelIsAllied(fromSeat, toSeat) == 1 then
        -- 解除
        ChoukaAllyFrom[fromName][toName] = nil
        ChoukaPanelRelate(fromSeat, toSeat, "Enemy")
        if ChoukaPanelIsAllied(toSeat, fromSeat) == 1 then
            ChoukaAllyFrom[toName][fromName] = nil
            ChoukaPanelRelate(toSeat, fromSeat, "Enemy")
            ChoukaAlertFor(format(ChoukaT.panelBcBreakBoth,
                ChoukaPlayerDisplayName(fromSeat), ChoukaPlayerDisplayName(toSeat)), 10)
        else
            ChoukaAlertFor(format(ChoukaT.panelBcBreak,
                ChoukaPlayerDisplayName(fromSeat), ChoukaPlayerDisplayName(toSeat)), 10)
        end
        return 1
    end

    if ChoukaPanelCanAlly(fromSeat, toSeat) ~= 1 then
        ChoukaPanelTell(fromName, ChoukaT.panelAllyDenied)
        return 0
    end

    if ChoukaAllyFrom[fromName] == nil then
        ChoukaAllyFrom[fromName] = {}
    end
    ChoukaAllyFrom[fromName][toName] = 1
    ChoukaPanelRelate(fromSeat, toSeat, "Neutral")
    if ChoukaPanelIsAllied(toSeat, fromSeat) == 1 then
        ChoukaAlertFor(format(ChoukaT.panelBcAllyBoth,
            ChoukaPlayerDisplayName(fromSeat), ChoukaPlayerDisplayName(toSeat)), 10)
    else
        ChoukaAlertFor(format(ChoukaT.panelBcAllyOne,
            ChoukaPlayerDisplayName(fromSeat), ChoukaPlayerDisplayName(toSeat)), 10)
    end
    return 1
end


-- ============================================================
-- 点击入口（由 16_buttons.lua 在 onCenterTopBtnClickEvent 里调用）
-- ============================================================

function ChoukaPanelOnBtn(playerName, btnIndex)
    if playerName == nil or btnIndex == nil then
        return 0
    end
    local seat = ChoukaPanelSeatOf(playerName)
    if seat == nil then
        return 0
    end

    if btnIndex == CHOUKA_PANEL_BTN_OPEN then
        -- 三国杀模式下这个按钮由 32_bang_pref.lua 的 ChoukaBangOnBtn 先认领（它还负责私发身份）;
        -- 只有"身份还没发下去"的时候才会落到这里，那时面板没意义，直接不管。
        if CHOUKA_MODE == 1 and ChoukaBangRolesReady ~= 1 then
            return 0
        end
        ChoukaPanelToggle(seat)
        return 1
    end
    if btnIndex == CHOUKA_PANEL_I_CLOSE then
        ChoukaPanelHide(seat)
        return 1
    end
    if btnIndex > CHOUKA_PANEL_I_PLAYER and btnIndex <= CHOUKA_PANEL_I_PLAYER + 6 then
        ChoukaPanelClickPlayer(seat, btnIndex - CHOUKA_PANEL_I_PLAYER)
        return 1
    end
    return 0
end

-- 点玩家色块：**一步到位直接结盟 / 解除**（原来要点开操作页再选，作者要求去掉操作页）。
-- 点完立刻重画一遍列表，状态词马上变成最新关系。
function ChoukaPanelClickPlayer(seat, slot)
    local playerName = ChoukaPanelName(seat)
    local seats = ChoukaPanelSlots[playerName]
    if seats == nil then
        return 0
    end
    local targetSeat = seats[slot]
    if targetSeat == nil then
        return 0
    end
    if targetSeat == seat then
        ChoukaPanelTell(playerName, ChoukaT.panelSelf)
        return 0
    end
    if ChoukaPanelSeatAlive(targetSeat) ~= 1 then
        return 0
    end
    ChoukaPanelAllyToggle(seat, targetSeat)
    ChoukaPanelShowList(seat)
    return 1
end

-- ============================================================
-- 每次求值
-- ============================================================

-- 顶部第 5 个按钮是**唯一的入口**（一个按钮开面板，选完人再展开结盟，和官渡一致）。
--   · 三国杀模式：这个按钮由 30_bang_mode.lua 负责显示（间谍图标 + 身份速览 desc），
--     这里不再插手，只负责接点击（见 32_bang_pref.lua 的 ChoukaBangOnBtn）。
--   · 常规混战：没有身份可言，所以由这里把同一个按钮换成通用结盟图标 + 结盟说明。
if CHOUKA_GAME_STARTED == 1 and CHOUKA_MODE ~= 1 then
    if ChoukaPanelBtnTick < CHOUKA_PANEL_BTN_TICK_MAX then
        ChoukaPanelBtnTick = ChoukaPanelBtnTick + 1
        if type(exCenterTopBtnShowForPlayer) == "function" then
            local i, name
            for i = 1, 6, 1 do
                name = "Player_" .. i
                exCenterTopBtnShowForPlayer(name, CHOUKA_PANEL_BTN_OPEN,
                    ChoukaPanelIconOpen(), ChoukaT.panelBtnDescMelee)
                if type(exCenterTopBtnSetEnableForPlayer) == "function" then
                    exCenterTopBtnSetEnableForPlayer(name, CHOUKA_PANEL_BTN_OPEN, 1)
                end
            end
        end
    end
end

-- 结算后把面板收掉
if CHOUKA_BANG_ENDED == 1 and CHOUKA_MODE == 1 then
    if ChoukaPanelEndedCleared ~= 1 then
        ChoukaPanelEndedCleared = 1
        local i
        for i = 1, 6, 1 do
            ChoukaPanelHide(i)
        end
    end
end
