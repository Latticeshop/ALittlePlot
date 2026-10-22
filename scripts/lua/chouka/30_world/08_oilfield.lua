-- ============================================================
-- 油井重建：把"被清场带走的油井"原地变回中立无敌井，谁抢到谁收钱
-- 详见 docs/12-中立油井重建.md
--
-- ① 中央 centerOil1/2
--   被某位玩家占领后（NAMED_TRANSFER_OWNERSHIP_PLAYER 把归属转给了他），
--   该玩家一旦被清场，这口井会作为"他的东西"一起被系统杀掉 → 中央油井永久消失。
--   现在：定期扫描，井没了就在原坐标重生一口「中立 + 无敌」的，玩家可以重新抢。
--
-- ② 玩家 oil1~oil6
--   玩家被清场时，系统会把他名下所有东西一起杀，包括这口（地编里标了不可摧毁的）油井。
--   现在：原地重生一口中立无敌井 + 同样的占点功能，谁占领谁拿"战利品"收入。
--   ⚠ 不满 6 人的局，空位**本来就没有**起重机也没有油井，所以永不为它重建（开局登记时就排除）。
--
-- ③ 兜底：万一"无敌"真的挡住了清场（井还留着但主人已经没了），
--   直接把那口井转成"中立据点"参与占点，不依赖系统清场一定成功。
-- ============================================================

ChoukaMarkNodeReady("油井重建")

-- ---------------- 参数（想调手感就改这几行） ----------------

-- 井的模型：**必须按原位的地形选**，地编里两处用的不是同一个东西
--   玩家岛上 oil1~6  = OilDerrick_OnWater（水上版）
--   中央 centerOil1/2 = OilDerrick（陆地版，中心那是块陆地小岛）
-- 生成时先用"该点位该用的版本"，失败再退到另一个版本，避免某一版引擎不认某个模板名。
CHOUKA_OIL_TYPE_SEAT     = "OilDerrick_OnWater"   -- 玩家岛（水上）
CHOUKA_OIL_TYPE_CENTER   = "OilDerrick"           -- 中央岛（陆地）
CHOUKA_OIL_TYPE_ALTERNATES = {
    "OilDerrick_OnWater",
    "OilDerrick",
}

CHOUKA_OIL_SCAN_EVERY    = 5       -- 每几秒做一次「重建 + 占点」扫描
CHOUKA_OIL_CAPTURE_AT    = 3       -- 同一人连续领先几次算占领（3 × 5 秒 ≈ 15 秒，与中央油井一致）
CHOUKA_OIL_REBUILD_WAIT  = 1       -- 连续几次扫描都找不到才重建（=1 表示下一次扫描就重建，约 5 秒）
CHOUKA_OIL_SPOILS_INCOME = 40      -- 抢到"阵亡玩家留下的油井"后 $/秒（中央油井同档；想调就改这里）
CHOUKA_OIL_INVULN_TICKS  = 999999  -- 无敌时长。每次扫描都会重刷一次，等效永久

-- 中立归属队名：按顺序试，第一个真能生成出对象的就记住它
--   原图中央油井挂的是"无主玩家"（playerName 为空）→ 队名字符串就是 "/team"；
--   万一这一版引擎不允许空名生成，自动退到 PlyrCivilian / PlyrNeutral。
CHOUKA_OIL_TEAMS = {
    "/team",
    "PlyrCivilian/teamPlyrCivilian",
    "PlyrNeutral/teamPlyrNeutral",
}

-- ---------------- 状态（全局：Lua 桥的闭包拿不到外层 local） ----------------

ChoukaOilArmed       = ChoukaOilArmed or {}       -- seat -> 1：这个座位本局真的有 craneN + oilN
ChoukaOilPos         = ChoukaOilPos or {}         -- seat -> {x=,y=,z=} 记住原坐标
ChoukaOilObj         = ChoukaOilObj or {}         -- seat -> 当前那口井的对象句柄
ChoukaOilRebuilt     = ChoukaOilRebuilt or {}     -- seat -> 1：这口井已经变成"中立据点"，参与占点
ChoukaOilOwner       = ChoukaOilOwner or {}       -- seat -> 占领者（0 = 中立没人占）
ChoukaOilScore       = ChoukaOilScore or {}       -- seat -> 占点进度
ChoukaOilChall       = ChoukaOilChall or {}       -- seat -> 正在挑战的玩家
ChoukaOilGone        = ChoukaOilGone or {}        -- seat -> 连续几次扫描找不到它
ChoukaOilCraneSeen   = ChoukaOilCraneSeen or {}   -- seat -> 1：至少见过一次这台起重机活着（判死的前提）
ChoukaCenterWellPos  = ChoukaCenterWellPos or {}  -- k(1/2) -> {x=,y=,z=}
ChoukaCenterWellGone = ChoukaCenterWellGone or {} -- k -> 连续几次扫描找不到它
ChoukaOilArmedOnce   = ChoukaOilArmedOnce or 0
ChoukaOilTick        = ChoukaOilTick or 0
ChoukaOilTeamGood    = ChoukaOilTeamGood or 0     -- 已经验证可用的中立队名下标（0 = 还没试出来）

