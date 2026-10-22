-- ============================================================
-- 详见 docs/10-Lua注释存档.md §07_crates-1
-- ============================================================

-- ---------------- 常量（Lua 4.0 桥：函数体读不到外层 local，必须全局） ----------------

ChoukaMarkNodeReady("随机箱清理")

CHOUKA_CRATE_FIRST_TICK  = 1     -- 第几帧删"生成器"
CHOUKA_CRATE_SECOND_TICK = 45    -- 第几帧扫"已经刷出来的实体箱子"（照 DSA）
CHOUKA_CRATE_SWEEP_EVERY = 600   -- 兜底扫描间隔（帧）；interval=0 即每帧一次求值
CHOUKA_CRATE_SWEEP_UNTIL = 7200  -- 兜底扫描只跑到第几帧（≈2 分钟），之后不再扫
CHOUKA_CRATE_KEEP_RANGE  = 80    -- 离预设点位多近算"自家箱子"（世界单位）；同一批点位彼此远大于这个值

-- 引擎自然刷新的随机箱类型（生成器单独一份，见下）
CHOUKA_CRATE_NATURAL = {
    [1] = "UnitCrateNew",
    [2] = "UnitCrate",
    [3] = "ShroudCrate",
    [4] = "MoneyCrateMP",
    [5] = "MoneyCrate",
}

-- 生成器（刷箱子的东西，不是箱子）：永远删，不看保留点位 ——
-- 留着它就会一直往图上刷箱子，哪怕它正好落在某个点位旁边。
CHOUKA_CRATE_SPAWNER = "GenericCrateSpawner"

-- 本图自己的箱子只会出现在这些点位上
-- （02_private_box.lua 的两组家庭箱点 + 06_center.lua 的中央七点 `center`+`center1~6`）
-- （box1~box6 是老写法，留着兜底；实际航点是 box11~box62）
-- ⚠ `center` 必须在这张表里：否则我们自己刷在中心点的盲盒会被下面的清理逻辑当成自然随机箱删掉
CHOUKA_CRATE_KEEP_WPS = {
    [1]  = "box1",   [2]  = "box2",   [3]  = "box3",
    [4]  = "box4",   [5]  = "box5",   [6]  = "box6",
    [7]  = "box11",  [8]  = "box12",
    [9]  = "box21",  [10] = "box22",
    [11] = "box31",  [12] = "box32",
    [13] = "box41",  [14] = "box42",
    [15] = "box51",  [16] = "box52",
    [17] = "box61",  [18] = "box62",
    [19] = "center", [20] = "center1", [21] = "center2", [22] = "center3",
    [23] = "center4", [24] = "center5", [25] = "center6",
}

ChoukaCrateTick       = ChoukaCrateTick or 0
ChoukaCrateSweptTotal = ChoukaCrateSweptTotal or 0
CHOUKA_LOBBY_CRATE_ON = CHOUKA_LOBBY_CRATE_ON or 0   -- 1 = 大厅勾了「开启随机箱子」

-- ============================================================
-- 1. 小工具
-- ============================================================

-- 自然箱子过滤器（建一次就缓存；类型表改了要重新进游戏才生效）
function ChoukaCrateFilterNatural()
    if ChoukaCrateNaturalFilter == nil then
        ChoukaCrateNaturalFilter = CreateObjectFilter({
            Rule = "ANY",
            IncludeThing = CHOUKA_CRATE_NATURAL,
        })
    end
    return ChoukaCrateNaturalFilter
end

-- 只认生成器的过滤器（第 1 帧 + 每次兜底都用它）
function ChoukaCrateFilterSpawner()
    if ChoukaCrateSpawnerFilter == nil then
        ChoukaCrateSpawnerFilter = CreateObjectFilter({
            Rule = "ANY",
            IncludeThing = { CHOUKA_CRATE_SPAWNER },
        })
    end
    return ChoukaCrateSpawnerFilter
end

-- 这个坐标离某个预设刷箱点位近不近（近 = 自家箱子，不删）
-- ⚠ exWaypointGetPos 返回**数组**（p[1]/p[2]/p[3]），不是 p.X
function ChoukaCrateNearKeepPoint(x, y)
    if x == nil or y == nil then
        return 0
    end
    local limit = CHOUKA_CRATE_KEEP_RANGE * CHOUKA_CRATE_KEEP_RANGE
    for i = 1, getn(CHOUKA_CRATE_KEEP_WPS), 1 do
        local p = exWaypointGetPos(CHOUKA_CRATE_KEEP_WPS[i])
        if p ~= nil and p[1] ~= nil and p[2] ~= nil then
            local dx = x - p[1]
            local dy = y - p[2]
            if (dx * dx + dy * dy) <= limit then
                return 1
            end
        end
    end
    return 0
end

-- ============================================================
-- 2. 清扫
-- ============================================================

-- ① 删生成器（DSA 第 1 帧那一段）。返回删掉的个数。
function ChoukaCrateKillSpawners()
    local filter = ChoukaCrateFilterSpawner()
    local units, count = ObjectFindObjects(nil, nil, filter)
    if count == nil or count <= 0 then
        return 0
    end
    for i = 1, count, 1 do
        if units[i] ~= nil then
            ExecuteAction("NAMED_DELETE", units[i])
        end
    end
    return count
end

-- ② 扫实体箱子（DSA 第 45 帧那一段 + 保留点位判断）。返回删掉的个数。
--    每次都先把生成器再清一遍：引擎有时会更晚才把生成器补上。
function ChoukaCrateSweep()
    local removed = ChoukaCrateKillSpawners()
    local filter = ChoukaCrateFilterNatural()
    local units, count = ObjectFindObjects(nil, nil, filter)
    if count == nil or count <= 0 then
        return removed
    end
    for i = 1, count, 1 do
        local obj = units[i]
        if obj ~= nil then
            local x, y, z = ObjectGetPosition(obj)
            if ChoukaCrateNearKeepPoint(x, y) == 0 then
                ExecuteAction("NAMED_DELETE", obj)
                removed = removed + 1
            end
        end
    end
    return removed
end

-- ============================================================
-- 3. 每次求值（每帧）：靠自己的帧计数决定活干不干
-- ============================================================

ChoukaCrateTick = ChoukaCrateTick + 1

if ChoukaCrateTick == CHOUKA_CRATE_FIRST_TICK then
    -- 第 1 帧：删生成器；顺便记下"大厅开没开随机箱子"（以后要联动别的系统可以用）
    local killed = ChoukaCrateKillSpawners()
    if killed > 0 then
        CHOUKA_LOBBY_CRATE_ON = 1
        ChoukaCrateSweptTotal = ChoukaCrateSweptTotal + killed
    end
elseif ChoukaCrateTick == CHOUKA_CRATE_SECOND_TICK then
    -- 第 45 帧：把开局已经落地的实体箱子也清掉（自家点位上的一律放过）
    local removed = ChoukaCrateSweep()
    ChoukaCrateSweptTotal = ChoukaCrateSweptTotal + removed
    if removed > 0 then
        ChoukaAlert(format(ChoukaT.crateCleaned, removed))
    end
elseif ChoukaCrateTick > CHOUKA_CRATE_SECOND_TICK
    and ChoukaCrateTick <= CHOUKA_CRATE_SWEEP_UNTIL
    and mod(ChoukaCrateTick, CHOUKA_CRATE_SWEEP_EVERY) == 0 then
    -- 兜底：个别箱子可能比开局动画还晚落地，前 2 分钟每 10 秒补扫一次
    ChoukaCrateSweptTotal = ChoukaCrateSweptTotal + ChoukaCrateSweep()
end