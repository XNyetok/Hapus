// Renders design/AppIcon.svg into every size the macOS app icon needs.
//
//   make icon   (or: swift scripts/render-icon.swift)
//
// Uses the SVG support built into AppKit, so there's nothing to install.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appending(path: "design/AppIcon.svg")
let iconSet = root.appending(path: "Havus/Assets.xcassets/AppIcon.appiconset")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let image = NSImage(contentsOf: source) else {
    fail("Can't read \(source.path(percentEncoded: false))")
}

/// Draws the SVG at exactly `pixels` x `pixels` in sRGB and returns it as PNG data.
func png(pixels: Int) -> Data? {
    guard
        let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage().flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let data = png(pixels: points * scale) else { fail("Couldn't render \(name)") }
        do {
            try data.write(to: iconSet.appending(path: name))
        } catch {
            fail("Couldn't write \(name): \(error.localizedDescription)")
        }
        print("✓ \(name) (\(points * scale) px)")
    }
}