-- 06_center.lua 里定义的那几张表，本节点也要读写（重建出来的中央油井得交回给它去占点）。
-- 两个节点都是"各自加载、谁先跑不一定"，所以这边也来一遍 or {} —— 谁先跑谁建，不会互相覆盖。
ChoukaCenterOilObj   = ChoukaCenterOilObj or {}
ChoukaCenterOilOwner = ChoukaCenterOilOwner or { [1] = 0, [2] = 0 }
ChoukaCenterOilScore = ChoukaCenterOilScore or { [1] = 0, [2] = 0 }
ChoukaCenterOilChall = ChoukaCenterOilChall or { [1] = 0, [2] = 0 }

-- ============================================================
-- 1. 小工具
-- ============================================================

-- 取对象坐标；拿不到返回 nil（返回 table，方便到处传）
function ChoukaOilPosOf(obj)
    if obj == nil then
        return nil
    end
    if not ObjectIsAlive(obj) then
        return nil
    end
    local x, y, z = ObjectGetPosition(obj)
    if x == nil then
        return nil
    end
    return { x = x, y = y, z = z }
end

-- 给井挂"无敌"。注意：系统清场是**强制移除**、不是打伤害，
-- 所以无敌不会阻止"玩家阵亡 → 他的油井一起消失"这件事（作者实测中央油井就是如此）。
-- 万一这版引擎的无敌真的挡住了清场，§3 的兜底会把井转成中立据点，功能不受影响。
function ChoukaOilMakeInvincible(obj)
    if obj == nil or not ObjectIsAlive(obj) then
        return 0
    end
    if type(ObjectLoadAttributeModifier) == "function" then
        ObjectLoadAttributeModifier(obj, "AttributeModifier_INVULNERABLE", CHOUKA_OIL_INVULN_TICKS)
        return 1
    end
    return 0
end

-- 该点位要试的类型顺序：want 优先，另一个兜底
function ChoukaOilTypeOrder(wantType)
    local list = {}
    local i
    if wantType ~= nil then
        tinsert(list, wantType)
    end
    for i = 1, getn(CHOUKA_OIL_TYPE_ALTERNATES), 1 do
        if CHOUKA_OIL_TYPE_ALTERNATES[i] ~= wantType then
            tinsert(list, CHOUKA_OIL_TYPE_ALTERNATES[i])
        end
    end
    return list
end

-- 在指定坐标生成一口中立油井；成功返回对象句柄，失败返回 nil
--   wantType：该点位原本用的模型（玩家岛 = 水上版，中央岛 = 陆地版）
function ChoukaOilSpawnNeutral(name, pos, wantType)
    if pos == nil or name == nil then
        return nil
    end
    if type(ExecuteAction) ~= "function" or type(GetObjectByScriptName) ~= "function" then
        return nil
    end

    local tries = getn(CHOUKA_OIL_TEAMS)
    local startIndex = ChoukaOilTeamGood
    if startIndex == nil or startIndex < 1 or startIndex > tries then
        startIndex = 1
    end

    local types = ChoukaOilTypeOrder(wantType)
    local ti, i, idx, team, obj, typeName
    for ti = 1, getn(types), 1 do
        typeName = types[ti]
        for i = 0, tries - 1, 1 do
            idx = mod(startIndex - 1 + i, tries) + 1
            team = CHOUKA_OIL_TEAMS[idx]
            ExecuteAction("UNIT_SPAWN_NAMED_LOCATION_ORIENTATION",
                name, typeName, team,
                { X = pos.x, Y = pos.y, Z = pos.z }, 0)
            obj = GetObjectByScriptName(name)
            if obj ~= nil and ObjectIsAlive(obj) then
                ChoukaOilTeamGood = idx
                ChoukaOilMakeInvincible(obj)
                _LOG("油井重建：" .. name .. " 生成成功（模型 " .. typeName .. " / 队名 " .. team .. "）")
                return obj
            end
        end
    end

    _LOG("油井重建：" .. name .. " 生成失败 —— 模型 " .. (wantType or "?") ..
         " 和兜底模型、三种中立队名都试过了")
    return nil
