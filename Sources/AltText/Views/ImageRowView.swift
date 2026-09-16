import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImageRowView: View {
    let item: ImageItem
    let onRegenerate: () -> Void
    let onRemove: () -> Void

    @State private var thumbnail: PlatformImage?
    @State private var showsCopyConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Scales with Dynamic Type so the placeholder/generated text areas stay
    // tall enough to read comfortably at larger accessibility text sizes.
    @ScaledMetric(relativeTo: .body) private var altTextAreaMinHeight: CGFloat = 44

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
        case .done(let text):
            doneAltText(text)
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

    // Read-only text plus its two actions, laid out like the placeholder
    // states above it rather than as an editable field — generated alt text
    // is meant to be reviewed and reused, not hand-edited in place.
    private func doneAltText(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(minHeight: altTextAreaMinHeight, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)

            actionButton(
                systemImage: "arrow.clockwise",
                label: "Regenerate",
                help: "Regenerate alt text",
                action: onRegenerate
            )

            actionButton(
                systemImage: showsCopyConfirmation ? "checkmark" : "doc.on.doc",
                label: showsCopyConfirmation ? "Copied" : "Copy",
                help: "Copy alt text",
                action: { copyToPasteboard(text) }
            )

            shareButton(text: text)
        }
    }

    private func actionButton(systemImage: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(label))
    }

    // `message:` is SwiftUI's built-in way to pair a file share with
    // accompanying text — Mail drops it into the body, Notes/Messages
    // attach it as context — so there's no need for a custom Transferable
    // just to send the image and its caption together.
    private func shareButton(text: String) -> some View {
        ShareLink(item: item.url, message: Text(text), preview: SharePreview(Text(item.filename))) {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Share image and alt text")
        .accessibilityLabel(Text("Share \(item.filename) with alt text"))
    }

    private func copyToPasteboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif

        AccessibilityNotification.Announcement("Copied").post()

        withAnimation(reduceMotion ? nil : .default) {
            showsCopyConfirmation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(reduceMotion ? nil : .default) {
                showsCopyConfirmation = false
            }
        }
    }
}

#Preview {
    List {
        ForEach(
            [
                ImageItem(url: URL(filePath: "/tmp/sunset-beach.jpg"), status: .pending),
                ImageItem(url: URL(filePath: "/tmp/family-dinner.jpg"), status: .generating),
                ImageItem(
                    url: URL(filePath: "/tmp/golden-retriever.jpg"),
                    status: .done("A golden retriever puppy sits in tall green grass, looking up at the camera with its tongue out.")
                ),
                ImageItem(url: URL(filePath: "/tmp/broken.jpg"), status: .failed("Couldn't generate alt text for this image. Try again."))
            ]
        ) { item in
            ImageRowView(item: item, onRegenerate: {}, onRemove: {})
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
    }
    .listStyle(.plain)
}
