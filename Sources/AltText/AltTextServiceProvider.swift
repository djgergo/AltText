#if os(macOS)
import AppKit
import UniformTypeIdentifiers

// Backs the "Generate Alt Text" entry in the system Services menu (declared
// in Resources/NSServices.plist), so selecting image files in Finder — or
// any app that puts file URLs on the services pasteboard — can hand them
// straight to this app without opening it and using Add Images first.
final class AltTextServiceProvider: NSObject {
    private let viewModel: () -> AltTextViewModel?

    init(viewModel: @escaping () -> AltTextViewModel?) {
        self.viewModel = viewModel
    }

    // Signature and selector name are fixed by NSServices' Objective-C-era
    // contract: the method name here must match NSMessage in the plist
    // exactly, and the parameter shape (NSPasteboard, String, error
    // out-pointer) is what AppKit expects to call. AppKit always delivers
    // service invocations on the main thread, so this genuinely is
    // main-actor work, not just a warning to silence.
    @MainActor @objc func generateAltText(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let viewModel = viewModel() else {
            error.pointee = "AltText isn't ready yet. Try again in a moment."
            return
        }

        guard let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !fileURLs.isEmpty else {
            error.pointee = "No files were selected."
            return
        }

        let imageURLs = fileURLs.filter { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
            return type.conforms(to: .image)
        }
        guard !imageURLs.isEmpty else {
            error.pointee = "The selected files aren't images."
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        Task {
            await viewModel.addImagesAndGenerate(at: imageURLs)
        }
    }
}
#endif
