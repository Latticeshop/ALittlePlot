-- ============================================================
-- ★ 每回合开始：给场上所有飞机补满弹药（作者要求：只补满、**不播报**，免得刷屏）
--   接口见《日冕 Lua.lua》[[34]]：
--     ObjectGetWeaponSetUpdateWeaponMaxAmmoCount(单位, WeaponSlot 的 ID, Ordering, 武器序号)
--     ObjectSetWeaponSetUpdateWeaponCurrentAmmoCount(单位, WeaponSlot 的 ID, Ordering, 武器序号, 数值)
--   Ordering：PRIMARY=1 SECONDARY=2 TERTIARY=3 QUATERNARY=4 QUINARY=5
--   ⚠ "WeaponSlot 的 ID" 不是槽位序号；飞机主武器一般在 ID=1 的槽里，所以默认扫 1~2 号槽。
-- ============================================================
CHOUKA_AMMO_REFILL = 1      -- 1 = 每回合开始补满（改 0 关掉）
CHOUKA_AMMO_SLOTS  = 2      -- 扫几个 WeaponSlot（ID 1~2）
CHOUKA_AMMO_ORDERS = 5      -- PRIMARY ~ QUINARY
CHOUKA_AMMO_INDEX  = 6      -- 每个 Ordering 里最多几个武器
CHOUKA_AMMO_RADIUS = 20000  -- 找飞机的搜索半径（够包住整张图）

if ChoukaRefillAircraftAmmo == nil then
    function ChoukaRefillAircraftAmmo()
        if CHOUKA_AMMO_REFILL ~= 1 then
            return 0
        end
        if type(ObjectFindObjects) ~= "function" then
            return 0
        end
        if type(ObjectSetWeaponSetUpdateWeaponCurrentAmmoCount) ~= "function" then
            _LOG("补弹药：这个 mod 没有 ObjectSetWeaponSetUpdateWeaponCurrentAmmoCount，跳过")
            return 0
        end

        if ChoukaAircraftFilter == nil then
            ChoukaAircraftFilter = CreateObjectFilter({
                Rule = "ANY",
                Relationship = "ENEMIES NEUTRAL ALLIES",
                Include = "AIRCRAFT",
            })
        end
        local objs, count = ObjectFindObjects(nil, {
            X = 0, Y = 0, Z = 0,
            Radius = CHOUKA_AMMO_RADIUS,
            DistType = "EXTENTS_3D",
        }, ChoukaAircraftFilter)
        if count == nil or count < 1 then
            _LOG(format("补弹药：第%d回合，场上没有飞机", CHOUKA_ROUND or 0))
            return 0
        end

        local hasMax = (type(ObjectGetWeaponSetUpdateWeaponMaxAmmoCount) == "function")
        local planes = 0
        local weapons = 0
        for i = 1, count, 1 do
            local obj = objs[i]
            if obj ~= nil and ObjectIsAlive(obj) then
                planes = planes + 1
                for slot = 1, CHOUKA_AMMO_SLOTS, 1 do
                    for ord = 1, CHOUKA_AMMO_ORDERS, 1 do
                        for idx = 1, CHOUKA_AMMO_INDEX, 1 do
                            local maxAmmo = nil
                            if hasMax then
                                maxAmmo = ObjectGetWeaponSetUpdateWeaponMaxAmmoCount(obj, slot, ord, idx)
                            end
                            if type(maxAmmo) == "number" and maxAmmo > 0 then
                                ObjectSetWeaponSetUpdateWeaponCurrentAmmoCount(obj, slot, ord, idx, maxAmmo)
                                weapons = weapons + 1
                            end
                        end
                    end
                end
            end
        end
        _LOG(format("补弹药：第%d回合，飞机 %d 架，补满武器 %d 处",
            CHOUKA_ROUND or 0, planes, weapons))
        return planes
    end
end

