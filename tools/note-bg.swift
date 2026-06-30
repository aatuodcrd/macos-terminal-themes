import Foundation
import AppKit

// Render a centered, faint, big watermark PNG for iTerm2's SetBackgroundImageFile.
// Transparent background so the profile's colours show through; text sits dead
// centre. Used by `note` on iTerm2.  Usage:  note-bg "<text>" <out.png>
//
// Env overrides:  TT_NOTE_ALPHA (0..1, default 0.16),  TT_NOTE_GRAY (0..1, default 0.78)

let args = CommandLine.arguments
guard args.count >= 3 else { FileHandle.standardError.write("usage: note-bg <text> <out.png>\n".data(using: .utf8)!); exit(2) }
let text = args[1] as NSString
let outPath = args[2]

let W: CGFloat = 1600, H: CGFloat = 1000
let alpha = CGFloat(Double(ProcessInfo.processInfo.environment["TT_NOTE_ALPHA"] ?? "") ?? 0.16)
let gray  = CGFloat(Double(ProcessInfo.processInfo.environment["TT_NOTE_GRAY"]  ?? "") ?? 0.78)

let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

// fit the font so the text spans ~86% of the width (and <= 60% height)
let para = NSMutableParagraphStyle(); para.alignment = .center
func size(_ pt: CGFloat) -> NSSize {
    text.size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: pt), .paragraphStyle: para])
}
var pt: CGFloat = 400
while pt > 12 {
    let s = size(pt)
    if s.width <= W * 0.86 && s.height <= H * 0.6 { break }
    pt -= 4
}
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: pt),
    .foregroundColor: NSColor(calibratedWhite: gray, alpha: alpha),
    .paragraphStyle: para,
]
let ts = size(pt)
text.draw(in: NSRect(x: 0, y: (H - ts.height) / 2, width: W, height: ts.height), withAttributes: attrs)
img.unlockFocus()

guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("render failed\n".data(using: .utf8)!); exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
