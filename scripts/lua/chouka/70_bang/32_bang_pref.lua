-- ============================================================
-- 三国杀 · 身份偏好（复用原生选择页 + 文字选项）
-- 详见 docs/11-三国杀模式方案.md §5
--
-- 作者 2026-10 定案：**不要自绘卡片和图标**，直接用游戏原生的
-- `exShowCustomBtnChoiceDialogForPlayer`（和房主配置页、交易市场同一个控件），
-- 一屏 5 个文字选项：
--     主公（名额 1） / 忠臣（名额 1） / 反贼（名额 2） / 内奸（名额 1） / 弃权（随机分配）
--
-- 交互 = 一步到位：点哪个就是哪个（原生选择页点完自动关），没有"再点确认"那一步。
--
-- ★★ 关键教训（2026-10 实测）：**只给真人弹面板，绝不能给 AI 座位弹。**
--    第一版给全部 6 个座位都弹了，结果真人还没选，自己那份面板就被"别人"关掉了。
--    原因：按钮选择对话框在引擎里只有一个"当前显示位"，
--      · 给另一个座位 Show 一次，就会把屏幕上正开着的那份顶掉；
--      · 任何一个座位应答，`exHideCustomBtnChoiceDialogForPlayer` 收掉的也是同一份。
--    所以 AI 座位一律不弹 —— 它们的身份直接随机（正好是它们本来的行为）。
-- ============================================================

ChoukaMarkNodeReady("三国杀-偏好")

-- ---------------- 常量 ----------------

-- 原生选择页 id。已占用：700+序号=交易市场(701~706)、710+序号=防御塔(711~716)、
--                      810=开局公告长文本、811=房主配置页
CHOUKA_BANG_PREF_DIALOG       = 730

CHOUKA_BANG_PREF_SECONDS      = CHOUKA_BANG_PREF_SECONDS or 180

-- ★ 提前收尾：只要真人选过，再静默这么多秒就结束
--   （现在是"真人一选就立刻收尾"，这条只在将来多真人时兜底）
CHOUKA_BANG_PREF_GRACE        = CHOUKA_BANG_PREF_GRACE or 15

-- 还没选的话，每隔这么多秒重新弹一次面板（玩家把面板点叉了也能再拿到）
CHOUKA_BANG_PREF_REOPEN_EVERY = CHOUKA_BANG_PREF_REOPEN_EVERY or 30

-- ---------------- 状态（全局：Lua 桥的闭包拿不到外层 local） ----------------

ChoukaBangPref              = ChoukaBangPref or {}         -- playerName -> 想要的身份
ChoukaBangReady             = ChoukaBangReady or {}        -- playerName -> 1 已选过
ChoukaBangPrefPlayers       = ChoukaBangPrefPlayers or {}  -- 真正弹了面板的座位（= 真人座位）
ChoukaBangPrefHumanPlayers  = ChoukaBangPrefHumanPlayers or {}
ChoukaBangPrefTick          = ChoukaBangPrefTick or 0
ChoukaBangPrefLastReadyTick = ChoukaBangPrefLastReadyTick or 0
ChoukaBangPrefUiCreated     = ChoukaBangPrefUiCreated or {}
ChoukaBangPrefNoApiWarned   = ChoukaBangPrefNoApiWarned or 0

-- 面板上的 5 个选项（文案来自 ChoukaT，因此身份名和逻辑值天然一致）
ChoukaBangPrefRolesCache = ChoukaBangPrefRolesCache or {
    ChoukaT.bangRoleLord,
    ChoukaT.bangRoleLoyalist,
    ChoukaT.bangRoleRebel,
    ChoukaT.bangRoleTraitor,
    ChoukaT.bangRoleAbstain,
}

function ChoukaBangPrefRoles()
    return ChoukaBangPrefRolesCache
end

-- 这个身份在"当前人数"下的名额（实现在 30 号节点）
function ChoukaBangPrefQuotaOf(role)
    if type(ChoukaBangRoleCountOf) == "function" then
        return ChoukaBangRoleCountOf(role)
    end
    return 0
end

-- ============================================================
-- 找出"该弹面板的座位"
--
-- 本图唯一可靠的真人接口是 `ObjectPlayerScriptName("<1st Human Player>")`
-- （03_start.lua:105-106 就是这么认出房主的 —— 房主配置页确实弹给了真人，
--   证明这条路是通的）。`EvaluateCondition(..., "Human")` 在本图返回空，
-- 那正是第一版"零真人 → 偏好被静默跳过"的真凶，别再用它。
-- ============================================================

