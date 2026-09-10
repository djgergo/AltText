import SwiftUI

#if os(macOS)
import AppKit

typealias PlatformImage = NSImage

extension PlatformImage {
    nonisolated static func fromCGImage(_ cgImage: CGImage) -> PlatformImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#else
import UIKit

typealias PlatformImage = UIImage

extension PlatformImage {
    nonisolated static func fromCGImage(_ cgImage: CGImage) -> PlatformImage {
        UIImage(cgImage: cgImage)
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif
