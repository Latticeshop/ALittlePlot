-- ============================================================
-- 抽卡hex · 持续收入（底薪 + 油井加成 = 双轨）
--
-- 对应 ScriptsData.json：抽卡hex / 收入
--   EvaluationInterval     = 1     （每约 1 秒一次，与地编 Money 脚本同口径）
--   DeactivateUponSuccess  = false （常驻）
--   条件                   = CONDITION_TRUE
--
-- 判定口径（本图没有建造场、没有基地车，所以不能再用"有建造场就给钱"）：
--   · 底薪     ：自己的起重机 craneN 还活着 → 给 BASE_INCOME
--                （起重机 = 核心；实测被摧毁时该玩家直接判负，所以这里只是"还没被拆"的同义词）
--   · 油井加成 ：自己在 Total 区内还有 OilDerrick → 再给 OIL_INCOME
--                （本图每人 1 座 oilN，objectIndestructible=true，稳定生效）
--
-- 数值：40 + 20 = 60 元/秒 → 约 41 秒够一次日冕抽卡（2480/抽）
--       想更快就把 BASE_INCOME 调大，这个文件改完重新同步 JSON 即可。
-- ============================================================

local BASE_INCOME = 40    -- 底薪 $/秒
local OIL_INCOME  = 20    -- 每座自己的油井 $/秒
local BASE_POWER  = 100000

for i = 1, 6, 1 do
    local playerName = "Player_" .. i

    -- 起重机 = 核心，也用来判"这个座位还在场上"
    local crane = GetObjectByScriptName("crane" .. i)
    if ObjectIsAlive(crane) then

        -- 1) 底薪
        ExecuteAction("PLAYER_GIVE_MONEY", playerName, BASE_INCOME)

        -- 2) 电力每轮重设一次，防止被死亡模式/其它逻辑改回去
        ExecuteAction("PLAYER_SET_BASE_POWER", playerName, BASE_POWER)

        -- 3) 油井加成（Comparison 4 = ">"，与地编 Money 脚本同一枚举）
        if EvaluateCondition("PLAYER_HAS_COMPARISON_UNIT_TYPE_IN_TRIGGER_AREA",
                             playerName, 4, 0, "OilDerrick", "Total") then
            ExecuteAction("PLAYER_GIVE_MONEY", playerName, OIL_INCOME)
        end
    end
end
