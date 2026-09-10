import SwiftUI

struct ModelStatusView: View {
    let state: ModelAvailabilityState

    /// `.help()` tooltips (how the reason for `.unavailable` normally surfaces)
    /// only reach a pointer hovering on macOS — there's no touch equivalent, so
    /// this renders the reason as visible text instead wherever it's set.
    var showsDetail: Bool = false

    /// Offered only alongside `showsDetail`: the compact header has room for an
    /// actionable retry, the toolbar's tight regular-width slot doesn't. Model
    /// readiness (e.g. an Apple Intelligence download finishing) isn't
    /// something this app is told about, so there's no way to know without
    /// asking again.
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                switch state {
                case .checking:
                    Label {
                        Text(state.label)
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                    }
                case .ready:
                    Label(state.label, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .unavailable:
                    Label(state.label, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.callout)

            if showsDetail, let detail = state.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsDetail, case .unavailable = state, let onRefresh {
                Button("Check Again", action: onRefresh)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .help(state.detail ?? state.label)
        .accessibilityLabel(Text(state.detail ?? state.label))
    }
}
