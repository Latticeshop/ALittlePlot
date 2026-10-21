#!/usr/bin/env node
/**
 * sync-scriptsdata.js
 * ----------------------------------------------------------------------------
 * 把 lua/chouka/*.lua 回填进 ScriptsData.json 里对应的 #!ra3luabridge payload。
 * 思路照抄《日冕自走棋(DSA)》工程里的 analysis/tools/lua_payload.py + sync_scriptsdata.py：
 *   · lua/** 是唯一真源，ScriptsData.json 里的 payload 是生成物；
 *   · payload = "#!ra3luabridge\r\n" + 源文件全文（CRLF，去掉尾部空行）；
 *   · 单个 payload 上限 65536 B，超了 WorldBuilder 会截断，游戏内报
 *     `last token read: '<eof>'` 语法错误 —— 这里直接报错，不写坏包。
 *
 * 用法：
 *   node tools/sync-scriptsdata.js            # 生成 scripts/ScriptsData.json
 *   node tools/sync-scriptsdata.js --check    # 只算体积，不写文件
 *
 * 生成出来的 ScriptsData.json 用日冕「JSON 地编」导入地图（手动导入，不走 MCP）。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');           // ...\ALittlePlot
const SCRIPTS_DIR = path.join(ROOT, 'scripts');
const OUT_JSON = path.join(SCRIPTS_DIR, 'ScriptsData.json');

const PAYLOAD_PREFIX = '#!ra3luabridge\r\n';
const PAYLOAD_HARD_LIMIT = 65536;
const PAYLOAD_WARN_LIMIT = 64512;

/** 一个地编脚本节点 = 一个或多个 Lua 文件拼成的一段 payload（DSA 也是这么拼的）。顺序即执行顺序。 */
const NODES = [
    {
        // ★ 自检 / 心跳：必须排第一。整局每 10 秒往日志写一行
        //   （CoronaData/Logs/EnhancerCorona-*.dll.log），说明"脚本还活着、开局门控过了没、
        //   回合/倒计时在不在动、哪些节点真的跑起来了"。前面任何节点报错都不影响它。
        file: 'lua/chouka/00_selfcheck.lua',
        folder: '抽卡hex',
        name: '自检',
        evaluationInterval: 1,
        deactivateUponSuccess: false,
    },
    {
        // ★ 开局：锁视角 + 全屏公告 + 房主选配置 + 正式开始（照 DSA 的三段开局，去掉运镜）
        //   必须排在最前面：它定义了 onUserBtnChoiceDialogEvent / onUserLongTextDialogEvent
        //   的分发器，后面的「按钮栏」节点只往分发器里注册自己的处理函数。
        //   常驻（不一次性停用）：回调函数要靠它每秒重新定义一次。
        //   CHOUKA_GAME_STARTED 是全场开局门控，收入/盲盒/军犬/中央/按钮都看它。
        file: 'lua/chouka/03_start.lua',
        folder: '抽卡hex',
        name: '开局',
        evaluationInterval: 1,       // 一秒节点：等待期重钉视角、重刷中心提示
        deactivateUponSuccess: false,
    },
    {
        // ★ 引擎随机箱清理：照 DSA PureDraw/06_init_mcv.lua:43-79 的两段延迟删除，
        //   除了 02_private_box / 06_center 在预设点位刷的箱子，场上不出现任何自然随机箱。
        //   每帧节点 + 自己的帧计数（1 帧删生成器 → 45 帧清已落地的实体箱 → 前 2 分钟每 10 秒兜底）。
        //   不能一次性停用，否则 45 帧那一遍跑不到。
        file: 'lua/chouka/07_crates.lua',
        folder: '抽卡hex',
        name: '随机箱清理',
        evaluationInterval: 0,       // 每帧
        deactivateUponSuccess: false,
    },
    {
        // 初始化节点：抽卡等级表要先于一切（交易市场按钮、HUD、抽卡都用它）
        files: [
            'lua/chouka/09_level.lua',
            'lua/chouka/00_init.lua',
        ],
        folder: '抽卡hex',
        name: '初始化',
        evaluationInterval: 0,       // 每帧求值
        deactivateUponSuccess: true, // 成功一次即自我停用
    },
    {
        file: 'lua/chouka/01_income.lua',
        folder: '抽卡hex',
        name: '收入',
        evaluationInterval: 1,      // 约 1 秒一次
        deactivateUponSuccess: false,
    },
    {
        // 私有箱：**每秒节点自己数秒**（原来 interval 直接吃 BOX_SECONDS=120）。
        // 原因见 02_private_box.lua 文件头：节点间隔从进游戏算起，和"房主确认开局"
        // 那个时间点对不齐，改成每秒节点 + 自己数 CHOUKA_BOX_LEFT 才准。
        file: 'lua/chouka/02_private_box.lua',
        folder: '抽卡hex',
        name: '私有箱',
        evaluationInterval: 1,
        deactivateUponSuccess: false,
    },
    {
        // 单位出生事件登记：整表登记（gen_allunits.lua = 日冕单位信息汇总.txt 全表）
        // 必须在任何单位出生前跑完，所以排在初始化后面、抽卡初始化前面。
        // 只跑一次（deactivateUponSuccess），但 onUnitCreateEvent 是全局函数，登记与它都常驻。
        files: [
            'lua/chouka/gen_allunits.lua',
            'lua/chouka/11a_register.lua',
        ],
        folder: '抽卡hex',
        name: '单位登记',
        evaluationInterval: 0,
        deactivateUponSuccess: true,
    },
    {
        // 抽卡系统：数据 → 卡池 → 替换/帧队列，拼成一次性初始化
        files: [
            'lua/chouka/09a_watermask.lua',      // 地图掩码（从地图预览图提取的海陆），必须先于判定脚本
    'lua/chouka/10_puredraw_data.lua',
            'lua/chouka/gen_pool.lua',
            'lua/chouka/12_puredraw_replace.lua',
        ],
        folder: '抽卡hex',
        name: '抽卡初始化',
        evaluationInterval: 0,
        deactivateUponSuccess: true,
    },
    {
        // 保底军犬 + 中央油井：放在"抽卡初始化"之后，才能用上卡池表与 CHOUKA_ROUND。
        // 拆成两个节点，一边出错不会把另一边也带死。
        file: 'lua/chouka/05_dog.lua',
        folder: '抽卡hex',
        name: '保底军犬',
        evaluationInterval: 1,
        deactivateUponSuccess: false,
    },
    {
        file: 'lua/chouka/06_center.lua',
        folder: '抽卡hex',
        name: '中央油井',
        evaluationInterval: 1,
        deactivateUponSuccess: false,
    },
    {
        // 解锁科技：玩家造不了建筑、也买不到科技协议，索性开局全发下去。
        // 名单 = 双兵种 Tech_Upgrade + Enhanced_Tech_Upgrade + DSA upgrades + UpgradeEnum 全量，
        // 含龙船（青龙战斗核心舰）全套升级。
        files: [
            'lua/chouka/gen_upgrades.lua',
            'lua/chouka/15_upgrades.lua',
        ],
        folder: '抽卡hex',
        name: '解锁科技',
        evaluationInterval: 1,       // 一秒节点：科技表就绪后再发，和"发技能"同一个理由
        deactivateUponSuccess: true,
    },
    {
        // 发抽卡技能（单抽 + 十连）单独放一秒节点，不塞进第 0 帧的初始化里：
        // 第 0 帧玩家的科技/技能表可能还没就绪，晚一秒更稳（DSA 也是等建筑发放时才发）。
        // ★ 不能一次性停用 —— 房主确认开局之后才发技能（脚本内部门控 CHOUKA_GAME_STARTED），
        //   而节点从进游戏 1 秒就开始求值，一次性会在"还没开局"时就自我停用。
        file: 'lua/chouka/14_grant_draw.lua',
        folder: '抽卡hex',
        name: '发技能',
        evaluationInterval: 1,
        deactivateUponSuccess: false,
    },
    {
        // 顶部按钮栏：3 = 交易市场、4 = 海克斯（1/2/5/6 留空），点开是选择对话框
        // 不能一次性停用：教程要求 Show 之后等 1~2 帧才能设"启用"，脚本内部靠
        // ChoukaBtnStage 分两次求值完成（0→1 建、1→2 启用），之后空转即可。
        file: 'lua/chouka/16_buttons.lua',
        folder: '抽卡hex',
        name: '按钮栏',
        evaluationInterval: 1,       // 一秒节点
        deactivateUponSuccess: false,
    },
    {
        // AI 对手（电脑）：
        //   ① 每回合给每个电脑座位免费抽 1 个单位（走同一套卡池/阵营池/水陆判定，
        //      概率取"自动升级"那条线）—— 模拟电脑也在抽卡
        //   ② 周期扫描非玩家阵营（PlyrCivilian / PlyrCreeps）的单位，
        //      照 DSA PureDrawJoinAIAttackTeam 塞进 "<阵营>/ATTACK" 攻击队，
        //      让原本站着不动的中立单位主动去打玩家
        // 不能一次性停用：整局都要跑（脚本内部靠 CHOUKA_ROUND 变化触发抽卡）
        file: 'lua/chouka/17_ai.lua',
        folder: '抽卡hex',
        name: 'AI对手',
        evaluationInterval: 1,       // 一秒节点：回合变化判定 + 5 秒一次的扫场
        deactivateUponSuccess: false,
    },
    {
        file: 'lua/chouka/13_frame_loop.lua',
        folder: '抽卡hex',
        name: '帧循环',
        evaluationInterval: 0,       // 每帧：消费帧延迟队列（截获要等 3 帧再删批）
        deactivateUponSuccess: false,
    },
    {
        file: 'lua/chouka/20_hud.lua',
        folder: '抽卡hex',
        name: 'HUD',
        evaluationInterval: 1,       // 约 1 秒：刷计分板与左下角倒计时
        deactivateUponSuccess: false,
    },
];

