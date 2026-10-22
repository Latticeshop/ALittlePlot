-- ============================================================
-- 三国杀 · 胜负判定与结算
-- 详见 docs/11-三国杀模式方案.md §9 §10
--   出局 = 自己的起重机没了（01_income / 02_private_box / 05_dog 早就在按这条跳过座位，
--          所以这里只负责「记录死亡 + 公开身份 + 判胜负」，不需要 PLAYER_KILL 阵亡者）
--   胜负照赤壁 checkGameEnd（Bang_162_code:2-49），但做了两处修正，见 §9③
-- ============================================================

ChoukaMarkNodeReady("三国杀-胜负")

CHOUKA_BANG_RES_REBEL   = "rebel"
CHOUKA_BANG_RES_TRAITOR = "traitor"
CHOUKA_BANG_RES_LORD    = "lord"
CHOUKA_BANG_RES_NONE    = "none"

ChoukaBangEliminated = ChoukaBangEliminated or {}

function ChoukaBangSeatAlive(seat)
    local crane = GetObjectByScriptName("crane" .. seat)
    if ObjectIsAlive(crane) then
        return 1
    end
    return 0
end

function ChoukaBangResultText(code)
    if code == CHOUKA_BANG_RES_REBEL then
        return ChoukaT.bangWinRebel
    elseif code == CHOUKA_BANG_RES_TRAITOR then
        return ChoukaT.bangWinTraitor
    elseif code == CHOUKA_BANG_RES_LORD then
        return ChoukaT.bangWinLord
    end
    return ChoukaT.bangNoWinner
end

-- 阵亡播报：起重机没了 → 公开身份（照赤壁的暗将模型，只有死亡才揭身份）
function ChoukaBangAnnounceEliminations()
    local n = getn(ChoukaBangSeats)
    local i, seat, role
    for i = 1, n, 1 do
        seat = ChoukaBangSeats[i]
        role = ChoukaBangRole[seat]
        if role ~= nil and ChoukaBangEliminated[seat] ~= 1 then
            if ChoukaBangSeatAlive(seat) ~= 1 then
                ChoukaBangEliminated[seat] = 1
                -- ★ 全图通报（日志 + 左下消息区 + 公屏三路，见 00_core/00_alert.lua 的 ChoukaAlertFor）
                --   赤壁的原始形式是把身份写进记分板那一行（Bang_159_code:401-403），
                --   本图记分板没有身份位，所以改成公屏通报，效果等价且更直白。
                ChoukaAlertFor(format(ChoukaT.bangEliminated, ChoukaPlayerDisplayName(seat), role), 20)
                _LOG("三国杀：阵亡通报 —— Player_" .. seat .. " 身份 " .. role)
            end
        end
    end
    return 1
end

-- ============================================================
-- 胜负判定
--   ★ 与赤壁的两处差异：
--     ① 删掉「主公失去控制」那段（本图没有 PW<主公> 这个具名对象，起重机只会被摧毁）
--     ② 内奸判定从 alive_count==1 and traitor==1
--        改成 alive_count == traitor_count（场上只剩内奸），
--        这样 6 人局两个内奸不会在主公刚死时被提前判和
-- ============================================================

function ChoukaBangCheckGameEnd()
    local n = getn(ChoukaBangSeats)
    if n < 2 then
        return nil
    end

    local alive_count = 0
    local lord_alive = 0
    local loyalist_alive = 0
    local rebel_alive = 0
    local traitor_count = 0

    local i, seat, role
    for i = 1, n, 1 do
        seat = ChoukaBangSeats[i]
        if ChoukaBangSeatAlive(seat) == 1 then
            alive_count = alive_count + 1
            role = ChoukaBangRole[seat]
            if role == ChoukaT.bangRoleLord then
                lord_alive = 1
            elseif role == ChoukaT.bangRoleLoyalist then
                loyalist_alive = 1
            elseif role == ChoukaT.bangRoleRebel then
                rebel_alive = 1
            elseif role == ChoukaT.bangRoleTraitor then
                traitor_count = traitor_count + 1
            end
        end
    end

    if lord_alive == 0 then
        -- 主公阵亡后，还有反贼活着 → 反贼胜
        if rebel_alive == 1 then
            return CHOUKA_BANG_RES_REBEL
        end
        -- 内奸还在 → 只有"场上只剩内奸"才判内奸胜，否则还要先清掉忠臣
        if traitor_count >= 1 then
            if alive_count == traitor_count then
                return CHOUKA_BANG_RES_TRAITOR
            end
            return nil
        end
        -- 反贼与内奸都没了，主公也死了 → 无人可胜
        return CHOUKA_BANG_RES_NONE
    elseif rebel_alive == 0 and traitor_count == 0 then
        return CHOUKA_BANG_RES_LORD
    end

    return nil
