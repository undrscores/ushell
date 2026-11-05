// Run: node scripts/test-dnd.js   (tests services/dnd.js)
const fs = require("fs"), vm = require("vm"), assert = require("assert")
const ctx = {}; vm.createContext(ctx)
vm.runInContext(fs.readFileSync(__dirname + "/../services/dnd.js", "utf8").replace(".pragma library", ""), ctx)
const at = (h, m) => new Date(2026, 0, 1, h, m)
const t = (name, fn) => { fn(); console.log("ok  " + name) }
t("same-day window", () => {
    assert.ok(ctx.inWindow("09:00", "17:00", at(9, 0))); assert.ok(ctx.inWindow("09:00", "17:00", at(16, 59)))
    assert.ok(!ctx.inWindow("09:00", "17:00", at(17, 0))); assert.ok(!ctx.inWindow("09:00", "17:00", at(8, 59)))
})
t("window across midnight", () => {
    assert.ok(ctx.inWindow("22:00", "07:00", at(23, 30))); assert.ok(ctx.inWindow("22:00", "07:00", at(0, 0)))
    assert.ok(ctx.inWindow("22:00", "07:00", at(6, 59))); assert.ok(!ctx.inWindow("22:00", "07:00", at(7, 0)))
    assert.ok(!ctx.inWindow("22:00", "07:00", at(12, 0))); assert.ok(ctx.inWindow("22:00", "07:00", at(22, 0)))
})
t("empty and invalid windows are never active", () => {
    assert.ok(!ctx.inWindow("08:00", "08:00", at(8, 0))); assert.ok(!ctx.inWindow("25:00", "07:00", at(1, 0))); assert.ok(!ctx.inWindow("", "", at(1, 0)))
})