function ChoukaBangPrefPushSeat(list, name)
    if name == nil or name == "" then
        return
    end
    local i
    for i = 1, getn(list), 1 do
        if list[i] == name then
            return
        end
    end
    tinsert(list, name)
end

function ChoukaBangPrefCollectSeats()
    local out = {}

    -- ① 第一个真人玩家
    if type(ObjectPlayerScriptName) == "function" then
        ChoukaBangPrefPushSeat(out, ObjectPlayerScriptName("<1st Human Player>"))
    end

    -- ② 房主（03_start 认出来的那个；和上面重复会自动去重）
    ChoukaBangPrefPushSeat(out, ChoukaStartHost)

    -- ③ 全都没认出来：兜底给 Player_1（03_start.lua:112 的房主兜底值也是它）
    if getn(out) == 0 then
        tinsert(out, "Player_1")
        _LOG("三国杀：偏好认不出真人，兜底只弹给 Player_1")
    end

    return out
end

-- ============================================================
-- 原生选择页
-- ============================================================

-- 5 个文字选项：「主公（名额 1）」…
function ChoukaBangPrefOptions()
    local roles = ChoukaBangPrefRoles()
    local out = {}
    local i, role
    for i = 1, getn(roles), 1 do
        role = roles[i]
        if role == ChoukaT.bangRoleAbstain then
            tinsert(out, ChoukaT.bangPrefAbstain)
        else
            tinsert(out, format(ChoukaT.bangPrefOption, role, ChoukaBangPrefQuotaOf(role)))
        end
    end
    return out
end

-- 参数顺序照 03_start.lua 的 ChoukaStartShowDialog：
--   固定 10 参 = 玩家名 + 面板id + 标题 + 最多 7 个选项，不足补空串
function ChoukaBangPrefShowFor(playerName)
    if playerName == nil then
        return 0
    end
    if type(exShowCustomBtnChoiceDialogForPlayer) ~= "function" then
        if ChoukaBangPrefNoApiWarned ~= 1 then
            ChoukaBangPrefNoApiWarned = 1
            ChoukaAlert(ChoukaT.bangPrefNoApi)
            _LOG("三国杀：没有 exShowCustomBtnChoiceDialogForPlayer，身份偏好面板开不出来，本局随机")
        end
        return 0
    end

    local args = { playerName, CHOUKA_BANG_PREF_DIALOG, ChoukaT.bangPrefTitle }
    local choices = ChoukaBangPrefOptions()
    local i
    for i = 1, getn(choices), 1 do
        tinsert(args, choices[i])
    end
    while getn(args) < 10 do
        tinsert(args, "")
    end
    call(exShowCustomBtnChoiceDialogForPlayer, args)

    ChoukaBangPrefUiCreated[playerName] = 1
    return 1
end

function ChoukaBangPrefHideFor(playerName)
    if playerName == nil then
        return 0
    end
    if type(exHideCustomBtnChoiceDialogForPlayer) == "function" then
        exHideCustomBtnChoiceDialogForPlayer(playerName)
    end
    return 1
end

-- ============================================================
-- 选择页回调（由 16_buttons.lua 的 onUserBtnChoiceDialogEvent 分发进来）
--   签名照 03_start.lua 的 ChoukaChoice_start：(playerName, btnIndex, dialogId)
-- ============================================================

function ChoukaChoice_bangPref(playerName, btnIndex, dialogId)
    if dialogId ~= CHOUKA_BANG_PREF_DIALOG then
        return 0
    end

    -- 已经过了投票阶段（或不是三国杀局）：把面板收掉就行
    if CHOUKA_MODE ~= 1 or ChoukaBangStage ~= 1 or ChoukaBangPrefDone == 1 then
        ChoukaBangPrefHideFor(playerName)
        return 1
    end
    if playerName == nil or btnIndex == nil then
        return 1
    end

    local roles = ChoukaBangPrefRoles()
    if btnIndex < 1 or btnIndex > getn(roles) then
        return 1
    end

    local role = roles[btnIndex]
    ChoukaBangPref[playerName] = role
    ChoukaBangReady[playerName] = 1
    ChoukaBangPrefLastReadyTick = ChoukaBangPrefTick or 0
    ChoukaBangPrefHideFor(playerName)

    _LOG("三国杀：偏好 " .. playerName .. " 选了 " .. role .. "（立刻进入发身份）")
    if type(ChoukaBangTellPlayer) == "function" then
        ChoukaBangTellPlayer(playerName, format(ChoukaT.bangPrefYouPicked, role))
    end
    return 1
