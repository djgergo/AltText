import ImageIO
import XCTest
@testable import AltText

#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class AltTextMetadataEmbedderTests: XCTestCase {
    func testEmbedWritesDescriptionToTIFFIPTCAndXMP() throws {
        let url = try Self.writeSampleJPEG()
        defer { try? FileManager.default.removeItem(at: url) }

        let altText = "A golden retriever puppy sits in tall green grass."
        let data = try AltTextMetadataEmbedder.embed(altText: altText, into: url)

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return XCTFail("Couldn't re-read the embedded image data")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFImageDescription] as? String, altText)

        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any]
        XCTAssertEqual(iptc?[kCGImagePropertyIPTCCaptionAbstract] as? String, altText)

        guard let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) else {
            return XCTFail("Expected XMP metadata on the re-read image")
        }
        let xmpDescription = CGImageMetadataCopyStringValueWithPath(metadata, nil, "dc:description" as CFString)
        XCTAssertEqual(xmpDescription as String?, altText)
    }

    func testEmbedThrowsForUnreadableSource() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString).jpg")

        XCTAssertThrowsError(try AltTextMetadataEmbedder.embed(altText: "text", into: url))
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