-- ============================================================
-- ★ 登神盲盒（AttributeCrate = 通用木箱 NPCrate01，原版捡起来没任何效果）
--   箱子被碰掉（销毁）时：给"箱子点位附近小范围里、箱子主人的单位"加一项属性 buff，
--   并且只给箱子主人一个人播报一句。掷骰与接口都照 DSA 自走棋的"登神"
--   （DSA_ggz自走棋/lua/GAME/HextechRune/06_ascension.lua）：
--     概率：血量 40% / 伤害 30% / 攻速 20% / 射程 10%（累计 0.40 / 0.70 / 0.90 / 1.00）
--     幅度：25% ~ 50%（本图自定义；DSA 是按阶级 30/40/50/60）
--     接口：exAttributeModifierCreate({ ... }, 1) + ObjectLoadAttributeModifier(单位, mod, 秒)
--   累计：**同一个单位吃两次同一种加成会叠上去**（登记表 + 引擎查询双保险，见下面 ChoukaAscendPushStack）
--   ⚠ 只影响"箱子周围 CHOUKA_ASCEND_RADIUS 以内"的单位（一般 3~5 个），不是玩家全部单位。
-- ============================================================
CHOUKA_ASCEND_TYPE     = "AttributeCrate"   -- 登神盲盒 = 属性箱（模型 NPCrate01）
CHOUKA_ASCEND_RADIUS   = 96                 -- 生效半径（世界单位）= 作者定的基准：家里 box11↔box12 的间距 95.5
                                            -- （(5066,4310)→(5136,4245)，dx70 dy65）。直径 192 ≈ 两个箱子点的跨度。
CHOUKA_ASCEND_MIN      = 25                 -- 幅度下限 %
CHOUKA_ASCEND_MAX      = 50                 -- 幅度上限 %
CHOUKA_ASCEND_DURATION = 999999999          -- 持续**帧数**（LuaBridge 的第三个参数是帧，30 帧 = 1 秒）
                                            -- DSA 登神写 9999（≈5.5 分钟），巨人城废墟-登神参考工程写
                                            -- permanent_frame_count = 999999999，这里照后者 = 整局不消
CHOUKA_ASCEND_LOG      = 1                  -- 1 = 每次结算写一行日志

ChoukaAscendBoxes = ChoukaAscendBoxes or {}   -- 箱子对象 id → { player=…, x=…, y=…, z=…, waypoint=… }

-- 从 team 名（Player_3/teamPlayer_3）里取出玩家名
function ChoukaTeamPlayerName(team)
    if team == nil then
        return nil
    end
    local pos = strfind(team, "/")
    if pos == nil then
        return team
    end
    return strsub(team, 1, pos - 1)
end

-- 箱子类型哈希集合（把"箱子自己"从加成目标里排除，纯 Lua 比较，不额外依赖过滤器）
function ChoukaCrateHashSet()
    if ChoukaCrateHashes ~= nil then
        return ChoukaCrateHashes
    end
    -- 本文件里 ChoukaCrateFilterTypes 定义在更下面（第一次求值时可能还没轮到），
    -- 那种情况下**不要缓存空表**，下次再算
    if type(ChoukaCrateFilterTypes) ~= "function" then
        return {}
    end
    ChoukaCrateHashes = {}
    local list = ChoukaCrateFilterTypes()
    for i = 1, getn(list), 1 do
        ChoukaCrateHashes[FastHash(list[i])] = 1
    end
    return ChoukaCrateHashes
end

