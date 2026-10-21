-- ============================================================
-- 抽卡hex · 每帧驱动
--
-- 对应 ScriptsData.json 节点：抽卡hex / 帧循环
--   EvaluationInterval     = 0     （每帧求值）
--   DeactivateUponSuccess  = false （常驻）
--   条件                   = CONDITION_TRUE
--
-- 现在做两件事：
--   ① 消费帧延迟队列（ChoukaDelayCall 排的活）
--   ② 倒数并结算抽卡批次：等 3 帧让引擎那一整批落地，再只删"出生事件收上来的 id"，
--      然后补 1 个卡池单位（不按半径扫场，旧单位不会被误吞）
-- 以后要加每帧逻辑（飘字、单位计数缓存…）也挂这里。
-- ============================================================

if ChoukaFrameTick ~= nil then
    ChoukaFrameTick()
end
