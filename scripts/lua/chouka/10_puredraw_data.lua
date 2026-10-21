-- ============================================================
-- 抽卡hex · 抽卡系统「数据层」
--
-- 照搬《DSA_ggz自走棋》PureDraw 的做法：
--   原版抽卡的随机发生在引擎/mod 侧 —— 箱子被拾取后引擎直接生成**一整批**同型单位，
--   Lua 拿不到"抽到了什么"的决策，只能事后看到"结果单位被创建"。
--   所以我们做的是：拦截这批原生结果 → 整批删掉 → 在自己队伍生成 1 个卡池单位。
--
-- 本文件只放数据与状态；钩子在 11，替换逻辑在 12，每帧驱动在 13。
-- ============================================================

-- 玩家锚点：ObjectFindObjects 的第一个参数是"某个物体"，过滤器里的
-- Relationship = SAME_PLAYER 就按这个物体的主人判定。我们图每人一台 craneN，
-- 正好当锚点（DSA 用的是地图上摆的 P1~P8 隐形物件）。
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

-- 白名单：这些类型即使没有生产者，也**绝不能**当成"原版抽卡结果"删掉。
-- 照抄 DSA 的工程师 + 各型 MCV（DSA 原表见 PureDraw/02_data.lua:228-236）。
-- ⚠ 日冕的协议/技能召唤物同样"没有生产者"，如果实测发现它们被误删，
--   把对应类型名加进这张表即可（这是唯一需要维护的地方）。
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

-- 自定义抽卡概率（0~100）。100 = 原版抽卡结果**必定**转成自定义单位（当前设定）。
-- 注意闸门是"一抽掷一次"，不是"每个单位掷一次"，不会出现半批转换。
CHOUKA_CUSTOM_CHANCE = 100

-- ---------------- 玩家阵营（1=盟军 2=苏联 3=升阳 4=神州） ----------------
-- 照 DSA 的做法（lua/GAME/PlayerSide.lua：用 PLAYER_HAS_PLAYER_TECH 探四个基础科技）。
-- ⚠ 但**不能在第 0 帧探测**：那时科技树可能还没就绪，会全部误判成盟军。
--   所以第一次抽卡时（最早也要 40 秒后）再探测，结果缓存起来。
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