// 地编里这些 *_IGNORE 字段只给人看，编译器不读；照 DSA 的原样写上，方便在编辑器里核对。
const CONDITION_TRUE = {
    Name: 'CONDITION_TRUE',
    Name_EN_IGNORE: '[3] Scripting/True.',
    Name_ZH_IGNORE: '[3] 真实 真',
    ArgumentsDesc_IGNORE: ' True.',
    ArgumentsType_IGNORE: [],
};

const LUA_ACTION = {
    Name: 'DEBUG_MESSAGE_BOX',
    Name_EN_IGNORE: '[0] Scripting/Debug/Display message and pause',
    Name_ZH_IGNORE: '[0] 显示消息和暂停',
    ArgumentsDesc_IGNORE: ' Show debug string and pause: ',
    ArgumentsType_IGNORE: ['String'],
};

function readLuaBody(relPath) {
    const abs = path.join(SCRIPTS_DIR, relPath);
    if (!fs.existsSync(abs)) throw new Error(`找不到 Lua 源文件：${abs}`);
    let text = fs.readFileSync(abs, 'utf8');

    // ★★ 致命坑（2026-10 实测踩过一次，一次废掉 10 个节点）：
    //    Windows PowerShell 的 `Set-Content -Encoding utf8` 会写 UTF-8 BOM（EF BB BF）。
    //    BOM 拼进 payload 后落在 `#!ra3luabridge` 之后，Lua 4.0 把 EF BB BF 当非法 token
    //    → 整个节点的 payload 解析失败 → **该节点静默不执行**（游戏里什么都不发生，也没有报错）。
    //    这里读到 BOM 直接报错拦下，绝不生成坏包。
    if (text.charCodeAt(0) === 0xFEFF) {
        throw new Error(
            `${relPath} 开头有 UTF-8 BOM，会让整个节点的 payload 解析失败（Lua 4.0 不认 EF BB BF）；` +
            `请存成「UTF-8 无 BOM」：node .dsh-tools/scratch/strip_bom.js`);
    }

    text = text.replace(/\r?\n/g, '\r\n').replace(/(\r\n)+$/, '');
    if (text.indexOf(PAYLOAD_PREFIX) === 0) {
        throw new Error(`${relPath} 里不要自己写 ${PAYLOAD_PREFIX.trim()} 前缀，工具会加`);
    }
    return text;
}

