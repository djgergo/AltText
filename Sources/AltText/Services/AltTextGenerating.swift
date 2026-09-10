import Foundation

protocol AltTextGenerating: Sendable {
    func availability() -> ModelAvailabilityState
    func prewarm()
    func generateAltText(for item: ImageItem) async throws -> String
}
