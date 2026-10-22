-- ============================================================
-- 详见 docs/10-Lua注释存档.md §03_start-1
-- ============================================================

-- ---------------- 常量 ----------------

ChoukaMarkNodeReady("开局")

CHOUKA_START_ANNOUNCE_DIALOG = 810      -- 全屏公告的长文本对话框 id
CHOUKA_START_HOST_DIALOG     = 811      -- 房主配置的按钮对话框 id

CHOUKA_START_CENTER_WP       = "center" -- 锁视角的中心航点（本图中心点就叫 center）
CHOUKA_START_WAIT_TEXT       = ChoukaT.waitHost
CHOUKA_START_TEXT_Z_OFFSET   = 80       -- 中心提示文字的抬高量（世界单位）
CHOUKA_START_TEXT_COLOR      = 16776960 -- 0xFFFF00 亮黄（十进制 RGB）
CHOUKA_START_CAMERA_PERIOD   = 3        -- 每 N 次求值重新钉一次视角（秒）
CHOUKA_START_LOCK_INPUT      = 0        -- 1 = 开局期间 DISABLE_INPUT（照 DSA）；见文件头说明
CHOUKA_BOX_SECONDS           = CHOUKA_BOX_SECONDS or 120  -- 盲盒刷新间隔，02_private_box 共用

CHOUKA_START_ANNOUNCE_TEXT = ChoukaT.announce

-- 详见 docs/10-Lua注释存档.md §03_start-2
ChoukaStartScopeOptions = ChoukaStartScopeOptions or {
    [1] = { scope = 0, name = ChoukaT.scopeAll },
    [2] = { scope = 1, name = ChoukaT.scopeOwn },
}

-- ---------------- 状态（必须是全局：Lua 桥的闭包拿不到外层 local） ----------------

ChoukaStartStage     = ChoukaStartStage or 0     -- 0 未启动 / 1 等房主 / 2 已开局
CHOUKA_GAME_STARTED  = CHOUKA_GAME_STARTED or 0  -- 0 未开局 / 1 已开局（全场共用）
ChoukaStartScopeKey  = ChoukaStartScopeKey or 1  -- 房主选的档（键 1 = 箱子包括全部阵营，默认）
ChoukaStartTick      = ChoukaStartTick or 0      -- 等待期求值次数
ChoukaStartConfirm   = ChoukaStartConfirm or 0   -- 房主点过「确认，开始游戏」
CHOUKA_DRAW_SCOPE    = CHOUKA_DRAW_SCOPE or 0    -- 0 全部阵营（默认）/ 1 只有自己阵营（12_puredraw_replace 用）

-- ============================================================
-- 详见 docs/10-Lua注释存档.md §03_start-3
-- ============================================================

ChoukaChoiceHandlers   = ChoukaChoiceHandlers or {}
ChoukaLongTextHandlers = ChoukaLongTextHandlers or {}

function ChoukaAddChoiceHandler(f)
    if type(f) ~= "function" then
        return
    end
    for i = 1, getn(ChoukaChoiceHandlers), 1 do
        if ChoukaChoiceHandlers[i] == f then
            return
        end
    end
    tinsert(ChoukaChoiceHandlers, f)
end

function ChoukaAddLongTextHandler(f)
    if type(f) ~= "function" then
        return
    end
    for i = 1, getn(ChoukaLongTextHandlers), 1 do
        if ChoukaLongTextHandlers[i] == f then
            return
        end
    end
    tinsert(ChoukaLongTextHandlers, f)
end

function onUserBtnChoiceDialogEvent(playerName, btnIndex, dialogId)
    for i = 1, getn(ChoukaChoiceHandlers), 1 do
        if ChoukaChoiceHandlers[i](playerName, btnIndex, dialogId) == 1 then
            return 1
        end
    end
    return 0
end

function onUserLongTextDialogEvent(playerName, btnIndex, dialogId)
    for i = 1, getn(ChoukaLongTextHandlers), 1 do
        if ChoukaLongTextHandlers[i](playerName, btnIndex, dialogId) == 1 then
            return 1
        end
    end
    return 0
end

-- ============================================================
-- 1. 小工具
-- ============================================================

