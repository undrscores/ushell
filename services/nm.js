.pragma library

// Helpers for `nmcli -t` (terse) output. Fields are separated by ':'; a literal ':' or '\' inside a
// field is escaped with a backslash.

function splitTerse(line) {
    const out = []
    let cur = ""
    for (let i = 0; i < line.length; i++) {
        const c = line[i]
        if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
        if (c === ":") { out.push(cur); cur = ""; continue }
        cur += c
    }
    out.push(cur)
    return out
}

function lines(text) { return text.split("\n").filter(l => l.length > 0) }

// `nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status` -> the connection the machine uses to reach the
// network: wired wins over wifi. Returns { kind: "ethernet" | "wifi" | "none", name, device, wifiPresent }.
function parseStatus(text) {
    let best = { kind: "none", name: "", device: "", wifiPresent: false }
    for (const l of lines(text)) {
        const [device, type, state, conn] = splitTerse(l)
        if (type === "wifi") best.wifiPresent = true
        if (state !== "connected") continue
        if (type === "ethernet") { best.kind = "ethernet"; best.name = conn; best.device = device }
        else if (type === "wifi" && best.kind !== "ethernet") { best.kind = "wifi"; best.name = conn; best.device = device }
    }
    return best
}

// `nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list` -> one entry per SSID (strongest signal), the
// connected one first, then by signal. Hidden networks (no SSID) are skipped.
function parseWifi(text, savedNames) {
    const saved = savedNames || []
    const best = {}
    for (const l of lines(text)) {
        const [inUse, ssid, signal, security] = splitTerse(l)
        if (!ssid) continue
        const e = { ssid: ssid, signal: parseInt(signal) || 0, security: security || "",
                    secured: !!security && security !== "--", active: inUse === "*", saved: saved.includes(ssid) }
        const prev = best[ssid]
        if (!prev) best[ssid] = e
        else {
            if (e.signal > prev.signal) prev.signal = e.signal
            if (e.active) prev.active = true
        }
    }
    return Object.values(best).sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
}

// `nmcli -t -f NAME,TYPE connection show` -> names of saved wifi profiles
function parseSavedWifi(text) {
    return lines(text).map(splitTerse).filter(f => f[1] === "802-11-wireless").map(f => f[0])
}

// `nmcli -t -f NAME,TYPE,ACTIVE connection show` -> VPN and WireGuard profiles: [{ name, type, active }], active first
function parseVpn(text) {
    return lines(text).map(splitTerse)
        .filter(f => f[1] === "vpn" || f[1] === "wireguard")
        .map(f => ({ name: f[0], type: f[1], active: f[2] === "yes" }))
        .sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name))
}

// 0..3 bars from a 0..100 signal strength
function bars(signal) { return signal >= 75 ? 3 : signal >= 50 ? 2 : signal >= 25 ? 1 : 0 }
