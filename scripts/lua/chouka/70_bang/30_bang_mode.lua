-- ============================================================
-- 三国杀 · 身份核心（模式开关 / 参战座位 / 发身份 / 身份展示）
-- 详见 docs/11-三国杀模式方案.md §2 §4 §6
--   CHOUKA_MODE = 0 默认玩法（拆起重机争夺）/ 1 三国杀
--   本节点只在 CHOUKA_MODE == 1 时有执行体；默认玩法一个字节都不跑
-- ============================================================

ChoukaMarkNodeReady("三国杀-身份")

-- ---------------- 全局状态（Lua 桥的闭包拿不到外层 local，必须全是全局） ----------------

CHOUKA_MODE          = CHOUKA_MODE or 0
ChoukaBangStage      = ChoukaBangStage or 0    -- 0 未进入 / 1 偏好投票中 / 2 已发身份 / 3 已结算
CHOUKA_BANG_ENDED    = CHOUKA_BANG_ENDED or 0  -- 1 = 已结算，收入/箱子/军犬/中央全部停手
ChoukaBangPrefDone   = ChoukaBangPrefDone or 0 -- 偏好投票结束
ChoukaBangRolesReady = ChoukaBangRolesReady or 0

ChoukaBangSeats       = ChoukaBangSeats or {}   -- 参战座位号数组（下标连续，值 = 座位号）
ChoukaBangRole        = ChoukaBangRole or {}    -- 座位号 -> 身份名
ChoukaBangPlayerCount = ChoukaBangPlayerCount or 0
ChoukaBangIdentityTick = ChoukaBangIdentityTick or 0
ChoukaBangIdentitySig  = ChoukaBangIdentitySig or {}  -- playerName -> 上次写进悬浮框的内容（变了才重建）
ChoukaBangLordMarked   = ChoukaBangLordMarked or 0     -- 计分板上是否已标出主公

-- ---------------- 常量 ----------------

-- 顶部"情报"按钮：图标 = 神州渗透步兵（间谍）；desc 就是悬浮框，直接写当前身份
CHOUKA_BANG_BTN_IDENTITY = 5
CHOUKA_BANG_BTN_ICON     = "Button_CelestialInfiltrationInfantry"
CHOUKA_BANG_IDENTITY_TICK_MAX = 30   -- 发完身份后连刷 30 秒，覆盖 16_buttons 建整排按钮那一刻

-- 顶部按钮**没有单独的 Desc setter**（赤壁也踩过：Bang_160_code:710「Desc 似乎无法实时更新，
-- 所以在玩家死亡时删除旧按钮并重建」）。所以刷新只能"重新 Show 一次"。
-- 万一某个引擎版本 Show 不刷新 desc，把这个开关改 1：会先 SetVisibility 0 再 Show，强制重建。
CHOUKA_BANG_IDENTITY_HIDE_FIRST = CHOUKA_BANG_IDENTITY_HIDE_FIRST or 0

-- 身份表：照赤壁 Bang_159_code:18-30，只取 2~6 人（本图 6 个座位）
ChoukaBangRoleCounts = {
    [2] = { lord = 1, loyalist = 0, rebel = 1, traitor = 0 },
    [3] = { lord = 1, loyalist = 0, rebel = 1, traitor = 1 },
    [4] = { lord = 1, loyalist = 0, rebel = 2, traitor = 1 },
    [5] = { lord = 1, loyalist = 1, rebel = 2, traitor = 1 },
    [6] = { lord = 1, loyalist = 1, rebel = 2, traitor = 2 },
}

-- 固定遍历顺序（只用于"填剩余名额"时保持稳定）
function ChoukaBangRoleOrder()
    return {
        ChoukaT.bangRoleLord,
        ChoukaT.bangRoleLoyalist,
        ChoukaT.bangRoleRebel,
        ChoukaT.bangRoleTraitor,
    }
end

-- ---------------- 小工具 ----------------

