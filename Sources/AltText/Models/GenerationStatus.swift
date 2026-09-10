import Foundation

enum GenerationStatus: Equatable, Sendable {
    case pending
    case generating
    case done(String)
    case failed(String)

    var isPendingOrFailed: Bool {
        switch self {
        case .pending, .failed: true
        case .generating, .done: false
        }
    }
}
