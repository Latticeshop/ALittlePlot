-- ============================================================
-- 详见 docs/10-Lua注释存档.md §06_center-1
-- ============================================================



ChoukaMarkNodeReady("中央油井")

CHOUKA_CENTER_DEBUG      = CHOUKA_CENTER_DEBUG or 0   -- 0 = 关闭诊断播报（功能已实测通过）
CHOUKA_CENTER_RADIUS     = 200    -- 占点扫描半径（照双兵种）
CHOUKA_CENTER_OIL_RADIUS = 250    -- 几何兜底：从航点 center 出发找油井的搜索半径
CHOUKA_CENTER_CAPTURE_AT = 3      -- 连续领先几次才算占领（5 秒一次 → ≈15 秒）
CHOUKA_CENTER_BOX_RANGE  = 25     -- 中央箱子点位占用判定半径（center1~6 相邻约 60）
CHOUKA_CENTER_REPORT     = 30     -- 没变化时每多少次占点播报一次（30*5=150 秒）

ChoukaCenterOilOwner = ChoukaCenterOilOwner or { [1] = 0, [2] = 0 }   -- 0 = 中立
ChoukaCenterOilScore = ChoukaCenterOilScore or { [1] = 0, [2] = 0 }   -- 挑战进度 0~3
ChoukaCenterOilChall = ChoukaCenterOilChall or { [1] = 0, [2] = 0 }   -- 正在挑战的玩家
ChoukaCenterOilObj   = ChoukaCenterOilObj or {}                       -- 油井对象句柄
ChoukaCenterOilLead  = ChoukaCenterOilLead or { [1] = -1, [2] = -1 }  -- 上次播报的领先者（仅播报用）

-- ★ 开局门控：房主点过「确认，开始游戏」之前什么都不做
if CHOUKA_GAME_STARTED ~= 1 then
    return
end

ChoukaCenterTickCount = (ChoukaCenterTickCount or 0) + 1

-- ============================================================
-- ① 中央钱箱：每回合在 center1~6 各刷 1 个，**点位已有箱子就跳过**
--    （和家里的 boxN1/boxN2 完全一样的规则；放在最前面，保证不会被下面占点逻辑拖累）
-- ============================================================
if CHOUKA_ROUND ~= nil and ChoukaCenterCrateRound ~= CHOUKA_ROUND
    and type(ChoukaBoxBusyRange) == "function" then
    ChoukaCenterCrateRound = CHOUKA_ROUND
    local spawnedCrates = 0
    for k = 1, 6, 1 do
        local wp = "center" .. k
        if exWaypointGetPos(wp) ~= nil and ChoukaBoxBusyRange(wp, CHOUKA_CENTER_BOX_RANGE) == 0 then
            -- 归属：占领了中央油井就给占领方，没人占就按点位交替给 1/2 号玩家（箱子谁都能捡）
            local ownerIndex = 1
            local oilOwner = ChoukaCenterOilOwner[mod(k, 2) + 1]
            if oilOwner ~= nil and oilOwner > 0 then
                ownerIndex = oilOwner
            end
            local crateTeam = format("Player_%d/teamPlayer_%d", ownerIndex, ownerIndex)
            if type(ChoukaSpawnBoxCrate) == "function" then
                ChoukaSpawnBoxCrate(crateTeam, wp, "center")
            else
                ExecuteAction("CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT", "moneycrate", crateTeam, wp)
            end
            spawnedCrates = spawnedCrates + 1
        end
    end
    if CHOUKA_CENTER_DEBUG == 1 then
        _ALERT(format(ChoukaT.centerCrateRefreshed, CHOUKA_ROUND, spawnedCrates))
    end
end

-- ============================================================
-- ② 找中央两座油井（真名优先，几何兜底；找到就缓存）
-- ============================================================

function ChoukaCenterOilFilter()
    if ChoukaCenterOilFilterCache == nil then
        -- 中央油井是 OilDerrick；万一类型改成别的，把新类型名加进这个表即可
        ChoukaCenterOilFilterCache = CreateObjectFilter({
            Rule = "ANY",
            IncludeThing = { "OilDerrick" },
        })
    end
    return ChoukaCenterOilFilterCache
end

function ChoukaCenterOilText(oil)
    if oil ~= nil and ObjectIsAlive(oil) then
        return "有"
    end
    return "无"