-- 0..1 随机数：优先用引擎的 GetRandomNumber，取不到就用线性同余兜底
function ChoukaBangRand01()
    if type(GetRandomNumber) == "function" then
        local r = GetRandomNumber()
        if r ~= nil and r >= 0 and r < 1 then
            return r
        end
    end
    ChoukaBangRandSeed = mod((ChoukaBangRandSeed or 20240501) * 1103515245 + 12345, 2147483648)
    return ChoukaBangRandSeed / 2147483648
end

-- Fisher-Yates 原地洗牌（Lua 4.0：只能 getn / mod，没有 # 和 %）
function ChoukaBangShuffle(list)
    local n = getn(list)
    if n < 2 then
        return list
    end
    local i, j, tmp
    for i = n, 2, -1 do
        j = floor(ChoukaBangRand01() * i) + 1
        if j < 1 then
            j = 1
        end
        if j > i then
            j = i
        end
        tmp = list[i]
        list[i] = list[j]
        list[j] = tmp
    end
    return list
end

-- "Player_3" -> 3（不用 tonumber，避免 4.0 里的版本差异）
function ChoukaBangSeatOfName(playerName)
    if playerName == nil then
        return nil
    end
    local i
    for i = 1, 6, 1 do
        if playerName == "Player_" .. i then
            return i
        end
    end
    return nil
end

-- 参战座位 = 起重机活着且归属还是本人（与 01_income / 02_private_box / 05_dog 同一条链；
-- 归属校验见 00_core/04_seat.lua：退出/被占领不算参战）
-- AI 天然包含；空位不出现起重机，所以数量 = 真实参战人数
function ChoukaBangCollectSeats()
    ChoukaBangSeats = {}
    local i, crane, alive
    for i = 1, 6, 1 do
        crane = GetObjectByScriptName("crane" .. i)
        alive = 0
        if type(ChoukaSeatAlive) == "function" then
            alive = ChoukaSeatAlive(i)
        elseif ObjectIsAlive(crane) then
            alive = 1
        end
        if alive == 1 then
            tinsert(ChoukaBangSeats, i)
        end
    end
    ChoukaBangPlayerCount = getn(ChoukaBangSeats)
    return ChoukaBangPlayerCount
end

-- 某个身份在"当前人数"下的名额（给偏好卡片的悬浮提示用）
function ChoukaBangRoleCountOf(role)
    local tbl = ChoukaBangRoleCounts[ChoukaBangPlayerCount]
    if tbl == nil then
        return 0
    end
    if role == ChoukaT.bangRoleLord then
        return tbl.lord
    elseif role == ChoukaT.bangRoleLoyalist then
        return tbl.loyalist
    elseif role == ChoukaT.bangRoleRebel then
        return tbl.rebel
    elseif role == ChoukaT.bangRoleTraitor then
        return tbl.traitor
    end
    return 0
end

-- 私发一条给单个玩家（ForPlayer 通道，别人看不到）
function ChoukaBangTellPlayer(playerName, text)
    if type(exAddTextToPublicBoardForPlayer) == "function" then
        exAddTextToPublicBoardForPlayer(playerName, text, 12)
    end
    _LOG(text .. "   -> " .. playerName)
end

-- ============================================================
-- 顶部「情报」按钮 = 常驻情报面板（悬浮框 desc 里塞三行）
--
--   你的身份：内奸
--   主公：Player_3
--   当前存活：主公、忠臣x1、反贼x2、内奸x1
--
-- 主公之所以能公开：三国杀原本主公就是明牌（赤壁 Bang_159_code:416-420 lorddeathdisplay 里
-- 主公永远带标记）。其余身份仍然暗着，只在阵亡时由 33_bang_win.lua 全图通报。
-- ============================================================

-- 某个座位还活着吗（优先复用 33 号节点的权威实现，没加载就退化成自己的判断）
function ChoukaBangAliveSeat(seat)
    if type(ChoukaBangSeatAlive) == "function" then
        return ChoukaBangSeatAlive(seat)
    end
    if type(GetObjectByScriptName) ~= "function" then
        return 1
    end
    local crane = GetObjectByScriptName("crane" .. seat)
    if crane == nil then
        return 0
    end
    if ObjectIsAlive(crane) then
        return 1
    end
    return 0
end

