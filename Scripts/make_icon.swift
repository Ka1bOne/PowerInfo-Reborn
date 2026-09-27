// Renders the 1024×1024 app icon PNG. Usage: swift Scripts/make_icon.swift out.png
import AppKit

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Squircle background with a soft drop shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(colors: [
    NSColor(red: 0.20, green: 0.88, blue: 0.56, alpha: 1),
    NSColor(red: 0.07, green: 0.62, blue: 0.72, alpha: 1),
    NSColor(red: 0.10, green: 0.32, blue: 0.78, alpha: 1),
])!.draw(in: tilePath, angle: -65)

// Glassy highlight across the top.
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 40, y: 560, width: 944, height: 560)), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Battery outline, fill and nub.
let body = NSRect(x: 252, y: 430, width: 470, height: 240)
let outline = NSBezierPath(roundedRect: body, xRadius: 64, yRadius: 64)
outline.lineWidth = 34
NSColor.white.setStroke()
outline.stroke()
NSColor.white.withAlphaComponent(0.9).setFill()
NSBezierPath(roundedRect: NSRect(x: 740, y: 505, width: 34, height: 90), xRadius: 17, yRadius: 17).fill()
NSColor.white.withAlphaComponent(0.28).setFill()
NSBezierPath(roundedRect: body.insetBy(dx: 38, dy: 38), xRadius: 30, yRadius: 30).fill()

// Bolt, drawn as a plain polygon.
let cx = body.midX, cy = body.midY
let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: cx + 41, y: cy + 95))
bolt.line(to: NSPoint(x: cx - 59, y: cy - 10))
bolt.line(to: NSPoint(x: cx + 1, y: cy - 10))
bolt.line(to: NSPoint(x: cx - 35, y: cy - 95))
bolt.line(to: NSPoint(x: cx + 65, y: cy + 12))
bolt.line(to: NSPoint(x: cx + 5, y: cy + 12))
bolt.close()
bolt.lineJoinStyle = .round
bolt.lineWidth = 12
NSColor.white.setFill()
NSColor.white.setStroke()
bolt.fill()
bolt.stroke()

// "PIR" lettering, drawn with strokes so no font is embedded in the icon.
let letters = NSBezierPath()
letters.lineWidth = 30
letters.lineCapStyle = .round
letters.lineJoinStyle = .round
func bowl(from x: CGFloat) {
    letters.move(to: NSPoint(x: x, y: 370))
    letters.line(to: NSPoint(x: x + 55, y: 370))
    letters.appendArc(withCenter: NSPoint(x: x + 55, y: 330), radius: 40, startAngle: 90, endAngle: -90, clockwise: true)
    letters.line(to: NSPoint(x: x, y: 290))
}
// P
letters.move(to: NSPoint(x: 367, y: 220)); letters.line(to: NSPoint(x: 367, y: 370))
bowl(from: 367)
// I
letters.move(to: NSPoint(x: 517, y: 220)); letters.line(to: NSPoint(x: 517, y: 370))
// R
letters.move(to: NSPoint(x: 572, y: 220)); letters.line(to: NSPoint(x: 572, y: 370))
bowl(from: 572)
letters.move(to: NSPoint(x: 605, y: 290)); letters.line(to: NSPoint(x: 660, y: 220))
letters.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
