import SwiftUI

struct DropZoneView: View {
    let isTargeted: Bool
    let onChoosePhotos: () -> Void
    let onChooseFiles: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ContentUnavailableView {
            Label("Drop Images Here", systemImage: "photo.badge.plus")
        } description: {
            Text("Because nobody actually writes alt text.")
        } actions: {
            Button("Choose Photos…", action: onChoosePhotos)
                .buttonStyle(.borderedProminent)
            Button("Choose Files…", action: onChooseFiles)
                .buttonStyle(.bordered)
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(8)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isTargeted)
    }
}
