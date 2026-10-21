-- ============================================================
-- 详见 docs/10-Lua注释存档.md §20_hud-1
-- ============================================================

-- 左下角逐玩家文字（Index 要避开按钮栏/开局用的编号：开局用 1~99，按钮栏用 200+）
CHOUKA_HUD_ROUND_INDEX     = 101
CHOUKA_HUD_COUNTDOWN_INDEX = 102
CHOUKA_HUD_LEVEL_INDEX     = 103
CHOUKA_HUD_PROB1_INDEX     = 104

CHOUKA_HUD_TEXT_X          = 22      -- 屏幕坐标系（1024 x 768，Y 从**屏幕底边**往上量）
CHOUKA_HUD_ROUND_Y         = 286     -- ★ 实测确认：这套数值（208~286）就是"左下角"；
CHOUKA_HUD_COUNTDOWN_Y     = 260     --   之前误改成 690 跑到了左上角（Y 越大越靠上）。
CHOUKA_HUD_LEVEL_Y         = 234     --   嫌太靠下就整体 +20，嫌太靠上就整体 -20。
CHOUKA_HUD_PROB1_Y         = 208
CHOUKA_HUD_TEXT_SIZE       = 12

CHOUKA_HUD_ROUND_COLOR     = 16776960   -- 0xFFFF00 亮黄
CHOUKA_HUD_COUNTDOWN_COLOR = 16744448   -- 0xFF8800 亮橙
CHOUKA_HUD_LEVEL_COLOR     = 65535      -- 0x00FFFF 青
CHOUKA_HUD_PROB_COLOR      = 65280      -- 0x00FF00 绿

ChoukaHudCreated = ChoukaHudCreated or {}   -- 玩家序号 → 1（该玩家的四行字已经建好）
ChoukaHudFailed  = ChoukaHudFailed  or {}   -- 玩家序号 → 1（建失败，下秒重试）

-- ---------------- 逐玩家文字 ----------------

