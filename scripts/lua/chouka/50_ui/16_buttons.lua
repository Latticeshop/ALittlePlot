-- ============================================================
-- 详见 docs/10-Lua注释存档.md §16_buttons-1
-- ============================================================

ChoukaMarkNodeReady("按钮栏")

CHOUKA_BTN_MARKET       = 3
CHOUKA_BTN_HEXTECH      = 4
CHOUKA_BTN_ICON_MARKET  = "Button_PlayerPower_FreeTrade"
CHOUKA_BTN_ICON_HEXTECH = "Button_SovietChiefScientist"

CHOUKA_DIALOG_MAIN      = 700       -- 700 + 玩家序号 = 交易市场第一页
CHOUKA_DIALOG_TOWERS    = 710       -- 710 + 玩家序号 = 防御塔第二页

CHOUKA_AIRPORT_ENABLED  = 0                          -- 0 = 不显示购买入口（备用）；1 = 打开
CHOUKA_AIRPORT_TYPE     = "CelestialAirfield"        -- 神州机场的类型名（DSA GiveFreeStructure__2.lua 同款）
CHOUKA_AIRPORT_PRICE    = 1200
CHOUKA_AIRPORT_WP       = "airport"                  -- 航点：airport1 ~ airport6（一个座位一个）
CHOUKA_AIRPORT_ANGLE    = -3.1415926 / 4             -- 朝向（照 DSA 的 -45°）
CHOUKA_AIRPORT_RADIUS   = 200                        -- 判断"点位上已经有机场了"的搜索半径

ChoukaBtnStage = 0
ChoukaTowerSerial = 0

-- ============================================================
-- 详见 docs/10-Lua注释存档.md §16_buttons-2
-- ============================================================

ChoukaChoiceHandlers   = ChoukaChoiceHandlers or {}
ChoukaLongTextHandlers = ChoukaLongTextHandlers or {}

function ChoukaAddChoiceHandler(f)
    if type(f) ~= "function" then
        return
    end
    for i = 1, getn(ChoukaChoiceHandlers), 1 do
        if ChoukaChoiceHandlers[i] == f then
            return
        end
    end
    tinsert(ChoukaChoiceHandlers, f)
end

function ChoukaAddLongTextHandler(f)
    if type(f) ~= "function" then
        return
    end
    for i = 1, getn(ChoukaLongTextHandlers), 1 do
        if ChoukaLongTextHandlers[i] == f then
            return
        end
    end
    tinsert(ChoukaLongTextHandlers, f)
end

function onUserBtnChoiceDialogEvent(playerName, btnIndex, dialogId)
    for i = 1, getn(ChoukaChoiceHandlers), 1 do
        if ChoukaChoiceHandlers[i](playerName, btnIndex, dialogId) == 1 then
            return 1
        end
    end
    return 0
end

function onUserLongTextDialogEvent(playerName, btnIndex, dialogId)
    for i = 1, getn(ChoukaLongTextHandlers), 1 do
        if ChoukaLongTextHandlers[i](playerName, btnIndex, dialogId) == 1 then
            return 1
        end
    end
    return 0
end

-- ---------------- 氪金防御塔名单 ----------------
-- T1 ￥500 / T2 ￥2000 / T3 ￥7500 / T4 ￥20000（作者 2026-10 定稿）
-- 类型名全部对应 日冕 真实地编ID（来源：巨人城 ThingEnum.lua、DSA 市场塔、原版目录）
ChoukaTowerPriceByTier = {
    [1] = 500,
    [2] = 2000,
    [3] = 7500,
    [4] = 20000,
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
            ChoukaT.btnMarket)
        ChoukaBtnShow(playerName, CHOUKA_BTN_HEXTECH, CHOUKA_BTN_ICON_HEXTECH,
            ChoukaT.btnHextech)
    end
end

function ChoukaButtonsEnable()
    for i = 1, 6, 1 do
        local playerName = "Player_" .. i
        ChoukaBtnEnable(playerName, CHOUKA_BTN_MARKET, 1)
        ChoukaBtnEnable(playerName, CHOUKA_BTN_HEXTECH, 0)   -- 海克斯先禁用
    end
end

-- ★ 开局门控：房主点过「确认，开始游戏」之后才把顶部按钮栏建出来
--   （开局公告 / 等待房主配置期间不该露出交易市场，CHOUKA_GAME_STARTED 见 03_start.lua）
if CHOUKA_GAME_STARTED ~= 1 then
    ChoukaBtnStage = 0
