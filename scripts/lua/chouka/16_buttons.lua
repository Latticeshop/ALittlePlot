-- ============================================================
-- 抽卡hex · 顶部按钮栏 + 交易市场 + 氪金防御塔
--
-- 对应 ScriptsData.json 节点：抽卡hex / 按钮栏
--
-- API 以 教程.lua:284-332 为准：
--   区域可见：exCenterTopBtnsChangeVisibilityForPlayer(playerName, visible)
--   建/改按钮：exCenterTopBtnShowForPlayer(playerName, index, textureName, desc)
--   启用：  exCenterTopBtnSetEnableForPlayer(playerName, index, enable)
--   ⚠ Show 之后要**等 1 或 2 帧**再调其它 ui 函数，所以启用放在下一次求值。
--   点击回调固定名：function onCenterTopBtnClickEvent(playerName, btnIndex)
--
-- 按钮位置（作者定）：1、2 留空，3 = 交易市场，4 = 海克斯，5、6 留空。
--
-- 交易市场两页：
--   第一页：1 购买下一抽卡等级：<价格>   2 购买防御塔   3 关闭
--   第二页：1 购买随机T1防御塔：500     2 …T2：2000
--           3 …T3：5000               4 …T4：10000      5 返回
--
-- 防御塔只落在自己的四个预设点位 tower<玩家号>1~4（点位名 tower11 ~ tower64），
-- 按 1→4 顺序填，一格一塔不可堆叠；没有空位时只给自己发提示。
-- ============================================================

CHOUKA_BTN_MARKET       = 3
CHOUKA_BTN_HEXTECH      = 4
CHOUKA_BTN_ICON_MARKET  = "Button_PlayerPower_FreeTrade"
CHOUKA_BTN_ICON_HEXTECH = "Button_SovietChiefScientist"

CHOUKA_DIALOG_MAIN      = 700       -- 700 + 玩家序号 = 交易市场第一页
CHOUKA_DIALOG_TOWERS    = 710       -- 710 + 玩家序号 = 防御塔第二页

ChoukaBtnStage = 0
ChoukaTowerSerial = 0

-- ---------------- 氪金防御塔名单 ----------------
-- T1 ￥500 / T2 ￥2000 / T3 ￥5000 / T4 ￥10000
-- 类型名全部对应 日冕 真实地编ID（来源：巨人城 ThingEnum.lua、DSA 市场塔、原版目录）
ChoukaTowerPriceByTier = {
    [1] = 500,
    [2] = 2000,
    [3] = 5000,
    [4] = 10000,
}

ChoukaTowerPoolByTier = {
    [1] = {
        "CelestialBaseDefenseAir",      -- 重弩碉台
        "SovietBaseDefenseGround",      -- 哨兵枪
        "SovietBaseDefenseAir",         -- 防空炮
        "AlliedBaseDefense",            -- 多功能防御塔
        "JapanBaseDefense",             -- 防卫者-VX
    },
    [2] = {
        "AlliedBaseDefenseAdvanced",    -- 光棱塔
        "SovietBaseDefenseAdvanced",    -- 磁暴线圈
        "JapanBaseDefenseAdvanced",     -- 波能塔
        "CelestialBaseDefenseAdvanced", -- 浑天塔
    },
    [3] = {
        "AlliedHeavyArtilleryDefenseBase",  -- 施耐德巨炮
        "JapanPointShieldControlTower",     -- 瞬息纳米护盾投射塔
        "CelestialEnergyGatlingTower",      -- 疾雷铳台
        "SovietHeavyAntiAirMissileTurret",  -- 胡杨防空系统
    },
    [4] = {
        "CelestialEnergyRailgunBase",       -- 天门神弓
        "AlliedAegisLargeDefenseBase",      -- 埃奎斯护盾发生器
        "JapanKamikazeCommandTower",        -- 樱花井
        "SovietDualPurposeCruiseMissileTurret", -- 礁石岸防导弹要塞（作者提供）
    },
}

-- ---------------- 底层封装（带名字兜底） ----------------

function ChoukaBtnShow(playerName, index, texture, desc)
    if type(exCenterTopBtnShowForPlayer) == "function" then
        exCenterTopBtnShowForPlayer(playerName, index, texture, desc)
    elseif type(exCenterTopBtnShow) == "function" then
        exCenterTopBtnShow(index, texture, desc)
    end
end

