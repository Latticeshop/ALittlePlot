-- ============================================================
-- 抽卡hex · 界面
--
-- 对应 ScriptsData.json 节点：抽卡hex / HUD（interval 1，常驻）
--
-- ① 右上角 = 引擎**计分板**：每人一行场上单位数 + 第 7 行回合数
-- ② 左下角 = 五行自绘文字（12px 白色）：
--      回合数：3
--      盲盒刷新倒计时：01:47
--      抽卡等级：Lv.3
--      T1：75%, T2：25%, T3：0%
--      T4：0%, T5：0%
--
-- 概率表来自 09_level.lua 的 ChoukaLevelWeights（等级 → 各档概率），
-- "购买等级"（顶部按钮 3 → 交易市场）会推进这个等级。
-- ============================================================

-- 左下角各行文字（位置/颜色/字号都在这里，嫌靠下就加大 Y）
CHOUKA_HUD_ROUND_INDEX     = 101
CHOUKA_HUD_COUNTDOWN_INDEX = 102
CHOUKA_HUD_LEVEL_INDEX     = 103
CHOUKA_HUD_PROB1_INDEX     = 104
CHOUKA_HUD_TEXT_X          = 20
CHOUKA_HUD_ROUND_Y         = 286
CHOUKA_HUD_COUNTDOWN_Y     = 260
CHOUKA_HUD_LEVEL_Y         = 234
CHOUKA_HUD_PROB1_Y         = 208
CHOUKA_HUD_TEXT_SIZE       = 12

-- 统一用普通白色（16777215 = 0xFFFFFF），别搞彩色
CHOUKA_HUD_ROUND_COLOR     = 16776960   -- 0xFFFF00 亮黄
CHOUKA_HUD_COUNTDOWN_COLOR = 16744448   -- 0xFF8800 亮橙
CHOUKA_HUD_LEVEL_COLOR     = 65535      -- 0x00FFFF 青
CHOUKA_HUD_PROB_COLOR      = 65280      -- 0x00FF00 绿

ChoukaHudReady = nil

function ChoukaHudCreateText(index, y, color)
    exCreateCustomText({
        Index      = index,
        Content    = "",
        X          = CHOUKA_HUD_TEXT_X,
        Y          = y,
        Color      = color,
        Size       = CHOUKA_HUD_TEXT_SIZE,
        AlignX     = "left",
        AlignY     = "bottom",
        GroupIndex = 1,
    })
end

function ChoukaHudInitOnce()
    if ChoukaHudReady ~= nil then
        return
    end
    ChoukaHudReady = 1

    -- 右上角计分板
    exScoreBoardSetVisibility(1)
    exScoreBoardSetTitle("抽卡hex · 场上单位")
    for i = 1, 6, 1 do
        exScoreBoardSetText(format("$p%dName:", i), i, 1)
        exScoreBoardSetText("  0", i, 2)
    end
    exScoreBoardSetText("回合", 7, 2)
    exScoreBoardSetText("0", 7, 3)

    -- 左下角五行
    ChoukaHudCreateText(CHOUKA_HUD_ROUND_INDEX,     CHOUKA_HUD_ROUND_Y,     CHOUKA_HUD_ROUND_COLOR)
    ChoukaHudCreateText(CHOUKA_HUD_COUNTDOWN_INDEX, CHOUKA_HUD_COUNTDOWN_Y, CHOUKA_HUD_COUNTDOWN_COLOR)
    ChoukaHudCreateText(CHOUKA_HUD_LEVEL_INDEX,     CHOUKA_HUD_LEVEL_Y,     CHOUKA_HUD_LEVEL_COLOR)
    ChoukaHudCreateText(CHOUKA_HUD_PROB1_INDEX,     CHOUKA_HUD_PROB1_Y,     CHOUKA_HUD_PROB_COLOR)
end

-- 场上单位数：以 craneN 当"本方锚点"，过滤器按 SAME_PLAYER 判归属
function ChoukaCountPlayerUnits(crane)
    if ChoukaUnitFilter == nil then
        ChoukaUnitFilter = CreateObjectFilter({
            Rule = "ANY",
            Relationship = "SAME_PLAYER",
            Include = "SELECTABLE",
            Exclude = "STRUCTURE",
            ExcludeThing = {
                "LuckyUnitCrateSeed",
                "UnitCrateNew",
                "UnitCrate",
                "moneycrate",
                "MoneyCrate",
            },
        })
    end
    local units, count = ObjectFindObjects(crane, nil, ChoukaUnitFilter)
    return count
end

ChoukaHudInitOnce()

-- ① 右上角：每人一行单位数
for i = 1, 6, 1 do
    local crane = GetObjectByScriptName(ChoukaCranePrefix .. i)
    local count = 0
    if ObjectIsAlive(crane) then
        count = ChoukaCountPlayerUnits(crane)
    end
    exScoreBoardSetText(format("  %d", count), i, 2)
end

local round = CHOUKA_ROUND or 0
exScoreBoardSetText(format("%d", round), 7, 3)

-- ② 左下角：自己数秒的倒计时
if CHOUKA_BOX_LEFT == nil then
    CHOUKA_BOX_LEFT = 120
end
CHOUKA_BOX_LEFT = CHOUKA_BOX_LEFT - 1
if CHOUKA_BOX_LEFT < 0 then
    CHOUKA_BOX_LEFT = 0
end
local remainMinutes = floor(CHOUKA_BOX_LEFT / 60)
local remainSeconds = CHOUKA_BOX_LEFT - remainMinutes * 60

-- ② 左下角：抽卡等级 + 各档概率
local level = ChoukaDrawLevel or 1
local weights = nil
if ChoukaGetLevelWeights ~= nil then
    weights = ChoukaGetLevelWeights(level)
end
if weights == nil then
    weights = ChoukaDrawTierWeights or { 100, 0, 0, 0, 0 }
end

-- 只写"抽卡等级：Lv.N"；升级价格与自动升级都是隐性规则，不占界面
local levelText = format("抽卡等级：Lv.%d", level)

exCustomTextUpdateText(CHOUKA_HUD_ROUND_INDEX,
    format("回合数：%d", round))
exCustomTextUpdateText(CHOUKA_HUD_COUNTDOWN_INDEX,
    format("盲盒刷新倒计时：%02d:%02d", remainMinutes, remainSeconds))
exCustomTextUpdateText(CHOUKA_HUD_LEVEL_INDEX, levelText)
exCustomTextUpdateText(CHOUKA_HUD_PROB1_INDEX,
    format("T1：%d%%, T2：%d%%, T3：%d%%, T4：%d%%, T5：%d%%",
        weights[1] or 0, weights[2] or 0, weights[3] or 0, weights[4] or 0, weights[5] or 0))
