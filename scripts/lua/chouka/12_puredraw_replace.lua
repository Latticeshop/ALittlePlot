-- ============================================================
-- 抽卡hex · 抽卡系统「替换层」+ 每帧结算
--
-- 一次抽卡的完整流程：
--   ① 引擎在 mod 侧随机，生成**一整批**同型单位（随机发生在引擎侧，Lua 拿不到决策）
--   ② 每个结果单位的出生事件都进 onUnitCreateEvent（11_puredraw_hook.lua）
--   ③ 逐个收进「这一抽」的批次（按玩家分开），等 CHOUKA_BATCH_FRAMES 帧让整批落地
--   ④ 结算：只删**收上来的那些 id** → 在自己队伍生成 **1 个**卡池单位
--
-- ⚠ 关键修正：绝不按半径扫场删。首版照 DSA 用半径 260 扫，在本图这种一小块地上
--   会把玩家旁边的同类旧单位一起吞掉。现在删除的目标只来自"出生事件收上来的 id"，
--   旧单位不在集合里，永远碰不到。
--
-- 概率闸门：CHOUKA_CUSTOM_CHANCE（0~100）。100 = 这一抽必定转成自定义单位（当前设定）。
--   闸门在**结算时按"一抽"掷一次**，不是按单位掷，所以不会出现半批转换。
-- ============================================================

-- ---------------- 帧延迟队列（保留：以后加飘字/延迟逻辑直接用） ----------------

function ChoukaDelayCall(fn, frames, args)
    if ChoukaFrameQueue == nil then
        ChoukaFrameQueue = {}
    end
    tinsert(ChoukaFrameQueue, { fn = fn, left = frames, args = args })
end

-- ---------------- 抽卡批次 ----------------

-- 把一个"疑似原版抽卡结果"的单位收进当前批次（同玩家合批）
function ChoukaAddToBatch(objId, playerName)
    if ChoukaPendingBatch == nil then
        ChoukaPendingBatch = {}
    end
    if playerName == nil then
        return
    end

    local batch = ChoukaPendingBatch[playerName]
    if batch == nil then
        local x = 0
        local y = 0
        local z = 0
        local obj = GetObjectById(objId)
        if ObjectIsAlive(obj) then
            x, y, z = ObjectGetPosition(obj)
        end
        batch = { ids = {}, left = CHOUKA_BATCH_FRAMES, x = x, y = y, z = z }
        ChoukaPendingBatch[playerName] = batch
    end
    tinsert(batch.ids, objId)
end

-- 结算一个批次：删掉收上来的 id，然后补 1 个卡池单位
function ChoukaResolveBatch(playerName, batch)
    -- 概率闸门：一抽掷一次。CHOUKA_CUSTOM_CHANCE = 100 → 恒过
    local chance = 100
    if CHOUKA_CUSTOM_CHANCE ~= nil then
        chance = CHOUKA_CUSTOM_CHANCE
    end
    if chance < 100 and GetRandomNumber() * 100 >= chance then
        return      -- 这一抽保持原版结果（不删、不补）
    end

    local removed = 0
    if batch ~= nil and batch.ids ~= nil then
        for i = 1, getn(batch.ids), 1 do
            local unit = GetObjectById(batch.ids[i])
            if ObjectIsAlive(unit) then
                ExecuteAction("NAMED_DELETE", unit)
                removed = removed + 1
            end
        end
    end

    -- 就算一个都没删成（比如单位已被玩家自己处理掉），也照补 1 个：
    -- "抽卡必出 1 个"是这张图的核心承诺
    if batch ~= nil then
        ChoukaSpawnUnit(playerName, batch.x, batch.y, batch.z)
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
        if batch.left <= 0 then
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

-- ---------------- 水陆判定（陆地不刷船、水里不刷陆地单位） ----------------
-- 判定方式：地形高度。本图采样 min=0 / avg≈132，全局水位（反射面）= 0，
-- 所以"地形高度 <= CHOUKA_WATER_MAX_HEIGHT"就是水面。
CHOUKA_WATER_MAX_HEIGHT = 0.5

function ChoukaIsWaterAt(x, y)
    local h = exTerrainGetHeightByPos(x, y)
    if h == nil then
        return 0
    end
    if h <= CHOUKA_WATER_MAX_HEIGHT then
        return 1
    end
    return 0
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

function ChoukaChooseUnit(playerName, onWater)
    -- 先拿到这个玩家的阵营池：1=盟军 2=苏联 3=升阳 4=神州
    local sourceTiers = nil
    if ChoukaDrawPoolBySide ~= nil and playerName ~= nil then
        sourceTiers = ChoukaDrawPoolBySide[ChoukaGetPlayerSide(playerName)]
    end
    if sourceTiers == nil then
        return nil
    end

    -- 概率表由抽卡等级决定（09_level.lua）；等级系统缺失时退回固定档权重
    local weights = nil
    if ChoukaGetLevelWeights ~= nil then
        weights = ChoukaGetLevelWeights(ChoukaDrawLevel or 1)
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

-- ---------------- 生成 1 个卡池单位 ----------------

function ChoukaSpawnUnit(playerName, x, y, z)
    local onWater = ChoukaIsWaterAt(x, y)
    local unitType = ChoukaChooseUnit(playerName, onWater)
    if unitType == nil then
        return nil
    end

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
