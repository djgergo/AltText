import CoreGraphics
import Foundation
import ImageIO

actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private var thumbnails: [URL: PlatformImage] = [:]

    func thumbnail(for url: URL, maxPixelSize: CGFloat = 192) async -> PlatformImage? {
        if let cached = thumbnails[url] {
            return cached
        }

        guard let decoded = Self.decode(url: url, maxPixelSize: maxPixelSize) else {
            return nil
        }

        thumbnails[url] = decoded
        return decoded
    }

    // Decoding straight to thumbnail resolution via ImageIO avoids materializing
    // a full-size multi-megapixel image just to shrink it for a 64x64 row.
    //
    // Under App Sandbox, reading a user-picked file requires explicitly
    // claiming access first — even a file the user just selected via the file
    // importer or dropped in. Skipping this silently fails the read rather
    // than throwing.
    nonisolated private static func decode(url: URL, maxPixelSize: CGFloat) -> PlatformImage? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return PlatformImage.fromCGImage(cgImage)
    }
}
