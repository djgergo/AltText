// Renders the AltText app icon: a blue rounded-square field with a white
// "photo" glyph and a white sparkle badge in the top-right corner (echoing
// the in-app empty-state icon and the Generate button's sparkle).
//
// Produces two masters:
//   icon-mac-1024.png  - macOS style: squircle shape + padding baked into
//                         the pixels, transparent margin (Apple's Big Sur
//                         icon template proportions) since macOS does NOT
//                         auto-mask classic appiconset icons.
//   icon-ios-1024.png  - iOS style: full-bleed opaque square, no baked
//                         rounding, since iOS auto-masks the corners.
//
// Regenerate after tweaking colors/glyphs, then re-run the resize step:
//
//   swift scripts/render-app-icon.swift /tmp/alttext-icon
//   ICONSET=Sources/AltText/Assets.xcassets/AppIcon.appiconset
//   for size in 16 32 128 256 512; do
//     double=$((size*2))
//     sips -z $size $size /tmp/alttext-icon/icon-mac-1024.png --out "$ICONSET/mac-${size}.png"
//     sips -z $double $double /tmp/alttext-icon/icon-mac-1024.png --out "$ICONSET/mac-${size}@2x.png"
//   done
//   cp /tmp/alttext-icon/icon-ios-1024.png "$ICONSET/ios-1024.png"
//
// Validate before trusting it (a bare `swift build`/`xcodebuild build` on
// this package does not compile app icons — that only happens through
// Xcode's IDE-driven Run step or a direct actool invocation):
//
//   xcrun actool --app-icon AppIcon --output-partial-info-plist /tmp/p.plist \
//     --platform macosx --minimum-deployment-target 26.0 --compile /tmp/out \
//     Sources/AltText/Assets.xcassets
//   sips -s format png /tmp/out/AppIcon.icns --out /tmp/preview.png

import AppKit
import CoreGraphics

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func makeContext(size: Int) -> (CGContext, NSGraphicsContext) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let nsGraphicsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
    return (ctx, nsGraphicsContext)
}

func tintedSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
        fatalError("Missing SF Symbol: \(name)")
    }
    let sizeConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    let colorConfig = NSImage.SymbolConfiguration(paletteColors: [color])
    let config = sizeConfig.applying(colorConfig)
    guard let configured = base.withSymbolConfiguration(config) else {
        fatalError("Could not configure symbol: \(name)")
    }
    configured.isTemplate = false
    return configured
}

func renderIcon(pixelSize: Int, macStyle: Bool) -> CGImage {
    let size = CGFloat(pixelSize)
    let (cgCtx, nsCtx) = makeContext(size: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // Transparent canvas to start.
    cgCtx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let accent = NSColor(red: 0.13, green: 0.42, blue: 0.95, alpha: 1)
    let accentDeep = NSColor(red: 0.09, green: 0.30, blue: 0.80, alpha: 1)

    let bgRect: CGRect
    let cornerRadius: CGFloat
    if macStyle {
        // Apple's macOS icon template: content sits within ~80.5% of the
        // canvas, centered, with the rounded shape baked into the pixels.
        let inset = size * 0.0975
        bgRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        cornerRadius = bgRect.width * 0.225
    } else {
        bgRect = CGRect(x: 0, y: 0, width: size, height: size)
        cornerRadius = 0
    }

    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(starting: accent, ending: accentDeep)
    gradient?.draw(in: bgPath, angle: -90)

    // Main glyph: plain photo icon, white, centered in the background shape.
    let glyphPointSize = bgRect.width * 0.46
    let glyph = tintedSymbol("photo", pointSize: glyphPointSize, weight: .medium, color: .white)
    let glyphSize = glyph.size
    let glyphOrigin = CGPoint(
        x: bgRect.midX - glyphSize.width / 2,
        y: bgRect.midY - glyphSize.height / 2 - bgRect.height * 0.02
    )
    glyph.draw(at: glyphOrigin, from: .zero, operation: .sourceOver, fraction: 1)

    // AI sparkle badge: white disc in the top-right, blue sparkle inside —
    // mirrors how compound SF Symbols (e.g. photo.badge.plus) punch a
    // background-colored disc for their badge, and reuses the same
    // "sparkles" glyph as the in-app Generate button for consistency.
    let badgeDiameter = bgRect.width * 0.34
    let badgeCenter = CGPoint(
        x: bgRect.maxX - badgeDiameter * 0.62,
        y: bgRect.maxY - badgeDiameter * 0.62
    )
    let badgeRect = CGRect(
        x: badgeCenter.x - badgeDiameter / 2,
        y: badgeCenter.y - badgeDiameter / 2,
        width: badgeDiameter,
        height: badgeDiameter
    )
    let badgePath = NSBezierPath(ovalIn: badgeRect)
    NSColor.white.setFill()
    badgePath.fill()

    let sparklePointSize = badgeDiameter * 0.56
    let sparkle = tintedSymbol("sparkles", pointSize: sparklePointSize, weight: .semibold, color: accent)
    let sparkleSize = sparkle.size
    sparkle.draw(
        at: CGPoint(x: badgeCenter.x - sparkleSize.width / 2, y: badgeCenter.y - sparkleSize.height / 2),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()
    return cgCtx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed for \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path)")
}

let macMaster = renderIcon(pixelSize: 1024, macStyle: true)
writePNG(macMaster, to: "\(outputDir)/icon-mac-1024.png")

let iosMaster = renderIcon(pixelSize: 1024, macStyle: false)
writePNG(iosMaster, to: "\(outputDir)/icon-ios-1024.png")
