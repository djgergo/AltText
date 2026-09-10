import SwiftUI

struct ImageRowView: View {
    let item: ImageItem
    let altText: Binding<String>
    let onRemove: () -> Void

    @State private var thumbnail: PlatformImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                thumbnailView

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.filename)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        statusBadge

                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove")
                        .accessibilityLabel(Text("Remove \(item.filename)"))
                    }

                    altTextArea
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)

            // Drawn manually (rather than relying on the List's built-in row
            // separator) because its default inset differs between iOS and
            // macOS — neither reaches full width the way the design calls for.
            Divider()
        }
    }

    private var thumbnailView: some View {
        Group {
            if let thumbnail {
                Image(platformImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 1)
        }
        .clipped()
        .accessibilityHidden(true)
        .task(id: item.url) {
            thumbnail = await ThumbnailCache.shared.thumbnail(for: item.url)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            Label("Pending", systemImage: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .generating:
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)
                Text("Generating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var altTextArea: some View {
        switch item.status {
        case .pending:
            placeholderText("Not generated yet.")
        case .generating:
            placeholderText("Writing alt text…")
        case .done:
            TextEditor(text: altText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 44, maxHeight: 88)
                .padding(8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(Text("Alt text for \(item.filename)"))
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(minHeight: 44, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
