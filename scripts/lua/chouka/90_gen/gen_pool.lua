-- ============================================================
-- 抽卡卡池：自动生成勿手改，生成器 tools/build-pool.js（真源=作者《完整单位表》）
-- ============================================================

ChoukaDrawTierWeights = { 37, 50, 10, 2.5, 0.5 }

-- 类型名 → 类别（1步兵 2载具 3空军 4海军 5两栖）
ChoukaUnitCategory = {
    -- 步兵（27）
    AlliedScoutInfantry = 1, AlliedAntiInfantryInfantry = 1, AlliedAntiVehicleInfantry = 1,
    SovietScoutInfantry = 1, SovietAntiInfantryInfantry = 1, SovietAntiVehicleInfantry = 1,
    JapanScoutInfantry = 1, JapanAntiInfantryInfantry = 1, JapanAntiVehicleInfantry = 1,
    JapanArcherInfantry = 1, CelestialScoutDrone = 1, CelestialAntiInfantryInfantry = 1,
    CelestialAntiVehicleInfantry = 1, SovietMortarCycle = 1, WinterArmyScoutVehicle = 1,
    AlliedRangerInfantry = 1, JapanKamikazeInfantry = 1, SovietHeavyAntiVehicleInfantry = 1,
    JapanInfiltrationInfantry = 1, CelestialInfiltrationInfantry = 1, AlliedInfiltrationInfantry = 1,
    AlliedCryoLegionnaire = 1, CelestialAntiInfantryInfantryAdvanced = 1, AlliedCommandoTech1 = 1,
    SovietCommandoTech1 = 1, JapanAntiVehicleInfantryTech3 = 1, JapanCommandoTech1 = 1,
    -- 载具（51）
    AlliedAntiInfantryVehicle_Ground = 2, AlliedAntiAirVehicleTech1 = 2, SovietScoutVehicle = 2,
    SovietAntiInfantryVehicle = 2, JapanAntiInfantryVehicle = 2, JapanLightTransportVehicle = 2,
    AlliedHumveeVehicle = 2, AlliedGrizzlyMainBattleTank = 2, VUAntiInfantryVehicleTech1 = 2,
    SovietAntiAirVehicle = 2, CelestialMBT99A = 2, CelestialMBT99B = 2,
    AlliedAntiVehicleVehicleTech1 = 2, prismtank = 2, SovietHeavyAntiVehicleVehicleTech2 = 2,
    SovietSledgehammerSPG = 2, JapanSentinelVehicle = 2, CelestialAntiVehicleVehicleTech1 = 2,
    CelestialWaveriderIFV_ATGM = 2, JapanAntiVehicleVehicleTech1 = 2, JapanAntiAirVehicleTech1 = 2,
    RheinEntenteNimravusMBT = 2, RheinEntentePalaeoloxodonTD = 2, AlliedPacifierFAV = 2,
    VUBmptVehicle = 2, SovietHeavyAntiAirVehicleTech2 = 2, VUAntiAirVehicleTech1 = 2,
    VUAntiVehicleVehicleTech1 = 2, SovietAntiVehicleVehicleTech1 = 2, WinterArmyReaperHeavyMecha = 2,
    SovietAntiVehicleVehicleTech2 = 2, CelestialWheeledAssaultVehicle = 2, SovietHeavyGrinder = 2,
    JapanMissileMechaAdvanced = 2, AlliedAntiStructureVehicle = 2, AlliedAntiVehicleVehicleTech3 = 2,
    SovietAntiStructureVehicle = 2, SovietAntiVehicleVehicleTech3 = 2, JapanAntiVehicleVehicleTech3 = 2,
    JapanAntiStructureVehicle = 2, CelestialAntiVehicleVehicleTech3 = 2, CelestialHeavyAntiAirVehicleTech3 = 2,
    CelestialAntiStructureVehicle = 2, VUMissileAntiVehicleVehicleTech1 = 2, SovietHeavyMortarVehicle = 2,
    AlliedFutureTank = 2, AlliedBattleFortress = 2, SovietAntiVehicleVehicleTech4 = 2,
    JapanMechaX = 2, CelestialAntiVehicleVehicleTech4 = 2, CelestialDF41 = 2,
    -- 空军（28）
    AlliedAntiGroundAircraft = 3, AlliedFighterAircraft = 3, SovietAntiGroundAircraft = 3,
    SovietFighterAircraft = 3, CelestialSupportAircraft = 3, CelestialFighterAircraft = 3,
    WinterArmyKoelAttackUAV = 3, AlliedSupportAircraft = 3, CelestialAttackerAircraft = 3,
    AlliedAvengerAttackAircraft = 3, AlliedNightinaleHelicopter = 3, AlliedInterceptorAircraft = 3,
    AlliedBomberAircraft = 3, SovietInterceptorAircraft = 3, SovietAntiGroundAttacker = 3,
    CelestialInterceptorAircraft = 3, CelestialBomberAircraft = 3, JapanInterceptorAircraft = 3,
    JapanSakuraAttackRocket = 3, SovietHeavyTransportAircraft = 3, SovietTransportAircraft = 3,
    CelestialEngineerRepairDrone = 3, AlliedGunshipAircraft = 3, SovietBomberAircraft = 3,
    CelestialAdvanceAircraftTech4 = 3, SovietTransportAircraft_HeavyCannon = 3, CelestialEngineerRepairDroneLv2 = 3,
    CelestialEngineerRepairDroneLv3 = 3,
    -- 海军（23）
    AlliedAntiNavalScout = 4, AlliedAntiAirShip = 4, JapanNavyScoutShip = 4,
    CelestialAntiNavyShipTech1 = 4, AlliedAntiNavyShipTech1 = 4, SovietAntiNavyShipTech2 = 4,
    JapanAntiVehicleShip = 4, CelestialAlmightlyShip = 4, JapanAntiAirShip = 4,
    AlliedAntiNavyShipTech3 = 4, SovietAntiNavyShipTech3 = 4, JapanAntiNavyShipTech3 = 4,
    CelestialAntiNavyShipTech3 = 4, CelestialSeized_JapanAntiNavyShipTech3 = 4, AlliedAircraftCarrier = 4,
    SovietAntiStructureShip = 4, JapanAntiStructureShip = 4, CelestialAntiStructureShip = 4,
    JapanGigaFortress_Land = 4, AlliedThetisBattleShip = 4, CelestialMCV = 4,
    AlliedGaintAirCraftCarrier_B = 4, JapanYumiAircraftCarrier = 4,
    -- 两栖（5）
    SovietAntiAirShip = 5, CelestialAntiInfantryVehicle_B = 5, CelestialAntiAirVehicle = 5,
    SovietAntiNavyShipTech1 = 5, AlliedLandingCraftAirCushion = 5,
}