-- 箱子刷出来后登记（只登记登神盲盒）：记下箱子对象 id、点位、归属玩家
function ChoukaRegisterAscendBox(team, waypoint)
    if type(ObjectFindObjects) ~= "function" then
        return
    end
    local p = exWaypointGetPos(waypoint)
    if p == nil or p[1] == nil then
        return
    end
    if ChoukaAscendBoxFilter == nil then
        ChoukaAscendBoxFilter = CreateObjectFilter({
            Rule = "ANY",
            IncludeThing = { CHOUKA_ASCEND_TYPE },
        })
    end
    local objs, count = ObjectFindObjects(nil, {
        X = p[1], Y = p[2], Z = p[3] or 0,
        Radius = 20, DistType = "CENTER_2D",
    }, ChoukaAscendBoxFilter)
    if count == nil or count < 1 then
        _LOG(format("登神盲盒：%s 刷出来了但没找到箱子对象（不会触发加成播报）", waypoint))
        return
    end
    local playerName = ChoukaTeamPlayerName(team)
    for i = 1, count, 1 do
        local obj = objs[i]
        if obj ~= nil and ObjectIsAlive(obj) then
            ChoukaAscendBoxes[ObjectGetId(obj)] = {
                player = playerName,
                x = p[1], y = p[2], z = p[3] or 0,
                waypoint = waypoint,
            }
        end
    end
end

-- 掷一次：返回 种类, 中文名, 幅度%
function ChoukaRollAscend()
    local roll = GetRandomNumber()
    local kind = "health"
    local kindName = ChoukaT.ascendHealth
    if roll < 0.40 then
        kind = "health"
        kindName = ChoukaT.ascendHealth
    elseif roll < 0.70 then
        kind = "damage"
        kindName = ChoukaT.ascendDamage
    elseif roll < 0.90 then
        kind = "rateOfFire"
        kindName = ChoukaT.ascendRate
    else
        kind = "range"
        kindName = ChoukaT.ascendRange
    end
    local span = CHOUKA_ASCEND_MAX - CHOUKA_ASCEND_MIN + 1
    local percent = CHOUKA_ASCEND_MIN + floor(GetRandomNumber() * span)
    if percent > CHOUKA_ASCEND_MAX then
        percent = CHOUKA_ASCEND_MAX
    end
    if percent < CHOUKA_ASCEND_MIN then
        percent = CHOUKA_ASCEND_MIN
    end
    return kind, kindName, percent
end

-- ============================================================
-- 登神累计：单位登记表 + 引擎查询，把"再吃一次同种加成"变成"在原有加成上往上加"
--
-- 为什么要这么写：
--   · 引擎里每条 AttributeModifier 是**相乘**的，所以"再加 40%"如果直接再挂一条，
--     结果是 1.4 × 1.4 = 1.96（+96%），而不是累计想要的 1.8（+80%）；
--   · 想累计成"1 + 已有% + 这次%"这一条，只能重算——但卸载旧 modifier 的接口在
--     exAttributeModifierCreate 造出来的对象上不一定好使（DSA 干脆一次重算一条）。
-- 所以这里用"**补差额倍数**"的写法，不用卸载：
--   已有倍数 = 1 + 这只单位这一维**已经吃到的累计%** / 100   ← 只用登记表，绝不查引擎
--   目标倍数 = 1 + (已有% + 本次%) / 100
--   补的倍数 = 目标倍数 / 已有倍数  → 新挂一条
--   因为 modifier 相乘：已有 × 补 = 目标，累计语义与 DSA 的"1 + n×p%"完全一致。
-- 好处：
--   ① 不需要卸载接口；
--   ② **乘法链天然可叠**：单位吃 N 次就是 1×d1×d2×…×dN = 1 + Σp%，想叠多少叠多少；
--   ③ 基准只能用**登记表**，不能用 ObjectGetAttributeModifier 的实时值 ——
--      实时值里混着协议/技能等外部 buff，拿它当分母会把登神的加成"稀释"掉
--      （例：外部已有 +40%，我们目标 +41%，若用 1.4 当分母只补 1.007，
--        玩家实际只多得 0.7%，而不是应得的 41%）。引擎实时值只在日志里输出用于核对；
--   ④ 登记表还能给日志报出"这只单位现在累计多少"。
-- ============================================================
ChoukaAscendUnitStacks = ChoukaAscendUnitStacks or {}   -- 单位对象 id → { health=Σ%, damage=Σ%, rateOfFire=Σ%, range=Σ% }

