-- ============================================================
-- 详见 docs/10-Lua注释存档.md §10_puredraw_data-1
-- ============================================================

-- 玩家锚点：ObjectFindObjects 的第一个参数是"某个物体"，过滤器里的
-- Relationship = SAME_PLAYER 就按这个物体的主人判定。我们图每人一台 craneN，
-- 正好当锚点（DSA 用的是地图上摆的 P1~P8 隐形物件）。
ChoukaMarkNodeReady("抽卡初始化")

ChoukaCranePrefix = "crane"

-- 原版箱子可能开出的单位类型（照抄 DSA：lua/LUABOX/UNITCOUNTERINI_0.lua:137/161/169）
-- 只有这些类型出生时才可能是"原版抽卡结果"，其余一律不管。
ChoukaNativeResultTypes = {
    -- 陆地 22
    "SovietAntiAirVehicle",
    "VUAntiAirVehicleTech1",
    "VUAntiInfantryVehicleTech1",
    "VUAntiVehicleVehicleTech1",
    "SovietHeavyGrinder",
    "CelestialWaveriderIFV_DragonBreathe",
    "AlliedPacifierFAV",
    "CelestialWaveriderIFV_Mortar",
    "CelestialWaveriderIFV_ATGM",
    "SovietHeavyAntiAirVehicleTech2",
    "AlliedHumveeVehicle",
    "JapanKamikazeInfantry",
    "CelestialWheeledAssaultVehicle",
    "CelestialMBT99A",
    "VUMissileAntiVehicleVehicleTech1",
    "VUBmptVehicle",
    "AlliedGrizzlyMainBattleTank",
    "RheinEntenteNimravusMBT",
    "RheinEntentePalaeoloxodonTD",
    "CelestialMBT99B",
    "WinterArmyReaperHeavyMecha",
    "CelestialSaluteGun",
    -- 海上 6
    "CelestialWaveriderIFV_Water",
    "AlliedLandingCraftAirCushion",
    "AlliedThetisBattleShip",
    "JapanYumiAircraftCarrier",
    "CelestialSeized_JapanAntiNavyShipTech3",
    "AlliedGaintAirCraftCarrier_B",
    -- 空中 3
    "AlliedAvengerAttackAircraft",
    "WinterArmyKoelAttackUAV",
    "SovietTransportAircraft_HeavyCannon",
}

-- 详见 docs/10-Lua注释存档.md §10_puredraw_data-2
ChoukaAlwaysKnownTypes = {
    "AlliedEngineer", "SovietEngineer", "JapanEngineer", "CelestialEngineer",
    "AlliedMCV", "AlliedMCV_Enhanced", "AlliedMCV_Naval", "AlliedMCV_Enhanced_Naval",
    "SovietMCV", "SovietMCV_Enhanced", "SovietMCV_Naval", "SovietMCV_Enhanced_Naval",
    "JapanMCV", "JapanMCV_Enhanced", "JapanMCV_Naval", "JapanMCV_Enhanced_Naval",
    "CelestialMCV", "CelestialMCV_Enhanced", "CelestialMCV_Ground", "CelestialMCV_Naval",
    "CelestialMCV_Air", "CelestialMCV_Enhanced_Ground", "CelestialMCV_Enhanced_Naval",
    "CelestialMCV_Enhanced_Air",
}

-- ---------------- 状态（跨调用保留，一律挂全局） ----------------
ChoukaScriptCreated = {}        -- 脚本自己生成的单位 id → 1（防递归误删）
ChoukaDrawSerial    = 0         -- 抽卡生成序号（单位脚本名用）
ChoukaFrameQueue    = {}        -- 帧延迟队列（见 13_frame_loop.lua）
ChoukaPendingBatch  = {}        -- 玩家名 → 这一抽的批次 { ids, left, x, y, z }

-- 等几帧再结算一抽：引擎同一帧生成一整批，收得太快会只收到第一个
CHOUKA_BATCH_FRAMES = 3
-- 十连兜底：一批最多等这么多帧（引擎跨帧吐单位时不会把一批劈成两半，也不会无限拖）
CHOUKA_BATCH_MAX_FRAMES = 30
-- 一批最多补几个单位（十连 = 10）
CHOUKA_MAX_DRAW_BATCH = 10

-- 自定义抽卡概率（0~100）。100 = 原版抽卡结果**必定**转成自定义单位（当前设定）。
-- 注意闸门是"一抽掷一次"，不是"每个单位掷一次"，不会出现半批转换。
CHOUKA_CUSTOM_CHANCE = 100

-- 详见 docs/10-Lua注释存档.md §10_puredraw_data-3
ChoukaPlayerSideTech = {
    "PlayerTech_Allied",
    "PlayerTech_Soviet",
    "PlayerTech_Japan",
    "PlayerTech_Celestial",
}
ChoukaPlayerSideCache = {}

function ChoukaGetPlayerSide(playerName)
    if playerName == nil then
        return 1
    end
    if ChoukaPlayerSideCache[playerName] ~= nil then
        return ChoukaPlayerSideCache[playerName]
    end
    local side = 1
    for j = 1, 4, 1 do
        if EvaluateCondition("PLAYER_HAS_PLAYER_TECH", playerName, ChoukaPlayerSideTech[j]) then
            side = j
        end
    end
    ChoukaPlayerSideCache[playerName] = side
    return side
end

-- 预计算哈希表（引擎回调里给的是模板名哈希，不是名字）
ChoukaNativeResultHash = {}
for i = 1, getn(ChoukaNativeResultTypes), 1 do
    ChoukaNativeResultHash[FastHash(ChoukaNativeResultTypes[i])] = 1
end
ChoukaAlwaysKnownHash = {}
for i = 1, getn(ChoukaAlwaysKnownTypes), 1 do
    ChoukaAlwaysKnownHash[FastHash(ChoukaAlwaysKnownTypes[i])] = 1
end

-- 详见 docs/10-Lua注释存档.md §10_puredraw_data-4
ChoukaNativeWaterTypes = {
    "CelestialWaveriderIFV_Water",
    "AlliedLandingCraftAirCushion",
    "AlliedThetisBattleShip",
    "JapanYumiAircraftCarrier",
    "CelestialSeized_JapanAntiNavyShipTech3",
    "AlliedGaintAirCraftCarrier_B",
}
ChoukaNativeAirTypes = {
    "AlliedAvengerAttackAircraft",
    "WinterArmyKoelAttackUAV",
    "SovietTransportAircraft_HeavyCannon",
}

ChoukaNativeWaterHash = {}
for i = 1, getn(ChoukaNativeWaterTypes), 1 do
    ChoukaNativeWaterHash[FastHash(ChoukaNativeWaterTypes[i])] = 1
end
ChoukaNativeAirHash = {}
for i = 1, getn(ChoukaNativeAirTypes), 1 do
    ChoukaNativeAirHash[FastHash(ChoukaNativeAirTypes[i])] = 1
end

-- ---------------- 房主配置：抽卡范围（由 03_start.lua 的开局配置页写） ----------------
--   CHOUKA_DRAW_SCOPE = 0   箱子包括全部阵营（**默认**，四阵营卡池合并）
--   CHOUKA_DRAW_SCOPE = 1   抽卡只有自己阵营
CHOUKA_DRAW_SCOPE = CHOUKA_DRAW_SCOPE or 0