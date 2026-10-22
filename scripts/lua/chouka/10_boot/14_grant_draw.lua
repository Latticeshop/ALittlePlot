-- ============================================================
-- 详见 docs/10-Lua注释存档.md §14_grant_draw-1
-- ============================================================

ChoukaMarkNodeReady("发技能")

if CHOUKA_GAME_STARTED ~= 1 then
    return
end
if CHOUKA_DRAW_POWER_GRANTED == 1 then
    return
end
CHOUKA_DRAW_POWER_GRANTED = 1

local previous = SetWorldBuilderThisPlayer(1)

ExecuteAction("PLAYER_GRANT_SPECIAL_POWER", "SpecialPower_LuckyUnitCrate", "<All Human Players>")
ExecuteAction("PLAYER_GRANT_SPECIAL_POWER", "SpecialPower_LuckyUnitCrateX10", "<All Human Players>")

SetWorldBuilderThisPlayer(previous)