-- 掷骰种类 → 引擎属性键（查询/创建同名）
function ChoukaAscendAttrKey(kind)
    if kind == "health" then
        return "HEALTH_MULT"
    elseif kind == "damage" then
        return "DAMAGE_MULT"
    elseif kind == "rateOfFire" then
        return "RATE_OF_FIRE"
    end
    return "RANGE"
end

-- 取这只单位的登记记录（没有就建一条）
function ChoukaAscendUnitRecord(unitId)
    local rec = ChoukaAscendUnitStacks[unitId]
    if rec == nil then
        rec = { health = 0, damage = 0, rateOfFire = 0, range = 0 }
        ChoukaAscendUnitStacks[unitId] = rec
    end
    return rec
end

-- 引擎里这只单位这一维现在的实际倍数。**只用来打日志核对**，不参与增量计算
-- （原因见文件开头 ③：实时值里混着外部 buff，当分母会把登神加成稀释掉）
function ChoukaAscendCurrentMult(unit, kind, fallback)
    if type(ObjectGetAttributeModifier) == "function" then
        local cur = nil
        if type(ChoukaAscendAttrKey) == "function" then
            cur = ObjectGetAttributeModifier(unit, ChoukaAscendAttrKey(kind))
        end
        if cur ~= nil and cur > 0 then
            return cur
        end
    end
    return fallback
end

-- 把这一维的累计从"登记表旧值"推到"旧值 + percent"，返回：要补的倍数、新的累计%
--   · 只用登记表当基准（每个单位一条记录，没吃过箱子 = 0）
--   · 补的倍数 = (1 + 新累计%) / (1 + 旧累计%)，连乘起来正好是 1 + 累计%
--     例：第一次 +41% → 挂 1.41；第二次 +41% → 补 1.82/1.41 = 1.2908，
--         引擎里 1.41 × 1.2908 = 1.82（+82%，累计），而不是 1.41 × 1.41 = 1.99
function ChoukaAscendPushStack(unitId, kind, percent)
    local rec = ChoukaAscendUnitRecord(unitId)
    local oldTotal = rec[kind] or 0
    local newTotal = oldTotal + percent
    local oldMult = 1 + oldTotal / 100
    local newMult = 1 + newTotal / 100
    rec[kind] = newTotal
    return newMult / oldMult, newTotal
end

-- 按"种类 + 差值倍数"造一条 modifier（每次新造，避免同一对象重复挂被引擎当成刷新）
function ChoukaAscendMakeModifier(kind, delta)
    if kind == "range" then
        -- 射程必须和视野成对写，否则单位停在射程边缘却看不见目标（DSA 的注释）
        return exAttributeModifierCreate({ RANGE = delta, VISION = delta }, 1)
    end
    if kind == "health" then
        return exAttributeModifierCreate({ HEALTH_MULT = delta }, 1)
    end
    if kind == "damage" then
        return exAttributeModifierCreate({ DAMAGE_MULT = delta }, 1)
    end
    return exAttributeModifierCreate({ RATE_OF_FIRE = delta }, 1)
end

-- 清理登记表里已经死掉的单位（单位 id 会被新单位复用，不清会串加成）
function ChoukaAscendPruneStacks()
    local alive = 0
    for id, rec in ChoukaAscendUnitStacks do
        if rec ~= nil then
            local obj = GetObjectById(id)
            if ObjectIsAlive(obj) then
                alive = alive + 1
            else
                ChoukaAscendUnitStacks[id] = nil
            end
        end
    end
    return alive
end

