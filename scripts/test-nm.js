// Run: node scripts/test-nm.js   (tests services/nm.js against sample nmcli output)
const fs = require("fs"), vm = require("vm"), assert = require("assert"), J = JSON.stringify
const ctx = {}; vm.createContext(ctx)
vm.runInContext(fs.readFileSync(__dirname + "/../services/nm.js", "utf8").replace(".pragma library", ""), ctx)
const t = (name, fn) => { fn(); console.log("ok  " + name) }

t("splitTerse handles escapes", () => {
    assert.strictEqual(J(ctx.splitTerse("a:b\\:c:d\\\\e:")), J(["a", "b:c", "d\\e", ""]))
})
t("wired beats wifi", () => {
    const s = ctx.parseStatus("wlp8s0:wifi:connected:Home\neno1:ethernet:connected:Wired 1\nlo:loopback:connected (externally):lo\n")
    assert.strictEqual(s.kind, "ethernet"); assert.strictEqual(s.name, "Wired 1"); assert.ok(s.wifiPresent)
})
t("wifi only", () => {
    const s = ctx.parseStatus("wlp8s0:wifi:connected:Home\neno1:ethernet:unavailable:\n")
    assert.strictEqual(s.kind, "wifi"); assert.strictEqual(s.name, "Home")
})
t("nothing connected", () => {
    const s = ctx.parseStatus("eno1:ethernet:disconnected:\nlo:loopback:connected (externally):lo\n")
    assert.strictEqual(s.kind, "none"); assert.ok(!s.wifiPresent)
})
t("wifi list dedupes, sorts, skips hidden", () => {
    const l = ctx.parseWifi(" :Ziggo:52:WPA2\n ::84:WPA2\n*:Home:40:WPA2 WPA3\n :Ziggo:84:WPA2\n :Cafe:90:\n :Odd\\:Name:30:WPA2\n", ["Ziggo"])
    assert.strictEqual(J(l.map(n => n.ssid)), J(["Home", "Cafe", "Ziggo", "Odd:Name"]))
    assert.strictEqual(l[2].signal, 84); assert.ok(l[2].saved); assert.ok(!l[1].secured); assert.ok(l[0].active)
})
t("saved wifi profiles", () => {
    assert.strictEqual(J(ctx.parseSavedWifi("Wired 1:802-3-ethernet\nHome:802-11-wireless\n")), J(["Home"]))
})
t("bars", () => { assert.strictEqual(J([0, 24, 25, 50, 75, 100].map(ctx.bars)), J([0, 0, 1, 2, 3, 3])) })
