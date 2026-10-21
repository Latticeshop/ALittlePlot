-- ============================================================
-- 抽卡hex · 发放抽卡技能
--
-- 照 DSA（lua/GAME/PureDraw/01_crate_event.lua:55-56）：
--   只发 SpecialPower_LuckyUnitCrate，**不发 SpecialPower_LuckyUnitCrateX10**
--   （本图每次抽卡固定出 1 个，十连那套按钮必须不存在）
--
-- 参数顺序（已按地编动作表核对，editorNumber 528）：
--   PLAYER_GRANT_SPECIAL_POWER( specialpower, Player )
--   注意是"先技能名、后玩家"，和大部分 PLAYER_* 动作相反。
--
-- "<All Human Players>" = 只给真人玩家，AI/中立不占按钮。
-- SetWorldBuilderThisPlayer 的保存/还原照 DSA 的写法，避免污染后续动作的执行身份。
--
-- 十连技能不需要额外关：没发放就等于不存在（PLAYER_SPECIAL_POWER_AVAILABILITY
-- 第三个参数是枚举字符串而不是 0/1，乱传反而可能出问题，所以这里不碰）。
-- ============================================================

local previous = SetWorldBuilderThisPlayer(1)

ExecuteAction("PLAYER_GRANT_SPECIAL_POWER", "SpecialPower_LuckyUnitCrate", "<All Human Players>")

SetWorldBuilderThisPlayer(previous)
