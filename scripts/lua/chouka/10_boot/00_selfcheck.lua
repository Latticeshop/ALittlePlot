-- ============================================================
-- 详见 docs/10-Lua注释存档.md §00_selfcheck-1
-- ============================================================

ChoukaSelfCheckTick = (ChoukaSelfCheckTick or 0) + 1

if ChoukaSelfCheckTick == 1 or mod(ChoukaSelfCheckTick, 10) == 0 then
    local started = "nil"
    if CHOUKA_GAME_STARTED ~= nil then
        started = CHOUKA_GAME_STARTED
    end
    local round = "nil"
    if CHOUKA_ROUND ~= nil then
        round = CHOUKA_ROUND
    end
    local boxLeft = "nil"
    if CHOUKA_BOX_LEFT ~= nil then
        boxLeft = CHOUKA_BOX_LEFT
    end
    -- ★ 抽卡等级是每人一份（09_level.lua），心跳里拼成 "1,1,1,1,1,1"
    local level = "nil"
    if type(ChoukaLevelGet) == "function" then
        level = ""
        for i = 1, 6, 1 do
            if level == "" then
                level = "" .. ChoukaLevelGet("Player_" .. i)
            else
                level = level .. "," .. ChoukaLevelGet("Player_" .. i)
            end
        end
    end
    local hud = "no"
    if ChoukaHudReady == 1 then
        hud = "yes"
    end
    local readyList = "无"
    if type(ChoukaNodeReadyList) == "function" then
        readyList = ChoukaNodeReadyList()
    end

    _LOG("心跳 tick=" .. ChoukaSelfCheckTick
        .. " started=" .. started
        .. " round=" .. round
        .. " boxLeft=" .. boxLeft
        .. " lv=" .. level
        .. " hud=" .. hud
        .. " 节点就绪=" .. readyList)
end