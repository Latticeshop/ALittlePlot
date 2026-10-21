-- ============================================================
-- 抽卡hex · 抽卡系统「钩子层」
--
-- 引擎侧：exObjectRegisterCreateEvent(类型名) 把该模板登记为"要通知出生事件"，
-- 之后每次该模板有单位出生，引擎调用全局函数
--     onUnitCreateEvent(createdObjId, createdObjInstanceId, ownerPlayerName)
-- 其中 createdObjInstanceId 是**模板名的哈希**（拿不到名字字符串，用 FastHash 比对）。
-- 这与 DSA 的 lua/GAME/UnitCreate.lua:1377 是同一个入口名，不能改名。
--
-- ⚠ 实测修正（首版把旧单位一起吞了）：
--   首版照 DSA 用"以结果单位为中心、半径 260 扫场删批"，那个半径在本图太小的一小块地上
--   等于把玩家附近的同类旧单位全删了。现在改成**按出生事件收集这一批的 id，只删收上来的 id**，
--   完全不按空间半径扫，旧单位一个都不会被碰（见 12_puredraw_replace.lua 的批次逻辑）。
--
-- 注意：桥是 Lua 4.0，闭包拿不到外层 local，所以这里全部用全局表。
-- ============================================================

-- 登记"可能是原版抽卡结果"的模板：原生箱子名单 + 卡池自身（登记得越全，越接近"全部自定义"）
for i = 1, getn(ChoukaNativeResultTypes), 1 do
    exObjectRegisterCreateEvent(ChoukaNativeResultTypes[i])
end
-- 卡池里所有类型都登记一遍：ChoukaUnitCategory 的键就是全池（四阵营去重后的并集）
for choukaTypeName, choukaTypeCat in ChoukaUnitCategory do
    exObjectRegisterCreateEvent(choukaTypeName)
end

-- 引擎入口（保留 DSA 的函数名）
function onUnitCreateEvent(createdObjId, createdObjInstanceId, ownerPlayerName)
    if ChoukaNativeResultHash == nil then
        return
    end

    -- 排除①：脚本自己生成的（我们补上去的卡池单位、赠送单位…）
    if ChoukaScriptCreated[createdObjId] ~= nil then
        return
    end

    -- 排除②：有生产者的 —— 生产栏/工厂造出来的正常单位，绝不能删
    if ObjectGetProducerObject(createdObjId) ~= nil then
        return
    end

    -- 排除③：白名单（工程师 / MCV / 需要手工补充的协议召唤物）
    if ChoukaAlwaysKnownHash[createdObjInstanceId] ~= nil then
        return
    end

    -- 收进"这一抽"的批次，等几帧让整批都落地，再统一结算
    ChoukaAddToBatch(createdObjId, ownerPlayerName)
end
