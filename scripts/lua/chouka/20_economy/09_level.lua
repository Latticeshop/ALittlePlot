-- ============================================================
-- 抽卡等级：★ 每个玩家一份，互相不影响（接口一律按 playerName 取）
--   自动升级（回合 5/10/15/20）是"给每人抬到该回合的保底等级"，只升不降。
-- 详见 docs/10-Lua注释存档.md §09_level-1 §09_level-2
-- ============================================================

ChoukaMarkNodeReady("初始化")

CHOUKA_MAX_LEVEL = 8

-- 玩家名 → 等级（没写过的按 1 级算）
ChoukaDrawLevelOf = ChoukaDrawLevelOf or {}

-- 各级各档概率（%），键 1~5 对应 T1~T5
ChoukaLevelWeights = {
    [1] = { 100, 0, 0, 0, 0 },
    [2] = { 90, 10, 0, 0, 0 },
    [3] = { 75, 25, 0, 0, 0 },
    [4] = { 55, 30, 15, 0, 0 },
    [5] = { 45, 33, 20, 2, 0 },
    [6] = { 30, 40, 25, 5, 0 },
    [7] = { 16, 30, 43, 10, 1 },
    [8] = { 15, 20, 34, 30, 1 },
}

-- 升到第 N 级的价格（键 = 目标等级；作者 2026-10 定稿）
--   Lv1 开局自带 / 1000 / 2000 / 5000 / 10000 / 20000 / 50000 / 50000
ChoukaLevelPrice = {
    [2] = 1000,
    [3] = 2000,
    [4] = 5000,
    [5] = 10000,
    [6] = 20000,
    [7] = 50000,
    [8] = 50000,
}

-- 第几个回合结束后自动升到该级（键 = 目标等级）
ChoukaAutoLevelRound = {
    [2] = 5,
    [3] = 10,
    [4] = 15,
    [5] = 20,
}

-- ============================================================
-- 按玩家的读写接口（其它脚本一律走这三个，别再碰全局）
-- ============================================================

-- 某个玩家当前的抽卡等级（没记录 = 1）
function ChoukaLevelGet(playerName)
    if playerName == nil then
        return 1
    end
    local level = ChoukaDrawLevelOf[playerName]
    if level == nil or level < 1 then
        return 1
    end
    if level > CHOUKA_MAX_LEVEL then
        return CHOUKA_MAX_LEVEL
    end
    return level
end

-- 直接设定某个玩家的等级（夹在 1~CHOUKA_MAX_LEVEL 之间），返回最终等级
function ChoukaLevelSet(playerName, level)
    if playerName == nil or level == nil then
        return 0
    end
    if level < 1 then
        level = 1
    end
    if level > CHOUKA_MAX_LEVEL then
        level = CHOUKA_MAX_LEVEL
    end
    ChoukaDrawLevelOf[playerName] = level
    return level
end

function ChoukaGetLevelWeights(level)
    local weights = ChoukaLevelWeights[level]
    if weights == nil then
        weights = ChoukaLevelWeights[1]
    end
    return weights
end

-- 升到 level 的价格（nil = 已满级）
function ChoukaGetLevelPrice(level)
    return ChoukaLevelPrice[level]
end

-- ============================================================
-- 自动升级：每刷一轮箱子（回合 +1）后调用
--   把**每个玩家**抬到该回合的保底等级（只升不降），并私聊告知本人。
--   已经是更高等级的玩家不受影响 —— 买上去的等级不会被打回去。
-- ============================================================

function ChoukaAutoLevelTick(round)
    if round == nil then
        return
    end
    local i, name, current, target, level, atRound
    for i = 1, 6, 1 do
        name = "Player_" .. i
        current = ChoukaLevelGet(name)
        target = current
        for level, atRound in ChoukaAutoLevelRound do
            if round >= atRound and level > target then
                target = level
            end
        end
        if target > current then
            ChoukaLevelSet(name, target)
            ChoukaTellPlayer(name, format(ChoukaT.levelAutoUp, target))
            _LOG("抽卡等级自动升级：" .. name .. " Lv." .. current .. " → Lv." .. target)
        end
    end
end

-- 升一级（购买，只影响掏钱的人）。返回 1=成功 / 0=失败，第二个返回是提示文字
function ChoukaBuyLevel(playerName)
    if playerName == nil then
        return 0, ""
    end

    local current = ChoukaLevelGet(playerName)
    local nextLevel = current + 1
    local price = ChoukaGetLevelPrice(nextLevel)
    if price == nil then
        return 0, format(ChoukaT.levelMax, current)
    end

    local money = exPlayerGetCurrentMoney(playerName)
    if money == nil then
        money = 0
    end
    if money < price then
        return 0, format(ChoukaT.levelNoMoney, nextLevel, price)
    end

    ExecuteAction("PLAYER_GIVE_MONEY", playerName, -price)
    ChoukaLevelSet(playerName, nextLevel)
    return 1, format(ChoukaT.levelUp, nextLevel)
end