-- 主公是谁（本局一定有一个主公）
function ChoukaBangLordSeat()
    local i, seat
    for i = 1, getn(ChoukaBangSeats), 1 do
        seat = ChoukaBangSeats[i]
        if ChoukaBangRole[seat] == ChoukaT.bangRoleLord then
            return seat
        end
    end
    return nil
end

-- 「主公、忠臣x1、反贼x2、内奸x1」——只统计还活着的
function ChoukaBangAliveRoleSummary()
    local i, seat, role
    local lord, loyal, rebel, traitor
    lord = 0
    loyal = 0
    rebel = 0
    traitor = 0
    for i = 1, getn(ChoukaBangSeats), 1 do
        seat = ChoukaBangSeats[i]
        if ChoukaBangAliveSeat(seat) == 1 then
            role = ChoukaBangRole[seat]
            if role == ChoukaT.bangRoleLord then
                lord = lord + 1
            elseif role == ChoukaT.bangRoleLoyalist then
                loyal = loyal + 1
            elseif role == ChoukaT.bangRoleRebel then
                rebel = rebel + 1
            elseif role == ChoukaT.bangRoleTraitor then
                traitor = traitor + 1
            end
        end
    end

    local out = ""
    if lord > 0 then
        out = ChoukaT.bangRoleLord            -- 主公唯一，不写 x1
    end
    if loyal > 0 then
        out = ChoukaBangJoin(out, format(ChoukaT.bangAliveCount, ChoukaT.bangRoleLoyalist, loyal))
    end
    if rebel > 0 then
        out = ChoukaBangJoin(out, format(ChoukaT.bangAliveCount, ChoukaT.bangRoleRebel, rebel))
    end
    if traitor > 0 then
        out = ChoukaBangJoin(out, format(ChoukaT.bangAliveCount, ChoukaT.bangRoleTraitor, traitor))
    end
    if out == "" then
        out = ChoukaT.bangAliveNone
    end
    return out
end

-- 用「、」把两段拼起来（Lua 4.0 没有 table.concat）
function ChoukaBangJoin(head, tail)
    if head == nil or head == "" then
        return tail
    end
    return head .. ChoukaT.bangAliveSep .. tail
end

-- 悬浮框正文（三~四行，\n 分隔）
function ChoukaBangIdentityDesc(seat)
    local role = ChoukaBangRole[seat]
    if role == nil then
        return ""
    end
    local out = format(ChoukaT.bangInfoSelf, role)
    if ChoukaBangAliveSeat(seat) ~= 1 then
        out = out .. "\n" .. ChoukaT.bangInfoDead
    end
    out = out .. "\n" .. format(ChoukaT.bangInfoAlive, ChoukaBangAliveRoleSummary())
    out = out .. "\n" .. ChoukaT.panelBtnDescBang
    return out
end

-- 底层：把 desc 写进顶部按钮
function ChoukaBangShowIdentityWithDesc(playerName, desc)
    if desc == nil or desc == "" then
        return 0
    end
    if type(exCenterTopBtnShowForPlayer) == "function" then
        exCenterTopBtnShowForPlayer(playerName, CHOUKA_BANG_BTN_IDENTITY,
            CHOUKA_BANG_BTN_ICON, desc)
    elseif type(exCenterTopBtnShow) == "function" then
        exCenterTopBtnShow(CHOUKA_BANG_BTN_IDENTITY, CHOUKA_BANG_BTN_ICON, desc)
    else
        return 0
    end
    if type(exCenterTopBtnSetEnableForPlayer) == "function" then
        exCenterTopBtnSetEnableForPlayer(playerName, CHOUKA_BANG_BTN_IDENTITY, 1)
    end
    return 1
end

-- 无条件重刷（开局头 30 秒用，覆盖 16_buttons 建整排按钮那一刻）
function ChoukaBangForceIdentity(playerName, seat)
    local desc = ChoukaBangIdentityDesc(seat)
    if desc == "" then
        return 0
    end
    ChoukaBangIdentitySig[playerName] = desc
    return ChoukaBangShowIdentityWithDesc(playerName, desc)
end