end

function ChoukaFindCenterOils()
    -- 两座都在且都活着就直接用缓存
    if ChoukaCenterOilObj[1] ~= nil and ObjectIsAlive(ChoukaCenterOilObj[1])
        and ChoukaCenterOilObj[2] ~= nil and ObjectIsAlive(ChoukaCenterOilObj[2]) then
        return
    end

    ChoukaCenterOilObj = {}

    -- ① 真名：centerOil1 / centerOil2（作者实测确认地图里就是这两个名字）
    if type(GetObjectByScriptName) == "function" then
        for k = 1, 2, 1 do
            local oil = GetObjectByScriptName("centerOil" .. k)
            if oil ~= nil and ObjectIsAlive(oil) then
                ChoukaCenterOilObj[k] = oil
            end
        end
    end
    if ChoukaCenterOilObj[1] ~= nil and ChoukaCenterOilObj[2] ~= nil then
        return
    end

    -- ② 几何兜底：离航点 center 250 以内的 OilDerrick
    local c = exWaypointGetPos("center")
    if c == nil or c[1] == nil then
        return
    end
    local cz = c[3]
    if cz == nil then
        cz = 0
    end
    local oils, count = ObjectFindObjects(nil, {
        X = c[1], Y = c[2], Z = cz,
        Radius = CHOUKA_CENTER_OIL_RADIUS,
        DistType = "CENTER_2D",
    }, ChoukaCenterOilFilter())
    if count == nil or count <= 0 then
        return
    end
    local slot = 1
    for i = 1, count, 1 do
        local oil = oils[i]
        if oil ~= nil and ObjectIsAlive(oil) then
            -- 真名已经拿到的那座跳过，避免同一座被塞两次
            local duplicate = 0
            for j = 1, 2, 1 do
                if ChoukaCenterOilObj[j] ~= nil
                    and ObjectGetId(ChoukaCenterOilObj[j]) == ObjectGetId(oil) then
                    duplicate = 1
                end
            end
            if duplicate == 0 and slot <= 2 then
                ChoukaCenterOilObj[slot] = oil
                slot = slot + 1
            end
        end
    end
end

ChoukaFindCenterOils()

-- 定位结果只播报一次（"找没找到"是这一轮最关键的信息）
if CHOUKA_CENTER_DEBUG == 1 and ChoukaCenterOilReported ~= 1 then
    ChoukaCenterOilReported = 1
    local t1 = ChoukaCenterOilText(ChoukaCenterOilObj[1])
    local t2 = ChoukaCenterOilText(ChoukaCenterOilObj[2])
    local px = "?"
    local py = "?"
    if ChoukaCenterOilObj[1] ~= nil and ObjectIsAlive(ChoukaCenterOilObj[1]) then
        local ox, oy = ObjectGetPosition(ChoukaCenterOilObj[1])
        if ox ~= nil then
            px = floor(ox)
            py = floor(oy)
        end
    end
    _ALERT(ChoukaT.centerOilLocate .. t1 .. " 2号=" .. t2 .. " 1号坐标=(" .. px .. "," .. py .. ")")
end

-- ============================================================
-- ③ 占点扫描 + 争夺进度
-- ============================================================

-- 只数"能打的东西"：直接用 05_dog.lua 建好的"卡池单位全集"（箱子/建筑都不在其中）
function ChoukaCenterUnitFilter()
    if ChoukaCenterUnitFilterCache == nil then
        local typeList = nil
        if type(ChoukaBuildGroundTypeList) == "function" then
            typeList = ChoukaBuildGroundTypeList()
        end
        if typeList == nil then
            return nil
        end
        ChoukaCenterUnitFilterCache = CreateObjectFilter({
            Rule = "ANY",
            IncludeThing = typeList,
        })
    end
    return ChoukaCenterUnitFilterCache
end

