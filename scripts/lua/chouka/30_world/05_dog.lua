-- ============================================================
-- 详见 docs/10-Lua注释存档.md §05_dog-1
-- ============================================================

CHOUKA_DOG_RETRY_SECONDS = 5      -- 工程师没了之后隔几秒再补（节点是 1 秒一次）
CHOUKA_DOG_FORWARD       = 0.55   -- 从起重机往出生点走多远（0=起重机处，1=出生点）
CHOUKA_DOG_SERIAL        = 0

ChoukaMarkNodeReady("保底军犬")

-- 详见 docs/10-Lua注释存档.md §05_dog-2
ChoukaDogLastType = nil
ChoukaDogSameCount = 0

function ChoukaFallbackUnitType()
    local pick = "AlliedEngineer"
    if type(GetRandomNumber) == "function" then
        local r = GetRandomNumber()
        if r ~= nil and mod(floor(r * 1000), 2) == 0 then
            pick = "SovietEngineer"
        end
    end
    if ChoukaDogLastType ~= nil and pick == ChoukaDogLastType
        and (ChoukaDogSameCount or 0) >= 2 then
        if pick == "SovietEngineer" then
            pick = "AlliedEngineer"
        else
            pick = "SovietEngineer"
        end
    end
    if pick == ChoukaDogLastType then
        ChoukaDogSameCount = (ChoukaDogSameCount or 0) + 1
    else
        ChoukaDogSameCount = 1
    end
    ChoukaDogLastType = pick
    return pick
end

-- 只数"苏联工程师 / 盟军工程师"（这正是玩家开箱、捡东西要用的那只）
function ChoukaEngineerFilter()
    if ChoukaEngineerFilterCache == nil then
        ChoukaEngineerFilterCache = CreateObjectFilter({
            Rule = "ANY",
            Relationship = "SAME_PLAYER",
            IncludeThing = { "AlliedEngineer", "SovietEngineer" },
        })
    end
    return ChoukaEngineerFilterCache
end

-- 返回 -1 = 这条座位已经出局（起重机没了/被移交，别补）；否则返回手上的工程师个数
function ChoukaDogCountEngineers(playerIndex)
    local seatAlive = 1
    if type(ChoukaSeatAlive) == "function" then
        seatAlive = ChoukaSeatAlive(playerIndex)
    elseif not ObjectIsAlive(GetObjectByScriptName("crane" .. playerIndex)) then
        seatAlive = 0
    end
    if seatAlive ~= 1 then
        return -1
    end
    local crane = GetObjectByScriptName("crane" .. playerIndex)
    local units, count = ObjectFindObjects(crane, nil, ChoukaEngineerFilter())
    if count == nil then
        return 0
    end
    return count
end

-- 地面/单位类型清单：卡池全集 + 几个原生可能出现的（06_center.lua 拿它当"占点单位"过滤器用，
-- 所以只放单位、不放建筑/箱子）
function ChoukaBuildGroundTypeList()
    if ChoukaGroundTypeList ~= nil then
        return ChoukaGroundTypeList
    end
    local list = {}
    if ChoukaUnitCategory ~= nil then
        for typeName, cat in ChoukaUnitCategory do
            tinsert(list, typeName)
        end
    end
    tinsert(list, "AlliedScoutInfantry")
    tinsert(list, "SovietScoutInfantry")
    tinsert(list, "JapanAntiInfantryInfantry")
    tinsert(list, "CelestialAntiInfantryInfantry")
    tinsert(list, "AlliedEngineer")
    tinsert(list, "SovietEngineer")
    tinsert(list, "JapanEngineer")
    tinsert(list, "CelestialEngineer")
    ChoukaGroundTypeList = list
    return list
end

