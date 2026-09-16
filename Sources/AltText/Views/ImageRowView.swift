import SwiftUI

struct ImageRowView: View {
    let item: ImageItem
    let altText: Binding<String>
    let onRemove: () -> Void

    @State private var thumbnail: PlatformImage?

    // Scales with Dynamic Type so enlarged accessibility text sizes still fit
    // without the editor's own scrolling fighting the outer List's.
    @ScaledMetric(relativeTo: .body) private var altTextAreaMinHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var altTextAreaMaxHeight: CGFloat = 88

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

                        // iOS already offers swipe-to-delete and a long-press context
                        // menu for this — a third, always-visible remove control right
                        // next to the swipe-reveal trash button doubled up on the same
                        // trailing edge and was the actual cause of the "off" feeling
                        // during a swipe. macOS has neither gesture, so it keeps a
                        // normal small inline control sized for a pointer, not a touch
                        // target.
                        #if os(macOS)
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove")
                        .accessibilityLabel(Text("Remove \(item.filename)"))
                        #endif
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(thumbnailAccessibilityLabel ?? Text(""))
        .accessibilityHidden(thumbnailAccessibilityLabel == nil)
        .task(id: item.url) {
            thumbnail = await ThumbnailCache.shared.thumbnail(for: item.url)
        }
    }

    // The filename is already read by the row's own Text, so an empty
    // thumbnail would only repeat it — VoiceOver skips the image until there's
    // generated alt text, at which point the image can speak to its own
    // content instead of staying silent for the person who can't see it.
    private var thumbnailAccessibilityLabel: Text? {
        guard case .done(let text) = item.status, !text.isEmpty else { return nil }
        return Text(text)
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
            .accessibilityElement(children: .combine)
        case .done:
            Label {
                Text("Done")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .font(.caption)
        case .failed:
            Label {
                Text("Failed")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .font(.caption)
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
                .frame(minHeight: altTextAreaMinHeight, maxHeight: altTextAreaMaxHeight)
                .padding(8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(Text("Alt text for \(item.filename)"))
        case .failed(let message):
            // A manual top-aligned HStack rather than `Label` — with a
            // multi-line message, `Label` centers its icon against the whole
            // wrapped block instead of the first line, unlike how a leading
            // icon reads next to wrapped text elsewhere on the platform.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.footnote)
        }
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(minHeight: altTextAreaMinHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
