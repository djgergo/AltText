import Foundation
import Observation

@MainActor
@Observable
final class AltTextViewModel {
    private(set) var items: [ImageItem] = []
    var modelAvailability: ModelAvailabilityState = .checking
    private(set) var isGenerating = false

    private let service: AltTextGenerating

    init(service: AltTextGenerating? = nil) {
        self.service = service ?? AltTextService()
    }

    var canGenerate: Bool {
        !isGenerating && modelAvailability.isReady && items.contains { $0.status.isPendingOrFailed }
    }

    func refreshAvailability() {
        modelAvailability = service.availability()
        if modelAvailability.isReady {
            service.prewarm()
        }
    }

    func addImages(at urls: [URL]) {
        let existing = Set(items.map(\.url))
        let newItems = urls.filter { !existing.contains($0) }.map { ImageItem(url: $0) }
        items.append(contentsOf: newItems)
    }

    func removeImage(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func generateAltText() async {
        guard !isGenerating, modelAvailability.isReady else { return }

        let pendingIDs = items.filter(\.status.isPendingOrFailed).map(\.id)
        guard !pendingIDs.isEmpty else { return }

        isGenerating = true
        defer { isGenerating = false }

        await withTaskGroup(of: Void.self) { group in
            for id in pendingIDs {
                group.addTask { [self] in
                    await generate(id: id)
                }
            }
        }
    }

    // Re-runs generation for a single already-done (or failed) item, independent
    // of the batch `generateAltText()` — the model call itself already reports
    // unavailability as a per-item failure, so there's no availability guard here.
    func regenerateAltText(for id: UUID) async {
        await generate(id: id)
    }

    private func generate(id: UUID) async {
        updateStatus(.generating, for: id)
        guard let item = items.first(where: { $0.id == id }) else { return }

        do {
            let text = try await service.generateAltText(for: item)
            updateStatus(.done(text), for: id)
        } catch let error as AltTextServiceError {
            updateStatus(.failed(error.errorDescription ?? "Couldn't generate alt text."), for: id)
        } catch {
            // Anything else (a framework or sandbox failure) surfaces as an
            // opaque, implementation-specific string via `localizedDescription` —
            // not something a person can act on, so show a plain message instead.
            updateStatus(.failed("Couldn't generate alt text for this image. Try again."), for: id)
        }
    }

    private func updateStatus(_ status: GenerationStatus, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }
}