elseif ChoukaBtnStage == 0 then
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

    local levelText = ChoukaT.btnLevelMax
    if nextPrice ~= nil then
        levelText = format(ChoukaT.btnLevelPrice, nextPrice)
    end

    -- ★ 神州机场这一项暂时关掉（CHOUKA_AIRPORT_ENABLED = 0），选项表按需要拼，别写死序号：
    --   关掉时 1=购买等级 2=购买防御塔 3=关闭；打开时 1=等级 2=防御塔 3=神州机场 4=关闭
    local choices = {
        levelText,
        "购买防御塔",
    }
    if CHOUKA_AIRPORT_ENABLED == 1 then
        tinsert(choices, format(ChoukaT.btnAirportPrice, CHOUKA_AIRPORT_PRICE))
    end
    tinsert(choices, "关闭")
    ChoukaShowDialog(playerName, CHOUKA_DIALOG_MAIN + index, "交易市场", choices)
end

-- 第二页：防御塔
function ChoukaShowTowerDialog(playerName)
    local index = ChoukaPlayerIndexFromName(playerName)
    if index == nil then
        return
    end
    local choices = {}
    for tier = 1, 4, 1 do
        choices[tier] = format(ChoukaT.btnTowerPrice, tier, ChoukaTowerPriceByTier[tier])
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
        ChoukaAlert(msg)
    else
        exAddTextToPublicBoardForPlayer(playerName, msg, 6)
    end
    return ok
end

-- 占位台账：存**对象句柄**，塔被卖掉/拆掉句柄就失效，格子自动释放
ChoukaTowerSlotUsed = ChoukaTowerSlotUsed or {}

-- 找一个空格子（1~4 顺序），返回 序号, 航点数组
function ChoukaFreeTowerSlot(index)
    for slot = 1, 4, 1 do
        local key = index .. "_" .. slot
        local used = ChoukaTowerSlotUsed[key]
        if used ~= nil and not ObjectIsAlive(used) then
            ChoukaTowerSlotUsed[key] = nil      -- 塔没了，位置腾出来
            used = nil
        end
        if used == nil then
            local waypoint = exWaypointGetPos("tower" .. index .. slot)
            if waypoint ~= nil and waypoint[1] ~= nil then
                return slot, waypoint
            end
        end
    end
    return nil, nil
end

-- 照 DSA 市场塔的写法：exCreateObject + FastHash；失败返回 nil
function ChoukaSpawnTower(playerName, index, towerType, x, y, z)
    local team = playerName .. "/team" .. playerName
    local tower = nil
    if type(exCreateObject) == "function" then
        local id = exCreateObject({
            ObjectType = FastHash(towerType),
            TeamName   = team,
            Position   = { X = x, Y = y, Z = z },
            Angle      = 0,
        })
        if id ~= nil then
            tower = GetObjectById(id)
        end
    end
    if tower == nil then
        ChoukaTowerSerial = ChoukaTowerSerial + 1
        local name = format("ChoukaTower_%d_%d", index, ChoukaTowerSerial)
        ExecuteAction("UNIT_SPAWN_NAMED_LOCATION_ORIENTATION", name, towerType, team,
            { X = x, Y = y, Z = z }, 0)
        tower = GetObjectByScriptName(name)
    end
    return tower
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
            format(ChoukaT.btnTowerNoMoney, tier, price), 6)
        return 0
    end

    local slot, waypoint = ChoukaFreeTowerSlot(index)
    if slot == nil then
        exAddTextToPublicBoardForPlayer(playerName, ChoukaT.towerSlotsFull, 6)
        return 0
    end

    local x, y, z = waypoint[1], waypoint[2], waypoint[3]
    if x == nil then
        exAddTextToPublicBoardForPlayer(playerName, ChoukaT.towerBadPos, 6)
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
    local tower = ChoukaSpawnTower(playerName, index, towerType, x, y, z)
    if tower == nil then
        -- 生成失败就退款，别让钱白扣
        ExecuteAction("PLAYER_GIVE_MONEY", playerName, price)
        SetWorldBuilderThisPlayer(previous)
        exAddTextToPublicBoardForPlayer(playerName, ChoukaT.towerSpawnFail, 6)
        return 0
    end
    -- DSA FinishMarketTower 的收尾：免冷冻 + 购买当帧就能开火（不等建造动画）
    ExecuteAction("UNIT_CHANGE_OBJECT_STATUS", tower, "IN_SHIELD_SPHERE", 1)
    ExecuteAction("UNIT_CHANGE_OBJECT_STATUS", tower, "UNPACKING", 0)
    ChoukaTowerSlotUsed[index .. "_" .. slot] = tower
    SetWorldBuilderThisPlayer(previous)

    exAddTextToPublicBoardForPlayer(playerName,
        format(ChoukaT.towerBought, slot, tier, price), 6)
    return 1
end

