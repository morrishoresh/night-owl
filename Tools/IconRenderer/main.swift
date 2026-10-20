import AppKit

// Usage:
//   icon-renderer appicon <output.iconset>
//   icon-renderer preview <output-dir>   (menu bar glyphs at 8x, for review)

func renderPNG(pixels: Int, to url: URL, draw: () -> Void) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: icon-renderer appicon|preview <output>\n".data(using: .utf8)!)
    exit(2)
}
let out = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

switch args[1] {
case "appicon":
    for points in [16, 32, 128, 256, 512] {
        for factor in [1, 2] {
            let pixels = points * factor
            let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            try renderPNG(pixels: pixels, to: out.appendingPathComponent(name)) {
                OwlArt.drawAppIcon(side: CGFloat(pixels))
            }
        }
    }
case "preview":
    for (modeName, mode) in [("on", OwlArt.Mode.keptAwake), ("others", .awakeByOthers), ("off", .canSleep)] {
        for (bgName, bg, fg) in [("light", NSColor.white, NSColor.black), ("dark", NSColor.black, NSColor.white)] {
            let name = "menubar-\(modeName)-\(bgName).png"
            try renderPNG(pixels: 144, to: out.appendingPathComponent(name)) {
                bg.setFill()
                NSRect(x: 0, y: 0, width: 144, height: 144).fill()
                let glyph = OwlArt.menuBarImage(mode)
                let tinted = NSImage(size: glyph.size, flipped: false) { rect in
                    glyph.draw(in: rect)
                    if glyph.isTemplate {
                        fg.set()
                        rect.fill(using: .sourceAtop)
                    }
                    return true
                }
                tinted.draw(in: NSRect(x: 0, y: 0, width: 144, height: 144))
            }
        }
    }
    try renderPNG(pixels: 512, to: out.appendingPathComponent("appicon.png")) {
        OwlArt.drawAppIcon(side: 512)
    }
default:
    exit(2)
}
