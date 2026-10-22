-- ============================================================
-- 详见 docs/10-Lua注释存档.md §13_frame_loop-1
-- ============================================================

-- ① 开局兜底
ChoukaMarkNodeReady("帧循环")

ChoukaFrameCount = (ChoukaFrameCount or 0) + 1
if CHOUKA_GAME_STARTED ~= 1 and ChoukaFrameCount > 2700 then
    if CHOUKA_MODE == 1 then
        -- ★ 三国杀模式的保险丝整条让位（docs/11 §3③）：
        --     Stage 1 = 无限等房主（房主掉了直接重开，同 DSA 自走棋）
        --     Stage 2 = 由 32 号节点的 180 秒偏好超时接手
        --   CHOUKA_MODE 是"房主点选项那一刻"就写入的，所以房主在公告页慢慢琢磨
        --   也不会被这条兜底用默认玩法强行开局。
        if ChoukaBangFuseLogged ~= 1 then
            ChoukaBangFuseLogged = 1
            _LOG("三国杀模式：开局保险丝已让位，不再按 2700 帧强制放行")
        end
    else
    CHOUKA_GAME_STARTED = 1
    ChoukaStartStage = 2
    if type(ExecuteAction) == "function" then
        ExecuteAction("LOCK_CAMERA", 0)
        ExecuteAction("LOCK_CAMERA_SCROLL", 0)
        ExecuteAction("ENABLE_INPUT")
        for i = 1, 6, 1 do
            ExecuteAction("PLAYER_CAMERA_MOVE_TO", "Player_" .. i,
                "Player_" .. i .. "_Start", 0, 0, 0, 0)
        end
    end
    if type(exHideLongTextDialog) == "function" then
        exHideLongTextDialog()
    end
    if type(exAptShowObjectDetailsArea) == "function" then
        exAptShowObjectDetailsArea()
    end
    if CHOUKA_BOX_SECONDS ~= nil and (CHOUKA_BOX_LEFT == nil or CHOUKA_BOX_LEFT > CHOUKA_BOX_SECONDS) then
        CHOUKA_BOX_LEFT = CHOUKA_BOX_SECONDS
    end
    ChoukaAlert(ChoukaT.frameTimeout)
    end
end

-- ② 帧延迟队列
if ChoukaFrameTick ~= nil then
    ChoukaFrameTick()
end