-- ---------------- 购买神州机场 ----------------

-- 台账：存机场的对象句柄（机场被拆了句柄失效，就允许重新买）
ChoukaAirportUsed = ChoukaAirportUsed or {}

-- 自己的机场点位（airport1 ~ airport6），没有这个航点就返回 nil
function ChoukaAirportPoint(index)
    if type(exWaypointGetPos) ~= "function" then
        return nil
    end
    local wp = exWaypointGetPos(CHOUKA_AIRPORT_WP .. index)
    if wp == nil or wp[1] == nil then
        return nil
    end
    return wp[1], wp[2], wp[3]
end

-- 点位上已经有神州机场了吗？
--  ① 先看台账（自己买过的），② 再按类型在点位附近扫一遍结构（防止重进游戏/别人手放）
function ChoukaAirportExists(index, x, y, z)
    local used = ChoukaAirportUsed[index]
    if used ~= nil then
        if ObjectIsAlive(used) then
            return 1
        end
        ChoukaAirportUsed[index] = nil         -- 机场没了，点位腾出来
    end

    if type(ObjectFindObjects) ~= "function" then
        return 0
    end
    -- 按"类型名"扫（IncludeThing，照 DSA / 日冕 BUFF 的写法）
    if ChoukaAirportFilter == nil then
        ChoukaAirportFilter = CreateObjectFilter({
            Rule = "ANY",
            IncludeThing = { CHOUKA_AIRPORT_TYPE },
        })
    end
    local objs, count = ObjectFindObjects(nil, {
        X = x, Y = y, Z = z or 0,
        Radius = CHOUKA_AIRPORT_RADIUS,
        DistType = "CENTER_2D",
    }, ChoukaAirportFilter)
    if count ~= nil and count > 0 then
        for i = 1, count, 1 do
            local obj = objs[i]
            if obj ~= nil and ObjectIsAlive(obj) then
                ChoukaAirportUsed[index] = obj       -- 顺手记进台账
                _LOG(format("机场检查 玩家=Player_%d 点位上已有神州机场（扫到 %d 座），不能重复买",
                    index, count))
                return 1
            end
        end
    end
    return 0
end

-- 生成一座神州机场（照 DSA GiveFreeStructure__2.lua：CREATE_NAMED...+航点）
-- 先登记 ChoukaScriptCreated，免得被抽卡系统当成"原版结果"拦走
function ChoukaSpawnAirport(playerName, index, x, y, z)
    ChoukaAirportSerial = (ChoukaAirportSerial or 0) + 1
    local objName = format("ChoukaAirport_%d_%d", index, ChoukaAirportSerial)
    local nextId = GetNextObjectId()
    ChoukaScriptCreated[nextId] = 1

    ExecuteAction("CREATE_NAMED_ON_TEAM_AT_WAYPOINT_WITH_ORIENTATION",
        objName, CHOUKA_AIRPORT_TYPE,
        format("%s/team%s", playerName, playerName),
        CHOUKA_AIRPORT_WP .. index, CHOUKA_AIRPORT_ANGLE)

    local obj = GetObjectByScriptName(objName)
    if ObjectIsAlive(obj) then
        local actualId = ObjectGetId(obj)
        if actualId ~= nextId then
            ChoukaScriptCreated[nextId] = nil
            ChoukaScriptCreated[actualId] = 1
        end
        return obj
    end
    ChoukaScriptCreated[nextId] = nil

    -- 航点方式失败就退回 exCreateObject（和防御塔同一套兜底）
    if type(exCreateObject) == "function" then
        local id2 = exCreateObject({
            ObjectType = FastHash(CHOUKA_AIRPORT_TYPE),
            TeamName   = format("%s/team%s", playerName, playerName),
            Position   = { X = x, Y = y, Z = z },
            Angle      = CHOUKA_AIRPORT_ANGLE,
        })
        if id2 ~= nil then
            ChoukaScriptCreated[id2] = 1
            local obj2 = GetObjectById(id2)
            if ObjectIsAlive(obj2) then
                return obj2
            end
            ChoukaScriptCreated[id2] = nil
        end
    end
    return nil
end

