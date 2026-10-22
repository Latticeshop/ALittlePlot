// lua 源码里"某个位置被哪个函数调用包着"的小工具（两个文案工具共用）
//
// 做法：正向扫一遍源码，用栈记录"当前在哪些调用里"（跳过注释与字符串），
//       再按字符下标查这个栈。比从后往前找 '(' 稳，跨行/多参数都不会错。
exports.buildCallStacks = function (src) {
const n = src.length;
const stacks = [];          // 每个字符位置 → 当时的调用栈（只在需要的位置记录）
let i = 0;
let stack = [];
// 先做一张"下标 → 调用栈快照"的数组（只在 '(' 之后与 ')' 之前更新，用稀疏记录，最终按位置回填）
const events = [];          // { pos, stack }  栈的浅拷贝
while (i < n) {
    const c = src[i];
    if (c === '-' && src[i + 1] === '-') {
        while (i < n && src[i] !== '\n') i++;
        continue;
    }
    if (c === '"' || c === "'") {
        const q = c;
        i++;
        while (i < n) {
            if (src[i] === '\\') { i += 2; continue; }
            if (src[i] === q) { i++; break; }
            i++;
        }
        continue;
    }
    if (c === '(') {
        // 往前找调用者名字
        let e = i - 1;
        while (e >= 0 && /\s/.test(src[e])) e--;
        let s = e;
        while (s >= 0 && /[A-Za-z0-9_.]/.test(src[s])) s--;
        const name = src.slice(s + 1, e + 1);
        stack = stack.concat([name || '?']);
        events.push({ pos: i, stack });
        i++;
        continue;
    }
    if (c === ')') {
        if (stack.length) stack = stack.slice(0, stack.length - 1);
        events.push({ pos: i, stack });
        i++;
        continue;
    }
    i++;
}
// 把事件展开成"按位置可查"的数组：某位置 p 的调用栈 = 最后一个 pos < p 的事件里的栈
return { events, stackAt: function (p) {
    let lo = 0, hi = events.length - 1, found = null;
    while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (events[mid].pos < p) { found = events[mid]; lo = mid + 1; }
        else hi = mid - 1;
    }
    return found ? found.stack : [];
} };
};

/** 该位置最外层的"非包装"调用名（跳过 format/type/tostring），没有则返回 null */
exports.outerCallName = function (src, pos, built) {
const b = built || exports.buildCallStacks(src);
const chain = b.stackAt(pos);
for (let k = chain.length - 1; k >= 0; k--) {
    const name = chain[k];
    if (name === 'format' || name === 'type' || name === 'tostring' || name === '?') continue;
    return name;
}
return null;
};