/** 节点可以有多个源文件（按顺序拼接成一段 payload，DSA 的 61KB 节点就是 6 个文件拼的）。 */
function nodeFiles(node) {
    return node.files || [node.file];
}

/**
 * ★ 所有节点都会先拼上这个文件：诊断通道（_LOG / _ALERT / 节点自检）。
 * 2026-10 实测教训：只走 exAddTextToPublicBoard 的播报整局一条都没显示，
 * 结果"流程断在哪"完全没法判断。现在统一由 00_alert.lua 三路输出。
 */
const SHARED_PRELUDE = ['lua/chouka/00_alert.lua'];

function filesWithPrelude(node) {
    return SHARED_PRELUDE.concat(nodeFiles(node));
}

function nodeLabel(node) {
    return (node.files || [node.file]).join(' + ');
}

function readNodeBody(node) {
    const bodies = filesWithPrelude(node).map(readLuaBody);
    return bodies.join('\r\n\r\n');
}

/** 节点间隔：可以直接写死，也可以从 lua 里读常量（避免"改了 lua 忘了改 JSON"）。 */
function resolveInterval(node, body) {
    if (!node.intervalFromLua) {
        return node.evaluationInterval;
    }
    const { constant, fallback } = node.intervalFromLua;
    // 允许写成 local X = 120 或 X = 120（Lua 4.0 桥里函数体读不到外层 local，所以也可能是全局）
    const matched = new RegExp(`(?:local\\s+)?\\b${constant}\\s*=\\s*(\\d+)`).exec(body);
    if (!matched) {
        console.warn(`  ! ${nodeLabel(node)} 里没找到 ${constant} = <数字>，回退用 ${fallback}`);
        return fallback;
    }
    const value = Number(matched[1]);
    return value > 0 ? value : fallback;
}

