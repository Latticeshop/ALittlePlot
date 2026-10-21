-- ============================================================
-- 详见 docs/10-Lua注释存档.md §12_puredraw_replace-1
-- ============================================================



-- 1 = 抽卡生成失败/走兜底时公屏说一句（罕见，不会刷屏；定位完改 0）

-- ---------------- 帧延迟队列（保留：以后加飘字/延迟逻辑直接用） ----------------

function ChoukaDelayCall(fn, frames, args)
    if ChoukaFrameQueue == nil then
        ChoukaFrameQueue = {}
    end
    tinsert(ChoukaFrameQueue, { fn = fn, left = frames, args = args })
end

-- ---------------- 抽卡批次 ----------------

-- 模板名哈希 → 类别（1步兵 2载具 3空军 4海军 5两栖）
-- ★ 这是水陆判定最可靠的一路：引擎在水面开箱只吐海上单位（类别 4），在陆地只吐陆地单位。
--   哈希是引擎回调里唯一能拿到的东西（没有类型名字符串），所以在载入时把整张卡池反查表建好。
ChoukaNativeCatByHash = {}
if ChoukaUnitCategory ~= nil then
    for choukaTypeName, choukaTypeCat in ChoukaUnitCategory do
        ChoukaNativeCatByHash[FastHash(choukaTypeName)] = choukaTypeCat
    end
end

-- 详见 docs/10-Lua注释存档.md §12_puredraw_replace-2
function ChoukaAddToBatch(objId, playerName, instanceId)
    if ChoukaPendingBatch == nil then
        ChoukaPendingBatch = {}
    end
    if playerName == nil then
        return
    end

    local batch = ChoukaPendingBatch[playerName]
    if batch == nil then
        batch = { ids = {}, hashes = {}, px = {}, py = {}, pz = {},
                  left = CHOUKA_BATCH_FRAMES, age = 0,
                  nativeWater = 0, nativeAir = 0 }
        ChoukaPendingBatch[playerName] = batch
    end

    local n = getn(batch.ids) + 1
    local x = 0
    local y = 0
    local z = 0
    local obj = GetObjectById(objId)
    if ObjectIsAlive(obj) then
        x, y, z = ObjectGetPosition(obj)
    end
    batch.ids[n] = objId
    batch.hashes[n] = instanceId
    batch.px[n] = x
    batch.py[n] = y
    batch.pz[n] = z

    -- ★ 每来一个结果就把窗口重新数满：单抽是 1 个，十连是 10 个，
    --   引擎可能跨帧吐（一次十连不一定全在同一帧），重新数才不会把一批劈成两半。
    --   真正的上限由 CHOUKA_BATCH_MAX_FRAMES 兜住，不会无限拖延。
    batch.left = CHOUKA_BATCH_FRAMES

    -- ★ 水陆判定的第一路信号：引擎在**水面**开箱只会吐海上单位（见 10_puredraw_data 分组表），
    --   比我们自己猜地形可靠得多。
    if instanceId ~= nil then
        local nativeCat = nil
        if ChoukaNativeCatByHash ~= nil then
            nativeCat = ChoukaNativeCatByHash[instanceId]
        end
        if nativeCat == 4 then
            batch.nativeWater = 1
        elseif nativeCat == 3 then
            batch.nativeAir = 1          -- 空军结果不提供水陆信息，交给地形判断
        end
        if ChoukaNativeWaterHash ~= nil and ChoukaNativeWaterHash[instanceId] == 1 then
            batch.nativeWater = 1
        end
        if ChoukaNativeAirHash ~= nil and ChoukaNativeAirHash[instanceId] == 1 then
            batch.nativeAir = 1
        end
    end
end

-- 详见 docs/10-Lua注释存档.md §12_puredraw_replace-3
CHOUKA_GROUP_RADIUS = 60      -- 同箱单位落点相距多少以内算同一群（世界单位）
CHOUKA_PICKER_RADIUS = 100    -- "开箱那个人"的搜索半径（找落点附近最近的自己人）
CHOUKA_DRAW_LOG     = 1       -- 1 = 每次抽卡往日志写一行（定位完改 0，只走日志不刷屏）

