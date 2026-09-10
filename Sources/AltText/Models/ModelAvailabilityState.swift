import Foundation

enum ModelAvailabilityState: Equatable {
    case checking
    case ready
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self {
            true
        } else {
            false
        }
    }

    var label: String {
        switch self {
        case .checking: "Checking"
        case .ready: "Ready"
        case .unavailable: "Unavailable"
        }
    }

    var detail: String? {
        switch self {
        case .checking, .ready: nil
        case .unavailable(let reason): reason
        }
    }
}
