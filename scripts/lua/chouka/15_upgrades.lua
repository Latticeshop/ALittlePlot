-- ============================================================
-- 抽卡hex · 开局解锁全部科技协议
--
-- 对应 ScriptsData.json 节点：抽卡hex / 解锁科技
--   EvaluationInterval    = 1   （等一秒，科技表就绪）
--   DeactivateUponSuccess = true
--
-- 为什么直接发：
--   本图建造栏被 PLAYER_DISABLE_BASE_CONSTRUCTION 整条关掉，玩家既不能造建筑，
--   也进不了协议/升级面板 —— 科技协议留着也买不到，不如开局全给。
--
-- 机制照 双兵种作战/Troop Selection/initialization.lua:126：
--   ExecuteAction("GIVE_PLAYER_UPGRADE", "<All Players>", "Upgrade_XXX")
-- 名单由 tools/build-upgrades.js 从下面三处现成清单合并而来（见 gen_upgrades.lua）：
--   · 双兵种 Tech_Upgrade / Enhanced_Tech_Upgrade（玩家可购买的科技协议，含龙船全套）
--   · DSA lua/Upgrade.lua 的 upgrades 列表
--   · 双兵种 lib/enums/UpgradeEnum.lua 全量枚举
-- ============================================================

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