end

-- ============================================================
-- 流程
-- ============================================================

function ChoukaBangAllReady()
    local n = getn(ChoukaBangPrefPlayers)
    if n == 0 then
        return 1
    end
    local i
    for i = 1, n, 1 do
        if ChoukaBangReady[ChoukaBangPrefPlayers[i]] ~= 1 then
            return 0
        end
    end
    return 1
end

function ChoukaBangPrefReadyCount()
    local i, c
    c = 0
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        if ChoukaBangReady[ChoukaBangPrefPlayers[i]] == 1 then
            c = c + 1
        end
    end
    return c
end

-- 由 03_start.lua 在房主确认开局且玩法=三国杀时调用；节点体里也有一道兜底自启
function ChoukaBangBeginPreference()
    if ChoukaBangPrefDone == 1 then
        _LOG("三国杀：偏好跳过（PrefDone 已经是 1）")
        return 0
    end
    if ChoukaBangStage ~= 0 and ChoukaBangStage ~= 1 then
        _LOG("三国杀：偏好跳过（Stage=" .. (ChoukaBangStage or -1) .. "，只接受 0/1）")
        return 0
    end
    if ChoukaBangStage == 1 and getn(ChoukaBangPrefPlayers) > 0 then
        -- 已经在进行中：幂等，不重复弹面板
        return 1
    end

    ChoukaBangStage = 1
    ChoukaBangPrefTick = 0
    ChoukaBangPrefLastReadyTick = 0
    ChoukaBangPref = {}
    ChoukaBangReady = {}
    ChoukaBangPrefUiCreated = {}

    if type(ChoukaBangCollectSeats) == "function" then
        ChoukaBangCollectSeats()
    end

    -- ★ 只给真人座位弹面板（原因见文件头）。AI 座位不弹，身份直接随机。
    ChoukaBangPrefPlayers = ChoukaBangPrefCollectSeats()
    ChoukaBangPrefHumanPlayers = ChoukaBangPrefPlayers

    local i, name
    if getn(ChoukaBangPrefPlayers) == 0 then
        ChoukaAlert(ChoukaT.bangPrefNoApi)
        _LOG("三国杀：偏好跳过（没有真人座位可弹）")
        ChoukaBangPrefDone = 1
        return 1
    end

    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        ChoukaBangPrefShowFor(ChoukaBangPrefPlayers[i])
    end

    -- 面板没弹出来（接口缺失）→ 别干等 180 秒，直接随机
    if getn(ChoukaBangPrefUiCreated) == 0 then
        _LOG("三国杀：偏好面板没弹出来，直接随机身份（不等超时）")
        ChoukaBangPrefPlayers = {}
        ChoukaBangPrefDone = 1
        return 1
    end

    ChoukaAlert(format(ChoukaT.bangPrefBegin, CHOUKA_BANG_PREF_SECONDS))
    _LOG("三国杀：身份偏好面板已弹 —— 只弹给真人座位 " ..
         getn(ChoukaBangPrefPlayers) .. " 个（" ..
         ChoukaBangPrefPlayers[1] .. "）；参战座位 " .. getn(ChoukaBangSeats) ..
         " 个，其余随机；最多等 " .. CHOUKA_BANG_PREF_SECONDS .. " 秒")
    return 1
end

function ChoukaBangPrefFinish(timedOut)
    if ChoukaBangPrefDone == 1 then
        return 0
    end

    local i, name
    if timedOut == 1 then
        for i = 1, getn(ChoukaBangPrefPlayers), 1 do
            name = ChoukaBangPrefPlayers[i]
            if ChoukaBangPref[name] == nil then
                ChoukaBangPref[name] = ChoukaT.bangRoleAbstain
            end
            ChoukaBangReady[name] = 1
        end
        ChoukaAlert(ChoukaT.bangPrefTimeout)
    end

    -- 收面板（没选的人面板还开着，一起收掉）
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        ChoukaBangPrefHideFor(ChoukaBangPrefPlayers[i])
    end

    ChoukaBangPrefDone = 1
    _LOG("三国杀：身份偏好结束（timedOut=" .. (timedOut or 0) .. "）")
    return 1
