-- ============================================================
-- 中央 center1~6 / 家里 boxN1~boxN2 各刷**什么箱子**（想加/减种类只改这两张表）
--
-- weight = 相对权重：总和不必是 100，写 0 = 这一种不刷（想加进来把 0 改成正数即可）
-- type   = 物件类型名，必须出现在 日冕地图lua例子\日冕单位信息汇总.txt 里；
--          名字写错这个箱子就刷不出来（日志里能看到实际刷的类型）
-- name   = 只用于日志显示
--
-- ⚠ 加箱子类型时注意：
--   ① "点位还有没有箱子" 的过滤器用的是两张表里所有 weight>0 的类型（ChoukaBoxCrateTypeList），
--      不在这两张表里的箱子类型会被忽略 → 同一个点位会越刷越多；
--   ② 07_crates.lua 只删"预设点位 80 世界单位以外"的引擎随机箱，所以这里刷的箱子不会被误删；
--   ③ 治疗箱（HealCrateMP）只放在中央表里，家里不刷。
-- ============================================================

-- 中央 center1~6：好箱子概率高一点（治疗箱只在中央）
CHOUKA_CENTER_CRATE_TABLE = CHOUKA_CENTER_CRATE_TABLE or {
    [1] = { type = "moneycrate",       weight = 60, name = "现金箱" },
    [2] = { type = "MoneyCrate_200",   weight = 5,  name = "大现金箱" },
    [3] = { type = "HealCrateMP",      weight = 5,  name = "治疗箱（只在中央刷）" },
    [4] = { type = "VeterancyCrateMP", weight = 5,  name = "经验箱" },
    [5] = { type = "RandomCrate",      weight = 10, name = "神秘箱" },
    [6] = { type = "UnitCrateNew",     weight = 5,  name = "部队箱" },
    [7] = { type = "AttributeCrate",   weight = 10, name = "属性箱（临时增益）" },
    [8] = { type = "BombCrate",        weight = 0,  name = "炸弹箱（陷阱，会炸伤捡箱子的兵）" },
}

-- 家里的 boxN1 / boxN2：没有治疗箱
CHOUKA_BOX_CRATE_TABLE = CHOUKA_BOX_CRATE_TABLE or {
    [1] = { type = "moneycrate",       weight = 60, name = "现金箱" },
    [2] = { type = "MoneyCrate_200",   weight = 10, name = "大现金箱" },
    [3] = { type = "VeterancyCrateMP", weight = 5,  name = "经验箱" },
    [4] = { type = "RandomCrate",      weight = 10, name = "神秘箱" },
    [5] = { type = "UnitCrateNew",     weight = 5,  name = "部队箱" },
    [6] = { type = "AttributeCrate",   weight = 10, name = "属性箱（临时增益）" },
    [7] = { type = "BombCrate",        weight = 0,  name = "炸弹箱（陷阱，会炸伤捡箱子的兵）" },
}

CHOUKA_BOX_CRATE_LOG = 1    -- 1 = 每刷一个箱子就往日志里记一行"哪个点位·哪个类型"

-- 取一张表：kind = "home"（家里，默认）/ "center"（中央）
function ChoukaBoxCrateTable(kind)
    if kind == "center" then
        return CHOUKA_CENTER_CRATE_TABLE
    end
    return CHOUKA_BOX_CRATE_TABLE
end

-- 两张表里所有"会刷出来"的类型名（点位占用过滤器要用，自动去重）
function ChoukaBoxCrateTypeList()
    local list = {}
    local seen = {}
    local tables = { CHOUKA_BOX_CRATE_TABLE, CHOUKA_CENTER_CRATE_TABLE }
    for t = 1, getn(tables), 1 do
        local tbl = tables[t]
        if tbl ~= nil then
            for i = 1, getn(tbl), 1 do
                local item = tbl[i]
                if item ~= nil and item.type ~= nil and (item.weight or 0) > 0
                    and seen[item.type] == nil then
                    seen[item.type] = 1
                    tinsert(list, item.type)
                end
            end
        end
    end
    return list
end

-- 按权重随机挑一种；kind = "home"（默认）/ "center"；表里全 0 时退回现金箱
function ChoukaPickBoxCrate(kind)
    local tbl = ChoukaBoxCrateTable(kind)
    if tbl == nil then
        return "moneycrate"
    end
    local total = 0
    for i = 1, getn(tbl), 1 do
        local item = tbl[i]
        if item ~= nil and item.type ~= nil and (item.weight or 0) > 0 then
            total = total + item.weight
        end
    end
    if total <= 0 then
        return "moneycrate"
    end
    local roll = GetRandomNumber() * total
    local acc = 0
    for i = 1, getn(tbl), 1 do
        local item = tbl[i]
        if item ~= nil and item.type ~= nil and (item.weight or 0) > 0 then
            acc = acc + item.weight
            if roll < acc then
                return item.type
            end
        end
    end
    return "moneycrate"
end

-- 类型名 → 中文名（只用于日志；两张表都查）
function ChoukaBoxCrateName(crateType)
    local tables = { CHOUKA_BOX_CRATE_TABLE, CHOUKA_CENTER_CRATE_TABLE }
    for t = 1, getn(tables), 1 do
        local tbl = tables[t]
        if tbl ~= nil then
            for i = 1, getn(tbl), 1 do
                local item = tbl[i]
                if item ~= nil and item.type == crateType then
                    return item.name or crateType
                end
            end
        end
    end
    return crateType
end
