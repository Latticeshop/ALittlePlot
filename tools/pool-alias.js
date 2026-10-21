/**
 * pool-alias.js —— 抽卡池的「中文名 → 单位类型名」对照表
 * ----------------------------------------------------------------------------
 * 只在「自定义抽卡池.txt」和 NonProductionUnitTier 的注释里都查不到时才会用到，
 * 主要覆盖作者清单里的简称（维护者 ↔ 维护者轰炸机）。
 * 每一条都已经用 日冕单位信息汇总.txt 的「单位名称 / 地编ID」核对过。
 */
'use strict';

module.exports = {
    // ---------------- 盟军 ----------------
    光棱: 'prismtank',                                  // 光棱坦克
    幻影: 'AlliedAntiVehicleVehicleTech3',              // 幻影坦克
    守护者坦克: 'AlliedAntiVehicleVehicleTech1',
    维护者: 'AlliedAntiGroundAircraft',
    阿波罗: 'AlliedFighterAircraft',
    阿瑞斯: 'AlliedInterceptorAircraft',                // 阿瑞斯截击机（盟军）
    世纪: 'AlliedBomberAircraft',                       // 世纪轰炸机
    冰冻直升机: 'AlliedSupportAircraft',
    复仇者攻击机: 'AlliedAvengerAttackAircraft',
    夜莺直升机: 'AlliedNightinaleHelicopter',
    雅典娜炮: 'AlliedAntiStructureVehicle',
    平定者: 'AlliedPacifierFAV',
    激流ACV: 'AlliedAntiInfantryVehicle_Ground',
    多功能步兵战车: 'AlliedAntiAirVehicleTech1',
    机枪悍马: 'AlliedHumveeVehicle',
    灰熊坦克: 'AlliedGrizzlyMainBattleTank',
    特洛伊要塞: 'AlliedBattleFortress',                 // 特洛伊突击要塞
    未来坦克X1: 'AlliedFutureTank',
    先锋炮艇机: 'AlliedGunshipAircraft',
    航母: 'AlliedAircraftCarrier',
    奥林匹斯级航空母舰: 'AlliedGaintAirCraftCarrier_B',
    忒提斯战列舰: 'AlliedThetisBattleShip',
    海豚: 'AlliedAntiNavalScout',
    水翼船: 'AlliedAntiAirShip',
    突袭驱逐舰: 'AlliedAntiNavyShipTech1',
    波塞冬: 'AlliedAntiNavyShipTech3',
    间谍: 'AlliedInfiltrationInfantry',
    冰冻军团: 'AlliedCryoLegionnaire',
    谭雅: 'AlliedCommandoTech1',

    // ---------------- 苏联 / 子阵营 ----------------
    犀牛: 'SovietHeavyAntiVehicleVehicleTech2',         // 犀牛坦克
    重锤: 'SovietSledgehammerSPG',                      // 重锤突击炮
    铁锤: 'SovietAntiVehicleVehicleTech1',
    天启: 'SovietAntiVehicleVehicleTech3',              // 天启坦克
    V4: 'SovietAntiStructureVehicle',                   // V4 导弹发射车
    磁爆部队: 'SovietHeavyAntiVehicleInfantry',
    磁爆坦克: 'SovietAntiVehicleVehicleTech2',
    恐怖机器人: 'SovietScoutVehicle',
    镰刀机甲: 'SovietAntiInfantryVehicle',
    牛蛙战车: 'SovietAntiAirShip',
    双刃: 'SovietAntiGroundAircraft',
    米格: 'SovietFighterAircraft',
    苏霍伊: 'SovietInterceptorAircraft',
    伊尔: 'SovietAntiGroundAttacker',
    基洛夫: 'SovietBomberAircraft',
    鲁斯兰大型运输机: 'SovietHeavyTransportAircraft',
    纤夫: 'SovietTransportAircraft',
    武装纤夫: 'SovietTransportAircraft_HeavyCannon',
    收割机甲: 'WinterArmyReaperHeavyMecha',
    勘察飞轮: 'WinterArmyScoutVehicle',
    蜂鸟侦查无人机: 'WinterArmyKoelAttackUAV',
    民用气象飞艇: 'SovietWeatherBalloon',
    蝾螈步兵战车: 'VUAntiInfantryVehicleTech1',
    章鱼突击炮: 'VUAntiVehicleVehicleTech1',
    偏流两栖高射炮: 'VUAntiAirVehicleTech1',
    BMPT坦克支援车: 'VUBmptVehicle',
    ZSU85自行防空炮: 'SovietHeavyAntiAirVehicleTech2',
    石勒喀河自行高射炮: 'SovietAntiAirVehicle',
    火炮机车: 'SovietMortarCycle',
    粉碎者: 'SovietHeavyGrinder',
    新旧联盟: 'SovietAntiVehicleVehicleTech4',          // 联盟重型坦克
    娜塔莎: 'SovietCommandoTech1',
    磁爆快艇: 'SovietAntiNavyShipTech1',
    阿库拉: 'SovietAntiNavyShipTech2',                  // 阿库拉攻击潜艇
    光荣: 'SovietAntiNavyShipTech3',                    // 光荣级导弹巡洋舰
    无畏: 'SovietAntiStructureShip',                    // 无畏级武库舰

    // ---------------- 升阳 ----------------
    海啸: 'JapanAntiVehicleVehicleTech1',
    钢铁浪人: 'JapanSentinelVehicle',
    天狗: 'JapanAntiInfantryVehicle',
    波能坦克: 'JapanAntiStructureVehicle',
    鬼王: 'JapanAntiVehicleVehicleTech3',
    鬼王X: 'JapanMechaX',
    心神机甲: 'JapanMissileMechaAdvanced',
    百合子: 'JapanCommandoTech1',
    迅雷运输艇: 'JapanLightTransportVehicle',
    樱花回天雷: 'JapanInterceptorAircraft',
    鬼樱特攻机: 'JapanSakuraAttackRocket',
    长枪迷你潜艇: 'JapanNavyScoutShip',
    薙刀: 'JapanAntiVehicleShip',
    海翼: 'JapanAntiAirShip',
    太刀: 'JapanAntiNavyShipTech3',
    将军: 'JapanAntiStructureShip',
    超级要塞: 'JapanFortressShip',

    // ---------------- 神州 ----------------
    麒麟: 'CelestialAntiVehicleVehicleTech1',
    青锋: 'CelestialWaveriderIFV_ATGM',
    凌波: 'CelestialAntiInfantryVehicle_B',
    磁弩: 'CelestialAntiAirVehicle',
    貔貅甲: 'CelestialMBT99A',
    貔貅乙: 'CelestialMBT99B',
    神州礼炮: 'CelestialSaluteGun',
    神州军用叉车: 'CelestialForkLiftVehicle',
    维修天灯: 'CelestialEngineerRepairDrone',            // 小型
    中型维修天灯: 'CelestialEngineerRepairDroneLv2',      // 中型
    大型维修天灯: 'CelestialEngineerRepairDroneLv3',      // 大型
    毕方: 'CelestialSupportAircraft',
    凤凰: 'CelestialFighterAircraft',
    朱雀: 'CelestialAttackerAircraft',
    重明: 'CelestialInterceptorAircraft',
    金乌: 'CelestialBomberAircraft',
    摇光巡天炮: 'CelestialAdvanceAircraftTech4',
    祝融攻坚: 'CelestialAntiVehicleVehicleTech3',
    祝融雷铳: 'CelestialHeavyAntiAirVehicleTech3',
    白虎: 'CelestialAntiStructureVehicle',
    破军金甲: 'CelestialAntiVehicleVehicleTech4',
    迅雷天罡: 'CelestialAntiInfantryInfantryAdvanced',
    岚影刺: 'CelestialInfiltrationInfantry',
    忍者: 'JapanInfiltrationInfantry',
    火箭天使: 'JapanAntiVehicleInfantryTech3',
    乌篷猎船: 'CelestialAntiNavyShipTech1',
    计蒙: 'CelestialAlmightlyShip',
    玄武: 'CelestialAntiStructureShip',
    玄冥: 'CelestialAntiNavyShipTech3',
    一式磁轨炮重巡: 'CelestialSeized_JapanAntiNavyShipTech3',
    青龙战斗核心舰: 'CelestialMCV',
    东风洲际导弹发射车: 'CelestialDF41',
    千鸟特攻母舰: 'JapanYumiAircraftCarrier',

    // ---------------- 四家通用（作者清单里的短名） ----------------
    警犬: 'AlliedScoutInfantry',
    维和步兵: 'AlliedAntiInfantryInfantry',
    标枪兵: 'AlliedAntiVehicleInfantry',
    游骑兵: 'AlliedRangerInfantry',
    战熊: 'SovietScoutInfantry',
    征召兵: 'SovietAntiInfantryInfantry',
    防空部队: 'SovietAntiVehicleInfantry',
    爆裂机器人: 'JapanScoutInfantry',
    帝国武士: 'JapanAntiInfantryInfantry',
    坦克杀手: 'JapanAntiVehicleInfantry',
    弓箭少女: 'JapanArcherInfantry',
    狂热帝国武士: 'JapanKamikazeInfantry',
    天眼哨机: 'CelestialScoutDrone',
    龙炎军: 'CelestialAntiInfantryInfantry',
    破甲铁卫: 'CelestialAntiVehicleInfantry',
    史普尼克勘查车: 'SovietSurveyor',
};