-- 详见 docs/10-Lua注释存档.md §03_start-4
function ChoukaStartRefreshHost()
    if ChoukaStartHostLocked == 1 and ChoukaStartHost ~= nil then
        return ChoukaStartHost
    end
    local name = nil
    if type(ObjectPlayerScriptName) == "function" then
        name = ObjectPlayerScriptName("<1st Human Player>")
    end
    if name ~= nil and name ~= "" then
        ChoukaStartHost = name
        ChoukaStartHostLocked = 1
    elseif ChoukaStartHost == nil then
        ChoukaStartHost = "Player_1"
    end
    return ChoukaStartHost
end

-- 相机：全体先钉到 center，再逐个玩家钉一次（DSA 两种都用过，双保险）
function ChoukaStartCameraToCenter()
    if type(ExecuteAction) == "function" then
        ExecuteAction("MOVE_CAMERA_TO", CHOUKA_START_CENTER_WP, 0, 0, 0, 0)
        for i = 1, 6, 1 do
            ExecuteAction("PLAYER_CAMERA_MOVE_TO", "Player_" .. i,
                CHOUKA_START_CENTER_WP, 0, 0, 0, 0)
        end
    end
    -- 兜底：动作不生效就直接改相机坐标（教程:195 / 206）
    if type(exCameraAdjustPos) == "function" then
        local p = exWaypointGetPos(CHOUKA_START_CENTER_WP)
        if p ~= nil and p[1] ~= nil then
            exCameraAdjustPos(p[1], p[2], p[3])
        end
    end
end

-- 相机锁：开局上锁，正式开始成对解锁（1 锁 / 0 解锁）
function ChoukaStartLockCamera(value)
    if type(ExecuteAction) ~= "function" then
        return
    end
    ExecuteAction("LOCK_CAMERA", value)
    ExecuteAction("LOCK_CAMERA_SCROLL", value)
end

-- 地图中间那行提示：漂浮文字会自己消失，所以每次求值都重刷一遍
function ChoukaStartShowCenterText()
    if type(exShowTextAtPos) ~= "function" then
        return
    end
    local p = exWaypointGetPos(CHOUKA_START_CENTER_WP)
    if p == nil or p[1] == nil then
        return                      -- 航点没了就别在原点刷字
    end
    local z = p[3]
    if z == nil then
        z = 0
    end
    exShowTextAtPos(CHOUKA_START_WAIT_TEXT, p[1], p[2], z + CHOUKA_START_TEXT_Z_OFFSET,
        CHOUKA_START_TEXT_COLOR)
end

-- 给单个玩家播一条左下角消息（API 不在就退回全体公屏）
function ChoukaStartTellPlayer(playerName, text, seconds)
    if type(exAddTextToPublicBoardForPlayer) == "function" then
        exAddTextToPublicBoardForPlayer(playerName, text, seconds)
    end
    _LOG(text)          -- 只写日志（开局节点在关键路径上，不冒险调未验证的可见通道），见 00_alert.lua
end

-- 全图播报一条：左下角消息区（实测能看到）+ 公屏（能否显示看 mod 版本）+ 日志
-- ⚠ 只在关键动作**之后**调用：可见通道万一报错，也挡不住开局的发钱/开门这些正事
function ChoukaStartBroadcast(text, seconds)
    if seconds == nil then
        seconds = 15
    end
    _LOG(text)
    if type(exMessageAppendToMessageArea) == "function" then
        exMessageAppendToMessageArea(text)
    end
    if type(exAddTextToPublicBoard) == "function" then
        exAddTextToPublicBoard(text, seconds)
    end
end

-- 只给房主开的选择对话框（固定 10 个参数，照 16_buttons.lua 的 call 写法）
function ChoukaStartShowDialog(playerName, dialogId, title, choices)
    if type(exShowCustomBtnChoiceDialogForPlayer) ~= "function" then
        return
    end
    local args = { playerName, dialogId, title }
    for i = 1, getn(choices), 1 do
        tinsert(args, choices[i])
    end
    while getn(args) < 10 do
        tinsert(args, "")
    end
    call(exShowCustomBtnChoiceDialogForPlayer, args)
end

function ChoukaStartHostChoices()
    local choices = {}
    for k = 1, getn(ChoukaStartScopeOptions), 1 do
        local opt = ChoukaStartScopeOptions[k]
        local mark = ""
        if ChoukaStartScopeKey == k then
            mark = "√"                       -- 选中项带 √（作者指定的写法）
        end
        choices[k] = opt.name .. mark
    end
    local n = getn(ChoukaStartScopeOptions)
    choices[n + 1] = "确认，开始游戏"
    choices[n + 2] = "重新查看公告"
    return choices, n + 1, n + 2