end

function ChoukaBangPrefTickOnce()
    ChoukaBangPrefTick = ChoukaBangPrefTick + 1

    -- ① 该弹的座位都选过了 → 立刻收尾（单真人局：选完马上开局）
    if ChoukaBangAllReady() == 1 then
        ChoukaBangPrefFinish(0)
        return
    end

    -- ② 有人选过、且已静默 GRACE 秒 → 收尾（留给将来多个真人的场景兜底）
    if ChoukaBangPrefReadyCount() > 0 then
        if (ChoukaBangPrefTick - (ChoukaBangPrefLastReadyTick or 0)) >= CHOUKA_BANG_PREF_GRACE then
            _LOG("三国杀：选完静默 " .. CHOUKA_BANG_PREF_GRACE .. " 秒，偏好收尾")
            ChoukaBangPrefFinish(0)
            return
        end
    end

    -- ③ 硬超时
    if ChoukaBangPrefTick >= CHOUKA_BANG_PREF_SECONDS then
        ChoukaBangPrefFinish(1)
        return
    end

    -- ④ 没选的座位定期重弹（玩家把面板点叉了也能再拿到）
    if mod(ChoukaBangPrefTick, CHOUKA_BANG_PREF_REOPEN_EVERY) == 0 then
        local i, name
        for i = 1, getn(ChoukaBangPrefPlayers), 1 do
            name = ChoukaBangPrefPlayers[i]
            if ChoukaBangReady[name] ~= 1 then
                ChoukaBangPrefShowFor(name)
            end
        end
    end
end

-- ============================================================
-- 顶部按钮回调（由 16_buttons.lua 的 onCenterTopBtnClickEvent 分发进来）
--   偏好阶段已经改用原生选择页，这里只剩「情报按钮」一个分支。
-- ============================================================

function ChoukaBangOnBtn(playerName, btnIndex)
    if btnIndex == nil or playerName == nil then
        return 0
    end
    if btnIndex ~= CHOUKA_BANG_BTN_IDENTITY then
        return 0
    end
    if CHOUKA_MODE ~= 1 or ChoukaBangRolesReady ~= 1 then
        return 0
    end

    local seat = nil
    if type(ChoukaBangSeatOfName) == "function" then
        seat = ChoukaBangSeatOfName(playerName)
    end
    if seat == nil or ChoukaBangRole[seat] == nil then
        return 0
    end

    -- 点一下只开面板，**不再私发"你的身份是：X"**（面板里信息已经完整，作者要求去掉这条播报）；
    -- 悬浮框 desc 仍然重刷一次，保证鼠标划上去看到的是最新情报。
    if type(ChoukaBangForceIdentity) == "function" then
        ChoukaBangForceIdentity(playerName, seat)
    end
    -- 三国杀模式下，顶部身份按钮（index 5，间谍图标）就是**身份面板**的入口：
    -- 用 Toggle 与官渡 BangUiToggle 一致（面板已开时再点 = 关闭），面板本体见 35_ally_panel.lua
    if type(ChoukaPanelToggle) == "function" then
        ChoukaPanelToggle(seat)
    end
    return 1
end

-- ============================================================
-- 每次求值
-- ============================================================

if CHOUKA_MODE ~= 1 then
    return
end

-- ⚠ 回调只注册一次：脚本每次求值都会重新"定义"一遍函数（新的函数对象），
--   无脑 tinsert 会让处理函数表每秒变长，所以用标志位卡住（照 03_start.lua）
if ChoukaBangPrefHandlersRegistered ~= 1 then
    if type(ChoukaAddChoiceHandler) == "function" then
        ChoukaBangPrefHandlersRegistered = 1
        ChoukaAddChoiceHandler(ChoukaChoice_bangPref)
    end
end

-- 兜底自启：房主确认开局（ChoukaStartBangPath = 1，由 03_start 在确认分支里置位）之后，
-- 如果面板还没弹起来，就在这里补弹一次（幂等：已在投票中的会直接 return 1）
if ChoukaStartBangPath == 1 and ChoukaBangStage == 0 and ChoukaBangPrefDone ~= 1 then
    ChoukaBangBeginPreference()
end

if ChoukaBangStage == 1 and ChoukaBangPrefDone ~= 1 then
    if getn(ChoukaBangPrefPlayers) > 0 then
        ChoukaBangPrefTickOnce()
    end
end