end

-- 某位玩家的起重机还活着吗
function ChoukaOilCraneAlive(seat)
    local crane = GetObjectByScriptName("crane" .. seat)
    if crane == nil then
        return 0
    end
    if ObjectIsAlive(crane) then
        return 1
    end
    return 0
end

-- 扫描开始时刷新"这台起重机我确认见过活着"的标记
function ChoukaOilRefreshCranes()
    local i
    for i = 1, 6, 1 do
        if ChoukaOilCraneAlive(i) == 1 then
            ChoukaOilCraneSeen[i] = 1
        end
    end
end

-- "确认已阵亡"：必须**先见过它活着**、再见到它没了，才算数。
-- 这样 GetObjectByScriptName 偶发取不到时不会把活人误判成死人（那会把整局油井搞乱）。
function ChoukaOilSeatKnownDead(seat)
    if ChoukaOilCraneSeen[seat] ~= 1 then
        return 0
    end
    if ChoukaOilCraneAlive(seat) == 1 then
        return 0
    end
    return 1
end

-- ============================================================
-- 2. 开局登记：哪些座位这局真的有起重机 + 油井，并记住油井原坐标
--    ⚠ 这一步是"空位不重建"的唯一依据：
--      不满 6 人的局，空位既没有 craneN 也没有 oilN，这里直接判为"无"
-- ============================================================

function ChoukaOilArmOnce()
    if ChoukaOilArmedOnce == 1 then
        return 0
    end
    if type(GetObjectByScriptName) ~= "function" then
        return 0
    end
    ChoukaOilArmedOnce = 1

    local i, oil, pos
    local armedSeats = 0

    for i = 1, 6, 1 do
        -- ★ 必须"起重机 + 油井"都在才算这个座位参战
        pos = nil
        if ChoukaOilPosOf(GetObjectByScriptName("crane" .. i)) ~= nil then
            ChoukaOilCraneSeen[i] = 1
            oil = GetObjectByScriptName("oil" .. i)
            pos = ChoukaOilPosOf(oil)
        end

        if pos ~= nil then
            ChoukaOilArmed[i] = 1
            ChoukaOilPos[i] = pos
            ChoukaOilObj[i] = oil
            ChoukaOilRebuilt[i] = nil      -- 原装井还没转成中立据点
            ChoukaOilOwner[i] = 0
            ChoukaOilScore[i] = 0
            ChoukaOilChall[i] = 0
            ChoukaOilGone[i] = 0
            armedSeats = armedSeats + 1
        else
            ChoukaOilArmed[i] = nil        -- 空位：没有油井 → 永远不为它重建
        end
    end

    for i = 1, 2, 1 do
        pos = ChoukaOilPosOf(GetObjectByScriptName("centerOil" .. i))
        if pos ~= nil then
            ChoukaCenterWellPos[i] = pos
        end
    end

    _LOG("油井重建：本局真的有油井的座位 " .. armedSeats .. " 个")
    return 1
end

-- ============================================================
-- 3. 中央油井：消失 → 原地重生中立无敌井
-- ============================================================

function ChoukaOilReleaseCenterOwner(k, owner)
    ChoukaCenterOilOwner[k] = 0
    ChoukaCenterOilScore[k] = 0
    ChoukaCenterOilChall[k] = 0
    _LOG("中央油井" .. k .. "：拥有者 Player_" .. owner .. " 已阵亡，归属释放回中立")
end

