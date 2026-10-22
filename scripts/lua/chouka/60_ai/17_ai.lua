-- ============================================================
-- 详见 docs/10-Lua注释存档.md §17_ai-1
-- ============================================================



ChoukaMarkNodeReady("AI对手")

CHOUKA_AI_DEBUG          = CHOUKA_AI_DEBUG or 0   -- 0 = 关闭诊断播报（功能已实测通过）
CHOUKA_AI_AUTO_DRAW      = 1   -- 1 = 每个回合给每个电脑座位免费抽卡
CHOUKA_AI_DRAW_BASE      = 1   -- 每回合抽几个的基数（作者定：初始 1 个）
CHOUKA_AI_DRAW_STEP      = 5   -- 每几个回合 +1 个（作者定：每 5 回合 +1）
CHOUKA_AI_DRAW_MAX       = 5   -- 上限（和自动升级封顶 Lv.5 保持一致；想不封顶就设大）
CHOUKA_AI_JOIN_NEUTRAL   = 1   -- 1 = 把非玩家阵营的单位加入 <阵营>/ATTACK（AI 攻击队列）
CHOUKA_AI_FORCE_PLAYER_ATTACK = 0  -- 1 = 连电脑玩家的兵也塞进 Player_N/ATTACK（一般不需要）
CHOUKA_AI_NEUTRAL_LEVELUP = 0  -- 1 = 中立单位入队时按自动等级升星（野怪会跟着变强）
CHOUKA_AI_SCAN_SECONDS   = 5   -- 多久扫一次全场（秒）
CHOUKA_AI_SCAN_RADIUS    = 8000 -- 以航点 center 为圆心扫全图（地图对角约 9000）

ChoukaAIJoinedIds   = ChoukaAIJoinedIds or {}    -- 已处理过的对象 id（避免每 5 秒重复 SET_TEAM）
ChoukaAIIsComputerCache = ChoukaAIIsComputerCache or {}
ChoukaAIScanTick    = ChoukaAIScanTick or 0
ChoukaAIDrawSerial  = ChoukaAIDrawSerial or 0
ChoukaAIReportedAI  = ChoukaAIReportedAI or {}   -- 已经播报过"这是电脑"的座位

-- ★ 开局门控：房主点过「确认，开始游戏」之后才开始（CHOUKA_GAME_STARTED 见 03_start.lua）
if CHOUKA_GAME_STARTED ~= 1 then
    return
end

-- ---------------- 小工具 ----------------

-- "Player_N" 这种名字 = 玩家座位（1~6）
function ChoukaAIIsSlotName(name)
    if name == nil or type(strsub) ~= "function" then
        return 0
    end
    if strsub(name, 1, 7) ~= "Player_" then
        return 0
    end
    local index = tonumber(strsub(name, 8))
    if index ~= nil and index >= 1 and index <= 6 then
        return 1
    end
    return 0
end

-- 自动升级线：第 5/10/15/20 回合后的等级（电脑只走这条线）
function ChoukaAutoLevelForRound(round)
    local level = 1
    if round ~= nil and ChoukaAutoLevelRound ~= nil then
        for lv, atRound in ChoukaAutoLevelRound do
            if round >= atRound and level < lv then
                level = lv
            end
        end
    end
    return level
end

-- 探测一次"AI"人格参数是否可用（只做一次）
if ChoukaAIAIProbeWorks == nil and type(EvaluateCondition) == "function" then
    ChoukaAIAIProbeWorks = 0
    for i = 1, 6, 1 do
        if EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", "Player_" .. i, "AI") then
            ChoukaAIAIProbeWorks = 1
        end
    end
    if CHOUKA_AI_DEBUG == 1 and ChoukaAIAIProbeWorks == 0 then
        ChoukaAlert(ChoukaT.aiPersona)
    end
end

-- 详见 docs/10-Lua注释存档.md §17_ai-2
function ChoukaAIIsComputer(index)
    if CHOUKA_AI_SLOTS ~= nil then
        if CHOUKA_AI_SLOTS[index] == 1 then
            return 1
        end
        return 0
    end

    local cached = ChoukaAIIsComputerCache[index]
    if cached ~= nil then
        return cached
    end

    if type(EvaluateCondition) ~= "function" then
        return 0
    end

    local name = "Player_" .. index
    if EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", name, "Human") then
        ChoukaAIIsComputerCache[index] = 0
        return 0
    end

    local verdict = 0
    if EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", name, "AI") then
        verdict = 1
    elseif ChoukaAIAIProbeWorks ~= 1 then
        -- "AI" 参数不被支持：把"非人类 + 有起重机 + 有钱"当成电脑
        local crane = GetObjectByScriptName("crane" .. index)
        local money = nil
        if type(exPlayerGetCurrentMoney) == "function" then
            money = exPlayerGetCurrentMoney(name)
        end
        if ObjectIsAlive(crane) and money ~= nil then
            verdict = 1
        end
    end

    ChoukaAIIsComputerCache[index] = verdict
    if verdict == 1 and CHOUKA_AI_DEBUG == 1 and ChoukaAIReportedAI[index] ~= 1 then
        ChoukaAIReportedAI[index] = 1
        ChoukaAlert(format(ChoukaT.aiDetected, ChoukaPlayerDisplayName(index)))
    end
    return verdict
