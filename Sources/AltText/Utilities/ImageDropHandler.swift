import Foundation
import UniformTypeIdentifiers

@MainActor
enum ImageDropHandler {
    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            guard provider.canLoadObject(ofClass: URL.self) else { continue }
            if let url = await loadURL(from: provider), isImage(url) {
                urls.append(url)
            }
        }
        return urls
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func isImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
