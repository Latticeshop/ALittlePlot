-- ============================================================
-- 详见 docs/10-Lua注释存档.md §15_upgrades-1
-- ============================================================

ChoukaMarkNodeReady("解锁科技")

ChoukaUpgradesGiven = nil

function ChoukaGiveAllUpgrades()
    if ChoukaUpgradesGiven ~= nil then
        return
    end
    ChoukaUpgradesGiven = 1

    if ChoukaUnlockUpgrades == nil then
        return
    end

    -- 照 DSA 的习惯，发东西前把脚本玩家切成 1，发完还原
    local previous = SetWorldBuilderThisPlayer(1)
    for i = 1, getn(ChoukaUnlockUpgrades), 1 do
        ExecuteAction("GIVE_PLAYER_UPGRADE", "<All Players>", ChoukaUnlockUpgrades[i])
    end
    SetWorldBuilderThisPlayer(previous)
end

ChoukaGiveAllUpgrades()