end

-- ============================================================
-- 结算
-- ============================================================

function ChoukaBangSeatIsWinner(seat, code)
    local role = ChoukaBangRole[seat]
    if role == nil then
        return 0
    end
    if code == CHOUKA_BANG_RES_REBEL then
        if role == ChoukaT.bangRoleRebel then
            return 1
        end
        return 0
    elseif code == CHOUKA_BANG_RES_TRAITOR then
        if role == ChoukaT.bangRoleTraitor then
            return 1
        end
        return 0
    elseif code == CHOUKA_BANG_RES_LORD then
        if role == ChoukaT.bangRoleLord or role == ChoukaT.bangRoleLoyalist then
            return 1
        end
        return 0
    end
    return 0
end

function ChoukaBangEndGame(code)
    if CHOUKA_BANG_ENDED == 1 then
        return 0
    end
    CHOUKA_BANG_ENDED = 1
    ChoukaBangStage = 3

    local i, k, seat, otherName, otherSeat
    local winners = {}
    local n = getn(ChoukaBangSeats)

    for i = 1, n, 1 do
        seat = ChoukaBangSeats[i]
        if ChoukaBangSeatIsWinner(seat, code) == 1 then
            tinsert(winners, seat)
        end
    end

    -- ① 赢家之间互相友军（照赤壁 BangAllyWinners，Bang_162_code:130）
    if getn(winners) >= 2 then
        for i = 1, getn(winners), 1 do
            for k = i + 1, getn(winners), 1 do
                if type(ChoukaBangRelateBoth) == "function" then
                    ChoukaBangRelateBoth("Player_" .. winners[i],
                        "Player_" .. winners[k], CHOUKA_BANG_REL_FRIEND)
                end
            end
        end
    end

    -- ② 输家清场（照赤壁 BangKillLosers 的 PLAYER_KILL）
    if getn(winners) > 0 and type(ExecuteAction) == "function" then
        for i = 1, n, 1 do
            seat = ChoukaBangSeats[i]
            if ChoukaBangSeatIsWinner(seat, code) ~= 1 then
                ExecuteAction("PLAYER_KILL", "Player_" .. seat)
            end
        end
    end

    -- ③ 播报（ChoukaAlert 本身就是"日志 + 消息区 + 公屏"三路输出，见 00_core/00_alert.lua）
    local text = ChoukaBangResultText(code)
    ChoukaAlertFor(format(ChoukaT.bangGameOver, text), 30)

    -- ④ 把最终身份全公开（本局已结束，没有暗将的意义了）
    --   日志逐条留档 + 公屏再发一条"全员身份"总览，这样中途阵亡漏看的也能一次看清。
    local roster = ""
    for i = 1, n, 1 do
        seat = ChoukaBangSeats[i]
        if ChoukaBangRole[seat] ~= nil then
            _LOG("三国杀结算：Player_" .. seat .. " = " .. ChoukaBangRole[seat])
            if roster == "" then
                roster = format(ChoukaT.bangRosterItem, ChoukaPlayerDisplayName(seat), ChoukaBangRole[seat])
            else
                roster = roster .. "  " .. format(ChoukaT.bangRosterItem, ChoukaPlayerDisplayName(seat), ChoukaBangRole[seat])
            end
        end
    end
    if roster ~= "" then
        ChoukaAlertFor(format(ChoukaT.bangRoster, roster), 30)
    end

    return 1
end

-- ============================================================
-- 每次求值
-- ============================================================

if CHOUKA_MODE ~= 1 then
    return
end

if ChoukaBangRolesReady ~= 1 then
    return
end

if ChoukaBangStartApplied ~= 1 then
    return
end

if CHOUKA_BANG_ENDED == 1 then
    return
end

ChoukaBangAnnounceEliminations()

local bangResult = ChoukaBangCheckGameEnd()
if bangResult ~= nil then
    ChoukaBangEndGame(bangResult)
end
