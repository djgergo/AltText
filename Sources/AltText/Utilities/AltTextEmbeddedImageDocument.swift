import SwiftUI
import UniformTypeIdentifiers

// Export-only: the save panel never has anything for this document type to
// read back, so `init(configuration:)` exists purely to satisfy FileDocument.
struct AltTextEmbeddedImageDocument: FileDocument {
    static let readableContentTypes: [UTType] = []

    // `.fileExporter`'s runtime check requires the concrete type it's asked
    // to export (from ContentView's `exportContentType`) to appear in this
    // list — the abstract `.image` conforms but doesn't satisfy that check,
    // which silently drops the export with a console fault. Lists every
    // format `AltTextMetadataEmbedder` actually round-trips: what Photos and
    // the file importer hand this app.
    static let writableContentTypes: [UTType] = [.jpeg, .heic, .png, .tiff, .gif, .bmp]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