function ChoukaHudCreateTextForPlayer(playerName, index, y, color)
    if type(exCreateCustomTextForPlayer) ~= "function" then
        return 0
    end
    exCreateCustomTextForPlayer(playerName, {
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
    if type(exCustomTextUpdateVisibilityForPlayer) == "function" then
        exCustomTextUpdateVisibilityForPlayer(playerName, index, 1)
    end
    return 1
end

function ChoukaHudUpdateText(playerName, index, text)
    if type(exCustomTextUpdateTextForPlayer) == "function" then
        exCustomTextUpdateTextForPlayer(playerName, index, text)
    end
end

function ChoukaHudCreateForPlayer(index)
    if ChoukaHudCreated[index] == 1 then
        return 1
    end
    if type(exCreateCustomTextForPlayer) ~= "function" then
        if ChoukaHudFailed[index] == nil then
            ChoukaHudFailed[index] = 1
            _LOG("HUD：没有 exCreateCustomTextForPlayer，左下角文字跳过（改用右上角计分板）")
        end
        return 0
    end
    local playerName = "Player_" .. index
    ChoukaHudCreateTextForPlayer(playerName, CHOUKA_HUD_ROUND_INDEX,     CHOUKA_HUD_ROUND_Y,     CHOUKA_HUD_ROUND_COLOR)
    ChoukaHudCreateTextForPlayer(playerName, CHOUKA_HUD_COUNTDOWN_INDEX, CHOUKA_HUD_COUNTDOWN_Y, CHOUKA_HUD_COUNTDOWN_COLOR)
    ChoukaHudCreateTextForPlayer(playerName, CHOUKA_HUD_LEVEL_INDEX,     CHOUKA_HUD_LEVEL_Y,     CHOUKA_HUD_LEVEL_COLOR)
    ChoukaHudCreateTextForPlayer(playerName, CHOUKA_HUD_PROB1_INDEX,     CHOUKA_HUD_PROB1_Y,     CHOUKA_HUD_PROB_COLOR)
    ChoukaHudCreated[index] = 1
    return 1
end

-- ---------------- 右上角计分板 ----------------

function ChoukaHudInitScoreBoard()
    if ChoukaHudScoreBoardReady == 1 then
        return
    end
    if type(exScoreBoardSetVisibility) ~= "function" or type(exScoreBoardSetText) ~= "function" then
        if ChoukaHudScoreBoardFailed == nil then
            ChoukaHudScoreBoardFailed = 1
            _LOG("HUD：没有计分板 API（exScoreBoardSetVisibility/exScoreBoardSetText），右上角信息跳过")
        end
        return
    end
    exScoreBoardSetVisibility(1)
    if type(exScoreBoardSetTitle) == "function" then
        exScoreBoardSetTitle("抽卡hex · 场上单位")
    end
    for i = 1, 6, 1 do
        exScoreBoardSetText(format("$p%dName:", i), i, 1)
        exScoreBoardSetText("  0", i, 2)
    end
    exScoreBoardSetText("回合", 7, 1)
    exScoreBoardSetText("0", 7, 2)
    exScoreBoardSetText("倒计时", 8, 1)
    exScoreBoardSetText("--:--", 8, 2)
    exScoreBoardSetText("抽卡等级", 9, 1)
    exScoreBoardSetText("Lv.1", 9, 2)
    exScoreBoardSetText("概率", 10, 1)
    exScoreBoardSetText("T1 100%", 10, 2)
    ChoukaHudScoreBoardReady = 1
    _LOG("HUD：右上角计分板已建立")
end

-- ---------------- 场上单位数（以 craneN 当本方锚点） ----------------

function ChoukaHudCountUnits(crane)
    if ChoukaHudUnitFilter == nil then
        ChoukaHudUnitFilter = CreateObjectFilter({
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
    local units, count = ObjectFindObjects(crane, nil, ChoukaHudUnitFilter)
    if count == nil then
        return 0
    end
    return count
end

-- ---------------- 每秒刷新 ----------------

ChoukaMarkNodeReady("HUD")
ChoukaHudInitScoreBoard()

-- 回合 / 倒计时数值（倒计时由 02_private_box.lua 每秒推进，这里只读）
local hudRound = CHOUKA_ROUND or 0
if CHOUKA_BOX_LEFT == nil then
    if CHOUKA_BOX_SECONDS ~= nil then
        CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
    else
        CHOUKA_BOX_LEFT = 120
    end
end
if CHOUKA_BOX_LEFT < 0 then
    CHOUKA_BOX_LEFT = 0
end
local hudRemainMinutes = floor(CHOUKA_BOX_LEFT / 60)
local hudRemainSeconds = CHOUKA_BOX_LEFT - hudRemainMinutes * 60

local hudLevel = ChoukaDrawLevel or 1
local hudWeights = nil
if ChoukaGetLevelWeights ~= nil then
    hudWeights = ChoukaGetLevelWeights(hudLevel)
end
if hudWeights == nil then
    hudWeights = ChoukaDrawTierWeights or { 100, 0, 0, 0, 0 }
end

local hudCountdownText = format("%02d:%02d", hudRemainMinutes, hudRemainSeconds)
local hudProbText = format("T1 %d%%  T2 %d%%  T3 %d%%  T4 %d%%  T5 %d%%",
    hudWeights[1] or 0, hudWeights[2] or 0, hudWeights[3] or 0,
    hudWeights[4] or 0, hudWeights[5] or 0)

-- ① 右上角：每人一行单位数 + 回合/倒计时/等级/概率
if ChoukaHudScoreBoardReady == 1 then
    for i = 1, 6, 1 do
        local crane = GetObjectByScriptName((ChoukaCranePrefix or "crane") .. i)
        local count = 0
        if ObjectIsAlive(crane) then
            count = ChoukaHudCountUnits(crane)
        end
        exScoreBoardSetText(format("  %d", count), i, 2)
    end
    exScoreBoardSetText(format("%d", hudRound), 7, 2)
    exScoreBoardSetText(hudCountdownText, 8, 2)
    exScoreBoardSetText(format("Lv.%d", hudLevel), 9, 2)
    exScoreBoardSetText(hudProbText, 10, 2)
end

-- ② 左下角：只给真人玩家画（AI 座位没有客户端）
for i = 1, 6, 1 do
    local isHuman = 0
    if type(EvaluateCondition) == "function" then
        if EvaluateCondition("PLAYER_IS_HUMAN_OR_AI_PERSONALITY", "Player_" .. i, "Human") then
            isHuman = 1
        end
    else
        isHuman = 1
    end
    if isHuman == 1 and ChoukaHudCreateForPlayer(i) == 1 then
        local playerName = "Player_" .. i
        ChoukaHudUpdateText(playerName, CHOUKA_HUD_ROUND_INDEX, format("回合数：%d", hudRound))
        ChoukaHudUpdateText(playerName, CHOUKA_HUD_COUNTDOWN_INDEX, "盲盒刷新倒计时：" .. hudCountdownText)
        ChoukaHudUpdateText(playerName, CHOUKA_HUD_LEVEL_INDEX, format("抽卡等级：Lv.%d", hudLevel))
        ChoukaHudUpdateText(playerName, CHOUKA_HUD_PROB1_INDEX, hudProbText)
    end
end

ChoukaHudReady = 1