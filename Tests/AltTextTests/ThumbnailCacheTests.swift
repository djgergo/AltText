import XCTest
@testable import AltText

#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class ThumbnailCacheTests: XCTestCase {
    func testThumbnailDecodesAndDownsamplesJPEG() async throws {
        let url = try Self.writeSampleJPEG()
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbnail = await ThumbnailCache.shared.thumbnail(for: url, maxPixelSize: 64)

        XCTAssertNotNil(thumbnail)
        let largestDimension = max(thumbnail?.size.width ?? .infinity, thumbnail?.size.height ?? .infinity)
        XCTAssertLessThanOrEqual(largestDimension, 64)
    }

    func testThumbnailIsMemoizedAcrossCalls() async throws {
        let url = try Self.writeSampleJPEG()
        defer { try? FileManager.default.removeItem(at: url) }

        let first = await ThumbnailCache.shared.thumbnail(for: url)
        let second = await ThumbnailCache.shared.thumbnail(for: url)

        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
    }

    func testThumbnailReturnsNilForMissingFile() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString).jpg")

        let thumbnail = await ThumbnailCache.shared.thumbnail(for: url, maxPixelSize: 64)

        XCTAssertNil(thumbnail)
    }

    private static func writeSampleJPEG() throws -> URL {
        let size = CGSize(width: 400, height: 300)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")

        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .jpeg, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        #else
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        guard let image = UIGraphicsGetImageFromCurrentImageContext(), let data = image.jpegData(compressionQuality: 1) else {
            throw CocoaError(.fileWriteUnknown)
        }
        #endif

        try data.write(to: url)
        return url
    }
}
