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

    func availability() -> ModelAvailabilityState {
        switch model.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            return .unavailable(Self.userFacingReason(for: reason))
        }
    }

    func prewarm() {
        // Real prewarm (a LanguageModelSession primed for image input) lands once
        // Attachment-based generation replaces the stub below.
    }

    func generateAltText(for item: ImageItem) async throws -> String {
        guard case .ready = availability() else {
            throw AltTextServiceError.modelUnavailable(availability().detail ?? "Apple Intelligence is not ready.")
        }

        // TODO(macOS 27, GA 2026-09-14): swap this stub for real multimodal generation:
        //
        //   let session = LanguageModelSession(model: model, instructions: instructions)
        //   let response = try await session.respond {
        //       "Write concise, accessible alt text for this image."
        //       Attachment(imageURL: item.url)
        //   }
        //   return response.content
        //
        // The delay below stands in for that call so pending -> generating -> done
        // status transitions can be exercised end to end before that API exists here.
        try await Task.sleep(for: .milliseconds(500))
        return "placeholder"
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