-- 数某个油井周围每个玩家各有多少单位，返回「领先玩家序号(0=没人领先)」+ 计数表
function ChoukaCenterLeader(ox, oy, oz)
    local counts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 }
    local filter = ChoukaCenterUnitFilter()
    if filter == nil then
        return 0, counts
    end

    local units, count = ObjectFindObjects(nil, {
        X = ox, Y = oy, Z = oz,
        Radius = CHOUKA_CENTER_RADIUS,
        DistType = "CENTER_2D",
    }, filter)
    if count == nil or count <= 0 then
        return 0, counts
    end

    for i = 1, count, 1 do
        local unit = units[i]
        if unit ~= nil and ObjectIsAlive(unit) then
            local owner = ObjectPlayerScriptName(unit)
            if owner ~= nil then
                local index = tonumber(strsub(owner, 8))    -- "Player_N" → N
                if index ~= nil and index >= 1 and index <= 6 then
                    counts[index] = counts[index] + 1
                end
            end
        end
    end

    -- 领先者必须是**唯一**最多：并列不算领先
    local best = 0
    local bestCount = 0
    local tie = 0
    for i = 1, 6, 1 do
        if counts[i] > bestCount then
            bestCount = counts[i]
            best = i
            tie = 0
        elseif counts[i] == bestCount and counts[i] > 0 then
            tie = 1
        end
    end
    if bestCount <= 0 or tie == 1 then
        return 0, counts
    end
    return best, counts
end

function ChoukaCenterCountsText(counts)
    return format("%d-%d-%d-%d-%d-%d", counts[1], counts[2], counts[3],
        counts[4], counts[5], counts[6])
end

-- 挑战进度推进：leadIndex = 领先玩家（0 = 没人领先）
function ChoukaCenterTickCapture(k, oil, leadIndex)
    local owner = ChoukaCenterOilOwner[k]
    if owner == nil then
        owner = 0
        ChoukaCenterOilOwner[k] = 0
    end
    if ChoukaCenterOilScore[k] == nil then
        ChoukaCenterOilScore[k] = 0
    end
    if ChoukaCenterOilChall[k] == nil then
        ChoukaCenterOilChall[k] = 0
    end

    if leadIndex == 0 or leadIndex == owner then
        -- 没人压制 / 所有者自己在守 → 挑战进度回落
        if ChoukaCenterOilScore[k] > 0 then
            ChoukaCenterOilScore[k] = ChoukaCenterOilScore[k] - 1
        end
        if ChoukaCenterOilScore[k] <= 0 then
            ChoukaCenterOilChall[k] = 0
        end
        return
    end

    -- 有挑战者：换人挑战就从 1 重新数，同一个人连续领先才累加
    if ChoukaCenterOilChall[k] ~= leadIndex then
        ChoukaCenterOilChall[k] = leadIndex
        ChoukaCenterOilScore[k] = 1
    else
        ChoukaCenterOilScore[k] = ChoukaCenterOilScore[k] + 1
    end

    if ChoukaCenterOilScore[k] >= CHOUKA_CENTER_CAPTURE_AT then
        ChoukaCenterOilOwner[k] = leadIndex
        ChoukaCenterOilScore[k] = 0
        ChoukaCenterOilChall[k] = 0
        -- 所有权也真的转过去（油井颜色/归属跟着变，和双兵种一样）
        if oil ~= nil and ObjectIsAlive(oil) then
            ExecuteAction("NAMED_TRANSFER_OWNERSHIP_PLAYER", oil, "Player_" .. leadIndex)
        end
        _ALERT(format(ChoukaT.centerOilCaptured, k, leadIndex))
    end
end

local doCapture = (ChoukaCenterTickCount == 1) or (mod(ChoukaCenterTickCount, 5) == 0)

if doCapture then
    for k = 1, 2, 1 do
        local oil = ChoukaCenterOilObj[k]
        if oil ~= nil and ObjectIsAlive(oil) then
            local ox, oy, oz = ObjectGetPosition(oil)
            if ox ~= nil then
                local leadIndex, counts = ChoukaCenterLeader(ox, oy, oz)
                ChoukaCenterTickCapture(k, oil, leadIndex)

                if CHOUKA_CENTER_DEBUG == 1 then
                    if ChoukaCenterOilLead[k] ~= leadIndex
                        or mod(ChoukaCenterTickCount, CHOUKA_CENTER_REPORT) == 0 then
                        ChoukaCenterOilLead[k] = leadIndex
                        _ALERT(format(ChoukaT.centerOilProgress,
                            k, leadIndex, ChoukaCenterOilScore[k],
                            ChoukaCenterOilOwner[k], ChoukaCenterCountsText(counts)))
                    end
                end
            end
        end
    end
end