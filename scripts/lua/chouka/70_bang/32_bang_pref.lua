-- ============================================================
-- 三国杀 · 身份偏好（原生选择页 + 文字选项），详见 docs/11 §5
--   ★ 每人一份独立面板：面板 id = 730 + 座位号；等**所有人选完**才发身份开局；
--     没选的人每 2 秒重弹一次自己的面板；保险丝到点按弃权收口。
-- 详见 docs/10-Lua注释存档.md §32_bang_pref-1
-- ============================================================

ChoukaMarkNodeReady("三国杀-偏好")

-- ---------------- 常量 ----------------

-- 原生选择页 id 基址。已占用：700+序号=交易市场(701~706)、710+序号=防御塔(711~716)、
--                          810=开局公告长文本、811=房主配置页、730+序号=身份偏好(731~736)
CHOUKA_BANG_PREF_DIALOG       = 730

-- 保险丝：到点还没选完就按弃权收口（0 = 不设保险丝，只等所有人选完）
CHOUKA_BANG_PREF_SECONDS      = CHOUKA_BANG_PREF_SECONDS or 300

-- AI 座位的宽限：给它们这么多秒"假装在考虑"，然后自动弃权（真人不受影响）
CHOUKA_BANG_PREF_AI_GRACE     = CHOUKA_BANG_PREF_AI_GRACE or 6

-- 静默兜底：已经有人作答之后，还没作答的座位再等这么多秒就按弃权（0 = 关掉这条）
--   用途：认不出的电脑座位不会点面板，不能让人干等 300 秒保险丝
CHOUKA_BANG_PREF_SILENT       = CHOUKA_BANG_PREF_SILENT or 60

-- 还没选的话，每隔这么多秒重新弹一次面板（玩家把面板点叉了也能马上再拿到）
--   参考官渡：偏好对话框是在节点体里**每次求值都重弹**的，所以永远不会被关掉就再也出不来
CHOUKA_BANG_PREF_REOPEN_EVERY = CHOUKA_BANG_PREF_REOPEN_EVERY or 2

-- ---------------- 状态（全局：Lua 桥的闭包拿不到外层 local） ----------------

ChoukaBangPref              = ChoukaBangPref or {}         -- playerName -> 想要的身份
ChoukaBangReady             = ChoukaBangReady or {}        -- playerName -> 1 已选过
ChoukaBangPrefPlayers       = ChoukaBangPrefPlayers or {}  -- 要等的人（参战座位，电脑也在内，会自动弃权）
ChoukaBangPrefHumanPlayers  = ChoukaBangPrefHumanPlayers or {}
ChoukaBangPrefAiPlayers     = ChoukaBangPrefAiPlayers or {}-- 其中判定为电脑的座位
ChoukaBangPrefTick          = ChoukaBangPrefTick or 0
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
-- 座位 ↔ 玩家名
-- ============================================================

function ChoukaBangPrefSeatOfName(playerName)
    if playerName == nil then
        return nil
    end
    if strsub(playerName, 1, 7) ~= "Player_" then
        return nil
    end
    return tonumber(strsub(playerName, 8))
end

-- 某个座位对应的面板 id（每人一份，绝不共用）
function ChoukaBangPrefDialogOf(seat)
    return CHOUKA_BANG_PREF_DIALOG + seat
end

-- 从面板 id 反推座位（不是我们的一律返回 nil）
function ChoukaBangPrefSeatOfDialog(dialogId)
    if dialogId == nil then
        return nil
    end
    local seat = dialogId - CHOUKA_BANG_PREF_DIALOG
    if seat < 1 or seat > 6 then
        return nil
    end
    return seat
end

-- ============================================================
-- 要等哪些人：全部参战座位（ChoukaBangSeats），AI 座位弹了无害、宽限后自动弃权。
-- 真人识别完全失灵时一个都不自动弃权（宁可等保险丝，也不能把真人当 AI 提前收口）。
-- 详见 docs/10-Lua注释存档.md §32_bang_pref-1
-- ============================================================

