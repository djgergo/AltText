import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = AltTextViewModel()
    @State private var isDropTargeted = false
    @State private var isFileImporterPresented = false
    @State private var isPhotosPickerPresented = false
    @State private var isAddSourceDialogPresented = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var isExportPresented = false
    @State private var exportDocument: AltTextEmbeddedImageDocument?
    @State private var exportContentType: UTType = .jpeg
    @State private var exportFilename = ""
    @State private var exportErrorMessage: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// iPhone portrait gives the toolbar roughly a third of the width a Mac
    /// window does, and the passive status indicator — informational, not
    /// something you act on — moves out of the toolbar entirely on compact
    /// widths (see `statusHeader`) rather than shrinking to an icon nobody
    /// can get the reason out of without a mouse to hover with.
    ///
    /// Add stays icon-only there too, but that's iOS's own doing, not a
    /// choice made here: the leading (`.navigation`) toolbar slot reduces
    /// whatever's placed in it to a bare icon on iOS regardless of label
    /// content, custom `buttonStyle`, or which of `.navigation`/
    /// `.topBarLeading` is used — confirmed by testing every combination.
    /// Moving it next to Generate to force text onto it only trades one
    /// problem for three others: it empties out the leading corner Generate
    /// used to balance, competes with Generate for the one slot that *can*
    /// show a label (forcing Generate's own label to truncate), and — if
    /// given Generate's non-prominent style to get a background at all —
    /// makes an always-tappable button look disabled. Icon-only-in-the-
    /// leading-corner is how Mail, Notes, and Reminders all treat a single
    /// secondary action anyway, so this leaves it there and lets macOS's
    /// unaffected leading slot show "Add Images" in full as before.
    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isCompact {
                    statusHeader
                }
                workspace
            }
            .navigationTitle("AltText")
            .toolbar {
                if !isCompact {
                    ToolbarItem(placement: .principal) {
                        ModelStatusView(state: viewModel.modelAvailability)
                            .labelStyle(.titleAndIcon)
                    }
                }

                ToolbarItem(placement: .navigation) {
                    Button {
                        isAddSourceDialogPresented = true
                    } label: {
                        addMenuLabel
                    }
                    .keyboardShortcut("o", modifiers: .command)
                    .confirmationDialog("Add Images", isPresented: $isAddSourceDialogPresented) {
                        Button("From Photos…") {
                            isPhotosPickerPresented = true
                        }
                        Button("From Files…") {
                            isFileImporterPresented = true
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    generateButton
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .toolbar(removing: .title)
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 520)
        #endif
        .task {
            viewModel.refreshAvailability()
        }
        // Apple Intelligence's model can finish downloading while this app is
        // backgrounded; there's no push notification for that; a foreground
        // check is the only way to notice without the person taking action.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshAvailability()
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.addImages(at: urls)
            }
        }
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $selectedPhotosPickerItems,
            matching: .images
        )
        .onChange(of: selectedPhotosPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                let urls = await PhotosImportHandler.urls(from: newItems)
                viewModel.addImages(at: urls)
                selectedPhotosPickerItems = []
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task { @MainActor in
                let urls = await ImageDropHandler.urls(from: providers)
                viewModel.addImages(at: urls)
            }
            return true
        }
        // Declared here rather than on each row: on macOS, `.fileExporter`
        // drives an NSSavePanel sheet that resolves its hosting window by
        // walking up the view hierarchy, which is unreliable — to the point
        // of wedging the app — when the modifier lives on a view nested
        // inside a List row's recycling machinery. iOS's document-picker
        // presentation doesn't share that fragility, which is why the same
        // per-row modifier only misbehaved on macOS.
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
        .alert(
            "Couldn't Export Image",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { isPresented in if !isPresented { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    // Encoding runs off the main actor since it re-reads and re-packages the
    // full-resolution original, not the row's small cached thumbnail.
    private func exportAltText(for item: ImageItem, text: String) {
        Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try AltTextMetadataEmbedder.embed(altText: text, into: item.url)
                }.value
                exportDocument = AltTextEmbeddedImageDocument(data: data)
                exportContentType = UTType(filenameExtension: item.url.pathExtension) ?? .jpeg
                exportFilename = item.filename
                isExportPresented = true
            } catch {
                exportErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Compact-width replacement for the toolbar's status item: full label,
    /// color, and (when unavailable) the actual reason, all visible without
    /// needing a hover the touch screen can't produce.
    private var statusHeader: some View {
        HStack {
            ModelStatusView(
                state: viewModel.modelAvailability,
                showsDetail: true,
                onRefresh: { viewModel.refreshAvailability() }
            )
            .labelStyle(.titleAndIcon)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var workspace: some View {
        if viewModel.items.isEmpty {
            DropZoneView(
                isTargeted: isDropTargeted,
                onChoosePhotos: { isPhotosPickerPresented = true },
                onChooseFiles: { isFileImporterPresented = true }
            )
        } else {
            List {
                // Separates the image list from the toolbar above it, matching
                // the divider that appears below every row. Wrapped in a VStack
                // because a bare Divider() as a List row's only content has no
                // stack axis to size against and renders vertically instead.
                VStack(spacing: 0) {
                    Divider()
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                ForEach(viewModel.items) { item in
                    ImageRowView(
                        item: item,
                        onRegenerate: { Task { await viewModel.regenerateAltText(for: item.id) } },
                        onExport: { text in exportAltText(for: item, text: text) },
                        onRemove: { viewModel.removeImage(id: item.id) }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.removeImage(id: item.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.removeImage(id: item.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .padding(4)
                        .allowsHitTesting(false)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isDropTargeted)
        }
    }

    /// `.titleAndIcon` is the ask; whether it's honored is entirely up to the
    /// platform's leading toolbar slot (see the note on `isCompact`) — iOS
    /// renders this as icon-only no matter what's requested here, macOS
    /// renders it in full, and neither needs this view to know which.
    private var addMenuLabel: some View {
        Label("Add Images", systemImage: "photo.badge.plus")
            .labelStyle(.titleAndIcon)
            .help("Add Images")
    }

    /// `.glassProminent` is Apple's deliberate pattern for the toolbar's one
    /// tinted/"prominent" action, which the system always collapses to a
    /// circular icon-only chip regardless of available width — not usable
    /// here. Plain `.glass` keeps the label but comes wrapped in the
    /// toolbar's own automatic shared background, which doesn't match our
    /// capsule's shape and shows through as an outer border. A custom style
    /// draws its own solid capsule instead, with that shared background
    /// hidden via `.sharedBackgroundVisibility(.hidden)` on the ToolbarItem
    /// so there's nothing behind it to mismatch.
    @ViewBuilder
    private var generateButton: some View {
        let title = viewModel.isGenerating ? "Generating…" : "Generate"

        Button {
            Task { await viewModel.generateAltText() }
        } label: {
            Label(title, systemImage: "sparkles")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(GenerateButtonStyle(isProminent: viewModel.canGenerate))
        .disabled(!viewModel.canGenerate)
        .keyboardShortcut(.return, modifiers: .command)
    }
}

private struct GenerateButtonStyle: ButtonStyle {
    let isProminent: Bool

    @Environment(\.self) private var environment

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isProminent ? AnyShapeStyle(prominentForeground) : AnyShapeStyle(.secondary))
            .background(Capsule().fill(isProminent ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.quaternary)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    // White (the usual choice for a filled capsule) can drop below readable
    // contrast against light accent colors some people choose (yellow, mint,
    // …). Picking black or white from the tint's own relative luminance keeps
    // this legible for every system accent color instead of just the default.
    private var prominentForeground: Color {
        let resolved = Color.accentColor.resolve(in: environment)
        func linearize(_ component: Float) -> Float {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linearize(resolved.red)
            + 0.7152 * linearize(resolved.green)
            + 0.0722 * linearize(resolved.blue)
        return luminance > 0.5 ? .black : .white
    }
}

#Preview("Regular width") {
    ContentView()
}

// Forces the compact layout (shortened "Add"/"Generate" toolbar labels, full
// status readout under the title instead of in the toolbar) directly in the
// canvas, without needing to boot an iPhone Simulator to check it.
#Preview("Compact width (iPhone portrait)") {
    ContentView()
        .environment(\.horizontalSizeClass, .compact)
        .frame(width: 390, height: 700)
}
