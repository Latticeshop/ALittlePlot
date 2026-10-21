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
        file: 'lua/chouka/02_private_box.lua',
        folder: '抽卡hex',
        name: '私有箱',
        // 间隔直接从 lua 里的 BOX_SECONDS 读，避免"改了 lua 忘了改这里"
        intervalFromLua: { constant: 'BOX_SECONDS', fallback: 120 },
        deactivateUponSuccess: false,
    },
    {
        // 抽卡系统：数据 → 卡池 → 钩子 → 替换/帧队列，拼成一次性初始化
        files: [
            'lua/chouka/10_puredraw_data.lua',
            'lua/chouka/gen_pool.lua',
            'lua/chouka/11_puredraw_hook.lua',
            'lua/chouka/12_puredraw_replace.lua',
        ],
        folder: '抽卡hex',
        name: '抽卡初始化',
        evaluationInterval: 0,
        deactivateUponSuccess: true,
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
        // 发抽卡技能单独放一秒节点，不塞进第 0 帧的初始化里：
        // 第 0 帧玩家的科技/技能表可能还没就绪，晚一秒更稳（DSA 也是等建筑发放时才发）。
        file: 'lua/chouka/14_grant_draw.lua',
        folder: '抽卡hex',
        name: '发技能',
        evaluationInterval: 1,
        deactivateUponSuccess: true,
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

function nodeLabel(node) {
    return (node.files || [node.file]).join(' + ');
}

function readNodeBody(node) {
    const bodies = nodeFiles(node).map(readLuaBody);
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