-- 这座位是电脑吗（电脑不会点面板，只能被自动记成弃权）
--   ① 作者显式配置的 CHOUKA_AI_SLOTS 最可靠；
--   ② 否则问人格条件（和 17_ai.lua 同一条判据）；
--   ③ 都判不出来就当"人"——宁可等，也不要把真人当电脑提前收口。
function ChoukaBangPrefIsAi(seat)
    if seat == nil then
        return 0
    end
    local name = "Player_" .. seat
    if type(CHOUKA_AI_SLOTS) == "table" then
        if CHOUKA_AI_SLOTS[seat] == 1 then
            return 1
        end
    end
    -- 房主 / <1st Human Player> 一定是人（03_start 认出来的）
    if name == ChoukaStartHost then
        return 0
    end
    if type(ObjectPlayerScriptName) == "function" then
        if ObjectPlayerScriptName("<1st Human Player>") == name then
            return 0
        end
    end
    if type(EvaluateCondition) == "function" then
        if EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", name, "AI") then
            return 1
        end
    end
    return 0
end

function ChoukaBangPrefCollectSeats()
    local out = {}
    local i, seat, name

    if type(ChoukaBangSeats) == "table" and getn(ChoukaBangSeats) > 0 then
        for i = 1, getn(ChoukaBangSeats), 1 do
            seat = ChoukaBangSeats[i]
            if seat ~= nil then
                tinsert(out, "Player_" .. seat)
            end
        end
        return out
    end

    -- 参战座位还没收集（30 号节点没跑）→ 退回"有起重机的座位"
    for seat = 1, 6, 1 do
        name = "Player_" .. seat
        if type(ChoukaSeatCrane) == "function" then
            if ChoukaSeatCrane(seat) ~= nil then
                tinsert(out, name)
            end
        elseif type(GetObjectByScriptName) == "function" then
            if GetObjectByScriptName("crane" .. seat) ~= nil then
                tinsert(out, name)
            end
        end
    end
    return out
end

-- ============================================================
-- 原生选择页（每人一份 id）
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

    local seat = ChoukaBangPrefSeatOfName(playerName)
    if seat == nil then
        return 0
    end

    local args = { playerName, ChoukaBangPrefDialogOf(seat), ChoukaT.bangPrefTitle }
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

function ChoukaBangPrefHideAll()
    local i
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        ChoukaBangPrefHideFor(ChoukaBangPrefPlayers[i])
    end
    return 1
end

-- ============================================================
-- 选择页回调（由 16_buttons.lua 的 onUserBtnChoiceDialogEvent 分发进来）
--   签名照 03_start.lua 的 ChoukaChoice_start：(playerName, btnIndex, dialogId)
--   面板 id = 730 + 座位 → 每个座位只认自己那份；别人的 id 一律不接
-- ============================================================

function ChoukaChoice_bangPref(playerName, btnIndex, dialogId)
    if ChoukaBangPrefSeatOfDialog(dialogId) == nil then
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

    local seat = ChoukaBangPrefSeatOfName(playerName)
    if seat == nil then
        return 1
    end

    local role = roles[btnIndex]
    ChoukaBangPref[playerName] = role
    ChoukaBangReady[playerName] = 1
    ChoukaBangPrefHideFor(playerName)

    _LOG("三国杀：偏好 " .. playerName .. "（座位 " .. seat .. "）选了 " .. role)
    if type(ChoukaBangTellPlayer) == "function" then
        ChoukaBangTellPlayer(playerName, format(ChoukaT.bangPrefYouPicked, role))
    else
        ChoukaTellPlayer(playerName, format(ChoukaT.bangPrefYouPicked, role))
    end

    -- 给所有人刷一下进度（"已选 x/y 人"），让大家知道还差谁
    ChoukaBangPrefAnnounceProgress()
    return 1
end

-- ============================================================
-- 进度 / 收尾
-- ============================================================

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