-- 结算：按箱子点位找附近"箱子主人的"非建筑单位，套上这一项 buff，并给箱主播报
function ChoukaApplyAscendBuff(playerName, x, y, z)
    if type(exAttributeModifierCreate) ~= "function"
        or type(ObjectLoadAttributeModifier) ~= "function" then
        _LOG("登神盲盒：这个 mod 没有 exAttributeModifierCreate / ObjectLoadAttributeModifier，跳过")
        return 0
    end
    if type(ObjectFindObjects) ~= "function" then
        return 0
    end

    -- 一只箱子掷一次：种类 + 幅度（同一只箱子罩到的单位拿同一个数，与播报对得上）
    local kind, kindName, percent = ChoukaRollAscend()

    if ChoukaAscendUnitFilter == nil then
        -- 用项目里已验证过的组合（12_puredraw_replace.lua 的 ChoukaDrawPickerFilter 同款）：
        -- 只认能选中的、排除建筑。箱子本身再用类型哈希排掉（见下面 crateHashes）
        ChoukaAscendUnitFilter = CreateObjectFilter({
            Rule = "ANY",
            Include = "SELECTABLE",
            Exclude = "STRUCTURE",
        })
    end
    local objs, count = ObjectFindObjects(nil, {
        X = x, Y = y, Z = z or 0,
        Radius = CHOUKA_ASCEND_RADIUS, DistType = "CENTER_2D",
    }, ChoukaAscendUnitFilter)

    local crateHashes = ChoukaCrateHashSet()
    local buffed = 0
    local maxTotal = 0
    local lastUnit = nil   -- 最后一只被罩到的单位（日志里查引擎真实倍数核对用）
    if count ~= nil and count > 0 then
        for i = 1, count, 1 do
            local u = objs[i]
            if u ~= nil and ObjectIsAlive(u) then
                local owner = nil
                if type(ObjectPlayerScriptName) == "function" then
                    owner = ObjectPlayerScriptName(u)
                end
                if playerName == nil or owner == playerName then
                    local hash = nil
                    if type(exObjectGetInstanceId) == "function" then
                        hash = exObjectGetInstanceId(ObjectGetId(u))
                    end
                    if hash == nil or crateHashes[hash] == nil then
                        local unitId = ObjectGetId(u)
                        local delta, total = ChoukaAscendPushStack(unitId, kind, percent)
                        -- delta 只会在"引擎里已经比目标高"时才等于 1（外部 buff 加过头），
                        -- 那种情况不用再挂一条没用的 modifier，但这个人照样算"被箱子罩到"
                        if delta > 1.001 then
                            local mod = ChoukaAscendMakeModifier(kind, delta)
                            if mod ~= nil then
                                ObjectLoadAttributeModifier(u, mod, CHOUKA_ASCEND_DURATION)
                            end
                        end
                        buffed = buffed + 1
                        lastUnit = u
                        if total > maxTotal then
                            maxTotal = total
                        end
                    end
                end
            end
        end
    end

    if CHOUKA_ASCEND_LOG == 1 then
        -- 引擎核对值：拿最后一只被罩到的单位查一下引擎真实倍数，
        -- 正常情况下应该 ≈ 1 + 累计%（乘起来了）。对不上就说明引擎不是相乘，要回来改。
        local engineMult = 0
        if lastUnit ~= nil and type(ObjectGetAttributeModifier) == "function" then
            engineMult = ChoukaAscendCurrentMult(lastUnit, kind, 0) or 0
        end
        _LOG(format("登神盲盒：玩家=%s 点位=(%.0f,%.0f) %s +%d%% → %d 个单位（最高累计 %d%%，引擎核对 %.3f）",
            playerName or "?", x, y, kindName, percent, buffed, maxTotal, engineMult))
    end
    -- 个人播报（只有箱主看到，不刷屏）
    if buffed > 0 and playerName ~= nil then
        if type(exAddTextToPublicBoardForPlayer) == "function" then
            exAddTextToPublicBoardForPlayer(playerName,
                format(ChoukaT.ascendBox, kindName, percent), 10)
        end
    end
    return buffed
end

-- 每秒扫一次：登记过、但对象已经不在的箱子 = 被碰掉了 → 结算登神
function ChoukaAscendTick()
    -- 顺手清理登记表里已经死掉的单位（每秒一次，条目很少，开销可以忽略）
    ChoukaAscendPruneStacks()
    for id, box in ChoukaAscendBoxes do
        if box ~= nil then
            local obj = GetObjectById(id)
            if not ObjectIsAlive(obj) then
                ChoukaAscendBoxes[id] = nil
                ChoukaApplyAscendBuff(box.player, box.x, box.y, box.z)
            end
        end
    end
