-- ============================================================
-- 详见 docs/10-Lua注释存档.md §13_frame_loop-1
-- ============================================================

-- ① 开局兜底
ChoukaMarkNodeReady("帧循环")

ChoukaFrameCount = (ChoukaFrameCount or 0) + 1
if CHOUKA_GAME_STARTED ~= 1 and ChoukaFrameCount > 2700 then
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
    _ALERT(ChoukaT.frameTimeout)
end

-- ② 帧延迟队列
if ChoukaFrameTick ~= nil then
    ChoukaFrameTick()
end