function ChoukaBangPrefAnnounceProgress()
    local total = getn(ChoukaBangPrefPlayers)
    if total == 0 then
        return 0
    end
    local text = format(ChoukaT.bangPrefWait, ChoukaBangPrefReadyCount(), total)
    _LOG("三国杀：" .. text)
    -- 公屏播一条进度（每次有人选完才播，最多 total 条），让大家知道还差几个人
    ChoukaAlert(text)
    return 1
end

-- 所有要等的人都作答了吗（AI 座位由宽限逻辑提前记成弃权，所以"全部"是可达的）
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
    ChoukaBangPref = {}
    ChoukaBangReady = {}
    ChoukaBangPrefUiCreated = {}
    ChoukaBangPrefAiPlayers = {}
    ChoukaBangPrefHumanPlayers = {}

    if type(ChoukaBangCollectSeats) == "function" then
        ChoukaBangCollectSeats()
    end

    ChoukaBangPrefPlayers = ChoukaBangPrefCollectSeats()

    local i, name
    if getn(ChoukaBangPrefPlayers) == 0 then
        ChoukaAlert(ChoukaT.bangPrefNoApi)
        _LOG("三国杀：偏好跳过（没有参战座位可弹）")
        ChoukaBangPrefDone = 1
        return 1
    end

    -- 分拣：电脑座位不点面板，宽限后自动弃权；人类座位一律等（公平性）
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        name = ChoukaBangPrefPlayers[i]
        if ChoukaBangPrefIsAi(ChoukaBangPrefSeatOfName(name)) == 1 then
            tinsert(ChoukaBangPrefAiPlayers, name)
        else
            tinsert(ChoukaBangPrefHumanPlayers, name)
        end
    end

    -- 给**每个参战座位**各弹一份自己的面板（id = 730 + 座位）
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        ChoukaBangPrefShowFor(ChoukaBangPrefPlayers[i])
    end

    -- 面板没弹出来（接口缺失）→ 别干等，直接随机
    if getn(ChoukaBangPrefUiCreated) == 0 then
        _LOG("三国杀：偏好面板没弹出来，直接随机身份（不等超时）")
        ChoukaBangPrefPlayers = {}
        ChoukaBangPrefDone = 1
        return 1
    end

    ChoukaAlert(format(ChoukaT.bangPrefBegin, 0, getn(ChoukaBangPrefPlayers)))
    _LOG("三国杀：身份偏好开始 —— 参战座位 " .. getn(ChoukaBangPrefPlayers) ..
         " 个（电脑 " .. getn(ChoukaBangPrefAiPlayers) ..
         " 个，其余等真人选），每人一份面板 id " .. ChoukaBangPrefDialogOf(1) .. "~" ..
         ChoukaBangPrefDialogOf(6) .. "，所有人选完才开局" ..
         "（保险丝 " .. CHOUKA_BANG_PREF_SECONDS .. " 秒，静默 " ..
         CHOUKA_BANG_PREF_SILENT .. " 秒）")
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
        ChoukaAlert(format(ChoukaT.bangPrefTimeout, CHOUKA_BANG_PREF_SECONDS))
    end

    -- 收面板（没选的人面板还开着，一起收掉）
    ChoukaBangPrefHideAll()

    ChoukaBangPrefDone = 1
    _LOG("三国杀：身份偏好结束（timedOut=" .. (timedOut or 0) .. "，已选 " ..
         ChoukaBangPrefReadyCount() .. "/" .. getn(ChoukaBangPrefPlayers) .. "）")
    return 1
end

-- 座位中途没了（退出/被拆）：自动按弃权，绝不为一个已经不在的人卡住整局
function ChoukaBangPrefSweepMissing()
    local i, name, seat
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        name = ChoukaBangPrefPlayers[i]
        if ChoukaBangReady[name] ~= 1 then
            seat = ChoukaBangPrefSeatOfName(name)
            local alive = 1
            if type(ChoukaBangSeatAlive) == "function" then
                alive = ChoukaBangSeatAlive(seat)
            end
            if alive ~= 1 then
                ChoukaBangPref[name] = ChoukaT.bangRoleAbstain
                ChoukaBangReady[name] = 1
                _LOG("三国杀：偏好 —— " .. name .. " 已经不在了，自动弃权")
            end
        end
    end
    return 1
