import Foundation
import AppKit

// Generates the 10 dark + 10 light `.terminal` profile files used by term-tint.
// Backgrounds are spread wide across hue + brightness so every window is easy to
// tell apart at a glance. Constraints: soft / not vivid, no green & no red
// backgrounds. Text + ANSI colors are auto-adjusted to stay readable on each bg.
//
// Usage:  swift tools/generate-themes.swift   (writes into ./themes)

func color(_ hex: String) -> NSColor {
    let v = UInt32(hex, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: 1)
}
func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c/12.92 : pow((c+0.055)/1.055, 2.4) }
func luminance(_ col: NSColor) -> CGFloat { let c = col.usingColorSpace(.sRGB)!; return 0.2126*lin(c.redComponent)+0.7152*lin(c.greenComponent)+0.0722*lin(c.blueComponent) }
func contrast(_ a: NSColor, _ b: NSColor) -> CGFloat { let la=luminance(a), lb=luminance(b); return (max(la,lb)+0.05)/(min(la,lb)+0.05) }
// Nudge `col` until it clears `target` contrast on `bg`. Direction is set by the
// THEME (toBlack = light theme), never guessed from bg luminance: a mid-tone light
// background (e.g. Stone, lum 0.37) must still darken its accents toward black, not
// lighten toward white — lightening there can never reach target and saturates to
// pure white (the old `luminance(bg) > 0.5` bug that blanked whole palettes).
func fixContrast(_ col: NSColor, on bg: NSColor, target: CGFloat, toBlack: Bool) -> NSColor {
    let c = col.usingColorSpace(.sRGB)!
    if contrast(c, bg) >= target { return c }
    func at(_ t: CGFloat) -> NSColor {
        toBlack ? NSColor(srgbRed: c.redComponent*(1-t), green: c.greenComponent*(1-t), blue: c.blueComponent*(1-t), alpha: 1)
                : NSColor(srgbRed: c.redComponent+(1-c.redComponent)*t, green: c.greenComponent+(1-c.greenComponent)*t, blue: c.blueComponent+(1-c.blueComponent)*t, alpha: 1)
    }
    var lo: CGFloat = 0, hi: CGFloat = 1
    for _ in 0..<26 { let m=(lo+hi)/2; if contrast(at(m), bg) >= target { hi=m } else { lo=m } }
    return at(hi)
}
func colorData(_ c: NSColor) -> Data { try! NSKeyedArchiver.archivedData(withRootObject: c, requiringSecureCoding: false) }

let darkANSI  = ["45475a","e06c75","98c379","e5c07b","61afef","c678dd","56b6c2","cdd6e5","6b7089","e88d93","b5d6a0","ecd3a0","8fc4f5","d7a3e6","8bd3db","ffffff"]
let lightANSI = ["383a42","d1422f","4a8a2f","b07b00","0184bc","a626a4","0e8a9e","6b7079","4f525e","c0564c","5a9a3f","c79a3a","3a96d6","b86fce","3aa3b3","888888"]

let dark: [(String,String,String)] = [
    ("Ink Black",  "000000", "d0d0d0"),
    ("Steel Gray", "474d57", "e9eef5"),
    ("Deep Blue",  "08285f", "cadcfa"),
    ("Slate Blue", "32567f", "dcebfb"),
    ("Indigo",     "281060", "d3c9f7"),
    ("Violet",     "551f93", "ebddfb"),
    ("Magenta",    "73175f", "f7d2ee"),
    ("Plum",       "401038", "f3cce8"),
    ("Amber",      "6a3a0c", "f6dfb8"),
    ("Bronze",     "382806", "ecdcb0"),
]
let light: [(String,String,String)] = [
    ("Paper",      "fefefe", "2a2a2a"),
    ("Silver",     "cfcfd6", "242428"),
    ("Stone",      "9fa4ae", "1f1f23"),
    ("Sky Blue",   "9ccef7", "123049"),
    ("Periwinkle", "aab2f2", "242350"),
    ("Lavender",   "caa6f0", "301a4d"),
    ("Orchid",     "edabe2", "47193f"),
    ("Cream",      "f7ecaa", "474017"),
    ("Gold",       "eccb66", "453818"),
    ("Apricot",    "f5bd7c", "4a3212"),
]

let colorKeys = ["BackgroundColor","TextColor","TextBoldColor","CursorColor","SelectionColor",
    "ANSIBlackColor","ANSIRedColor","ANSIGreenColor","ANSIYellowColor","ANSIBlueColor","ANSIMagentaColor","ANSICyanColor","ANSIWhiteColor",
    "ANSIBrightBlackColor","ANSIBrightRedColor","ANSIBrightGreenColor","ANSIBrightYellowColor","ANSIBrightBlueColor","ANSIBrightMagentaColor","ANSIBrightCyanColor","ANSIBrightWhiteColor"]

let outDir = FileManager.default.currentDirectoryPath + "/themes"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Ctrl+Delete word-erase, matching the Option-as-Meta word motions. Terminal.app
// keyMapBoundKeys: `^` = control; \u{7f} = Delete (Backspace), \u{f728} = ⌦ forward.
// Values are the bytes sent to the shell — ESC+DEL and ESC-d are readline's
// backward/forward kill-word.
let keyBindings: [String: String] = [
    "^\u{7f}":   "\u{1b}\u{7f}",   // Ctrl+Delete (Backspace) → delete word to the left
    "^\u{f728}": "\u{1b}d",        // Ctrl+Forward-Delete (⌦)  → delete word to the right
]

func build(_ name: String, _ bgHex: String, _ fgHex: String, isDark: Bool) {
    let bg = color(bgHex)
    let toBlack = !isDark                                 // light themes darken text/accents, dark themes lighten
    let fg = fixContrast(color(fgHex), on: bg, target: 5.0, toBlack: toBlack)
    let ansiTarget: CGFloat = isDark ? 3.0 : 4.5         // accents: ≥3:1 on dark, ≥4.5:1 on light (pale colors need more on light bg)
    let ansi = (isDark ? darkANSI : lightANSI).map { fixContrast(color($0), on: bg, target: ansiTarget, toBlack: toBlack) }
    let selection = isDark ? color("3a4150") : color("c8cdd6")
    var d: [String: Any] = ["name": name, "type": "Window Settings", "ProfileCurrentVersion": "2.09",
                            "FontAntialias": true, "useOptionAsMetaKey": true, "keyMapBoundKeys": keyBindings]
    let colors = [bg, fg, fg, fg, selection] + ansi      // bg, text, bold, cursor, selection, ANSI...
    for (k, c) in zip(colorKeys, colors) { d[k] = colorData(c) }
    // Binary, not XML: keyMapBoundKeys values carry raw control bytes (ESC 0x1b, DEL
    // 0x7f) that are illegal in XML 1.0. Binary is also Terminal.app's own native format.
    let data = try! PropertyListSerialization.data(fromPropertyList: d, format: .binary, options: 0)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).terminal"))
    print("  \(isDark ? "dark " : "light")\(name)")
}

for (n,b,f) in dark  { build(n,b,f, isDark: true) }
for (n,b,f) in light { build(n,b,f, isDark: false) }
print("Wrote \(dark.count + light.count) themes to \(outDir)")