-- 工程师落点：起重机 → 出生点 的 55% 处（拿不到出生点就用起重机旁边 60 单位）
function ChoukaDogPosition(playerIndex)
    local crane = GetObjectByScriptName("crane" .. playerIndex)
    if not ObjectIsAlive(crane) then
        return nil
    end
    local cx, cy, cz = ObjectGetPosition(crane)
    if cx == nil then
        return nil
    end

    local wp = exWaypointGetPos("Player_" .. playerIndex .. "_Start")
    if wp == nil or wp[1] == nil then
        return cx + 60, cy, cz
    end
    local t = CHOUKA_DOG_FORWARD
    local sx = wp[1]
    local sy = wp[2]
    local sz = wp[3]
    if sz == nil then
        sz = cz
    end
    -- 出生点就在起重机脚下时不要和起重机重叠
    local dx = sx - cx
    local dy = sy - cy
    if dx * dx + dy * dy < 2500 then        -- < 50 单位
        return cx + 60, cy, cz
    end
    return cx + dx * t, cy + dy * t, sz
end

-- 补 1 只工程师
function ChoukaSpawnDog(playerIndex)
    local x, y, z = ChoukaDogPosition(playerIndex)
    if x == nil then
        return 0
    end

    CHOUKA_DOG_SERIAL = CHOUKA_DOG_SERIAL + 1
    local dogName = format("ChoukaFallback_%d_%d", playerIndex, CHOUKA_DOG_SERIAL)
    local dogType = ChoukaFallbackUnitType()

    -- 双保险：工程师本来就不在登记表里，这里还是照规矩登记一次 id
    local nextId = GetNextObjectId()
    if ChoukaScriptCreated == nil then
        ChoukaScriptCreated = {}
    end
    ChoukaScriptCreated[nextId] = 1

    ExecuteAction("UNIT_SPAWN_NAMED_LOCATION_ORIENTATION", dogName, dogType,
        format("Player_%d/teamPlayer_%d", playerIndex, playerIndex),
        { X = x, Y = y, Z = z }, 0)

    local dog = GetObjectByScriptName(dogName)
    if ObjectIsAlive(dog) then
        local actualId = ObjectGetId(dog)
        if actualId ~= nextId then
            ChoukaScriptCreated[nextId] = nil
            ChoukaScriptCreated[actualId] = 1
        end
        ChoukaDogLastSpawnType = dogType
        _LOG(format("保底工程师：给 Player_%d 投放 %s ",
            playerIndex, dogType, x, y, z or 0))
        return 1
    end
    ChoukaScriptCreated[nextId] = nil
    -- 生成失败清掉"上一次的类型"，下次重新随机（避免一直卡在同一种上）
    ChoukaDogLastType = nil
    ChoukaDogSameCount = 0
    _LOG(format("保底工程师生成失败：Player_%d 类型=%s 位置=(%.0f,%.0f,%.0f)",
        playerIndex, dogType, x, y, z or 0))
    return 0
end

-- ★ 开局门控：房主点过「确认，开始游戏」之后才补（CHOUKA_GAME_STARTED 见 03_start.lua）
--   三国杀模式结算之后同样停手（CHOUKA_BANG_ENDED 由 33_bang_win.lua 置 1）
if CHOUKA_GAME_STARTED ~= 1 or CHOUKA_BANG_ENDED == 1 then
    return
end

ChoukaDogTick = (ChoukaDogTick or 0) + 1
ChoukaDogLastTry = ChoukaDogLastTry or {}

for i = 1, 6, 1 do
    local engineers = ChoukaDogCountEngineers(i)      -- -1 = 起重机没了（出局）
    if engineers == 0 then
        -- 每个玩家各自节流：没工程师就等 5 秒再补，不要每秒刷屏
        local lastTry = ChoukaDogLastTry[i]
        if lastTry == nil or (ChoukaDogTick - lastTry) >= CHOUKA_DOG_RETRY_SECONDS then
            ChoukaDogLastTry[i] = ChoukaDogTick
            if ChoukaSpawnDog(i) == 1 then
                local which = "盟军工程师"
                if ChoukaDogLastSpawnType == "SovietEngineer" then
                    which = "苏联工程师"
                end
                local tip = format(ChoukaT.dogTip, which)
                if type(exAddTextToPublicBoardForPlayer) == "function" then
                    exAddTextToPublicBoardForPlayer(format("Player_%d", i), tip, 10)
                else
                    _LOG(format("Player_%d ", i) .. tip)
                end
            end
        end
    elseif engineers > 0 then
        ChoukaDogLastTry[i] = nil                 -- 已经有工程师了，下次没了立刻补
    end
end