end

-- ★ 放在早退之前：倒计时没到、箱子还没刷，也要每秒结算一次（箱子随时会被碰）
ChoukaAscendTick()

-- ============================================================
-- 详见 docs/10-Lua注释存档.md §02_private_box-1
-- ============================================================

-- ⚠ Lua 4.0 桥的坑：函数体里读不到外层的 local，所以这些常量必须是全局。
ChoukaMarkNodeReady("私有箱")

BOX_SECONDS        = 120
CHOUKA_BOX_SECONDS = CHOUKA_BOX_SECONDS or BOX_SECONDS   -- 与 03_start.lua 共用同一个数
CHOUKA_CRATE       = "moneycrate"
CHOUKA_BOX_RANGE   = 35       -- 点位占用判定半径（世界单位）；两点相距约 70，别调太大

-- 认作"箱子"的物件类型 = 箱子表(02a_crate_list.lua)里会刷的全部类型 + 两个原版通用箱名。
-- ⚠ 换了箱子种类必须让它出现在这里，否则"这点位还有没有箱子"会判空 → 同一个点越刷越多。
function ChoukaCrateFilterTypes()
    local list = { "UnitCrate", "LuckyUnitCrateSeed" }
    local extra = nil
    if type(ChoukaBoxCrateTypeList) == "function" then
        extra = ChoukaBoxCrateTypeList()
    end
    if extra ~= nil then
        for i = 1, getn(extra), 1 do
            tinsert(list, extra[i])
        end
    elseif CHOUKA_CRATE ~= nil then
        tinsert(list, CHOUKA_CRATE)
    end
    return list
end

ChoukaCrateFilter = ChoukaCrateFilter or CreateObjectFilter({
    Rule = "ANY",
    IncludeThing = ChoukaCrateFilterTypes(),
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

-- 在某个点位按 02a_crate_list.lua 的权重表刷一个箱子（家里和中央共用这一个入口）
-- kind：不填 / "home" = 家里的 boxN1·boxN2 表；"center" = 中央 center1~6 表
function ChoukaSpawnBoxCrate(team, waypoint, kind)
    local crateType = "moneycrate"
    if type(ChoukaPickBoxCrate) == "function" then
        crateType = ChoukaPickBoxCrate(kind)
    end
    ExecuteAction("CREATE_UNNAMED_ON_TEAM_AT_WAYPOINT", crateType, team, waypoint)

    -- 登神盲盒要记住"这只箱子是谁的、在哪"，箱子被碰掉才好结算
    if crateType == CHOUKA_ASCEND_TYPE then
        ChoukaRegisterAscendBox(team, waypoint)
    end
    if CHOUKA_BOX_CRATE_LOG == 1 then
        local crateName = crateType
        if type(ChoukaBoxCrateName) == "function" then
            crateName = ChoukaBoxCrateName(crateType)
        end
        local where = "家里"
        if kind == "center" then
            where = "中央"
        end
        _LOG(format("刷箱：%s[%s] 类型=%s（%s）", waypoint, where, crateType, crateName))
    end
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
            ChoukaSpawnBoxCrate(team, wp1, "home")
        end
        if exWaypointGetPos(wp2) ~= nil and ChoukaBoxBusy(wp2) == 0 then
            ChoukaSpawnBoxCrate(team, wp2, "home")
        end
    end
end

_ALERT(format(ChoukaT.boxRefreshed, CHOUKA_ROUND))

-- ★ 每回合开始补满飞机弹药（放在最后：万一这个接口报错，也挡不住上面刷箱和回合播报）
if type(ChoukaRefillAircraftAmmo) == "function" then
    ChoukaRefillAircraftAmmo()
end