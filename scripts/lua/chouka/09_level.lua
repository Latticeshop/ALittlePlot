-- ============================================================
-- 详见 docs/10-Lua注释存档.md §09_level-1
-- ============================================================

ChoukaMarkNodeReady("初始化")

CHOUKA_MAX_LEVEL = 8

ChoukaDrawLevel = 1

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

-- 每刷一轮箱子（回合 +1）后调用：到点自动升级 + 全图播报
function ChoukaAutoLevelTick(round)
    if round == nil then
        return
    end
    for level, atRound in ChoukaAutoLevelRound do
        -- 只在"当前等级更低"时升级，绝不把已经买上去的等级压下来
        if round >= atRound and ChoukaDrawLevel < level then
            ChoukaDrawLevel = level
            _ALERT(format(ChoukaT.levelAutoUp, level))
        end
    end
end

-- 升一级（购买）。返回 1=成功 / 0=失败，第二个返回是提示文字
function ChoukaBuyLevel(playerName)
    local nextLevel = ChoukaDrawLevel + 1
    local price = ChoukaGetLevelPrice(nextLevel)
    if price == nil then
        return 0, format(ChoukaT.levelMax, ChoukaDrawLevel)
    end
    local money = exPlayerGetCurrentMoney(playerName)
    if money == nil then
        money = 0
    end
    if money < price then
        return 0, format(ChoukaT.levelNoMoney, nextLevel, price)
    end
    ExecuteAction("PLAYER_GIVE_MONEY", playerName, -price)
    ChoukaDrawLevel = nextLevel
    return 1, format(ChoukaT.levelUp, ChoukaDrawLevel)
end