end

-- ---------------- ① 电脑每回合免费抽 1 个单位 ----------------

-- 这个座位还在打吗？起重机 = 本图的"水晶"（权威判定见 00_core/04_seat.lua，含"退出=死亡"）。
--   ★ 实测：电脑被打掉起重机后，出局玩家的 unit spawn 依然生效，
--     所以"死了还在造兵"。抽兵前必须先过这道门。
function ChoukaAISeatAlive(index)
    if type(ChoukaSeatAlive) == "function" then
        return ChoukaSeatAlive(index)
    end
    if type(GetObjectByScriptName) ~= "function" then
        return 1
    end
    local crane = GetObjectByScriptName("crane" .. index)
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
function ChoukaAIStartPos(index)
    local wp = exWaypointGetPos("Player_" .. index .. "_Start")
    if wp ~= nil and wp[1] ~= nil then
        return wp[1], wp[2], wp[3]
    end
    local crane = GetObjectByScriptName("crane" .. index)
    if ObjectIsAlive(crane) then
        return ObjectGetPosition(crane)
    end
    return nil
end

function ChoukaAIDrawOne(index)
    if type(ChoukaSpawnUnit) ~= "function" then
        return 0
    end
    -- ★ 已出局（起重机被打掉）的座位不再出兵
    if ChoukaAISeatAlive(index) ~= 1 then
        return 0
    end
    local x, y, z = ChoukaAIStartPos(index)
    if x == nil then
        return 0
    end

    local playerName = "Player_" .. index
    -- 电脑的落点是自家出生点（陆地），按同一个判定入口问一次
    local onWater = 0
    if type(ChoukaTerrainAt) == "function" then
        onWater = ChoukaTerrainAt(x, y)
    end
    local level = ChoukaAutoLevelForRound(CHOUKA_ROUND)

    ChoukaAIDrawSerial = ChoukaAIDrawSerial + 1
    local slot = mod(ChoukaAIDrawSerial, 6) + 1
    local unit = ChoukaSpawnUnit(playerName, x, y, z, onWater, slot, 6, level)
    if unit ~= nil then
        -- 记一行坐标：万一"某人家门口多一个"，一眼能看出是不是电脑抽卡刷到了人类座位上
        if CHOUKA_DRAW_LOG == 1 then
            _LOG(format("AI抽卡 玩家=%s 位置=(%.0f,%.0f,%.0f) 水陆=%d Lv.%d",
                playerName, x, y, z or 0, onWater, level))
        end
        return 1
    end
    return 0
end

-- 每回合每个电脑抽几个：初始 1 个，每 5 回合 +1 个（上限 CHOUKA_AI_DRAW_MAX）
--   回合 0~4 → 1 个；5~9 → 2 个；10~14 → 3 个；15~19 → 4 个；20+ → 5 个
function ChoukaAIDrawCount(round)
    local count = CHOUKA_AI_DRAW_BASE
    if round ~= nil and round > 0 then
        count = CHOUKA_AI_DRAW_BASE + floor(round / CHOUKA_AI_DRAW_STEP)
    end
    if count > CHOUKA_AI_DRAW_MAX then
        count = CHOUKA_AI_DRAW_MAX
    end
    if count < 0 then
        count = 0
    end
    return count
end

-- 给一个电脑座位抽 n 个（每次都独立掷点数，所以这 n 个各是随机的）
function ChoukaAIDrawMany(index, count)
    local drawn = 0
    for k = 1, count, 1 do
        drawn = drawn + ChoukaAIDrawOne(index)
    end
    return drawn
end

local aiRoundChanged = (CHOUKA_ROUND ~= nil and ChoukaAILastRound ~= CHOUKA_ROUND)

if CHOUKA_AI_AUTO_DRAW == 1 and aiRoundChanged then
    ChoukaAILastRound = CHOUKA_ROUND
    local perSeat = ChoukaAIDrawCount(CHOUKA_ROUND)
    local drawnCount = 0
    for i = 1, 6, 1 do
        if ChoukaAIIsComputer(i) == 1 and ChoukaAISeatAlive(i) == 1 then
            drawnCount = drawnCount + ChoukaAIDrawMany(i, perSeat)
        end
    end
    if drawnCount > 0 and CHOUKA_AI_DEBUG == 1 then
        ChoukaAlert(format(ChoukaT.aiDrawInfo,
            CHOUKA_ROUND, perSeat, drawnCount, ChoukaAutoLevelForRound(CHOUKA_ROUND)))
    end
