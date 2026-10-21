-- ============================================================
-- 详见 docs/10-Lua注释存档.md §02_private_box-1
-- ============================================================

-- ⚠ Lua 4.0 桥的坑：函数体里读不到外层的 local，所以这些常量必须是全局。
ChoukaMarkNodeReady("私有箱")

BOX_SECONDS        = 120
CHOUKA_BOX_SECONDS = CHOUKA_BOX_SECONDS or BOX_SECONDS   -- 与 03_start.lua 共用同一个数
CHOUKA_CRATE       = "moneycrate"
CHOUKA_BOX_RANGE   = 35       -- 点位占用判定半径（世界单位）；两点相距约 70，别调太大

-- 认作"箱子"的物件类型：以本图实际刷的 CHOUKA_CRATE 为准，外加两个原版通用箱名兜底
-- （不认识的类型名塞进过滤器有风险，所以这里只放确定存在的：
--   UnitCrate / LuckyUnitCrateSeed 都是原版就有的；换箱子类型时把新类型加进来即可）
ChoukaCrateFilter = ChoukaCrateFilter or CreateObjectFilter({
    Rule = "ANY",
    IncludeThing = { CHOUKA_CRATE, "UnitCrate", "LuckyUnitCrateSeed" },
})

-- 点位是否已经被占用：1 = 有箱子，0 = 空
-- radius 由调用方给（家里两点相距约 70，用 CHOUKA_BOX_RANGE=35；
-- 中央 center1~6 是半径 70 的正六边形，相邻两点只差 ~70/√3≈60，所以中央用小一点的半径）
function ChoukaBoxBusyRange(waypointName, radius)
    if radius == nil then
        radius = CHOUKA_BOX_RANGE
    end
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
    if x == nil or y == nil then
        return 0
    end
    if z == nil then
        z = 0
    end

    local TAR, count = ObjectFindObjects(nil, {
        X = x, Y = y, Z = z,
        Radius = radius,
        DistType = "CENTER_2D",
    }, ChoukaCrateFilter)
    if count ~= nil and count > 0 then
        return 1
    end
    return 0
end

function ChoukaBoxBusy(waypointName)
    return ChoukaBoxBusyRange(waypointName, CHOUKA_BOX_RANGE)
end

-- ============================================================
-- ① 开局门控：房主还没点确认 → 倒计时冻在整轮，回合数不推进，也不刷箱子
-- ============================================================
if CHOUKA_GAME_STARTED ~= 1 then
    CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
    return
end

-- ============================================================
-- ② 每秒推进盲盒刷新倒计时（HUD 只负责画这个数）
-- ============================================================
if CHOUKA_BOX_LEFT == nil then
    CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
end
if CHOUKA_BOX_LEFT > 0 then
    CHOUKA_BOX_LEFT = CHOUKA_BOX_LEFT - 1
end
if CHOUKA_BOX_LEFT > 0 then
    return                            -- 还没到点，这一秒什么都不用做
end

-- ============================================================
-- ③ 倒计时到底 → 开新回合：重置倒计时 + 回合数 +1 + 刷箱子
-- ============================================================
CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
CHOUKA_ROUND = (CHOUKA_ROUND or 0) + 1

-- 引擎计时器只用来给别的脚本/控制台看，界面上的倒计时是我们自己数的
ExecuteAction("SET_MILLISECOND_TIMER", "box", CHOUKA_BOX_SECONDS)

-- 到点自动升级抽卡等级（第 5/10/15/20 回合 → Lv.2/3/4/5，见 09_level.lua）
if ChoukaAutoLevelTick ~= nil then
    ChoukaAutoLevelTick(CHOUKA_ROUND)
end

for i = 1, 6, 1 do
    local playerName = "Player_" .. i
    -- 起重机还在 = 这个座位还在场上（起重机被摧毁时该玩家直接判负）
    local crane = GetObjectByScriptName("crane" .. i)
    if ObjectIsAlive(crane) then
        local team = playerName .. "/team" .. playerName
        local wp1 = "box" .. i .. "1"
        local wp2 = "box" .. i .. "2"
        -- 航点先确认存在，再去扫占用（航点不存在时扫占用会拿 nil 去索引）
        if exWaypointGetPos(wp1) ~= nil and ChoukaBoxBusy(wp1) == 0 then
            ExecuteAction("CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT", CHOUKA_CRATE, team, wp1)
        end
        if exWaypointGetPos(wp2) ~= nil and ChoukaBoxBusy(wp2) == 0 then
            ExecuteAction("CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT", CHOUKA_CRATE, team, wp2)
        end
    end
end

_ALERT(format("第 %d 回合开始：私人箱子已刷新", CHOUKA_ROUND))