function ChoukaBtnEnable(playerName, index, enable)
    if type(exCenterTopBtnSetEnableForPlayer) == "function" then
        exCenterTopBtnSetEnableForPlayer(playerName, index, enable)
    elseif type(exCenterTopBtnSetEnable) == "function" then
        exCenterTopBtnSetEnable(index, enable)
    end
end

function ChoukaBtnVisibility(playerName, visible)
    if type(exCenterTopBtnsChangeVisibilityForPlayer) == "function" then
        exCenterTopBtnsChangeVisibilityForPlayer(playerName, visible)
    elseif type(exCenterTopBtnsChangeVisibility) == "function" then
        exCenterTopBtnsChangeVisibility(visible)
    end
end

function ChoukaPlayerIndexFromName(playerName)
    if playerName == nil then
        return nil
    end
    return tonumber(strsub(playerName, 8))
end

-- ---------------- 建按钮（两次求值，静默） ----------------

function ChoukaButtonsBuild()
    for i = 1, 6, 1 do
        local playerName = "Player_" .. i
        ChoukaBtnVisibility(playerName, 1)
        ChoukaBtnShow(playerName, CHOUKA_BTN_MARKET, CHOUKA_BTN_ICON_MARKET,
            "交易市场\n购买等级 / 购买防御塔")
        ChoukaBtnShow(playerName, CHOUKA_BTN_HEXTECH, CHOUKA_BTN_ICON_HEXTECH,
            "海克斯\n本图暂未启用")
    end
end

function ChoukaButtonsEnable()
    for i = 1, 6, 1 do
        local playerName = "Player_" .. i
        ChoukaBtnEnable(playerName, CHOUKA_BTN_MARKET, 1)
        ChoukaBtnEnable(playerName, CHOUKA_BTN_HEXTECH, 0)   -- 海克斯先禁用
    end
end

if ChoukaBtnStage == 0 then
    ChoukaButtonsBuild()
    ChoukaBtnStage = 1
elseif ChoukaBtnStage == 1 then
    ChoukaButtonsEnable()
    ChoukaBtnStage = 2
end

-- ---------------- 对话框 ----------------

function ChoukaShowDialog(playerName, dialogId, title, choices)
    if type(exShowCustomBtnChoiceDialogForPlayer) ~= "function" then
        return
    end
    local args = { playerName, dialogId, title }
    for i = 1, getn(choices), 1 do
        tinsert(args, choices[i])
    end
    while getn(args) < 10 do
        tinsert(args, "")
    end
    call(exShowCustomBtnChoiceDialogForPlayer, args)
end

-- 第一页：交易市场
function ChoukaShowMarketDialog(playerName)
    local index = ChoukaPlayerIndexFromName(playerName)
    if index == nil then
        return
    end
    local level = ChoukaDrawLevel or 1
    local nextPrice = nil
    if ChoukaGetLevelPrice ~= nil then
        nextPrice = ChoukaGetLevelPrice(level + 1)
    end

    local levelText = "购买下一抽卡等级：已满级"
    if nextPrice ~= nil then
        levelText = format("购买下一抽卡等级：%d", nextPrice)
    end

    ChoukaShowDialog(playerName, CHOUKA_DIALOG_MAIN + index, "交易市场", {
        levelText,
        "购买防御塔",
        "关闭",
    })
end

-- 第二页：防御塔
function ChoukaShowTowerDialog(playerName)
    local index = ChoukaPlayerIndexFromName(playerName)
    if index == nil then
        return
    end
    local choices = {}
    for tier = 1, 4, 1 do
        choices[tier] = format("购买随机T%d防御塔：%d", tier, ChoukaTowerPriceByTier[tier])
    end
    choices[5] = "返回"
    ChoukaShowDialog(playerName, CHOUKA_DIALOG_TOWERS + index, "购买防御塔", choices)
end

-- ---------------- 购买动作 ----------------

function ChoukaDoBuyLevel(playerName)
    local previous = SetWorldBuilderThisPlayer(1)
    local ok, msg = ChoukaBuyLevel(playerName)
    SetWorldBuilderThisPlayer(previous)
    if ok == 1 then
        exAddTextToPublicBoard(msg, 6)
    else
        exAddTextToPublicBoardForPlayer(playerName, msg, 6)
    end
    return ok
end

