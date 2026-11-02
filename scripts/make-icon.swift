// Draws the app icon into Resources/Assets.xcassets/AppIcon.appiconset.
// build-app.sh compiles the catalog with actool; a bare .icns gets framed at small sizes on newer macOS.
//
//   swift scripts/make-icon.swift            # regenerates the appiconset PNGs
//   swift scripts/make-icon.swift out.png    # writes just the 1024px PNG (for previewing)
//
// Hand-drawn rather than an SF Symbol: the SF Symbols license doesn't allow them in app icons.
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon() {
    // macOS icon grid: an 824pt rounded square centered on the 1024pt canvas.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    // No drop shadow on the tile: macOS adds its own, and pixels outside the tile shape make it
    // treat small sizes as a legacy icon and frame them.
    let tileTop = color(0x6E7BF2)
    NSGradient(starting: tileTop, ending: color(0x3B3FB6))!.draw(in: tilePath, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()

    let cream = color(0xFFF7EC)
    let creamShade = color(0xE4DCF0)

    // Soft drop shadow under the bell.
    let shadow = NSShadow()
    shadow.shadowColor = color(0x1C1E6B, alpha: 0.4)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 28

    // Clapper (drawn first so the lip covers its top)
    cream.setFill()
    NSBezierPath(ovalIn: NSRect(x: 447, y: 248, width: 130, height: 112)).fill()

    // Bell body: a dome with straight-ish sides flaring out to the lip.
    let body = NSBezierPath()
    body.move(to: NSPoint(x: 248, y: 380))
    body.curve(to: NSPoint(x: 334, y: 480), controlPoint1: NSPoint(x: 300, y: 398), controlPoint2: NSPoint(x: 334, y: 430))
    body.line(to: NSPoint(x: 334, y: 590))
    body.curve(to: NSPoint(x: 512, y: 780), controlPoint1: NSPoint(x: 334, y: 710), controlPoint2: NSPoint(x: 412, y: 780))
    body.curve(to: NSPoint(x: 690, y: 590), controlPoint1: NSPoint(x: 612, y: 780), controlPoint2: NSPoint(x: 690, y: 710))
    body.line(to: NSPoint(x: 690, y: 480))
    body.curve(to: NSPoint(x: 776, y: 380), controlPoint1: NSPoint(x: 690, y: 430), controlPoint2: NSPoint(x: 724, y: 398))
    body.close()
    let lip = NSBezierPath(roundedRect: NSRect(x: 228, y: 344, width: 568, height: 56), xRadius: 28, yRadius: 28)
    let knob = NSBezierPath(ovalIn: NSRect(x: 470, y: 756, width: 84, height: 76))

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    cream.setFill()
    knob.fill()
    body.fill()
    lip.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Subtle shading on the bell's right side.
    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    NSGradient(colors: [cream.withAlphaComponent(0), creamShade], atLocations: [0.35, 1], colorSpace: .sRGB)!
        .draw(in: body.bounds, angle: 0)
    NSGraphicsContext.restoreGraphicsState()

    // Unread badge, ringed in the tile color so it reads as sitting on top of the bell.
    let badge = NSRect(x: 618, y: 640, width: 210, height: 210)
    tileTop.setFill()
    NSBezierPath(ovalIn: badge.insetBy(dx: -22, dy: -22)).fill()
    NSGradient(starting: color(0xFF6B5E), ending: color(0xE5322B))!.draw(in: NSBezierPath(ovalIn: badge), angle: -90)

    NSGraphicsContext.restoreGraphicsState()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
if args.count > 1 {
    try png(size: 1024).write(to: URL(fileURLWithPath: args[1]))
    exit(0)
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let appiconset = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: appiconset, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png(size: points * scale).write(to: appiconset.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}

let info = ["author": "xcode", "version": 1] as [String: Any]
func writeJSON(_ object: Any, to url: URL) throws {
    try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
try writeJSON(["images": images, "info": info], to: appiconset.appendingPathComponent("Contents.json"))
try writeJSON(["info": info], to: appiconset.deletingLastPathComponent().appendingPathComponent("Contents.json"))
print("Wrote \(appiconset.path)")
