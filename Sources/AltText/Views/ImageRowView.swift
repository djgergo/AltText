import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImageRowView: View {
    let item: ImageItem
    let onRegenerate: () -> Void
    let onExport: (String) -> Void
    let onRemove: () -> Void

    @State private var thumbnail: PlatformImage?
    @State private var showsCopyConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Scales with Dynamic Type so the placeholder/generated text areas stay
    // tall enough to read comfortably at larger accessibility text sizes.
    @ScaledMetric(relativeTo: .body) private var altTextAreaMinHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            // Top-aligned rather than centered: once the done state grew a
            // second line for its action row, centering made the thumbnail
            // drift away from the filename it's paired with as row height
            // grew, instead of anchoring to it the way a list avatar should.
            HStack(alignment: .top, spacing: 14) {
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

    // Read-only text on its own line, with a dedicated action row underneath
    // rather than icons squeezed beside it — four full-size tap targets
    // don't fit next to the text without crowding out the content they act
    // on, so this follows the same shape as Photos' bottom action bar:
    // everything visible at once, evenly spaced, below the content.
    private func doneAltText(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            actionRow(text: text)
        }
    }

    // Icon-only controls read fine once you know them, but nothing forces a
    // first-time visitor to hover for a tooltip (and iOS has no hover at
    // all) — a one-word caption under each icon, like Photos' own bottom
    // toolbar, makes the row self-explanatory at a glance instead of
    // relying on discovery.
    private func actionRow(text: String) -> some View {
        HStack(spacing: 0) {
            actionButton(
                systemImage: "arrow.clockwise",
                title: "Regenerate",
                accessibilityLabel: "Regenerate alt text",
                help: "Regenerate alt text",
                action: onRegenerate
            )

            actionButton(
                systemImage: showsCopyConfirmation ? "checkmark" : "doc.on.doc",
                title: showsCopyConfirmation ? "Copied" : "Copy",
                accessibilityLabel: showsCopyConfirmation ? "Copied" : "Copy alt text",
                help: "Copy alt text",
                action: { copyToPasteboard(text) }
            )

            shareButton(text: text)

            actionButton(
                systemImage: "square.and.arrow.down",
                title: "Export",
                accessibilityLabel: "Export \(item.filename) with alt text embedded",
                help: "Export with alt text embedded",
                action: { onExport(text) }
            )
        }
    }

    private func actionButton(
        systemImage: String,
        title: String,
        accessibilityLabel: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionLabel(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private func actionLabel(systemImage: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }

    // Sharing `item.url` directly would use URL's own Transferable
    // conformance, which hands recipients the URL itself rather than the
    // image — that's why Reminders showed a raw file:// link instead of an
    // attached photo. `ShareableImage` instead promises actual image bytes
    // under an image content type, so recipients treat it as a real photo.
    private func shareButton(text: String) -> some View {
        ShareLink(
            item: ShareableImage(url: item.url),
            message: Text(text),
            preview: SharePreview(Text(item.filename), image: sharePreviewImage)
        ) {
            actionLabel(systemImage: "square.and.arrow.up", title: "Share")
        }
        .buttonStyle(.plain)
        .help("Share image and alt text")
        .accessibilityLabel(Text("Share \(item.filename) with alt text"))
    }

    private var sharePreviewImage: Image {
        if let thumbnail {
            Image(platformImage: thumbnail)
        } else {
            Image(systemName: "photo")
        }
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

// Wraps a file URL so ShareLink promises actual image bytes rather than
// deferring to URL's own Transferable conformance, which shares the URL
// as a reference/link instead of the image it points to.
private struct ShareableImage: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .image) { shareable in
            SentTransferredFile(try shareable.exportedFileURL())
        }
    }

    // Copies the original into a fresh temporary file while explicitly
    // holding security-scoped access: the share extension reads the file
    // asynchronously, possibly after this app's own scoped access (from
    // `.fileImporter` or a drag) would otherwise have already expired.
    private func exportedFileURL() throws -> URL {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
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
            ImageRowView(item: item, onRegenerate: {}, onExport: { _ in }, onRemove: {})
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
    }
    .listStyle(.plain)
}
