import AppKit

/// Owl artwork shared by the menu bar glyph and the app icon.
/// Shapes are defined on an 18x18 design grid (origin bottom-left).
enum OwlArt {
    enum Mode {
        /// NightOwl's own switch is on; the display may still sleep.
        case keptAwake
        /// NightOwl's own switch and Keep Display On Too are both on.
        case keptAwakeWithDisplay
        /// Switch is off, but something else (System Settings, caffeinate, an app) keeps the Mac awake.
        case awakeByOthers
        /// Nothing prevents sleep.
        case canSleep
    }

    static let eyeCenters = [NSPoint(x: 6.2, y: 8.8), NSPoint(x: 11.8, y: 8.8)]
    static let eyeRadius: CGFloat = 2.4

    /// Owl head outline with ear tufts.
    static func headPath() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 9, y: 1.6))
        p.curve(to: NSPoint(x: 2.6, y: 8),
                controlPoint1: NSPoint(x: 5, y: 1.6), controlPoint2: NSPoint(x: 2.6, y: 4.2))
        p.line(to: NSPoint(x: 2.9, y: 16.2))
        p.curve(to: NSPoint(x: 6.6, y: 13.4),
                controlPoint1: NSPoint(x: 4.3, y: 15), controlPoint2: NSPoint(x: 5.4, y: 13.9))
        p.curve(to: NSPoint(x: 11.4, y: 13.4),
                controlPoint1: NSPoint(x: 8.1, y: 14.1), controlPoint2: NSPoint(x: 9.9, y: 14.1))
        p.curve(to: NSPoint(x: 15.1, y: 16.2),
                controlPoint1: NSPoint(x: 12.6, y: 13.9), controlPoint2: NSPoint(x: 13.7, y: 15))
        p.line(to: NSPoint(x: 15.4, y: 8))
        p.curve(to: NSPoint(x: 9, y: 1.6),
                controlPoint1: NSPoint(x: 15.4, y: 4.2), controlPoint2: NSPoint(x: 13, y: 1.6))
        p.close()
        return p
    }

    static func beakPath() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 8.1, y: 7.0))
        p.line(to: NSPoint(x: 9.9, y: 7.0))
        p.line(to: NSPoint(x: 9, y: 5.3))
        p.close()
        return p
    }

    static func circle(_ c: NSPoint, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    // MARK: - Menu bar glyph

    /// `keptAwake` is the brown owl from the app icon with closed eyes (the display may sleep);
    /// `keptAwakeWithDisplay` is the same owl in blue with open eyes. The other modes are the same owl as a line drawing; `awakeByOthers` is a template image, so it follows the menu bar appearance
    /// (white on dark, black on light).
    static func menuBarImage(_ mode: Mode) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            switch mode {
            case .keptAwake:
                drawColorOwl(outlineWidth: 0.9, eyesClosed: true)
                return true
            case .keptAwakeWithDisplay:
                drawColorOwl(outlineWidth: 0.9, eyesClosed: false, palette: .blue)
                return true
            case .awakeByOthers: NSColor.black.set()
            case .canSleep: NSColor.systemGray.set()
            }
            let head = headPath()
            head.lineWidth = 1.3
            head.lineJoinStyle = .round
            head.stroke()
            for c in eyeCenters {
                let eye = circle(c, eyeRadius)
                eye.lineWidth = 1.1
                eye.stroke()
                circle(c, 1.15).fill()
            }
            beakPath().fill()
            return true
        }
        image.isTemplate = mode == .awakeByOthers
        switch mode {
        case .keptAwake: image.accessibilityDescription = "NightOwl is keeping the Mac awake"
        case .keptAwakeWithDisplay: image.accessibilityDescription = "NightOwl is keeping the Mac and display awake"
        case .awakeByOthers: image.accessibilityDescription = "Mac is kept awake by another source"
        case .canSleep: image.accessibilityDescription = "Mac can sleep"
        }
        return image
    }

    // MARK: - Colored owl

    /// Plumage colors of the colored owl. Eyes and beak are the same in every palette.
    struct Palette {
        let headTop: NSColor
        let headBottom: NSColor
        let outline: NSColor
        let facialDisc: NSColor
        let eyelid: NSColor

        static let brown = Palette(
            headTop: NSColor(srgbRed: 0.87, green: 0.56, blue: 0.25, alpha: 1),
            headBottom: NSColor(srgbRed: 0.58, green: 0.33, blue: 0.15, alpha: 1),
            outline: NSColor(srgbRed: 0.33, green: 0.18, blue: 0.08, alpha: 1),
            facialDisc: NSColor(srgbRed: 0.98, green: 0.84, blue: 0.62, alpha: 1),
            eyelid: NSColor(srgbRed: 0.78, green: 0.48, blue: 0.21, alpha: 1))

        static let blue = Palette(
            headTop: NSColor(srgbRed: 0.36, green: 0.62, blue: 1.00, alpha: 1),
            headBottom: NSColor(srgbRed: 0.13, green: 0.33, blue: 0.80, alpha: 1),
            outline: NSColor(srgbRed: 0.05, green: 0.13, blue: 0.38, alpha: 1),
            facialDisc: NSColor(srgbRed: 0.82, green: 0.91, blue: 1.00, alpha: 1),
            eyelid: NSColor(srgbRed: 0.25, green: 0.50, blue: 0.92, alpha: 1))
    }

    /// Draws the colored owl on the 18x18 design grid in the current coordinate system.
    static func drawColorOwl(outlineWidth: CGFloat, eyesClosed: Bool = false, palette: Palette = .brown) {
        let head = headPath()
        NSGradient(starting: palette.headTop, ending: palette.headBottom)?.draw(in: head, angle: 90)
        palette.outline.set()
        head.lineWidth = outlineWidth
        head.lineJoinStyle = .round
        head.stroke()

        // Facial disc around each eye.
        palette.facialDisc.set()
        for c in eyeCenters { circle(c, 3.3).fill() }

        for c in eyeCenters {
            if eyesClosed {
                drawClosedEye(at: c, lineWidth: outlineWidth, palette: palette)
                continue
            }
            NSColor(srgbRed: 1, green: 0.79, blue: 0.20, alpha: 1).set()
            circle(c, eyeRadius).fill()
            NSColor(srgbRed: 0.10, green: 0.08, blue: 0.16, alpha: 1).set()
            circle(c, 1.35).fill()
            NSColor.white.set()
            circle(NSPoint(x: c.x + 0.5, y: c.y + 0.5), 0.42).fill()
        }

        NSColor(srgbRed: 0.93, green: 0.48, blue: 0.13, alpha: 1).set()
        beakPath().fill()
    }

    /// Closed eye: the eye covered by its lid in the head color, with a dark downward-curved lash line.
    private static func drawClosedEye(at c: NSPoint, lineWidth: CGFloat, palette: Palette) {
        let r = eyeRadius + 0.05
        palette.eyelid.set()
        circle(c, r).fill()
        palette.outline.set()
        let lash = NSBezierPath()
        lash.move(to: NSPoint(x: c.x - r * 0.8, y: c.y + 0.3))
        lash.curve(to: NSPoint(x: c.x + r * 0.8, y: c.y + 0.3),
                   controlPoint1: NSPoint(x: c.x - r * 0.4, y: c.y - 0.9),
                   controlPoint2: NSPoint(x: c.x + r * 0.4, y: c.y - 0.9))
        lash.lineWidth = lineWidth
        lash.lineCapStyle = .round
        lash.stroke()
    }

    // MARK: - App icon

    /// Draws the full-color app icon into a 1024x1024 canvas scaled to `side`.
    static func drawAppIcon(side: CGFloat) {
        let scale = NSAffineTransform()
        scale.scale(by: side / 1024)
        scale.concat()

        // Night-sky squircle.
        let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
        NSGradient(starting: NSColor(srgbRed: 0.24, green: 0.12, blue: 0.40, alpha: 1),
                   ending: NSColor(srgbRed: 0.07, green: 0.09, blue: 0.27, alpha: 1))?.draw(in: tile, angle: 90)

        NSGraphicsContext.saveGraphicsState()
        tile.addClip()

        // Stars.
        NSColor(white: 1, alpha: 0.85).set()
        for (x, y, r) in [(210.0, 820.0, 7.0), (330, 870, 4), (450, 800, 5), (600, 860, 4), (170, 640, 4),
                          (860, 560, 5), (250, 520, 3), (880, 700, 3), (540, 900, 3)] {
            circle(NSPoint(x: x, y: y), r).fill()
        }

        // Crescent moon: moon disc minus an offset disc.
        let moonCenter = NSPoint(x: 790, y: 805)
        NSGraphicsContext.saveGraphicsState()
        let cutout = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))
        cutout.append(circle(NSPoint(x: moonCenter.x - 30, y: moonCenter.y + 22), 58))
        cutout.windingRule = .evenOdd
        cutout.addClip()
        NSColor(srgbRed: 1, green: 0.93, blue: 0.66, alpha: 1).set()
        circle(moonCenter, 62).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Owl, design grid scaled up.
        NSGraphicsContext.saveGraphicsState()
        let owl = NSAffineTransform()
        owl.translateX(by: 512 - 9 * 36, yBy: 112)
        owl.scale(by: 36)
        owl.concat()

        drawColorOwl(outlineWidth: 0.35)
        NSGraphicsContext.restoreGraphicsState()

        // Branch the owl perches on.
        NSColor(srgbRed: 0.30, green: 0.19, blue: 0.11, alpha: 1).set()
        NSBezierPath(roundedRect: NSRect(x: 140, y: 152, width: 744, height: 30), xRadius: 15, yRadius: 15).fill()

        NSGraphicsContext.restoreGraphicsState()
    }
}