-- 找一个空格子（1~4 顺序），返回序号；全满返回 nil
function ChoukaFreeTowerSlot(index)
    if ChoukaTowerSlotFilter == nil then
        ChoukaTowerSlotFilter = CreateObjectFilter({
            Rule = "ANY",
            Include = "STRUCTURE",
        })
    end
    for slot = 1, 4, 1 do
        local waypoint = exWaypointGetPos("tower" .. index .. slot)
        local occupied = 0
        if waypoint ~= nil then
            local x = waypoint[1]
            local y = waypoint[2]
            local z = waypoint[3]
            if x ~= nil then
                local found, count = ObjectFindObjects(nil,
                    { X = x, Y = y, Z = z, Radius = 45 }, ChoukaTowerSlotFilter)
                if count ~= nil and count > 0 then
                    occupied = 1
                end
            else
                occupied = 1   -- 点位读不出来，当作不可用
            end
        else
            occupied = 1
        end
        if occupied == 0 then
            return slot
        end
    end
    return nil
end

function ChoukaDoBuyTower(playerName, tier)
    local index = ChoukaPlayerIndexFromName(playerName)
    local price = ChoukaTowerPriceByTier[tier]
    local pool = ChoukaTowerPoolByTier[tier]
    if index == nil or price == nil or pool == nil then
        return 0
    end

    local money = exPlayerGetCurrentMoney(playerName) or 0
    if money < price then
        exAddTextToPublicBoardForPlayer(playerName,
            format("金币不足：T%d防御塔需要 %d", tier, price), 6)
        return 0
    end

    local slot = ChoukaFreeTowerSlot(index)
    if slot == nil then
        exAddTextToPublicBoardForPlayer(playerName, "你的 4 个防御塔点位都已被占用", 6)
        return 0
    end

    local waypoint = exWaypointGetPos("tower" .. index .. slot)
    local x, y, z = waypoint[1], waypoint[2], waypoint[3]
    if x == nil then
        exAddTextToPublicBoardForPlayer(playerName, "防御塔点位坐标异常，购买取消", 6)
        return 0
    end

    -- 随机一个该档的塔
    local pick = floor(GetRandomNumber() * getn(pool)) + 1
    if pick > getn(pool) then
        pick = getn(pool)
    end
    local towerType = pool[pick]

    local previous = SetWorldBuilderThisPlayer(1)
    ExecuteAction("PLAYER_GIVE_MONEY", playerName, -price)
    ChoukaTowerSerial = ChoukaTowerSerial + 1
    ExecuteAction("UNIT_SPAWN_NAMED_LOCATION_ORIENTATION",
        format("ChoukaTower_%d_%d_%d", index, slot, ChoukaTowerSerial),
        towerType,
        format("%s/team%s", playerName, playerName),
        { X = x, Y = y, Z = z }, 0)
    SetWorldBuilderThisPlayer(previous)

    exAddTextToPublicBoardForPlayer(playerName,
        format("已在 %d 号点位购买 T%d 防御塔（-%d）", slot, tier, price), 6)
    return 1
end

-- ---------------- 事件回调 ----------------

-- 顶部按钮点击（教程规定的固定名字）
function onCenterTopBtnClickEvent(playerName, btnIndex)
    if btnIndex == CHOUKA_BTN_MARKET then
        ChoukaShowMarketDialog(playerName)
    end
end

-- DSA 那边的名字，一起定义上兜底
function onCustomBtnClickEvent(playerName, btnIndex)
    onCenterTopBtnClickEvent(playerName, btnIndex)
end

-- 选择对话框回调
function onUserBtnChoiceDialogEvent(playerName, btnIndex, dialogId)
    if dialogId == nil or btnIndex == nil then
        return
    end

    local index = ChoukaPlayerIndexFromName(playerName)
    if index == nil then
        return
    end

    if dialogId == CHOUKA_DIALOG_MAIN + index then
        if btnIndex == 1 then
            ChoukaDoBuyLevel(playerName)
        elseif btnIndex == 2 then
            ChoukaShowTowerDialog(playerName)
        end
    elseif dialogId == CHOUKA_DIALOG_TOWERS + index then
        if btnIndex >= 1 and btnIndex <= 4 then
            ChoukaDoBuyTower(playerName, btnIndex)
            ChoukaShowTowerDialog(playerName)   -- 买完留在这一页，方便连买
        elseif btnIndex == 5 then
            ChoukaShowMarketDialog(playerName)
        end
    end
end
