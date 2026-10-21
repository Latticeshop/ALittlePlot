-- ============================================================
-- 抽卡hex · 抽卡等级（决定各档概率）
--
-- 等级 1~8，每级一张概率表；"购买等级"花钱升，或到指定回合自动升。
-- 作者定的表（见 日冕地图lua例子/抽卡hex地图说明.txt:40-49）：
--   等级   T1    T2    T3    T4   T5    升到该级的价格   自动升级
--   1级   100%    0%    0%    0%   0%   开局自带         —
--   2级    90%   10%    0%    0%   0%   500             第 5 回合后
--   3级    75%   25%    0%    0%   0%   1000            第 10 回合后
--   4级    55%   30%   15%    0%   0%   2000            第 15 回合后
--   5级    45%   33%   20%    2%   0%   3000            第 20 回合后
--   6级    30%   40%   25%    5%   0%   5000            —
--   7级    16%   30%   43%   10%   1%   10000           —
--   8级    15%   20%   34%   30%   1%   10000           —
--
-- ⚠ 简化为**全场共用一级**：这张图只有 6 个小格，等级做成公共进度，
--   任何人买都会推进全场等级（和左下角 HUD 显示的读数是同一个数）。
--   自动升级只在"当前等级更低"时生效，"不覆盖更高等级"自然成立。
-- ============================================================

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

-- 升到第 N 级的价格（键 = 目标等级）
ChoukaLevelPrice = {
    [2] = 500,
    [3] = 1000,
    [4] = 2000,
    [5] = 3000,
    [6] = 5000,
    [7] = 10000,
    [8] = 10000,
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
            exAddTextToPublicBoard(format("抽卡等级已自动升为%d级", level), 8)
        end
    end
end

-- 升一级（购买）。返回 1=成功 / 0=失败，第二个返回是提示文字
function ChoukaBuyLevel(playerName)
    local nextLevel = ChoukaDrawLevel + 1
    local price = ChoukaGetLevelPrice(nextLevel)
    if price == nil then
        return 0, format("抽卡等级已满（Lv.%d）", ChoukaDrawLevel)
    end
    local money = exPlayerGetCurrentMoney(playerName)
    if money == nil then
        money = 0
    end
    if money < price then
        return 0, format("金币不足：升到 Lv.%d 需要 %d", nextLevel, price)
    end
    ExecuteAction("PLAYER_GIVE_MONEY", playerName, -price)
    ChoukaDrawLevel = nextLevel
    return 1, format("抽卡等级提升到 Lv.%d", ChoukaDrawLevel)
end