function ChoukaDoBuyAirport(playerName)
    local index = ChoukaPlayerIndexFromName(playerName)
    if index == nil then
        return 0
    end

    local x, y, z = ChoukaAirportPoint(index)
    if x == nil then
        exAddTextToPublicBoardForPlayer(playerName, ChoukaT.airportNoPoint, 6)
        return 0
    end

    if ChoukaAirportExists(index, x, y, z) == 1 then
        exAddTextToPublicBoardForPlayer(playerName, ChoukaT.airportExists, 6)
        return 0
    end

    local price = CHOUKA_AIRPORT_PRICE
    local money = exPlayerGetCurrentMoney(playerName) or 0
    if money < price then
        exAddTextToPublicBoardForPlayer(playerName,
            format(ChoukaT.airportNoMoney, price), 6)
        return 0
    end

    local previous = SetWorldBuilderThisPlayer(1)
    ExecuteAction("PLAYER_GIVE_MONEY", playerName, -price)
    local building = ChoukaSpawnAirport(playerName, index, x, y, z)
    if building == nil then
        ExecuteAction("PLAYER_GIVE_MONEY", playerName, price)   -- 生成失败就退款
        SetWorldBuilderThisPlayer(previous)
        exAddTextToPublicBoardForPlayer(playerName, ChoukaT.airportSpawnFail, 6)
        return 0
    end

    -- 和防御塔一样收尾：免冷冻 + 购买当帧就是"已建成"（不等建造动画）
    ExecuteAction("UNIT_CHANGE_OBJECT_STATUS", building, "IN_SHIELD_SPHERE", 1)
    ExecuteAction("UNIT_CHANGE_OBJECT_STATUS", building, "UNPACKING", 0)
    ChoukaAirportUsed[index] = building
    SetWorldBuilderThisPlayer(previous)

    exAddTextToPublicBoardForPlayer(playerName,
        format(ChoukaT.airportBought, price), 6)
    return 1
end

-- ---------------- 事件回调 ----------------

-- 顶部按钮点击（教程规定的固定名字）
--   注意：onCustomBtnClickEvent 也转发到这里（自由摆放的自定义按钮走同一个入口）。
--   三国杀的身份偏好已改用原生选择页（见 32_bang_pref.lua），这里只剩顶部按钮的点击。
function onCenterTopBtnClickEvent(playerName, btnIndex)
    -- ★ 三国杀模块先认领。它第一件事就判 CHOUKA_MODE，
    --   非三国杀模式一律返回 0 → 与改造前逐字节一致（docs/11 §13）
    if type(ChoukaBangOnBtn) == "function" then
        if ChoukaBangOnBtn(playerName, btnIndex) == 1 then
            return 1
        end
    end
    -- 结盟面板（照搬官渡 BangUi）：认领顶部第 5 个按钮 + 1100~1187 面板内按钮。
    -- 它不判模式：常规混战局也能用它结盟，所以放在三国杀之后、市场之前。
    if type(ChoukaPanelOnBtn) == "function" then
        if ChoukaPanelOnBtn(playerName, btnIndex) == 1 then
            return 1
        end
    end
    if btnIndex == CHOUKA_BTN_MARKET then
        ChoukaShowMarketDialog(playerName)
    end
end

-- DSA 那边的名字，一起定义上兜底
function onCustomBtnClickEvent(playerName, btnIndex)
    onCenterTopBtnClickEvent(playerName, btnIndex)
end

-- 选择对话框回调（交易市场两页）。开局配置那个对话框由 03_start.lua 处理，
-- 这里只认自己的 dialogId，处理完返回 1，其余返回 0 让别的处理函数接手。
function ChoukaChoice_market(playerName, btnIndex, dialogId)
    if dialogId == nil or btnIndex == nil then
        return 0
    end

    local index = ChoukaPlayerIndexFromName(playerName)
    if index == nil then
        return 0
    end

    if dialogId == CHOUKA_DIALOG_MAIN + index then
        if btnIndex == 1 then
            ChoukaDoBuyLevel(playerName)
        elseif btnIndex == 2 then
            ChoukaShowTowerDialog(playerName)
        elseif btnIndex == 3 and CHOUKA_AIRPORT_ENABLED == 1 then
            -- 神州机场（备用）：开关关着时这一格是"关闭"，什么都不做
            ChoukaDoBuyAirport(playerName)
        end
        return 1
    elseif dialogId == CHOUKA_DIALOG_TOWERS + index then
        if btnIndex >= 1 and btnIndex <= 4 then
            ChoukaDoBuyTower(playerName, btnIndex)
            -- 买完立即关面板（作者要求）
            if type(exHideCustomBtnChoiceDialogForPlayer) == "function" then
                exHideCustomBtnChoiceDialogForPlayer(playerName)
            end
        elseif btnIndex == 5 then
            ChoukaShowMarketDialog(playerName)
        end
        return 1
    end
    return 0
end

-- ⚠ 只注册一次（脚本每次求值都会造一个新的函数对象，不卡住会让表每秒变长）
if ChoukaMarketHandlerRegistered ~= 1 then
    ChoukaMarketHandlerRegistered = 1
    ChoukaAddChoiceHandler(ChoukaChoice_market)
end