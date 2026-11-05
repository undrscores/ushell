.pragma library

// Tiny safe calculator (no eval). + - * / % ^ ( ), decimals, a few functions and constants.
// Returns a display string, or null if the text isn't a calculation.

const FUNCS = {
    sqrt: Math.sqrt, abs: Math.abs, sin: Math.sin, cos: Math.cos, tan: Math.tan,
    ln: Math.log, log: Math.log10, exp: Math.exp, round: Math.round, floor: Math.floor, ceil: Math.ceil
}
const CONSTS = { pi: Math.PI, e: Math.E }

function evaluate(src) {
    const s = src.toLowerCase().replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".")
    let i = 0
    const fail = () => { throw new Error("bad") }

    function expr() {
        let v = term()
        while (s[i] === "+" || s[i] === "-") { const op = s[i++]; const r = term(); v = op === "+" ? v + r : v - r }
        return v
    }
    function term() {
        let v = unary()
        while (s[i] === "*" || s[i] === "/" || s[i] === "%") {
            const op = s[i++]; const r = unary()
            v = op === "*" ? v * r : (op === "/" ? v / r : v % r)
        }
        return v
    }
    function unary() {
        if (s[i] === "-") { i++; return -unary() }
        if (s[i] === "+") { i++; return unary() }
        return power()
    }
    function power() {
        const b = atom()
        if (s[i] === "^") { i++; return Math.pow(b, unary()) }   // right-associative
        return b
    }
    function atom() {
        if (s[i] === "(") { i++; const v = expr(); if (s[i] !== ")") fail(); i++; return v }
        const m = s.slice(i).match(/^(\d+\.?\d*|\.\d+)/)
        if (m) { i += m[0].length; return parseFloat(m[0]) }
        const w = s.slice(i).match(/^[a-z]+/)
        if (!w) fail()
        i += w[0].length
        if (w[0] in CONSTS) return CONSTS[w[0]]
        if (w[0] in FUNCS && s[i] === "(") { i++; const v = expr(); if (s[i] !== ")") fail(); i++; return FUNCS[w[0]](v) }
        return fail()
    }

    const v = expr()
    if (i !== s.length) fail()
    return v
}

function format(v) {
    if (!isFinite(v)) return null
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v)
    return String(parseFloat(v.toPrecision(12)))
}

// Only treat input as a calculation if it has an operator between operands or a function call.
function tryCalc(text) {
    const t = text.trim()
    if (!/\d/.test(t)) return null
    if (!/[\d)pie][+\-*/^%×÷]|[a-z]+\(/i.test(t.replace(/\s+/g, ""))) return null
    try { return format(evaluate(t)) } catch (e) { return null }
}
