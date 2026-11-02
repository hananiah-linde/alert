import AppKit
import CoreImage.CIFilterBuiltins

/// Menu bar image for a watched app: its real icon, greyed out with no badge, or in full color
/// with a red dot (badge with no number) or a red count pill, like the Dock draws them.
@MainActor
enum BadgeIcon {
    private static let iconSize: CGFloat = 18
    private static let context = CIContext()

    static func image(icon: NSImage, badge: Badge) -> NSImage {
        let font = NSFont.systemFont(ofSize: 8, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]

        // The badge sits on the icon's top-right corner and hangs off its right edge a little.
        let badgeSize: NSSize
        switch badge {
        case .none:
            badgeSize = .zero
        case .dot:
            badgeSize = NSSize(width: 7, height: 7)
        case .label(let text):
            let width = (text as NSString).size(withAttributes: attributes).width
            badgeSize = NSSize(width: max(10, ceil(width) + 5), height: 10)
        }
        let overhang = badge == .none ? 0 : max(2, badgeSize.width - 8)
        let size = NSSize(width: iconSize + overhang, height: iconSize)
        let artwork = badge == .none ? grayscale(icon) : icon

        // Drawing handler (not lockFocus) so it re-renders at the menu bar's backing scale.
        return NSImage(size: size, flipped: false) { rect in
            let iconRect = NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
            artwork.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: badge == .none ? 0.45 : 1)
            guard badge != .none else { return true }

            let badgeRect = NSRect(
                x: rect.maxX - badgeSize.width,
                y: rect.maxY - badgeSize.height,
                width: badgeSize.width,
                height: badgeSize.height
            )
            let radius = badgeSize.height / 2

            // A transparent ring cut out of the icon keeps the badge readable.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(roundedRect: badgeRect.insetBy(dx: -1, dy: -1), xRadius: radius + 1, yRadius: radius + 1).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.systemRed.setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: radius, yRadius: radius).fill()

            if case .label(let text) = badge {
                let textSize = (text as NSString).size(withAttributes: attributes)
                (text as NSString).draw(
                    at: NSPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2),
                    withAttributes: attributes
                )
            }
            return true
        }
    }

    private static func grayscale(_ icon: NSImage) -> NSImage {
        var rect = NSRect(x: 0, y: 0, width: iconSize * 2, height: iconSize * 2)
        guard let cgImage = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return icon }
        let filter = CIFilter.colorControls()
        filter.inputImage = CIImage(cgImage: cgImage)
        filter.saturation = 0
        guard let output = filter.outputImage,
              let gray = context.createCGImage(output, from: output.extent)
        else { return icon }
        return NSImage(cgImage: gray, size: NSSize(width: iconSize, height: iconSize))
    }
}
