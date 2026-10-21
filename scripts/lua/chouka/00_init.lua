-- ============================================================
-- 抽卡hex · 开局初始化（一次性）
--
-- 对应 ScriptsData.json：抽卡hex / 初始化
--   EvaluationInterval     = 0     （每帧求值）
--   DeactivateUponSuccess  = true  （成功执行一次后自我停用）
--   条件                   = CONDITION_TRUE
--   动作                   = DEBUG_MESSAGE_BOX("#!ra3luabridge ...")
--                            ↑ 由 Lua 桥接管，游戏内不会弹窗
--
-- 做五件事：
--   1. 全图常亮 —— 参考 盲盒高原：开局 MAP_REVEAL_ALL_PERM
--      （本图没有建造场、不靠"有建造场才开视野"那套；起重机是视野与核心）
--   2. 基础电力 = 100000 —— "无限电量"
--      PLAYER_SET_BASE_POWER 设的是「虚空电力」（基础电力），不需要电厂，
--      电厂被拆、电厂断电都不影响，比堆电厂稳。
--   3. 关闭建造栏 —— 玩家不能造任何建筑。起重机保持**完全可用**（可建造、
--      回收功能正常），锁的是建造栏本身，不是起重机。
--      ✅ 实测正解：PLAYER_DISABLE_BASE_CONSTRUCTION(player)
--         （编辑器动作表 editorNumber 56，"玩家不允许建造建筑"）
--      ❌ 不要用 ALLOW_DISALLOW_ALL_BUILDINGS —— 它在动作表里属于
--         "Unused or Obsolete"（editorNumber 284），实测是空操作。
--      ❌ 也不要靠"把起重机设成不可建造"——那会连带废掉起重机的回收功能。
--   4. 开局资金 —— 在酒馆初始资金之上再加一笔
--   5. 箱子倒计时 —— 与 02_private_box.lua 的刷新节拍对齐
--
-- ⚠ 参数必须与另外两个文件保持一致：
--      BOX_SECONDS ←→ 02_private_box.lua 的 BOX_SECONDS
--                        ←→ 私有箱 节点的 EvaluationInterval
-- ============================================================

local BASE_MONEY  = 5096      -- 开局资金：单抽 2480 × 2 抽（照自走棋/双兵种"由地图直接设定"的做法）
local BASE_POWER  = 100000    -- 基础电力（够大即视为无限）
local BOX_SECONDS = 120       -- 箱子刷新间隔（秒）

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

-- 箱子倒计时（界面上那个圆形计时）
-- 文案键 SCRIPT:box 已写进 map.str（"下一次盲盒"）；不想让引擎显示就删下面两行
ExecuteAction("SET_MILLISECOND_TIMER", "box", BOX_SECONDS)
ExecuteAction("DISPLAY_COUNTDOWN_TIMER", "box", "SCRIPT:box")

-- HUD 左下角那个数字用**我们自己的秒计数**，不去读引擎计时器
-- （实测 exCounterGetByName("box") 读 SET_MILLISECOND_TIMER 建的计时器恒为 0）
CHOUKA_BOX_LEFT = BOX_SECONDS
