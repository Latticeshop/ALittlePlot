-- ============================================================
-- 抽卡hex · 私有箱（每人两个点位，只做私有，不做中央）
--
-- 对应 ScriptsData.json：抽卡hex / 私有箱
--   EvaluationInterval     = 120   （每约 120 秒一轮，必须等于 BOX_SECONDS）
--   DeactivateUponSuccess  = false
--   条件                   = CONDITION_TRUE
--
-- 每个还在场上的玩家，在自己那对点位各刷一个金钱箱，归属自己队伍：
--   Player_1 → box11 / box12      Player_4 → box41 / box42
--   Player_2 → box21 / box22      Player_5 → box51 / box52
--   Player_3 → box31 / box32      Player_6 → box61 / box62
--
-- ★ 箱子不重复刷：点位半径内已经有箱子（谁的都算）就跳过，等它被开掉/打掉
--   下一轮再补。这样点位永远不会堆成"箱子山"。
--
-- 用「未具名生成」而不是具名生成：箱子没人开就会留在场上，
-- 具名生成会因重名失败，未具名生成不会。
--
-- 箱子内容：moneycrate（金钱箱）—— 配合日冕「2480 一抽随机单位」的抽卡消耗。
-- 想改成单位箱就把 CRATE_TYPE 换成 "unitcratenew"（盲盒高原用的就是这个）。
-- ============================================================

-- ⚠ Lua 4.0 桥的坑：函数体里读不到外层的 local，所以这些常量必须是全局。
BOX_SECONDS      = 120        -- 刷新间隔（秒），与 00_init.lua 对齐
CHOUKA_CRATE     = "moneycrate"
CHOUKA_BOX_RANGE = 35         -- 点位占用判定半径（世界单位）；两点相距约 70，别调太大

-- 认作"箱子"的物件类型：以本图实际刷的 CHOUKA_CRATE 为准，外加两个原版通用箱名兜底
-- （不认识的类型名塞进过滤器有风险，所以这里只放确定存在的：
--   UnitCrate / LuckyUnitCrateSeed 都是原版就有的；换箱子类型时把新类型加进来即可）
ChoukaCrateFilter = ChoukaCrateFilter or CreateObjectFilter({
    Rule = "ANY",
    IncludeThing = { CHOUKA_CRATE, "UnitCrate", "LuckyUnitCrateSeed" },
})

-- 点位是否已经被占用：1 = 有箱子，0 = 空
function ChoukaBoxBusy(waypointName)
    local p = exWaypointGetPos(waypointName)
    if p == nil then
        return 0                     -- 拿不到坐标就照刷，宁可多刷也别卡住
    end

    -- ⚠ 实测坑：exWaypointGetPos 返回的是**数组**（p[1]/p[2]/p[3]），不是 p.X/p.Y/p.Z。
    --   之前写成 p.X 拿到 nil → ObjectFindObjects 抛错 → 整个"私有箱"脚本中断，
    --   于是箱子不刷、连后面的回合数也不加。下面两种都兼容，谁在就用谁。
    local x = p[1]
    local y = p[2]
    local z = p[3]
    if x == nil then
        x = p.X
    end
    if y == nil then
        y = p.Y
    end
    if z == nil then
        z = p.Z
    end
    if x == nil or y == nil or z == nil then
        return 0
    end

    local TAR, count = ObjectFindObjects(nil, {
        X = x, Y = y, Z = z,
        Radius = CHOUKA_BOX_RANGE,
        DistType = "CENTER_2D",
    }, ChoukaCrateFilter)
    if count ~= nil and count > 0 then
        return 1
    end
    return 0
end

for i = 1, 6, 1 do
    local playerName = "Player_" .. i
    -- 起重机还在 = 这个座位还在场上（起重机被摧毁时该玩家直接判负）
    local crane = GetObjectByScriptName("crane" .. i)
    if ObjectIsAlive(crane) then
        local team = playerName .. "/team" .. playerName
        local wp1 = "box" .. i .. "1"
        local wp2 = "box" .. i .. "2"
        if ChoukaBoxBusy(wp1) == 0 then
            ExecuteAction("CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT", CHOUKA_CRATE, team, wp1)
        end
        if ChoukaBoxBusy(wp2) == 0 then
            ExecuteAction("CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT", CHOUKA_CRATE, team, wp2)
        end
    end
end

-- 倒计时重置（与 00_init.lua 里显示的 box 计时器同一个）
ExecuteAction("SET_MILLISECOND_TIMER", "box", BOX_SECONDS)

-- HUD 左下角的倒计时用我们自己的秒计数（HUD 节点每秒减 1），不读引擎计时器
CHOUKA_BOX_LEFT = BOX_SECONDS

-- ★ 回合数：作者口径 = 「刷一轮箱子算一个回合」，所以在这里自增。
--   HUD 脚本（左下角倒计时 + 回合数）只读这个全局，不自己算。
CHOUKA_ROUND = (CHOUKA_ROUND or 0) + 1

-- 到点自动升级抽卡等级（第 5/10/15/20 回合 → Lv.2/3/4/5，见 09_level.lua）
if ChoukaAutoLevelTick ~= nil then
    ChoukaAutoLevelTick(CHOUKA_ROUND)
end