end

function ChoukaStartShowHostDialog(playerName)
    local choices = ChoukaStartHostChoices()
    ChoukaStartShowDialog(playerName, CHOUKA_START_HOST_DIALOG,
        ChoukaT.hostDialogTitle, choices)
end

-- ============================================================
-- 2. 三个阶段
-- ============================================================

-- ① 开局第一秒：锁视角 + 弹公告 + 挂中心提示
function ChoukaStartBegin()
    ChoukaStartStage = 1
    ChoukaStartTick = 0
    ChoukaStartRefreshHost()

    -- 视角锁在地图中间
    ChoukaStartCameraToCenter()
    ChoukaStartLockCamera(1)

    -- 固定玩家操作：先收掉右下角单位操作区（不碰鼠标键盘，房主还要点公告按钮）
    if type(exAptHideObjectDetailsArea) == "function" then
        exAptHideObjectDetailsArea()
    end
    if CHOUKA_START_LOCK_INPUT == 1 and type(ExecuteAction) == "function" then
        ExecuteAction("DISABLE_INPUT")
    end

    -- 全屏公告（长文本对话框：按钮传空串就隐藏，只留「已阅读」）
    if type(exShowLongTextDialog) == "function" then
        -- 按钮槽位：1=左 2=中 3=右；空串=不显示那个按钮。
        -- 只给第 1 个槽位按钮 → 实测靠左；放到中间槽位才是居中（照 DSA）
        exShowLongTextDialog(CHOUKA_START_ANNOUNCE_DIALOG, CHOUKA_START_ANNOUNCE_TEXT,
            "", ChoukaT.readDone, "")
    end

    -- 地图中间的等待提示 + 公屏
    ChoukaStartShowCenterText()
    _LOG(CHOUKA_START_WAIT_TEXT)
end

-- ② 等房主：每秒重钉视角、重刷提示，房主点确认就收尾
function ChoukaStartWaitTick()
    ChoukaStartTick = ChoukaStartTick + 1

    -- 房主可能第一秒还没认出来（玩家席位就绪有先后），等的时候每秒重认一次
    ChoukaStartRefreshHost()

    -- ⚠ 日冕的 Lua 是 4.0，**没有 % 运算符**（DSA 全程用 mod(x,y)），别手滑写成 %
    if mod(ChoukaStartTick, CHOUKA_START_CAMERA_PERIOD) == 0 then
        ChoukaStartCameraToCenter()
    end
    ChoukaStartShowCenterText()

    if ChoukaStartConfirm == 1 then
        ChoukaStartFinish()
    end
end

-- ③ 正式开始：视角回自己出生点、解锁、发钱、倒计时起步
--    ⚠ 顺序有讲究：标志位与"钱/倒计时"先做，关窗口、挪相机这类装饰性动作放后面 ——
--      Lua 4.0 没有 pcall，万一中间某一句报错，也不会把"发钱"这个关键动作挡掉。
function ChoukaStartFinish()
    ChoukaStartStage = 2
    CHOUKA_GAME_STARTED = 1

    -- 抽卡范围：按房主在配置页选的那一档写进全局（12_puredraw_replace 抽池时读它）
    local scopeOpt = ChoukaStartScopeOptions[ChoukaStartScopeKey]
    if scopeOpt ~= nil and scopeOpt.scope ~= nil then
        CHOUKA_DRAW_SCOPE = scopeOpt.scope
    end

    -- 盲盒倒计时从整轮开始走（02_private_box.lua 每秒减 1）
    CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
    CHOUKA_ROUND = 0
    ExecuteAction("SET_MILLISECOND_TIMER", "box", CHOUKA_BOX_SECONDS)

    -- 解相机锁 + 开输入
    ChoukaStartLockCamera(0)
    ExecuteAction("ENABLE_INPUT")

    -- 视角回归自己的出生点（起重机就在旁边）
    for i = 1, 6, 1 do
        ExecuteAction("PLAYER_CAMERA_MOVE_TO", "Player_" .. i,
            "Player_" .. i .. "_Start", 0, 0, 0, 0)
    end

    -- 恢复右下角单位操作区
    if type(exAptShowObjectDetailsArea) == "function" then
        exAptShowObjectDetailsArea()
    end

    -- 关掉可能还开着的公告 / 配置窗口（有人没点「已阅读」也一并收掉）
    if type(exHideLongTextDialog) == "function" then
        exHideLongTextDialog()
    end
    if type(exHideCustomBtnChoiceDialogForPlayer) == "function" then
        exHideCustomBtnChoiceDialogForPlayer(ChoukaStartHost)
    end

    -- 全图公告：房主到底选了什么（所有人都会在左下角消息区看到）
    local scopeText = ChoukaT.scopeAll
    if CHOUKA_DRAW_SCOPE == 1 then
        scopeText = ChoukaT.scopeOwn
    end
    ChoukaStartBroadcast(format(ChoukaT.hostConfigDone, scopeText, CHOUKA_BOX_SECONDS), 20)