end

-- ---------------- ② AI 攻击队列（照 DSA PureDrawJoinAIAttackTeam） ----------------

-- 扫"能选中的、非建筑"的东西；箱子和抽卡箱剔除
function ChoukaAIUnitFilter()
    if ChoukaAIUnitFilterCache == nil then
        ChoukaAIUnitFilterCache = CreateObjectFilter({
            Rule = "ANY",
            Include = "SELECTABLE",
            Exclude = "STRUCTURE",
            ExcludeThing = {
                "moneycrate",           -- 我们的钱箱
                "LuckyUnitCrateSeed",   -- 抽卡箱（点开就是抽卡）
                "UnitCrateNew", "UnitCrate", "MoneyCrateMP", "MoneyCrate", "ShroudCrate",
            },
        })
    end
    return ChoukaAIUnitFilterCache
end

-- 把一个对象塞进攻击队：<owner>/ATTACK
function ChoukaAIJoinAttackTeam(unit, ownerName, unitId)
    local attackTeam = ownerName .. "/ATTACK"
    if type(ObjectTeamName) == "function" then
        local currentTeam = ObjectTeamName(unit)
        if currentTeam == attackTeam then
            ChoukaAIJoinedIds[unitId] = 1
            return 0
        end
    end

    ExecuteAction("UNIT_SET_TEAM", unit, attackTeam)

    -- 可选：跟着自动等级给星（DSA 也会按 LEVELUP 补星，这里默认关）
    if CHOUKA_AI_NEUTRAL_LEVELUP == 1 then
        local level = ChoukaAutoLevelForRound(CHOUKA_ROUND)
        for i = 2, level, 1 do
            ExecuteAction("UNIT_GAIN_LEVEL", unit, 1)
        end
    end
    ChoukaAIJoinedIds[unitId] = 1
    return 1
end

-- 扫全场：非玩家阵营的单位 → 攻击队；电脑玩家的单位 → 可选攻击队
function ChoukaAIScanUnits()
    local c = exWaypointGetPos("center")
    if c == nil or c[1] == nil then
        return 0
    end
    local cz = c[3]
    if cz == nil then
        cz = 0
    end

    local units, count = ObjectFindObjects(nil, {
        X = c[1], Y = c[2], Z = cz,
        Radius = CHOUKA_AI_SCAN_RADIUS,
        DistType = "CENTER_2D",
    }, ChoukaAIUnitFilter())
    if count == nil or count <= 0 then
        return 0
    end

    local joined = 0
    for i = 1, count, 1 do
        local unit = units[i]
        if unit ~= nil and ObjectIsAlive(unit) then
            local unitId = ObjectGetId(unit)
            if ChoukaAIJoinedIds[unitId] == nil then
                local ownerName = ObjectPlayerScriptName(unit)
                if ownerName == nil then
                    ChoukaAIJoinedIds[unitId] = 1        -- 认不出归属的不碰
                elseif ChoukaAIIsSlotName(ownerName) == 0 then
                    -- 非玩家阵营（PlyrCivilian / PlyrCreeps / 其它中立）
                    if CHOUKA_AI_JOIN_NEUTRAL == 1 then
                        joined = joined + ChoukaAIJoinAttackTeam(unit, ownerName, unitId)
                    else
                        ChoukaAIJoinedIds[unitId] = 1
                    end
                else
                    -- 玩家座位：电脑的兵可选入队（一般不需要，引擎 AI 自己会打）
                    local slotIndex = tonumber(strsub(ownerName, 8))
                    if CHOUKA_AI_FORCE_PLAYER_ATTACK == 1 and slotIndex ~= nil
                        and ChoukaAIIsComputer(slotIndex) == 1 then
                        joined = joined + ChoukaAIJoinAttackTeam(unit, ownerName, unitId)
                    else
                        ChoukaAIJoinedIds[unitId] = 1
                    end
                end
            end
        end
    end
    return joined
end

ChoukaAIScanTick = ChoukaAIScanTick + 1
if CHOUKA_AI_JOIN_NEUTRAL == 1 or CHOUKA_AI_FORCE_PLAYER_ATTACK == 1 then
    if ChoukaAIScanTick == 1 or mod(ChoukaAIScanTick, CHOUKA_AI_SCAN_SECONDS) == 0 then
        local joinedCount = ChoukaAIScanUnits()
        if joinedCount > 0 and CHOUKA_AI_DEBUG == 1 then
            ChoukaAlert(format(ChoukaT.aiAttackQueue, joinedCount))
        end
    end
end