end

-- 电脑座位宽限后自动弃权（真人座位一律等；见 BeginPreference 的说明）
function ChoukaBangPrefSweepAi()
    if ChoukaBangPrefTick < CHOUKA_BANG_PREF_AI_GRACE then
        return 0
    end
    local i, name
    for i = 1, getn(ChoukaBangPrefAiPlayers), 1 do
        name = ChoukaBangPrefAiPlayers[i]
        if ChoukaBangReady[name] ~= 1 then
            ChoukaBangPref[name] = ChoukaT.bangRoleAbstain
            ChoukaBangReady[name] = 1
            _LOG("三国杀：偏好 —— " .. name .. " 是电脑，自动弃权")
        end
    end
    return 1
end

-- 静默兜底：**已经有人作答**之后，还没作答的座位再等 CHOUKA_BANG_PREF_SILENT 秒就按弃权
--   为什么需要它：这台机器上"人格条件"不一定认得出电脑（历史上 Human 参数直接返回空），
--   认不出的电脑座位就会一直不点 → 只能等保险丝（300 秒），单机测起来很难受。
--   条件写得很保守：必须先有人真的作答（证明这套面板是能点的），再给足静默时间。
--   设成 0 = 关掉这条，完全只等所有人选完 / 保险丝。
function ChoukaBangPrefSweepSilent()
    if CHOUKA_BANG_PREF_SILENT <= 0 then
        return 0
    end
    if ChoukaBangPrefTick < CHOUKA_BANG_PREF_SILENT then
        return 0
    end
    if ChoukaBangPrefReadyCount() <= 0 then
        return 0
    end
    local i, name
    for i = 1, getn(ChoukaBangPrefPlayers), 1 do
        name = ChoukaBangPrefPlayers[i]
        if ChoukaBangReady[name] ~= 1 then
            ChoukaBangPref[name] = ChoukaT.bangRoleAbstain
            ChoukaBangReady[name] = 1
            _LOG("三国杀：偏好 —— " .. name .. " 静默 " .. CHOUKA_BANG_PREF_SILENT .. " 秒未作答，按弃权")
        end
    end
    return 1
end

function ChoukaBangPrefTickOnce()
    ChoukaBangPrefTick = ChoukaBangPrefTick + 1

    -- ① 座位中途没了 → 自动弃权（不然整局卡在这里）
    ChoukaBangPrefSweepMissing()

    -- ② 电脑座位宽限后自动弃权
    ChoukaBangPrefSweepAi()

    -- ③ ★ 全部作答 → 收尾（作者要求：等到所有人选完才发身份开局）
    if ChoukaBangAllReady() == 1 then
        ChoukaBangPrefFinish(0)
        return
    end

    -- ④ 保险丝（0 = 不设保险丝，只等所有人选完）
    if CHOUKA_BANG_PREF_SECONDS > 0 and ChoukaBangPrefTick >= CHOUKA_BANG_PREF_SECONDS then
        ChoukaBangPrefFinish(1)
        return
    end

    -- ⑤ 静默兜底（认不出的电脑座位，别让人干等保险丝）
    ChoukaBangPrefSweepSilent()
    if ChoukaBangAllReady() == 1 then
        ChoukaBangPrefFinish(0)
        return
    end

    -- ⑥ 还没选的人：每隔 CHOUKA_BANG_PREF_REOPEN_EVERY 秒重弹一次自己的面板
    --    （照官渡"每帧重弹"的思路，玩家手滑关掉/被引擎关掉都能马上再拿到）
    if mod(ChoukaBangPrefTick - 1, CHOUKA_BANG_PREF_REOPEN_EVERY) == 0 then
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

-- ============================================================
-- 详见 docs/10-Lua注释存档.md §32_bang_pref-1
-- ============================================================
