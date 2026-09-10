import Foundation

struct ImageItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    var status: GenerationStatus

    init(url: URL, status: GenerationStatus = .pending) {
        self.id = UUID()
        self.url = url
        self.status = status
    }

    var filename: String { url.lastPathComponent }
}