function ChoukaOilRebuildCenter()
    local k, name, live, pos, obj, owner
    for k = 1, 2, 1 do
        name = "centerOil" .. k
        live = GetObjectByScriptName(name)

        if live ~= nil and ObjectIsAlive(live) then
            -- 还在：记坐标、续无敌、让 06_center 正常接管占点
            pos = ChoukaOilPosOf(live)
            if pos ~= nil and ChoukaCenterWellPos[k] == nil then
                ChoukaCenterWellPos[k] = pos
            end
            ChoukaCenterWellGone[k] = 0
            ChoukaOilMakeInvincible(live)
            if ChoukaCenterOilObj[k] == nil or not ObjectIsAlive(ChoukaCenterOilObj[k]) then
                ChoukaCenterOilObj[k] = live
            end

            -- 兜底：拥有者已确认阵亡但井还留着 → 释放回中立，
            -- 免得 01_income 一直给一个出局的人发中央油井收入
            owner = ChoukaCenterOilOwner[k]
            if owner ~= nil and owner > 0 and ChoukaOilSeatKnownDead(owner) == 1 then
                ChoukaOilReleaseCenterOwner(k, owner)
            end
        else
            -- 没了：等够扫描次数就原地重建
            ChoukaCenterWellGone[k] = (ChoukaCenterWellGone[k] or 0) + 1
            if ChoukaCenterWellPos[k] ~= nil
                and ChoukaCenterWellGone[k] > CHOUKA_OIL_REBUILD_WAIT then
                obj = ChoukaOilSpawnNeutral(name, ChoukaCenterWellPos[k], CHOUKA_OIL_TYPE_CENTER)
                if obj ~= nil then
                    ChoukaCenterWellGone[k] = 0
                    ChoukaCenterOilObj[k] = obj
                    ChoukaCenterOilOwner[k] = 0
                    ChoukaCenterOilScore[k] = 0
                    ChoukaCenterOilChall[k] = 0
                    _LOG("油井重建：中央油井" .. k .. " 已原地重建为中立无敌油井（默认规则，不播报）")
                end
            end
        end
    end
end

-- ============================================================
-- 4. 玩家油井：消失 → 原地重生中立无敌井；井还在但岛主没了 → 直接转成中立据点
-- ============================================================

function ChoukaOilTickCapture(seat, obj, leadIndex)
    if ChoukaOilOwner[seat] == nil then
        ChoukaOilOwner[seat] = 0
    end
    if ChoukaOilScore[seat] == nil then
        ChoukaOilScore[seat] = 0
    end
    if ChoukaOilChall[seat] == nil then
        ChoukaOilChall[seat] = 0
    end

    local owner = ChoukaOilOwner[seat]

    if leadIndex == 0 or leadIndex == owner then
        -- 没人压制 / 占领者自己在守 → 进度回落
        if ChoukaOilScore[seat] > 0 then
            ChoukaOilScore[seat] = ChoukaOilScore[seat] - 1
        end
        if ChoukaOilScore[seat] <= 0 then
            ChoukaOilChall[seat] = 0
        end
        return
    end

    if ChoukaOilChall[seat] ~= leadIndex then
        ChoukaOilChall[seat] = leadIndex
        ChoukaOilScore[seat] = 1
    else
        ChoukaOilScore[seat] = ChoukaOilScore[seat] + 1
    end

    if ChoukaOilScore[seat] >= CHOUKA_OIL_CAPTURE_AT then
        ChoukaOilOwner[seat] = leadIndex
        ChoukaOilScore[seat] = 0
        ChoukaOilChall[seat] = 0
        if obj ~= nil and ObjectIsAlive(obj) then
            ExecuteAction("NAMED_TRANSFER_OWNERSHIP_PLAYER", obj, "Player_" .. leadIndex)
        end
        _LOG("油井重建：Player_" .. leadIndex .. " 占领了 Player_" .. seat .. " 留下的油井（默认规则，不播报）")
    end
end

-- 把一口井变成"中立据点"（参与占点 + 发战利品收入）
function ChoukaOilMarkSpoiled(seat)
    ChoukaOilRebuilt[seat] = 1
    ChoukaOilOwner[seat] = 0
    ChoukaOilScore[seat] = 0
    ChoukaOilChall[seat] = 0
end

