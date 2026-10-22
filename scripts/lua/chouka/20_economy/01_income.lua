-- ============================================================
-- 详见 docs/10-Lua注释存档.md §01_income-1
-- ============================================================

-- ★ 开局门控：房主点过「确认，开始游戏」之前一律不结算
--   （CHOUKA_GAME_STARTED 由 03_start.lua 置 1；等待期间玩家不该凭空涨钱）
ChoukaMarkNodeReady("收入")

if CHOUKA_GAME_STARTED ~= 1 then
    return
end

-- 三国杀模式结算之后一律停手（docs/11 §9④）
if CHOUKA_BANG_ENDED == 1 then
    return
end

local BASE_INCOME        = 20   -- 底薪 $/秒（倍率 1 时；作者要求砍掉一半，原来 40 给钱太快）
local OIL_INCOME         = 20   -- 自己的私油井 oilN $/秒
local CENTER_OIL_INCOME  = 40   -- 占领中央油井 centerOilN $/秒（长期占据的核心收益）
local BASE_POWER         = 100000

-- 三国杀模式：主公底薪倍率（20 → 30）。油井 / 中央油井不受影响，见 docs/11 §8
CHOUKA_BANG_LORD_INCOME_MULT = CHOUKA_BANG_LORD_INCOME_MULT or 1.5

-- 经济倍率（读不到就按 1）
local choukaMult = 1
if type(exModeGetCheatMultiplier) == "function" then
    choukaMult = exModeGetCheatMultiplier()
    if choukaMult == nil or choukaMult <= 0 then
        choukaMult = 1
    end
end
CHOUKA_ECONOMY_MULT = choukaMult       -- 给其它脚本（中央油井播报）看

local baseIncome       = floor(BASE_INCOME * choukaMult)
local oilIncome        = floor(OIL_INCOME * choukaMult)
local centerOilIncome  = floor(CENTER_OIL_INCOME * choukaMult)

for i = 1, 6, 1 do
    local playerName = "Player_" .. i
    local crane = GetObjectByScriptName("crane" .. i)
    if ObjectIsAlive(crane) then

        -- 1) 底薪
        --    三国杀模式：主公底薪 ×1.5（20 → 30），油井和中央油井**不吃**这个加成
        --    —— 否则主公滚雪球太狠（docs/11 §8）
        local lordMult = 1
        if CHOUKA_MODE == 1 and ChoukaBangLordIndex == i then
            lordMult = CHOUKA_BANG_LORD_INCOME_MULT
        end
        ExecuteAction("PLAYER_GIVE_MONEY", playerName, floor(baseIncome * lordMult))

        -- 2) 电力每轮重设，防止被其它逻辑改回去
        ExecuteAction("PLAYER_SET_BASE_POWER", playerName, BASE_POWER)

        -- 3) 私油井加成
        if EvaluateCondition("PLAYER_HAS_COMPARISON_UNIT_TYPE_IN_TRIGGER_AREA",
                             playerName, 4, 0, "OilDerrick", "Total") then
            ExecuteAction("PLAYER_GIVE_MONEY", playerName, oilIncome)
        end

        -- 4) 中央油井收益（01_income 与 05_center 用同一个全局表）
        if ChoukaCenterOilOwner ~= nil then
            local mine = 0
            for k = 1, 2, 1 do
                if ChoukaCenterOilOwner[k] == i then
                    mine = mine + 1
                end
            end
            if mine > 0 then
                ExecuteAction("PLAYER_GIVE_MONEY", playerName, centerOilIncome * mine)
            end
        end
    end
end