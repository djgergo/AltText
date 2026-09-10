import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = AltTextViewModel()
    @State private var isDropTargeted = false
    @State private var isFileImporterPresented = false
    @State private var isPhotosPickerPresented = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    /// iPhone portrait gives the toolbar roughly a third of the width a Mac
    /// window does. Three labeled items (add / status / generate) don't all
    /// fit there, so the two actions the user is actively trying to do keep
    /// short labels, and the passive status indicator — informational, not
    /// something you act on — moves out of the toolbar entirely on compact
    /// widths (see `statusHeader`) rather than shrinking to an icon nobody
    /// can get the reason out of without a mouse to hover with.
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
                ToolbarItem(placement: .navigation) {
                    Menu {
                        Button {
                            isPhotosPickerPresented = true
                        } label: {
                            Label("From Photos…", systemImage: "photo.on.rectangle.angled")
                        }

                        Button {
                            isFileImporterPresented = true
                        } label: {
                            Label("From Files…", systemImage: "folder")
                        }
                    } label: {
                        Label(isCompact ? "Add" : "Add Images", systemImage: "photo.badge.plus")
                    }
                    .labelStyle(.titleAndIcon)
                    .keyboardShortcut("o", modifiers: .command)
                }

                if !isCompact {
                    ToolbarItem(placement: .principal) {
                        ModelStatusView(state: viewModel.modelAvailability)
                            .labelStyle(.titleAndIcon)
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
                        altText: Binding(
                            get: { viewModel.altText(for: item.id) },
                            set: { viewModel.setAltText($0, for: item.id) }
                        ),
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
            .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        }
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
        let title = viewModel.isGenerating ? "Generating…" : (isCompact ? "Generate" : "Generate Alt Text")

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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isProminent ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .background(Capsule().fill(isProminent ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.quaternary)))
            .opacity(configuration.isPressed ? 0.75 : 1)
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