function ChoukaDist2(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function ChoukaGroupBatch(batch)
    local groups = {}
    local n = getn(batch.ids)
    for i = 1, n, 1 do
        local x = batch.px[i]
        local y = batch.py[i]
        local target = nil
        for k = 1, getn(groups), 1 do
            local cand = groups[k]
            if x ~= nil and y ~= nil and cand.x ~= nil
                and ChoukaDist2(x, y, cand.x, cand.y)
                    <= CHOUKA_GROUP_RADIUS * CHOUKA_GROUP_RADIUS then
                target = cand
                break
            end
        end
        if target == nil then
            target = { ids = {}, hashes = {}, x = x, y = y, z = batch.pz[i],
                       nativeWater = 0, nativeAir = 0 }
            tinsert(groups, target)
        end
        tinsert(target.ids, batch.ids[i])
        tinsert(target.hashes, batch.hashes[i])
        if batch.nativeWater == 1 then
            target.nativeWater = 1
        end
        if batch.nativeAir == 1 then
            target.nativeAir = 1
        end
    end
    return groups
end

-- 类型哈希 → 名字（只给日志用：下次实测就知道"到底是哪个类型没被删掉"）
ChoukaTypeNameByHash = {}

function ChoukaRememberTypeName(typeName)
    if typeName ~= nil and ChoukaTypeNameByHash[FastHash(typeName)] == nil then
        ChoukaTypeNameByHash[FastHash(typeName)] = typeName
    end
end

if ChoukaUnitCategory ~= nil then
    for choukaCatName, choukaCatValue in ChoukaUnitCategory do
        ChoukaRememberTypeName(choukaCatName)
    end
end
if ChoukaNativeResultTypes ~= nil then
    for i = 1, getn(ChoukaNativeResultTypes), 1 do
        ChoukaRememberTypeName(ChoukaNativeResultTypes[i])
    end
end
if ChoukaExtraRegisterTypes ~= nil then
    for i = 1, getn(ChoukaExtraRegisterTypes), 1 do
        ChoukaRememberTypeName(ChoukaExtraRegisterTypes[i])
    end
end

function ChoukaTypeHashName(hash)
    if hash == nil then
        return "?"
    end
    local typeName = ChoukaTypeNameByHash[hash]
    if typeName == nil then
        return "hash=" .. hash
    end
    return typeName
end

-- 结算时的删除：删完立刻复查不可靠（引擎帧末才真正移除），
-- 所以再排一次"2 帧后再删"，并把这些删不掉的名字打进日志（这就是"MCV/运兵车没被删"的抓法）
function ChoukaDeleteAgain(ids)
    if ids == nil then
        return
    end
    local stillAlive = {}
    for i = 1, getn(ids), 1 do
        local unit = GetObjectById(ids[i])
        if ObjectIsAlive(unit) then
            ExecuteAction("NAMED_DELETE", unit)
            tinsert(stillAlive, ids[i])
        end
    end
    if getn(stillAlive) > 0 and CHOUKA_DRAW_LOG == 1 then
        local names = ""
        for i = 1, getn(stillAlive), 1 do
            if i > 1 then
                names = names .. ","
            end
            names = names .. stillAlive[i]
        end
        _LOG("抽卡：补删一次 " .. getn(stillAlive) .. " 个（id=" .. names .. "）")
    end
end

-- 结算一个批次：按落点分组，每组 = 一次抽卡结果 → 删掉这一组的所有单位，补 1 个卡池单位
--   （单抽：1 组；十连：10 组；运兵车 + 5 个乘客：1 组）
function ChoukaResolveBatch(playerName, batch)
    -- 概率闸门：一抽掷一次。CHOUKA_CUSTOM_CHANCE = 100 → 恒过
    local chance = 100
    if CHOUKA_CUSTOM_CHANCE ~= nil then
        chance = CHOUKA_CUSTOM_CHANCE
    end
    if chance < 100 and GetRandomNumber() * 100 >= chance then
        return      -- 这一抽保持原版结果（不删、不补）
    end

    if batch == nil or batch.ids == nil then
        return
    end
    local nativeCount = getn(batch.ids)
    if nativeCount < 1 then
        return
    end

    -- ① 删掉这一批的**全部**原生结果（车、乘客、MCV 一起删）
    for i = 1, nativeCount, 1 do
        local unit = GetObjectById(batch.ids[i])
        if ObjectIsAlive(unit) then
            ExecuteAction("NAMED_DELETE", unit)
        end
    end
    ChoukaDelayCall(ChoukaDeleteAgain, 2, batch.ids)

    -- ② 按落点分组：一组 = 一次抽卡结果
    local groups = ChoukaGroupBatch(batch)
    local groupCount = getn(groups)
    if groupCount < 1 then
        groupCount = 1
    end
    if groupCount > CHOUKA_MAX_DRAW_BATCH then
        groupCount = CHOUKA_MAX_DRAW_BATCH
    end

    -- ③ 每组补 1 个卡池单位（水陆按组各自判）
    for k = 1, groupCount, 1 do
        local group = groups[k]
        if group ~= nil then
            local onWater = ChoukaDecideWater(group)
            -- ★ 只按判定的地形抽。**绝不在这一层"换另一类地形再试"**：
            --   ChoukaSpawnUnit 内部已经处理了兜底（同地形重试 → 空军/两栖 → 放弃），
            --   以前这里再换一次地形，会在海面上生成陆地步兵（卡在海底动不了）。
            ChoukaSpawnUnit(playerName, group.x, group.y, group.z, onWater, 1, 1)
            if CHOUKA_DRAW_LOG == 1 then
                local nativeNames = ""
                for i = 1, getn(group.hashes), 1 do
                    if i > 1 then
                        nativeNames = nativeNames .. ","
                    end
                    nativeNames = nativeNames .. ChoukaTypeHashName(group.hashes[i])
                end
                -- 一行写清"这一抽在哪判的、凭什么判的、引擎吐了什么"
                _LOG(format("抽卡 玩家=%s 判水=%d 依据=%s 原生落点=(%.0f,%.0f,%.0f) 原生=%d个 原生类型=%s",
                    playerName, onWater, group.whyWater or "-",
                    group.x or 0, group.y or 0, group.z or 0,
                    getn(group.ids), nativeNames))
                ChoukaLogLeftovers(group)
            end
        end
    end
    if CHOUKA_DRAW_LOG == 1 then
        _LOG(format("抽卡结算 玩家=%s 原生=%d个 → 分%d组 共补%d个",
            playerName, nativeCount, getn(groups), getn(groups)))
    end
end

-- 只写日志、不删东西：看看箱子里有没有"我们没拦下来"的单位跟着出来（运兵车 / MCV 之类），
-- 下次实测就知道该把哪个类型补进登记表
function ChoukaLogLeftovers(group)
    if group == nil or group.x == nil then
        return
    end
    if type(ObjectFindObjects) ~= "function" then
        return
    end
    if ChoukaDrawPickerFilter == nil then
        ChoukaDrawPickerFilter = CreateObjectFilter({
            Rule = "ANY",
            Include = "SELECTABLE",
            Exclude = "STRUCTURE",
        })
    end
    local units, count = ObjectFindObjects(nil, {
        X = group.x, Y = group.y, Z = group.z or 0,
        Radius = CHOUKA_GROUP_RADIUS,
        DistType = "CENTER_2D",
    }, ChoukaDrawPickerFilter)
    if count == nil or count <= 0 then
        return
    end
    local text = ""
    for i = 1, count, 1 do
        local u = units[i]
        if u ~= nil and ObjectIsAlive(u) then
            local objId = ObjectGetId(u)
            local inBatch = 0
            for k = 1, getn(group.ids), 1 do
                if group.ids[k] == objId then
                    inBatch = 1
                    break
                end
            end
            if inBatch == 0 then
                local hash = nil
                if type(exObjectGetInstanceId) == "function" then
                    hash = exObjectGetInstanceId(objId)
                end
                text = text .. " " .. ChoukaTypeHashName(hash) .. "(id=" .. objId .. ")"
            end
        end
    end
    if text ~= "" then
        _LOG("抽卡 落点附近没被拦下的单位：" .. text)
    end
end


-- 每帧：跑延迟队列 + 倒数并结算抽卡批次（由 13_frame_loop.lua 调用）
function ChoukaFrameTick()
    -- ① 延迟队列
    if ChoukaFrameQueue ~= nil then
        local n = getn(ChoukaFrameQueue)
        if n > 0 then
            local keep = {}
            for i = 1, n, 1 do
                local item = ChoukaFrameQueue[i]
                if item.left <= 1 then
                    item.fn(item.args)
                else
                    item.left = item.left - 1
                    tinsert(keep, item)
                end
            end
            ChoukaFrameQueue = keep
        end
    end

    -- ② 抽卡批次
    if ChoukaPendingBatch == nil then
        return
    end
    local ready = {}
    for playerName, batch in ChoukaPendingBatch do
        batch.left = batch.left - 1
        batch.age = (batch.age or 0) + 1
        -- 双重保险：窗口数完 / 或者已经等太久（十连跨帧时兜底），都结算
        if batch.left <= 0 or batch.age >= CHOUKA_BATCH_MAX_FRAMES then
            tinsert(ready, playerName)
        end
    end
    for i = 1, getn(ready), 1 do
        local playerName = ready[i]
        local batch = ChoukaPendingBatch[playerName]
        ChoukaPendingBatch[playerName] = nil
        ChoukaResolveBatch(playerName, batch)
    end
end

-- ============================================================
-- 详见 docs/10-Lua注释存档.md §12_puredraw_replace-4
-- ============================================================

-- 水面高度（生成海军时把 z 抬到这里）：第一次见到原生海军结果时学下来，学不到用 0
CHOUKA_WATER_SURFACE_Z = 0

-- 唯一判定入口：返回 1 = 水 / 0 = 陆（第三个数是贴图名，只写日志）
function ChoukaTerrainAt(x, y)
    local onWater = 0
    if type(ChoukaMaskIsWater) == "function" then
        onWater = ChoukaMaskIsWater(x, y)
    else
        onWater = 1                     -- 掩码没加载上：按水处理（宁可不往海里放陆地单位）
    end
    local tex = nil
    if type(exTerrainGetTextureNameByPos) == "function" and x ~= nil and y ~= nil
        and not (x == 0 and y == 0) then
        tex = exTerrainGetTextureNameByPos(x, y)
    end
    return onWater, nil, tex
end

-- 结算时定"这一抽算水上还是陆地"：查地图掩码
function ChoukaDecideWater(group)
    if group == nil or group.x == nil then
        return 0
    end

    local onWater, _, tex = ChoukaTerrainAt(group.x, group.y)

    -- 顺手学一下水面高度：原生结果是海军时，它的 z 就是这一局的水面高度
    if onWater == 1 and group.z ~= nil and ChoukaSurfaceZLearned ~= 1
        and group.hashes ~= nil and ChoukaNativeWaterHash ~= nil then
        for i = 1, getn(group.hashes), 1 do
            if ChoukaNativeWaterHash[group.hashes[i]] ~= nil then
                CHOUKA_WATER_SURFACE_Z = group.z
                ChoukaSurfaceZLearned = 1
                _LOG(format("水面高度：原生海军 z=%.0f，生成海军时把 z 抬到这里", group.z))
                break
            end
        end
    end

    group.whyWater = format("地图掩码(%.0f,%.0f)=%s 贴图=%s",
        group.x, group.y,
        (onWater == 1 and "海" or "陆"),
        (tex ~= nil and tex or "?"))
    return onWater
end

-- 类别：1步兵 2载具 3空军 4海军 5两栖
function ChoukaCategoryAllowed(cat, onWater)
    if cat == 3 or cat == 5 then
        return 1                    -- 空军哪都能来；两栖水陆都行
    end
    if cat == 4 then
        return onWater              -- 船：只在水里
    end
    return 1 - onWater              -- 步兵/载具：只在陆地
end

-- 把某一档里"这块地形允许出"的类型挑进暂存表，返回个数
ChoukaEligibleScratch = {}

function ChoukaCollectEligible(tierPool, onWater)
    local n = 0
    if tierPool == nil then
        return 0
    end
    for i = 1, getn(tierPool), 1 do
        local unitType = tierPool[i]
        local cat = ChoukaUnitCategory[unitType]
        if cat ~= nil then
            if ChoukaCategoryAllowed(cat, onWater) == 1 then
                n = n + 1
                ChoukaEligibleScratch[n] = unitType
            end
        end
    end
    return n
end

-- ---------------- 卡池抽选（等级概率 → 档内均匀，再按阵营 + 水陆收窄） ----------------

-- 某一档在当前阵营下该用哪张表：T5 是**全阵营共用**的超级表
function ChoukaTierPool(sourceTiers, tier)
    if tier == 5 and ChoukaDrawPoolT5 ~= nil then
        return ChoukaDrawPoolT5
    end
    return sourceTiers[tier]
end

-- 「箱子包括全部阵营」用的合并池：四阵营同档合并（T1~T4），T5 仍是共用表
function ChoukaAllSidePool(tier)
    if tier == 5 and ChoukaDrawPoolT5 ~= nil then
        return ChoukaDrawPoolT5
    end
    if ChoukaAllSidePoolCache == nil then
        local cache = {}
        for t = 1, 4, 1 do
            local merged = {}
            if ChoukaDrawPoolBySide ~= nil then
                for s = 1, 4, 1 do
                    local sidePool = ChoukaDrawPoolBySide[s]
                    if sidePool ~= nil and sidePool[t] ~= nil then
                        for i = 1, getn(sidePool[t]), 1 do
                            tinsert(merged, sidePool[t][i])
                        end
                    end
                end
            end
            cache[t] = merged
        end
        ChoukaAllSidePoolCache = cache
    end
    return ChoukaAllSidePoolCache[tier]
end

function ChoukaChooseUnit(playerName, onWater, level)
    -- 用哪张卡池：CHOUKA_DRAW_SCOPE = 0 全部阵营（默认）/ 1 只有自己阵营
    local sourceTiers = nil
    if CHOUKA_DRAW_SCOPE ~= nil and CHOUKA_DRAW_SCOPE == 0 then
        ChoukaAllSidePool(1)                     -- 先建缓存
        sourceTiers = ChoukaAllSidePoolCache
    elseif ChoukaDrawPoolBySide ~= nil and playerName ~= nil then
        sourceTiers = ChoukaDrawPoolBySide[ChoukaGetPlayerSide(playerName)]
    end
    if sourceTiers == nil then
        return nil
    end

    -- 概率表由抽卡等级决定（09_level.lua）；等级系统缺失时退回固定档权重
    -- level 参数给 AI 用：电脑只按"自动升级"那条线走，不受玩家购买等级影响（17_ai.lua）
    local weights = nil
    if ChoukaGetLevelWeights ~= nil then
        if level == nil then
            level = ChoukaDrawLevel or 1
        end
        weights = ChoukaGetLevelWeights(level)
    end
    if weights == nil then
        weights = ChoukaDrawTierWeights
    end
    local tierCount = getn(weights)

    -- 按概率掷一次；只认"这一档在这块地形上至少有一个能出的单位"
    local roll = GetRandomNumber() * 100
    local cumulative = 0
    local pickedTier = nil
    for t = 1, tierCount, 1 do
        if weights[t] > 0 and ChoukaCollectEligible(ChoukaTierPool(sourceTiers, t), onWater) > 0 then
            cumulative = cumulative + weights[t]
            if roll < cumulative then
                pickedTier = t
                break
            end
        end
    end
    if pickedTier == nil then
        -- roll 落在"0% 档造成的空洞"里：退回到最后一个有货的档
        for t = tierCount, 1, -1 do
            if weights[t] > 0 and ChoukaCollectEligible(ChoukaTierPool(sourceTiers, t), onWater) > 0 then
                pickedTier = t
                break
            end
        end
    end
    if pickedTier == nil then
        return nil
    end

    local n = ChoukaCollectEligible(ChoukaTierPool(sourceTiers, pickedTier), onWater)
    if n == 0 then
        return nil
    end
    local index = floor(GetRandomNumber() * n) + 1
    if index > n then
        index = n
    end
    return ChoukaEligibleScratch[index]
end

-- ---------------- 生成卡池单位（单抽 1 个 / 十连 10 个） ----------------

-- slot / total：一次补多个时把一个点散成一小圈，避免叠成一个点
CHOUKA_SPAWN_SPREAD = 18        -- 散开半径（世界单位）；再大容易把船推到岸上
CHOUKA_SPAWN_TRIES  = 2         -- 同地形最多试几次（每次换一个随机类型）

-- 试生成一次：成功返回单位句柄，失败返回 nil
function ChoukaTrySpawnOne(playerName, unitType, x, y, z)
    ChoukaDrawSerial = (ChoukaDrawSerial or 0) + 1
    local unitName = format("ChoukaDraw_%d", ChoukaDrawSerial)
    local nextId = GetNextObjectId()
    -- 先登记再生成：新单位出生会再触发一次 onUnitCreateEvent，
    -- 不登记就会被自己当成"原版结果"收进下一批
    ChoukaScriptCreated[nextId] = 1

    ExecuteAction("UNIT_SPAWN_NAMED_LOCATION_ORIENTATION", unitName, unitType,
        format("%s/team%s", playerName, playerName),
        { X = x, Y = y, Z = z }, 0)

    local unit = GetObjectByScriptName(unitName)
    if ObjectIsAlive(unit) then
        local actualId = ObjectGetId(unit)
        if actualId ~= nextId then
            ChoukaScriptCreated[nextId] = nil
            ChoukaScriptCreated[actualId] = 1
        end
        return unit
    end
    ChoukaScriptCreated[nextId] = nil
    return nil
end

function ChoukaSpawnUnit(playerName, x, y, z, onWater, slot, total, level)
    -- 坐标无效（读不到 / 落到 0,0 就是地图左下角）时退回自己起重机的位置
    if x == nil or y == nil or (x == 0 and y == 0) then
        local index = tonumber(strsub(playerName or "Player_1", 8)) or 1
        local crane = GetObjectByScriptName(ChoukaCranePrefix .. index)
        local cx, cy, cz = ObjectGetPosition(crane)
        if cx ~= nil then
            x, y, z = cx, cy, cz
        end
        onWater = 0                     -- 起重机在自家岛上，是陆地
    end

    -- 水陆：调用方（结算）已经判好就照用；没给就现场按同一个方法判一次
    -- （唯一入口 ChoukaTerrainAt：地图掩码，见文件上半部分说明）
    if onWater == nil then
        onWater = ChoukaTerrainAt(x, y)
    end

    -- 散开（只在一次补多个时生效）
    if total ~= nil and total > 1 and slot ~= nil and slot > 1 then
        local angle = 6.28318530718 * (slot - 1) / total
        local radius = CHOUKA_SPAWN_SPREAD + 2 * total
        if type(cos) == "function" and type(sin) == "function" then
            x = x + cos(angle) * radius
            y = y + sin(angle) * radius
        end
    end

    -- ★ 水里生成必须抬到水面：原生结果单位可能站在**海床**上（z 比水面低），
    --   船放在水下会生成失败。
    local surfaceZ = CHOUKA_WATER_SURFACE_Z or 0
    if onWater == 1 and z ~= nil and z < surfaceZ then
        z = surfaceZ
    end

-- 详见 docs/10-Lua注释存档.md §12_puredraw_replace-5
    for attempt = 1, CHOUKA_SPAWN_TRIES, 1 do
        local unitType = ChoukaChooseUnit(playerName, onWater, level)
        if unitType ~= nil then
            local unit = ChoukaTrySpawnOne(playerName, unitType, x, y, z)
            if unit ~= nil then
                if CHOUKA_DRAW_LOG == 1 then
                    _LOG(format("抽卡生成 玩家=%s 水陆=%d 类型=%s 位置=(%.0f,%.0f,%.0f)",
                        playerName, onWater, unitType, x, y, z or 0))
                end
                return unit
            end
        end
    end

    if CHOUKA_DRAW_LOG == 1 then
        _LOG(format("抽卡生成失败 玩家=%s 水陆=%d 位置=(%.0f,%.0f,%.0f)（同地形试了 %d 次都没成，不做地形兜底）",
            playerName, onWater, x, y, z or 0, CHOUKA_SPAWN_TRIES))
    end
    return nil
end