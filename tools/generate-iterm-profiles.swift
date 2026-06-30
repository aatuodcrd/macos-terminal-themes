import Foundation
import AppKit

// Transcode the 20 Terminal.app .terminal themes into a single iTerm2 Dynamic
// Profiles file. Each profile carries the exact same colours plus the term-tint
// badge appearance (big + faint), so `note` watermarks look good on every theme.
// Colours are read straight from themes/*.terminal — one source of truth.
//
// Usage:  swift tools/generate-iterm-profiles.swift   (writes iterm2/term-tint.json)

func decode(_ d: [String: Any], _ k: String) -> NSColor? {
    guard let data = d[k] as? Data else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
}
func comps(_ c: NSColor) -> [String: Any] {
    let s = c.usingColorSpace(.sRGB)!
    return ["Color Space": "sRGB",
            "Red Component": Double(s.redComponent),
            "Green Component": Double(s.greenComponent),
            "Blue Component": Double(s.blueComponent),
            "Alpha Component": 1.0]
}

let badge: [String: Any] = [
    "Badge Color": ["Color Space": "sRGB", "Red Component": 0.62, "Green Component": 0.62,
                    "Blue Component": 0.66, "Alpha Component": 0.22],
    "Badge Max Width": 0.9, "Badge Max Height": 0.5,
    "Badge Top Margin": 14, "Badge Right Margin": 18, "Badge Font": "Menlo-Bold",
]

// .terminal key -> iTerm2 profile key
let map: [(String, String)] = [
    ("BackgroundColor", "Background Color"), ("TextColor", "Foreground Color"),
    ("TextBoldColor", "Bold Color"), ("CursorColor", "Cursor Color"),
    ("BackgroundColor", "Cursor Text Color"), ("SelectionColor", "Selection Color"),
    ("TextColor", "Selected Text Color"),
    ("ANSIBlackColor", "Ansi 0 Color"), ("ANSIRedColor", "Ansi 1 Color"),
    ("ANSIGreenColor", "Ansi 2 Color"), ("ANSIYellowColor", "Ansi 3 Color"),
    ("ANSIBlueColor", "Ansi 4 Color"), ("ANSIMagentaColor", "Ansi 5 Color"),
    ("ANSICyanColor", "Ansi 6 Color"), ("ANSIWhiteColor", "Ansi 7 Color"),
    ("ANSIBrightBlackColor", "Ansi 8 Color"), ("ANSIBrightRedColor", "Ansi 9 Color"),
    ("ANSIBrightGreenColor", "Ansi 10 Color"), ("ANSIBrightYellowColor", "Ansi 11 Color"),
    ("ANSIBrightBlueColor", "Ansi 12 Color"), ("ANSIBrightMagentaColor", "Ansi 13 Color"),
    ("ANSIBrightCyanColor", "Ansi 14 Color"), ("ANSIBrightWhiteColor", "Ansi 15 Color"),
]

let cwd = FileManager.default.currentDirectoryPath
let themesDir = cwd + "/themes"
let files = (try! FileManager.default.contentsOfDirectory(atPath: themesDir))
    .filter { $0.hasSuffix(".terminal") }.sorted()

var profiles: [[String: Any]] = []
for f in files {
    let name = String(f.dropLast(".terminal".count))
    guard let raw = try? Data(contentsOf: URL(fileURLWithPath: "\(themesDir)/\(f)")),
          let d = try? PropertyListSerialization.propertyList(from: raw, options: [], format: nil) as? [String: Any]
    else { continue }
    var p: [String: Any] = ["Name": "term-tint \(name)", "Guid": "term-tint-\(name)"]
    for (src, dst) in map { if let c = decode(d, src) { p[dst] = comps(c) } }
    badge.forEach { p[$0.key] = $0.value }
    profiles.append(p)
}

let outDir = cwd + "/iterm2"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let json = try! JSONSerialization.data(withJSONObject: ["Profiles": profiles],
                                       options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(outDir)/term-tint.json"))
print("Wrote \(profiles.count) iTerm2 profiles to \(outDir)/term-tint.json")
