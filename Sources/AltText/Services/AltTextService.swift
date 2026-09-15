import Foundation
import FoundationModels

enum AltTextServiceError: LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            "Model unavailable: \(reason)"
        }
    }
}

struct AltTextService: AltTextGenerating {
    private let model = SystemLanguageModel.default

    private static let instructions = """
        You write alt text for images, for use by screen readers and other \
        assistive technology. For each image, write one or two concise \
        sentences describing the important visual content. Do not start with \
        "Image of", "Picture of", or similar preambles, and do not mention the \
        filename.
        """

    func availability() -> ModelAvailabilityState {
        switch model.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            return .unavailable(Self.userFacingReason(for: reason))
        }
    }

    func prewarm() {
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        session.prewarm()
    }

    func generateAltText(for item: ImageItem) async throws -> String {
        guard case .ready = availability() else {
            throw AltTextServiceError.modelUnavailable(availability().detail ?? "Apple Intelligence is not ready.")
        }

        // Under App Sandbox, reading a user-picked or dropped file requires
        // explicitly claiming access first — see ThumbnailCache.decode(url:).
        // Without this, the model's attempt to read the image fails and
        // surfaces as an opaque "content the model cannot process" error.
        let isAccessing = item.url.startAccessingSecurityScopedResource()
        defer { if isAccessing { item.url.stopAccessingSecurityScopedResource() } }

        // A fresh session per image: LanguageModelSession isn't safe for concurrent
        // respond() calls on the same instance, and the view model generates
        // pending items concurrently via a TaskGroup.
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let response = try await session.respond {
            "Write concise, accessible alt text for this image."
            Attachment(imageURL: item.url)
        }
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func userFacingReason(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is off."
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence."
        case .modelNotReady:
            return "The model is still downloading or preparing."
        @unknown default:
            return "Apple Intelligence is not available here."
        }
    }
}