-- 分阵营卡池：[阵营][档] = { 类型名, ... }（T1~T4，T5 见下面单独一张表）
ChoukaDrawPoolBySide = {
    [1] = {   -- 盟军（35 种）
        [1] = {
            "AlliedScoutInfantry", "AlliedAntiInfantryInfantry", "AlliedAntiVehicleInfantry", "AlliedRangerInfantry",
            "AlliedAntiInfantryVehicle_Ground", "AlliedAntiAirVehicleTech1", "AlliedHumveeVehicle", "AlliedGrizzlyMainBattleTank",
            "AlliedAntiGroundAircraft", "AlliedFighterAircraft", "AlliedAntiNavalScout", "AlliedAntiAirShip",
        },
        [2] = {
            "AlliedInfiltrationInfantry", "AlliedAntiVehicleVehicleTech1", "prismtank", "RheinEntenteNimravusMBT",
            "RheinEntentePalaeoloxodonTD", "AlliedPacifierFAV", "AlliedSupportAircraft", "AlliedAvengerAttackAircraft",
            "AlliedNightinaleHelicopter", "AlliedAntiNavyShipTech1", "AlliedLandingCraftAirCushion",
        },
        [3] = {
            "AlliedCryoLegionnaire", "AlliedCommandoTech1", "AlliedAntiStructureVehicle", "AlliedAntiVehicleVehicleTech3",
            "AlliedInterceptorAircraft", "AlliedBomberAircraft", "AlliedAntiNavyShipTech3",
        },
        [4] = {
            "AlliedFutureTank", "AlliedBattleFortress", "AlliedGunshipAircraft", "AlliedAircraftCarrier",
            "AlliedThetisBattleShip",
        },
    },
    [2] = {   -- 苏联（40 种）
        [1] = {
            "SovietScoutInfantry", "SovietAntiInfantryInfantry", "SovietAntiVehicleInfantry", "SovietMortarCycle",
            "WinterArmyScoutVehicle", "SovietScoutVehicle", "SovietAntiInfantryVehicle", "SovietAntiAirShip",
            "VUAntiInfantryVehicleTech1", "SovietAntiAirVehicle", "SovietAntiGroundAircraft", "SovietFighterAircraft",
            "WinterArmyKoelAttackUAV", "SovietAntiNavyShipTech1",
        },
        [2] = {
            "SovietHeavyAntiVehicleInfantry", "SovietHeavyAntiVehicleVehicleTech2", "SovietSledgehammerSPG", "VUBmptVehicle",
            "SovietHeavyAntiAirVehicleTech2", "VUAntiAirVehicleTech1", "VUAntiVehicleVehicleTech1", "SovietAntiVehicleVehicleTech1",
            "WinterArmyReaperHeavyMecha", "SovietAntiVehicleVehicleTech2", "SovietHeavyGrinder", "SovietAntiNavyShipTech2",
        },
        [3] = {
            "SovietCommandoTech1", "SovietAntiStructureVehicle", "SovietAntiVehicleVehicleTech3", "VUMissileAntiVehicleVehicleTech1",
            "SovietHeavyMortarVehicle", "SovietInterceptorAircraft", "SovietAntiGroundAttacker", "SovietHeavyTransportAircraft",
            "SovietTransportAircraft", "SovietAntiNavyShipTech3",
        },
        [4] = {
            "SovietAntiVehicleVehicleTech4", "SovietBomberAircraft", "SovietTransportAircraft_HeavyCannon", "SovietAntiStructureShip",
        },
    },
    [3] = {   -- 升阳（25 种）
        [1] = {
            "JapanScoutInfantry", "JapanAntiInfantryInfantry", "JapanAntiVehicleInfantry", "JapanArcherInfantry",
            "JapanKamikazeInfantry", "JapanAntiInfantryVehicle", "JapanLightTransportVehicle", "JapanNavyScoutShip",
        },
        [2] = {
            "JapanInfiltrationInfantry", "JapanSentinelVehicle", "JapanAntiVehicleVehicleTech1", "JapanAntiAirVehicleTech1",
            "JapanAntiVehicleShip", "JapanAntiAirShip",
        },
        [3] = {
            "JapanAntiVehicleInfantryTech3", "JapanCommandoTech1", "JapanMissileMechaAdvanced", "JapanAntiVehicleVehicleTech3",
            "JapanAntiStructureVehicle", "JapanInterceptorAircraft", "JapanSakuraAttackRocket", "JapanAntiNavyShipTech3",
        },
        [4] = {
            "JapanMechaX", "JapanAntiStructureShip", "JapanGigaFortress_Land",
        },
    },
    [4] = {   -- 神州（29 种）
        [1] = {
            "CelestialScoutDrone", "CelestialAntiInfantryInfantry", "CelestialAntiVehicleInfantry", "CelestialAntiInfantryVehicle_B",
            "CelestialAntiAirVehicle", "CelestialMBT99A", "CelestialMBT99B", "CelestialSupportAircraft",
            "CelestialFighterAircraft", "CelestialAntiNavyShipTech1",
        },
        [2] = {
            "CelestialInfiltrationInfantry", "CelestialAntiVehicleVehicleTech1", "CelestialWaveriderIFV_ATGM", "CelestialWheeledAssaultVehicle",
            "CelestialAttackerAircraft", "CelestialAlmightlyShip",
        },
        [3] = {
            "CelestialAntiInfantryInfantryAdvanced", "CelestialAntiVehicleVehicleTech3", "CelestialHeavyAntiAirVehicleTech3", "CelestialAntiStructureVehicle",
            "CelestialInterceptorAircraft", "CelestialBomberAircraft", "CelestialEngineerRepairDrone", "CelestialAntiNavyShipTech3",
            "CelestialSeized_JapanAntiNavyShipTech3",
        },
        [4] = {
            "CelestialAntiVehicleVehicleTech4", "CelestialAdvanceAircraftTech4", "CelestialEngineerRepairDroneLv2", "CelestialAntiStructureShip",
        },
    },
}

-- T5：**全阵营共用一张表**（作者要求"合为一张表，全阵营可出"）
ChoukaDrawPoolT5 = {
    "CelestialMCV", "AlliedGaintAirCraftCarrier_B", "JapanYumiAircraftCarrier", "CelestialDF41",
    "CelestialEngineerRepairDroneLv3",
}
