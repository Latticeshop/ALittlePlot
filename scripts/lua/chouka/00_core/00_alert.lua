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

-- ★ 我方播报用独占名字，绝不抢通用全局名（全局 _ALERT 已被本图别的脚本占用且是哑的）
--   完整来龙去脉见 docs/03 §8「不要去抢通用全局名」；新代码一律用 ChoukaAlert / ChoukaAlertFor。

function ChoukaAlert(msg)
    if msg == nil then
        return
    end
    -- ① 日志（唯一确认可靠的通道，必须第一个调）
    _LOG(msg)
    -- ② 左下消息区
    if type(exMessageAppendToMessageArea) == "function" then
        exMessageAppendToMessageArea("[抽卡hex] " .. msg)
    end
    -- ③ 公屏（全场可见，阵亡通报/占领播报靠它）
    if type(exAddTextToPublicBoard) == "function" then
        exAddTextToPublicBoard(msg, 10)
    end
end

-- 带显示时长的版本（公告类用长一点）
function ChoukaAlertFor(msg, seconds)
    if msg == nil then
        return
    end
    _LOG(msg)
    if type(exMessageAppendToMessageArea) == "function" then
        exMessageAppendToMessageArea("[抽卡hex] " .. msg)
    end
    if type(exAddTextToPublicBoard) == "function" then
        if seconds == nil then
            seconds = 10
        end
        exAddTextToPublicBoard(msg, seconds)
    end
end

-- 真实昵称缓存：exGetPlayerNickNameByScriptName 查到的玩家名（查一次就记住）
ChoukaPlayerNames = ChoukaPlayerNames or {}

-- ① 公屏 / 计分板 / 消息区用：真实昵称；拿不到就退回 $p<N>Name（这些通道会替换）
function ChoukaPlayerDisplayName(seat)
    local name = ChoukaPlayerPlainName(seat)
    if name ~= nil then
        return name
    end
    if seat == nil then
        return "?"
    end
    return format("$p%dName", seat)
end

-- ② 顶部按钮悬浮框 / 对话框 desc 用：这些通道**不替换** $p<N>Name（实测原样显示 $p6Name），
--    所以必须拿到真实字符串；拿不到返回 nil，让调用方兜底成"6 号位"。详见 docs/03 §8.1。
--    注意：exGetPlayerNickNameByScriptName 在参考脚本里已被官方删除（38_code.txt:108
--    "该功能已被删除"），所以这里要容忍"接口不存在"和"返回占位符"两种结果。
function ChoukaPlayerPlainName(seat)
    if seat == nil then
        return nil
    end
    local cached = ChoukaPlayerNames[seat]
    if cached ~= nil then
        if cached == 0 then
            return nil
        end
        return cached
    end
    local name = nil
    if type(exGetPlayerNickNameByScriptName) == "function" then
        name = exGetPlayerNickNameByScriptName("Player_" .. seat)
    end
    if name == nil or name == "" or strsub(name, 1, 2) == "$p" then
        ChoukaPlayerNames[seat] = 0
        _LOG("玩家名字：Player_" .. seat .. " 没有可用的真实昵称，悬浮框改用座位号")
        return nil
    end
    ChoukaPlayerNames[seat] = name
    _LOG("玩家名字：Player_" .. seat .. " = " .. name)
    return name
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