function buildScriptNode(node) {
    const body = readNodeBody(node);
    const payload = PAYLOAD_PREFIX + body;
    const size = Buffer.byteLength(payload, 'utf8');
    const interval = resolveInterval(node, body);

    if (size > PAYLOAD_HARD_LIMIT) {
        throw new Error(
            `${nodeLabel(node)} 的 payload 为 ${size} B，超过 ${PAYLOAD_HARD_LIMIT} B 上限` +
            `（还超 ${size - PAYLOAD_HARD_LIMIT} B）；请拆成新的 lua 文件/节点`);
    }

    return {
        size,
        interval,
        stripped: false,
        script: {
            Type: 'Script',
            Name: node.name,
            DeactivateUponSuccess: node.deactivateUponSuccess,
            EvaluationInterval: interval,
            If: [[CONDITION_TRUE]],
            Then: [{ ...LUA_ACTION, Arguments: [payload] }],
            Else: [],
        },
    };
}

function main() {
    const checkOnly = process.argv.includes('--check');
    const folders = new Map();   // folder -> [script...]
    const sizes = [];

    for (const node of NODES) {
        const built = buildScriptNode(node);
        if (!folders.has(node.folder)) folders.set(node.folder, []);
        folders.get(node.folder).push(built.script);
        sizes.push({ size: built.size, label: `${node.folder}/${node.name}` });
        const warn = built.size > PAYLOAD_WARN_LIMIT ? '   <== 贴近上限' : '';
        const label = `${node.folder}/${node.name}`.padEnd(20, ' ');
        const sizeText = String(built.size).padStart(6, ' ');
        const leftText = String(PAYLOAD_HARD_LIMIT - built.size).padStart(6, ' ');
        console.log(
            `  ${label} ${sizeText} B (余 ${leftText} B)  interval=${built.interval}${warn}`);
    }

    // 整张图只有一个根脚本列表（PlayerName = ""）：本图的机制全部与"具体玩家"无关，
    // Lua 里按 Player_1..Player_6 自己循环，所以不需要往每个玩家列表塞脚本。
    const tree = [{
        PlayerName: '',
        Content: Array.from(folders.entries()).map(([name, content]) => ({
            Type: 'Folder',
            Name: name,
            Content: content,
        })),
    }];

    if (checkOnly) {
        console.log('\ncheck-only：未写文件');
        return;
    }

    fs.mkdirSync(path.dirname(OUT_JSON), { recursive: true });
    // ensure_ascii = false：中文直接以 UTF-8 原文写入（DSA 的海克斯节点也是这么写的）
    fs.writeFileSync(OUT_JSON, JSON.stringify(tree, null, 2) + '\n', 'utf8');

    // 回读校验：能 parse、节点数对、每个 payload 都能原样取回
    const back = JSON.parse(fs.readFileSync(OUT_JSON, 'utf8'));
    const scripts = back[0].Content[0].Content;
    if (scripts.length !== NODES.length) {
        throw new Error(`回读校验失败：节点数 ${scripts.length} != ${NODES.length}`);
    }
    for (const s of scripts) {
        const payload = s.Then[0].Arguments[0];
        if (payload.slice(0, PAYLOAD_PREFIX.length) !== PAYLOAD_PREFIX) {
            throw new Error(`回读校验失败：${s.Name} 的 payload 前缀不对`);
        }
    }

    console.log(`\n已写出 ${OUT_JSON}`);
    console.log(`  根列表 PlayerName=""，文件夹「抽卡hex」，脚本 ${scripts.length} 条`);
}

main();