-- 内容变了才重建（有人阵亡 / 主公变化 / 存活构成变化）
function ChoukaBangRefreshIdentity(playerName, seat)
    local desc = ChoukaBangIdentityDesc(seat)
    if desc == "" then
        return 0
    end
    if ChoukaBangIdentitySig[playerName] == desc then
        return 0
    end
    ChoukaBangIdentitySig[playerName] = desc
    if CHOUKA_BANG_IDENTITY_HIDE_FIRST == 1 then
        if type(exCenterTopBtnSetVisibilityForPlayer) == "function" then
            exCenterTopBtnSetVisibilityForPlayer(playerName, CHOUKA_BANG_BTN_IDENTITY, 0)
        end
    end
    return ChoukaBangShowIdentityWithDesc(playerName, desc)
end

-- 老名字保留（外面还有调用点），语义 = 无条件重刷
function ChoukaBangShowIdentityButton(playerName, seat)
    return ChoukaBangForceIdentity(playerName, seat)
end

function ChoukaBangPublishIdentities()
    local i, seat, role, name
    for i = 1, getn(ChoukaBangSeats), 1 do
        seat = ChoukaBangSeats[i]
        role = ChoukaBangRole[seat]
        if role ~= nil then
            name = "Player_" .. seat
            ChoukaBangTellPlayer(name, format(ChoukaT.bangYourRole, role))
            ChoukaBangForceIdentity(name, seat)
        end
    end

    -- ★ 赤壁同款：给主公在右上角计分板那一行打上【主公】标记
    --   （记分板 / 公屏 / 消息区都会替换 $p<N>Name，所以这里能看到真实名字；
    --     而顶部悬浮框 desc 不替换，这是"主公叫什么"最可靠的展示位置）
    ChoukaBangMarkLordOnBoard()
end

-- 在计分板上标出主公（只做一次，20_hud 的每秒刷新只动第 2 列，不会覆盖第 1 列）
function ChoukaBangMarkLordOnBoard()
    if ChoukaBangLordMarked == 1 then
        return 1
    end
    if type(exScoreBoardSetText) ~= "function" then
        _LOG("三国杀：没有 exScoreBoardSetText，主公标记跳过")
        ChoukaBangLordMarked = 1
        return 0
    end
    local lord = ChoukaBangLordSeat()
    if lord == nil then
        return 0
    end
    exScoreBoardSetText(format(ChoukaT.bangBoardLordMark, ChoukaPlayerDisplayName(lord)), lord, 1)
    ChoukaBangLordMarked = 1
    _LOG("三国杀：计分板第 " .. lord .. " 行已标出主公")
    return 1
end

-- ============================================================
-- 发身份：偏好优先 → 剩余名额随机补齐
-- ============================================================

