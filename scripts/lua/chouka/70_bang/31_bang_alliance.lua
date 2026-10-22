-- ============================================================
-- 三国杀 · 结盟子系统（严格身份阵营）  详见 docs/11-三国杀模式方案.md §7
-- 底层只有一句 ExecuteAction("PLAYER_RELATES_PLAYER", 我, 他, 关系)：
--   单向 = 1 次；双向 = 正反各 1 次（照赤壁 AllegianceModule，源码见 Bang_30_code）
-- ============================================================

ChoukaMarkNodeReady("三国杀-结盟")

CHOUKA_BANG_REL_FRIEND  = "Friend"
CHOUKA_BANG_REL_ENEMY   = "Enemy"
CHOUKA_BANG_REL_NEUTRAL = "Neutral"

ChoukaBangRelationsApplied = ChoukaBangRelationsApplied or 0

-- 单向：只改 from 对 to 的态度（to 对 from 不变）
function ChoukaBangRelateOne(fromName, toName, rel)
    if fromName == nil or toName == nil or rel == nil then
        return 0
    end
    if fromName == toName then
        return 0
    end
    if type(ExecuteAction) ~= "function" then
        return 0
    end
    ExecuteAction("PLAYER_RELATES_PLAYER", fromName, toName, rel)
    return 1
end

-- 双向：正反各设一次
function ChoukaBangRelateBoth(nameA, nameB, rel)
    if nameA == nil or nameB == nil or rel == nil then
        return 0
    end
    if nameA == nameB then
        return 0
    end
    ChoukaBangRelateOne(nameA, nameB, rel)
    ChoukaBangRelateOne(nameB, nameA, rel)
    return 1
end

-- 读关系：0 = 敌人 / 1 = 中立 / 2 = 友军（读不到返回 nil）
function ChoukaBangGetRel(nameA, nameB)
    if type(exPlayerGetRelationShip) ~= "function" then
        return nil
    end
    return exPlayerGetRelationShip(nameA, nameB)
end

function ChoukaBangIsLordSide(role)
    if role == nil then
        return 0
    end
    if role == ChoukaT.bangRoleLord or role == ChoukaT.bangRoleLoyalist then
        return 1
    end
    return 0
end

-- ============================================================
-- 初始关系（严格阵营）
--   分四遍写、后一遍覆盖前一遍，这样和遍历顺序无关：
--     ① 全员互为敌人  ② 主忠之间双向友军
--     ③ 内奸 → 主公 单向友军（唯一的不对称）  ④ 主公 ↔ PlyrCreeps 双向友军
-- ============================================================

function ChoukaBangApplyInitialRelations()
    if ChoukaBangSeats == nil or ChoukaBangRole == nil then
        return 0
    end
    local total = getn(ChoukaBangSeats)
    if total < 2 then
        return 0
    end

    local i, k, seatA, seatB, nameA, nameB, roleA, roleB

    -- ① 默认全员敌对（反贼之间也是敌人：身份是暗的，得靠"认亲"才成为盟友）
    for i = 1, total, 1 do
        seatA = ChoukaBangSeats[i]
        nameA = "Player_" .. seatA
        for k = i + 1, total, 1 do
            seatB = ChoukaBangSeats[k]
            nameB = "Player_" .. seatB
            ChoukaBangRelateBoth(nameA, nameB, CHOUKA_BANG_REL_ENEMY)
        end
    end

    -- ② 主公与忠臣之间天然友军
    for i = 1, total, 1 do
        seatA = ChoukaBangSeats[i]
        roleA = ChoukaBangRole[seatA]
        if ChoukaBangIsLordSide(roleA) == 1 then
            nameA = "Player_" .. seatA
            for k = i + 1, total, 1 do
                seatB = ChoukaBangSeats[k]
                roleB = ChoukaBangRole[seatB]
                if ChoukaBangIsLordSide(roleB) == 1 then
                    nameB = "Player_" .. seatB
                    ChoukaBangRelateBoth(nameA, nameB, CHOUKA_BANG_REL_FRIEND)
                end
            end
        end
    end

    -- ③ 内奸 → 主公 单向友军：内奸打不了主公，主公能打内奸
    if ChoukaBangLordIndex ~= nil then
        nameA = "Player_" .. ChoukaBangLordIndex
        for i = 1, total, 1 do
            seatB = ChoukaBangSeats[i]
            if ChoukaBangRole[seatB] == ChoukaT.bangRoleTraitor then
                nameB = "Player_" .. seatB
                ChoukaBangRelateOne(nameB, nameA, CHOUKA_BANG_REL_FRIEND)
            end
        end
    end

    -- ④ 主公 ↔ 中立怪 PlyrCreeps 双向友军（照赤壁 Bang_160_code:797-801）
    if ChoukaBangLordIndex ~= nil then
        nameA = "Player_" .. ChoukaBangLordIndex
        ChoukaBangRelateBoth(nameA, "PlyrCreeps", CHOUKA_BANG_REL_FRIEND)
    end

    _LOG("三国杀：初始关系已设（" .. total .. " 人，主公=Player_" ..
         (ChoukaBangLordIndex or 0) .. "）")
    return 1
end

-- ============================================================
-- 每次求值：只负责在关系模块加载晚于身份分配时补设一次
-- ============================================================

if CHOUKA_MODE ~= 1 then
    return
end

if ChoukaBangRolesReady == 1 and ChoukaBangRelationsApplied ~= 1 then
    if ChoukaBangApplyInitialRelations() == 1 then
        ChoukaBangRelationsApplied = 1
    end
end
