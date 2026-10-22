-- ============================================================
-- 详见 docs/10-Lua注释存档.md §00_init-1
-- ============================================================

local BASE_MONEY  = 5096      -- 开局资金兜底（房主确认开局时 03_start.lua 会按选择**重设**一次）
local BASE_POWER  = 100000    -- 基础电力（够大即视为无限）
local BOX_SECONDS = 120       -- 箱子刷新间隔（秒）；真正推进倒计时的是 02_private_box.lua

for i = 1, 6, 1 do
    local playerName = "Player_" .. i
    -- 视野：全图永久常亮
    ExecuteAction("MAP_REVEAL_ALL_PERM", playerName)
    -- 电力：虚空电力，不依赖任何电厂
    ExecuteAction("PLAYER_SET_BASE_POWER", playerName, BASE_POWER)
    -- 建造栏：整条关掉（这是地图侧唯一干净的"全锁"开关）
    ExecuteAction("PLAYER_DISABLE_BASE_CONSTRUCTION", playerName)
    -- 资金：直接**设为** 5096（= 2 抽），不去叠加酒馆里的初始资金
    ExecuteAction("PLAYER_SET_MONEY", playerName, BASE_MONEY)
end

-- 详见 docs/10-Lua注释存档.md §00_init-2
ExecuteAction("SET_MILLISECOND_TIMER", "box", BOX_SECONDS)

-- 详见 docs/10-Lua注释存档.md §00_init-3
CHOUKA_BOX_SECONDS = CHOUKA_BOX_SECONDS or BOX_SECONDS
CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
CHOUKA_ROUND = CHOUKA_ROUND or 0
CHOUKA_GAME_STARTED = CHOUKA_GAME_STARTED or 0