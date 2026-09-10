import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum PhotosImportHandler {
    static func urls(from items: [PhotosPickerItem]) async -> [URL] {
        var urls: [URL] = []
        for item in items {
            if let url = await writeToTemporaryFile(item) {
                urls.append(url)
            }
        }
        return urls
    }

    // PHPicker hands back opaque asset data, not a file the rest of the app
    // (thumbnailing, generation) can read by URL — so each pick is copied into
    // its own temp file to fit the URL-based ImageItem model everything else uses.
    private static func writeToTemporaryFile(_ item: PhotosPickerItem) async -> URL? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }

        let contentType = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .jpeg
        let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
