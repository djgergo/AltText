import CoreGraphics
import Foundation
import ImageIO

enum AltTextMetadataEmbedder {
    enum EmbeddingError: LocalizedError {
        case unreadableSource
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadableSource:
                "Couldn't read the original image."
            case .encodingFailed:
                "Couldn't write the alt text into this image."
            }
        }
    }

    // Losslessly copies the original image's encoded bytes into a new file
    // while merging the alt text into the description fields different tools
    // check: TIFF/EXIF ImageDescription, IPTC Caption-Abstract, and XMP
    // dc:description. `CGImageDestinationAddImageFromSource` — rather than
    // decoding to a CGImage and re-encoding — is what keeps this lossless:
    // it copies the source's compressed image data as-is and only touches
    // the metadata riding alongside it.
    static func embed(altText: String, into url: URL) throws -> Data {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) else {
            throw EmbeddingError.unreadableSource
        }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]

        var tiff = (properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
        tiff[kCGImagePropertyTIFFImageDescription] = altText
        properties[kCGImagePropertyTIFFDictionary] = tiff

        var iptc = (properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any]) ?? [:]
        iptc[kCGImagePropertyIPTCCaptionAbstract] = altText
        properties[kCGImagePropertyIPTCDictionary] = iptc

        // XMP lives in its own metadata tree rather than the plain property
        // dictionaries above, built from the source's existing tags (if any)
        // so unrelated XMP data survives the round trip.
        let mutableMetadata: CGMutableImageMetadata
        if let baseMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
           let copy = CGImageMetadataCreateMutableCopy(baseMetadata) {
            mutableMetadata = copy
        } else {
            mutableMetadata = CGImageMetadataCreateMutable()
        }

        CGImageMetadataRegisterNamespaceForPrefix(mutableMetadata, "http://purl.org/dc/elements/1.1/" as CFString, "dc" as CFString, nil)
        guard CGImageMetadataSetValueWithPath(mutableMetadata, nil, "dc:description" as CFString, altText as CFString) else {
            throw EmbeddingError.encodingFailed
        }

        properties[kCGImageDestinationMetadata] = mutableMetadata
        properties[kCGImageDestinationMergeMetadata] = true

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outputData, type, 1, nil) else {
            throw EmbeddingError.encodingFailed
        }

        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw EmbeddingError.encodingFailed
        }

        return outputData as Data
    }
}
