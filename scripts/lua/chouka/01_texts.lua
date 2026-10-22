-- ============================================================
-- 文案总表：**只放玩家看得见的文字**
--   日志文案（_LOG 里那些）不在这里，直接写在各自业务代码里，方便区分（docs/08 §7.6）
--   改文字直接改本文件；新增中文长句跑 tools/extract-texts.js 自动搬进来
-- ============================================================

ChoukaT = ChoukaT or {}

-- ============================================================
-- 公告 / 对话框（长文本窗口 + 房主配置页）
-- ============================================================
ChoukaT.waitHost = "请等待房主选择配置"
ChoukaT.announce =
    "作者：格格子 QQ群：618450478\n" ..
    "欢迎来到小块地抽卡hex！本地图有一套自定义抽卡系统，玩家使用日冕空投箱子抽卡获取单位，抢夺资源，击败其他玩家的起重机获取胜利！\n" ..
    "抽卡等级系统：抽卡单位严格按照当前抽卡等级，玩家可以花钱升级解锁更高科技单位的概率。\n" ..
    "购买防御塔：玩家可以在市场购买随机防御塔守护家园，最多四座！\n" ..
    "每回合会自动补充飞机弹药。\n" ..
    "登神盲盒：点位随机刷新的空白箱子，拾取后附近单位会获得随机属性提升，可无限叠加！"
ChoukaT.readDone = "已阅读"
ChoukaT.scopeAll = "箱子包括全部阵营"
ChoukaT.scopeOwn = "抽卡只有自己阵营"
ChoukaT.hostDialogTitle = "房主配置 · 抽卡hex"

-- ============================================================
-- 顶部按钮 / 交易市场
-- ============================================================
ChoukaT.btnMarket = "交易市场\n购买等级 / 购买防御塔"
ChoukaT.btnHextech = "海克斯\n本图暂未启用"
ChoukaT.btnLevelMax = "购买下一抽卡等级：已满级"
ChoukaT.btnLevelPrice = "购买下一抽卡等级：%d"
ChoukaT.btnTowerPrice = "购买随机T%d防御塔：%d"
ChoukaT.btnTowerNoMoney = "金币不足：T%d防御塔需要 %d"
ChoukaT.btnAirportPrice = "购买神州机场%d"
ChoukaT.airportNoPoint = "没找到你的机场点位（airport1~airport6），先在地图里补航点"
ChoukaT.airportExists = "机场点位上已经有神州机场了，不能重复购买"
ChoukaT.airportNoMoney = "金币不足：神州机场需要 %d"
ChoukaT.airportSpawnFail = "神州机场生成失败，钱已退回"
ChoukaT.airportBought = "已购买神州机场（花费 %d）"

-- ============================================================
-- 左上/左下 HUD
-- ============================================================
ChoukaT.hudTitle = "抽卡hex · 场上单位"
ChoukaT.hudCountdown = "盲盒刷新倒计时："

-- ============================================================
-- 提示与播报（公屏 / 飘字 / 消息栏）
-- ============================================================
ChoukaT.boxRefreshed = "第 %d 回合开始：私人箱子已刷新"
ChoukaT.hostTip = "你是房主：请在窗口里选好配置，然后点「确认，开始游戏」"
ChoukaT.hostPicking = "房主正在选择：%s"
ChoukaT.hostConfigDone = "房主已确认开局！抽卡范围：%s；第一轮盲盒将在 %d 秒后刷新"
ChoukaT.dogTip = "你手上没有工程师了，已在你家投放 1 只%s（去碰箱子抽卡！）"
ChoukaT.centerCrateRefreshed = "中央盲盒：第%d回合刷了%d个/6个点位"
ChoukaT.centerOilLocate = "中央油井定位：1号="
ChoukaT.centerOilCaptured = "中央油井%d 被 Player_%d 占领！"
ChoukaT.centerOilProgress = "中央油井%d 领先=%d 进度=%d 归属=%d 计数=%s"
ChoukaT.crateCleaned = "已清除 %d 个引擎随机箱子（本图只在预设点位刷箱）"
ChoukaT.levelAutoUp = "抽卡等级已自动升为%d级"
ChoukaT.levelMax = "抽卡等级已满（Lv.%d）"
ChoukaT.levelNoMoney = "金币不足：升到 Lv.%d 需要 %d"
ChoukaT.levelUp = "抽卡等级提升到 Lv.%d"
ChoukaT.frameTimeout = "开局流程超时，已自动放行（请检查 03_start.lua）"
ChoukaT.towerSlotsFull = "你的 4 个防御塔点位都已被占用"
ChoukaT.towerBadPos = "防御塔点位坐标异常，购买取消"
ChoukaT.towerSpawnFail = "防御塔生成失败（类型名可能不对）"
ChoukaT.towerBought = "已在 %d 号点位购买 T%d 防御塔（-%d）"
ChoukaT.aiPersona = "AI对手：人格参数\"AI\"不可用，改用\"非人类 + 有起重机 + 有钱\"判定电脑"
ChoukaT.aiDetected = "AI对手：Player_%d 是电脑，将每回合自动抽 1 个单位"
ChoukaT.aiDrawInfo = "AI对手：第%d回合，每个电脑抽 %d 个（合计 %d 个，概率按 Lv.%d）"
ChoukaT.aiAttackQueue = "AI攻击队列：%d 个非玩家阵营单位已加入攻击队"

-- 登神盲盒（AttributeCrate）：箱子被碰掉时只播报给箱主一个人
ChoukaT.ascendBox = "登神盲盒：%s 属性 提升 %d%%"
ChoukaT.ascendHealth = "血量"
ChoukaT.ascendDamage = "伤害"
ChoukaT.ascendRate = "攻速"
ChoukaT.ascendRange = "射程"