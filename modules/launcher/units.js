.pragma library

// Unit conversion for the launcher: "5 km in mi", "20c to f", "3.5 gb to mib", "60 mph to km/h".
// Returns { text: "5 km = 3.10686 mi", value: "3.10686 mi" } or null when the text is not a conversion.

// factor to the category's base unit
var CATS = {
    length: { m: 1, km: 1000, cm: 0.01, mm: 0.001, um: 1e-6, nm: 1e-9, mi: 1609.344, yd: 0.9144, ft: 0.3048, "in": 0.0254, nmi: 1852 },
    mass:   { kg: 1, g: 0.001, mg: 1e-6, t: 1000, lb: 0.45359237, oz: 0.028349523125, st: 6.35029318 },
    volume: { l: 1, ml: 0.001, cl: 0.01, dl: 0.1, m3: 1000, gal: 3.785411784, qt: 0.946352946, pt: 0.473176473, cup: 0.2365882365,
              floz: 0.0295735295625, tbsp: 0.01478676478125, tsp: 0.00492892159375, impgal: 4.54609 },
    area:   { m2: 1, km2: 1e6, cm2: 1e-4, ha: 1e4, acre: 4046.8564224, ft2: 0.09290304, in2: 0.00064516, mi2: 2589988.110336 },
    time:   { s: 1, ms: 0.001, min: 60, h: 3600, d: 86400, wk: 604800, yr: 31557600 },
    data:   { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776,
              bit: 0.125, kbit: 125, mbit: 125000, gbit: 125000000 },
    speed:  { "m/s": 1, "km/h": 1 / 3.6, mph: 0.44704, kn: 1852 / 3600, "ft/s": 0.3048 },
    temp:   { c: 1, f: 1, k: 1 }
}

var ALIASES = {
    meter: "m", metre: "m", kilometer: "km", kilometre: "km", centimeter: "cm", centimetre: "cm", millimeter: "mm", millimetre: "mm",
    mile: "mi", yard: "yd", foot: "ft", feet: "ft", inch: "in", inches: "in", kph: "km/h", kmh: "km/h", kmph: "km/h", knot: "kn", knots: "kn",
    kilogram: "kg", kilo: "kg", gram: "g", pound: "lb", lbs: "lb", ounce: "oz", stone: "st", tonne: "t",
    liter: "l", litre: "l", milliliter: "ml", millilitre: "ml", gallon: "gal", quart: "qt", pint: "pt", cups: "cup", "fl oz": "floz",
    tablespoon: "tbsp", teaspoon: "tsp", second: "s", sec: "s", minute: "min", mins: "min", hour: "h", hr: "h", hrs: "h", day: "d", week: "wk", year: "yr",
    byte: "b", bytes: "b", celsius: "c", fahrenheit: "f", kelvin: "k", "°c": "c", "°f": "f", hectare: "ha",
    sqm: "m2", sqft: "ft2", "m²": "m2", "km²": "km2", "ft²": "ft2", "m³": "m3"
}

function find(u) {
    var k = u.toLowerCase()
    if (ALIASES[k]) k = ALIASES[k]
    for (var cat in CATS) if (k in CATS[cat]) return { cat: cat, unit: k }
    if (k.length > 2 && k.charAt(k.length - 1) === "s") return find(k.slice(0, -1))      // plural
    return null
}

function fmt(v) {
    if (!isFinite(v)) return null
    if (v === 0) return "0"
    var a = Math.abs(v)
    if (a >= 1e12 || a < 1e-6) return v.toExponential(4)
    return String(parseFloat(v.toPrecision(7)))
}

function toBaseTemp(v, u) { return u === "c" ? v : (u === "f" ? (v - 32) * 5 / 9 : v - 273.15) }
function fromBaseTemp(c, u) { return u === "c" ? c : (u === "f" ? c * 9 / 5 + 32 : c + 273.15) }

function tryConvert(text) {
    var m = /^\s*(-?\d+(?:[.,]\d+)?)\s*([a-z°][a-z°\/0-9²³ ]*?)\s+(?:to|in|into|as|->|=)\s+([a-z°][a-z°\/0-9²³ ]*?)\s*$/i.exec(text)
    if (!m) return null
    var v = parseFloat(m[1].replace(",", "."))
    var a = find(m[2].trim()), b = find(m[3].trim())
    if (!a || !b || a.cat !== b.cat) return null
    var out
    if (a.cat === "temp") out = fromBaseTemp(toBaseTemp(v, a.unit), b.unit)
    else out = v * CATS[a.cat][a.unit] / CATS[b.cat][b.unit]
    var s = fmt(out)
    if (s === null) return null
    var name = function (u) { return u === "c" || u === "f" ? "°" + u.toUpperCase() : (u === "k" ? "K" : u) }
    return { text: m[1] + " " + name(a.unit) + " = " + s + " " + name(b.unit), value: s }
}
