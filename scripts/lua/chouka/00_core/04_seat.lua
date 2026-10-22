-- ============================================================
-- 座位状态权威：起重机 = 命（三国杀 / 默认玩法共用）
--   ChoukaSeatAlive(seat) = 起重机存在 ∧ 存活 ∧ 归属仍是本人
--   ChoukaSeatGuard()     = 归属变成本人以外（退出移交 / 被工程师刷漆）→ 立刻 NAMED_KILL 引爆
--   只定义函数，没有节点体；守卫由 01_income.lua（收入节点，每秒）驱动。
-- 详见 docs/10-Lua注释存档.md §04_seat-1
-- ============================================================

-- ① 归属不一致要连读几次才动手：防止某一次 ObjectPlayerScriptName 读空/读错就误炸活人
CHOUKA_SEAT_MISMATCH_TOLERANCE = 3

ChoukaSeatSeen         = ChoukaSeatSeen or {}          -- 这局见过这把起重机存在的座位
ChoukaSeatSelfSeen     = ChoukaSeatSelfSeen or {}      -- 见过它**归属是本人**的座位（守卫只认这些）
ChoukaSeatMismatch     = ChoukaSeatMismatch or {}      -- 归属不一致的连续次数
ChoukaSeatKilled       = ChoukaSeatKilled or {}        -- 已经由守卫引爆过的座位（只播报一次）
ChoukaSeatGuardTicks   = ChoukaSeatGuardTicks or 0

function ChoukaSeatName(seat)
    return "Player_" .. seat
end

function ChoukaSeatCrane(seat)
    if seat == nil then
        return nil
    end
    if type(GetObjectByScriptName) ~= "function" then
        return nil
    end
    return GetObjectByScriptName((ChoukaCranePrefix or "crane") .. seat)
end

-- 起重机当前归属的玩家脚本名（读不到返回 nil）
function ChoukaSeatOwner(seat)
    local crane = ChoukaSeatCrane(seat)
    if crane == nil then
        return nil
    end
    if not ObjectIsAlive(crane) then
        return nil
    end
    if type(ObjectPlayerScriptName) ~= "function" then
        return nil
    end
    local owner = ObjectPlayerScriptName(crane)
    if owner == nil or owner == "" then
        return nil
    end
    return owner
end

-- 归属是不是"本人"：读不到（nil）/ 读到的不是某个座位的脚本名 —— 一律当"是"，宁可放过不误杀。
-- ★ 只有"归属明确变成了**另一个参战座位**的 Player_N"才算被移交。
--   这条口径很关键：退出/被刷漆时引擎是把资产交给另一个玩家，
--   所以新归属一定是个能对上的 Player_k；对不上的怪字符串（空格、$p1Name、中立队……）
--   都当成"读不准"，绝不能拿去炸活人的起重机。
function ChoukaSeatOwnedBySelf(seat)
    local owner = ChoukaSeatOwner(seat)
    if owner == nil then
        return 1
    end
    if owner == ChoukaSeatName(seat) then
        return 1
    end
    local k
    for k = 1, 6, 1 do
        if k ~= seat and owner == ChoukaSeatName(k) then
            return 0                 -- 明确移交给了另一个玩家
        end
    end
    return 1                         -- 认不出的归属当"没事"
end

-- 座位还活着吗（0/1）。所有"这人还在不在"的判断都该走这里
function ChoukaSeatAlive(seat)
    if seat == nil then
        return 0
    end
    local crane = ChoukaSeatCrane(seat)
    if crane == nil then
        return 0
    end
    if not ObjectIsAlive(crane) then
        return 0
    end
    return ChoukaSeatOwnedBySelf(seat)
end

-- "确认已阵亡"：必须先见过它活着、再见到它没了，才算数
-- （避免开局那一瞬间还没扫到起重机就把活人判死）
function ChoukaSeatKnownDead(seat)
    if ChoukaSeatSeen[seat] ~= 1 then
        return 0
    end
    if ChoukaSeatAlive(seat) == 1 then
        return 0
    end
    return 1
end

-- 这个座位是不是真人（AI 座位弹不出面板、也点不了）
-- 参考《三国杀》核心规则与双兵种 BinaryLib 的写法：PLAYER_IS_HUMAN_OR_AI_PERSONALITY + "Human"
function ChoukaSeatIsHuman(seat)
    if seat == nil then
        return 0
    end
    if type(EvaluateCondition) ~= "function" then
        return 0
    end
    if EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", ChoukaSeatName(seat), "Human") then
        return 1
    end
    return 0
end

-- ============================================================
-- 守卫：每秒扫一遍，归属变了就引爆起重机（退出 = 完整死亡）
-- ============================================================

function ChoukaSeatGuard()
    ChoukaSeatGuardTicks = ChoukaSeatGuardTicks + 1

    local seat, crane, owner, selfName
    for seat = 1, 6, 1 do
        crane = ChoukaSeatCrane(seat)
        if crane ~= nil and ObjectIsAlive(crane) then
            ChoukaSeatSeen[seat] = 1
            selfName = ChoukaSeatName(seat)
            owner = ChoukaSeatOwner(seat)

            if ChoukaSeatOwnedBySelf(seat) == 1 then
                ChoukaSeatMismatch[seat] = 0
                ChoukaSeatSelfSeen[seat] = 1
            elseif ChoukaSeatSelfSeen[seat] == 1 then
                -- ★ 只有在"曾经确认过归属是本人"之后才认这个不一致：
                --   万一地图本身把某把起重机配给了别人（历史上 crane5 就配错过），
                --   那它永远进不了这一支，也就永远不会被误炸。
                ChoukaSeatMismatch[seat] = (ChoukaSeatMismatch[seat] or 0) + 1
                _LOG("座位守卫：crane" .. seat .. " 归属是 " .. (owner or "?") ..
                     "（应为 " .. selfName .. "），连续第 " ..
                     ChoukaSeatMismatch[seat] .. " 次")

                -- 连读够次数 → 判定这人不在了，直接引爆（塔/油井/单位会跟着连锁死亡）
                -- NAMED_KILL 要的是**对象**（SDK: type 14 = Object），和 NAMED_DELETE 同规矩
                if ChoukaSeatMismatch[seat] >= CHOUKA_SEAT_MISMATCH_TOLERANCE then
                    if ChoukaSeatKilled[seat] ~= 1 then
                        ChoukaSeatKilled[seat] = 1
                        _LOG("座位守卫：" .. selfName .. " 的起重机被移交给 " .. (owner or "?") ..
                             " —— 按退出处理，立刻引爆起重机（遗物不转交）")
                        if ChoukaT ~= nil and ChoukaT.seatGuardKill ~= nil then
                            ChoukaAlertFor(format(ChoukaT.seatGuardKill,
                                ChoukaPlayerDisplayName(seat)), 20)
                        end
                    end
                    if type(ExecuteAction) == "function" then
                        ExecuteAction("NAMED_KILL", crane)
                    end
                end
            end
        elseif ChoukaSeatSeen[seat] == 1 then
            -- 起重机已经不在了（被打掉 / 刚被我们引爆）：计数清零，别再反复报
            ChoukaSeatMismatch[seat] = 0
        end
    end
    return 1
end

-- ============================================================
-- 本文件只定义函数，没有节点体（不会被拼在某个节点的中段）：
-- 守卫由 01_income.lua（收入节点，每秒）调用 ChoukaSeatGuard() 驱动。
-- ============================================================