function ChoukaBangAssignRoles()
    local count = ChoukaBangCollectSeats()

    -- 人数不足 2（或表里没有这一档）：降级为默认玩法，别让整局卡死
    if count < 2 or ChoukaBangRoleCounts[count] == nil then
        CHOUKA_MODE = 0
        ChoukaBangPrefDone = 1
        ChoukaBangRolesReady = 1
        ChoukaBangDegraded = 1
        ChoukaAlert(ChoukaT.bangDegrade)
        return 0
    end

    local tbl = ChoukaBangRoleCounts[count]
    local quota = {}
    quota[ChoukaT.bangRoleLord]     = tbl.lord
    quota[ChoukaT.bangRoleLoyalist] = tbl.loyalist
    quota[ChoukaT.bangRoleRebel]    = tbl.rebel
    quota[ChoukaT.bangRoleTraitor]  = tbl.traitor

    -- 座位池洗牌：让"同样的偏好"在多人竞争时也是公平的
    local pool = {}
    local i, k
    for i = 1, count, 1 do
        tinsert(pool, ChoukaBangSeats[i])
    end
    ChoukaBangShuffle(pool)

    ChoukaBangRole = {}
    local taken = {}

    -- 第一轮：有偏好且该身份名额还够 → 直接给
    local seat, name, want
    for i = 1, count, 1 do
        seat = pool[i]
        name = "Player_" .. seat
        want = ChoukaBangPref[name]
        if want ~= nil and want ~= ChoukaT.bangRoleAbstain then
            if quota[want] ~= nil and quota[want] > 0 then
                ChoukaBangRole[seat] = want
                quota[want] = quota[want] - 1
                taken[seat] = 1
            end
        end
    end

    -- 第二轮：把剩下的名额拍成一个数组、洗牌，依次发给没身份的人
    local remain = {}
    local order = ChoukaBangRoleOrder()
    local q, rn, r
    for r = 1, getn(order), 1 do
        rn = order[r]
        q = quota[rn]
        if q ~= nil and q > 0 then
            for k = 1, q, 1 do
                tinsert(remain, rn)
            end
        end
    end
    ChoukaBangShuffle(remain)

    local idx = 1
    for i = 1, count, 1 do
        seat = pool[i]
        if taken[seat] ~= 1 then
            if remain[idx] ~= nil then
                ChoukaBangRole[seat] = remain[idx]
                idx = idx + 1
            end
            taken[seat] = 1
        end
    end

    -- 找主公座位（身份表保证主公恰好 1 个）
    ChoukaBangLordIndex = nil
    for i = 1, count, 1 do
        seat = ChoukaBangSeats[i]
        if ChoukaBangRole[seat] == ChoukaT.bangRoleLord then
            ChoukaBangLordIndex = seat
        end
    end

    -- 私发身份 + 顶部情报按钮
    ChoukaBangPublishIdentities()

    ChoukaBangRolesReady = 1
    ChoukaBangStage = 2
    ChoukaBangIdentityTick = 0

    -- 关系在这里设不了（31 号节点可能还没跑到），交给 31 的每次求值补设
    if type(ChoukaBangApplyInitialRelations) == "function" then
        if ChoukaBangApplyInitialRelations() == 1 then
            ChoukaBangRelationsApplied = 1
        end
    end

    ChoukaAlert(format(ChoukaT.bangAssigned, count,
        tbl.lord, tbl.loyalist, tbl.rebel, tbl.traitor))
    if ChoukaBangLordIndex ~= nil then
        _LOG("三国杀：主公 = Player_" .. ChoukaBangLordIndex)
    end

    local seatList = ""
    for i = 1, count, 1 do
        seat = ChoukaBangSeats[i]
        if seatList == "" then
            seatList = "Player_" .. seat .. "=" .. (ChoukaBangRole[seat] or "?")
        else
            seatList = seatList .. "," .. "Player_" .. seat .. "=" .. (ChoukaBangRole[seat] or "?")
        end
    end
    _LOG("三国杀：身份分布 = " .. seatList)
    return 1
end

-- ============================================================
-- 每次求值
-- ============================================================

if CHOUKA_MODE ~= 1 then
    return
end

-- ① 偏好投票结束 → 发身份（等 32 号节点把 ChoukaBangPrefDone 置 1）
if ChoukaBangPrefDone == 1 and ChoukaBangRolesReady ~= 1 then
    ChoukaBangAssignRoles()
end

-- ② 顶部情报按钮 = 常驻情报面板
--    头 30 秒：无条件重刷（16_buttons 的 exCenterTopBtnsChangeVisibilityForPlayer 可能把整排按钮重置掉）
--    之后：只在"面板内容变了"时重建（有人阵亡 → 存活构成变化）
--          顶部按钮没有 Desc setter，所以"变一次重建一次"，不每秒硬刷
if ChoukaBangRolesReady == 1 then
    local i, seat, role
    if ChoukaBangIdentityTick < CHOUKA_BANG_IDENTITY_TICK_MAX then
        ChoukaBangIdentityTick = ChoukaBangIdentityTick + 1
        for i = 1, getn(ChoukaBangSeats), 1 do
            seat = ChoukaBangSeats[i]
            if ChoukaBangRole[seat] ~= nil then
                ChoukaBangForceIdentity("Player_" .. seat, seat)
            end
        end
    else
        for i = 1, getn(ChoukaBangSeats), 1 do
            seat = ChoukaBangSeats[i]
            if ChoukaBangRole[seat] ~= nil then
                ChoukaBangRefreshIdentity("Player_" .. seat, seat)
            end
        end
    end
end
