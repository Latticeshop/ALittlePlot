-- ============================================================
-- 详见 docs/10-Lua注释存档.md §11a_register-1
-- ============================================================

ChoukaRegisterTotal = 0

if ChoukaAllUnitTypes ~= nil and type(exObjectRegisterCreateEvent) == "function" then
    for choukaRegIndex = 1, getn(ChoukaAllUnitTypes), 1 do
        local choukaRegName = ChoukaAllUnitTypes[choukaRegIndex]
        if choukaRegName ~= nil then
            exObjectRegisterCreateEvent(choukaRegName)
            ChoukaRegisterTotal = ChoukaRegisterTotal + 1
        end
    end
end

-- 引擎入口（函数名固定，DSA 同名）
function onUnitCreateEvent(createdObjId, createdObjInstanceId, ownerPlayerName)
    if createdObjId == nil then
        return
    end

    -- 排除：脚本自己生成的（我们补上去的卡池单位、保底工程师、AI 单位…）
    if ChoukaScriptCreated ~= nil and ChoukaScriptCreated[createdObjId] ~= nil then
        return
    end

    -- 批次逻辑在 12_puredraw_replace.lua（同帧随后加载）；它还没就绪就先不管
    if type(ChoukaAddToBatch) ~= "function" then
        return
    end

    -- 收进"这一抽"的批次；createdObjInstanceId（模板哈希）只用来反查名字写日志
    ChoukaAddToBatch(createdObjId, ownerPlayerName, createdObjInstanceId)
end

_LOG(format("单位出生事件已登记 %d 种类型（整表登记，含各种变体模板）", ChoukaRegisterTotal))
ChoukaMarkNodeReady("单位登记")