function ChoukaOilScanSeats()
    local seat, name, obj, live, pos, leadIndex, newObj, owner

    for seat = 1, 6, 1 do
        if ChoukaOilArmed[seat] == 1 then
            name = "oil" .. seat

            -- ① 先看手里登记的句柄还活着没
            obj = ChoukaOilObj[seat]
            if obj ~= nil and not ObjectIsAlive(obj) then
                ChoukaOilObj[seat] = nil
                obj = nil
            end

            -- ② 句柄空了就按真名再找一次（原装的、或我们重建的都叫这个名字）
            if obj == nil then
                live = GetObjectByScriptName(name)
                if live ~= nil and ObjectIsAlive(live) then
                    obj = live
                    ChoukaOilObj[seat] = live
                    if ChoukaOilPos[seat] == nil then
                        ChoukaOilPos[seat] = ChoukaOilPosOf(live)
                    end
                end
            end

            if obj == nil then
                -- ③ 真没了（岛主被清场 / 井被打掉）：等够扫描次数原地重建
                ChoukaOilGone[seat] = (ChoukaOilGone[seat] or 0) + 1
                if ChoukaOilPos[seat] ~= nil and ChoukaOilGone[seat] > CHOUKA_OIL_REBUILD_WAIT then
                    newObj = ChoukaOilSpawnNeutral(name, ChoukaOilPos[seat], CHOUKA_OIL_TYPE_SEAT)
                    if newObj ~= nil then
                        ChoukaOilGone[seat] = 0
                        ChoukaOilObj[seat] = newObj
                        ChoukaOilMarkSpoiled(seat)
                        _LOG("油井重建：Player_" .. seat .. " 的油井已转为中立据点（默认规则，不播报）")
                    end
                end
            else
                -- ④ 还在
                ChoukaOilGone[seat] = 0
                ChoukaOilMakeInvincible(obj)

                -- 原装井 + 岛主已确认阵亡 → 直接转成中立据点（不依赖系统清场一定成功）
                if ChoukaOilRebuilt[seat] ~= 1 and ChoukaOilSeatKnownDead(seat) == 1 then
                    ChoukaOilMarkSpoiled(seat)
                    _LOG("油井重建：Player_" .. seat .. " 的油井已转为中立据点（默认规则，不播报）")
                end

                -- 兜底：占领者已确认阵亡但井还留着 → 释放回中立，别给死人发钱
                owner = ChoukaOilOwner[seat]
                if owner ~= nil and owner > 0 and ChoukaOilSeatKnownDead(owner) == 1 then
                    ChoukaOilMarkSpoiled(seat)
                    _LOG("原 Player_" .. seat .. " 的油井：占领者 Player_" .. owner ..
                         " 已阵亡，归属释放回中立")
                end

                -- 只有"中立据点"才走占点（原装井是岛主自己的，收入由 01_income 的私油井规则给）
                if ChoukaOilRebuilt[seat] == 1 and type(ChoukaCenterLeader) == "function" then
                    pos = ChoukaOilPosOf(obj)
                    if pos ~= nil then
                        leadIndex = ChoukaCenterLeader(pos.x, pos.y, pos.z)
                        if leadIndex ~= nil then
                            ChoukaOilTickCapture(seat, obj, leadIndex)
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- 5. 战利品收入：占领"阵亡玩家留下的油井"每秒给钱
--    （放在本节点而不是 01_income.lua，是为了让这块逻辑自成一体、不改动已验证的收入代码）
-- ============================================================

function ChoukaOilPaySpoils()
    local mult = CHOUKA_ECONOMY_MULT
    if mult == nil or mult <= 0 then
        mult = 1
    end
    local money = floor(CHOUKA_OIL_SPOILS_INCOME * mult)
    if money <= 0 then
        return 0
    end

    local seat, owner, obj, paid
    paid = 0
    for seat = 1, 6, 1 do
        if ChoukaOilArmed[seat] == 1 and ChoukaOilRebuilt[seat] == 1 then
            owner = ChoukaOilOwner[seat]
            if owner ~= nil and owner > 0 then
                obj = ChoukaOilObj[seat]
                if obj ~= nil and ObjectIsAlive(obj) then
                    ExecuteAction("PLAYER_GIVE_MONEY", "Player_" .. owner, money)
                    paid = paid + 1
                end
            end
        end
    end
    return paid
end

-- ============================================================
-- 6. 每次求值
-- ============================================================

-- 开局门控 + 三国杀结算门控（与 01_income / 02_private_box / 05_dog / 06_center 同一条规则）
if CHOUKA_GAME_STARTED ~= 1 or CHOUKA_BANG_ENDED == 1 then
    return
end

if type(GetObjectByScriptName) ~= "function" then
    return
end

ChoukaOilArmOnce()
ChoukaOilTick = ChoukaOilTick + 1

-- 每秒：发战利品收入
ChoukaOilPaySpoils()

-- 每 CHOUKA_OIL_SCAN_EVERY 秒：刷新起重机存活状态 → 重建 + 占点
if mod(ChoukaOilTick, CHOUKA_OIL_SCAN_EVERY) == 0 then
    ChoukaOilRefreshCranes()
    ChoukaOilRebuildCenter()
    ChoukaOilScanSeats()
end