end

-- ============================================================
-- 3. 回调
-- ============================================================

-- 长文本对话框（公告）：所有人点「已阅读」→ 房主开配置页面，其他人继续等
function ChoukaLongText_start(playerName, btnIndex, dialogId)
    if dialogId ~= CHOUKA_START_ANNOUNCE_DIALOG then
        return 0
    end
    if type(exHideLongTextDialogForPlayer) == "function" then
        exHideLongTextDialogForPlayer(playerName)
    end
    ChoukaStartRefreshHost()
    if playerName == ChoukaStartHost then
        ChoukaStartShowHostDialog(playerName)
        ChoukaStartTellPlayer(playerName,
            ChoukaT.hostTip, 20)
    else
        ChoukaStartTellPlayer(playerName, CHOUKA_START_WAIT_TEXT, 20)
    end
    return 1
end

-- 按钮对话框（房主配置）：1/2 = 两个二选一，第 3 个确认，第 4 个重看公告
function ChoukaChoice_start(playerName, btnIndex, dialogId)
    if dialogId ~= CHOUKA_START_HOST_DIALOG then
        return 0
    end
    -- 只有房主能操作这个窗口
    if playerName ~= ChoukaStartHost then
        return 1
    end

    local optionCount = getn(ChoukaStartScopeOptions)
    local confirmBtn = optionCount + 1
    local rereadBtn = optionCount + 2

    if btnIndex >= 1 and btnIndex <= optionCount then
        ChoukaStartScopeKey = btnIndex
        -- 房主每点一次选项，全图播一条（照 DSA：让所有人知道房主正在选什么）
        local picked = ChoukaStartScopeOptions[btnIndex]
        if picked ~= nil and picked.name ~= nil then
            ChoukaStartBroadcast(format(ChoukaT.hostPicking, picked.name), 8)
        end
        -- 选择对话框点一下就自动消失，所以重开一遍把 √ 标出来
        ChoukaStartShowHostDialog(playerName)
        return 1
    end
    if btnIndex == confirmBtn then
        ChoukaStartConfirm = 1
        if type(exHideCustomBtnChoiceDialogForPlayer) == "function" then
            exHideCustomBtnChoiceDialogForPlayer(playerName)
        end
        return 1
    end
    if btnIndex == rereadBtn then
        if type(exShowLongTextDialogForPlayer) == "function" then
            exShowLongTextDialogForPlayer(playerName, CHOUKA_START_ANNOUNCE_DIALOG,
                CHOUKA_START_ANNOUNCE_TEXT, "", ChoukaT.readDone, "")
        end
        return 1
    end
    return 1
end

-- ⚠ 只注册一次：脚本每次求值都会重新"定义"一遍函数（新的函数对象），
--   无脑 tinsert 会让处理函数表每秒变长，所以用标志位卡住。
if ChoukaStartHandlersRegistered ~= 1 then
    ChoukaStartHandlersRegistered = 1
    ChoukaAddLongTextHandler(ChoukaLongText_start)
    ChoukaAddChoiceHandler(ChoukaChoice_start)
end

-- ============================================================
-- 4. 每次求值
-- ============================================================

if CHOUKA_GAME_STARTED == 1 then
    -- 已经开局：本节点只剩"让上面两个回调一直存在"的作用，什么都不做
elseif ChoukaStartStage == 0 then
    ChoukaStartBegin()
else
    ChoukaStartWaitTick()
end