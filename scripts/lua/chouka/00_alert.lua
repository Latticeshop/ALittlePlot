-- ============================================================

if _LOG == nil then
    function _LOG(msg)
        if type(exPrintln) == "function" then
            exPrintln("[抽卡hex] " .. msg)
        end
    end
end

if _ALERT == nil then
    function _ALERT(msg)
        _LOG(msg)
        if type(exMessageAppendToMessageArea) == "function" then
            exMessageAppendToMessageArea("[抽卡hex] " .. msg)
        end
        if type(exAddTextToPublicBoard) == "function" then
            exAddTextToPublicBoard(msg, 10)
        end
    end
end

-- 节点自检表：哪个节点的 payload 真的跑起来过（只记一次）
ChoukaNodeReady = ChoukaNodeReady or {}

function ChoukaMarkNodeReady(nodeName)
    if ChoukaNodeReady[nodeName] == nil then
        ChoukaNodeReady[nodeName] = 1
        _LOG("节点就绪：" .. nodeName)
    end
end

-- 已经就绪的节点名，拼成一行字符串（给心跳日志用）
function ChoukaNodeReadyList()
    local list = ""
    for name, flag in ChoukaNodeReady do
        if list == "" then
            list = name
        else
            list = list .. "," .. name
        end
    end
    if list == "" then
        return "无"
    end
    return list
end

-- ============================================================
-- 详见 docs/10-Lua注释存档.md §00_alert-1
-- ============================================================