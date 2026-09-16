#if os(macOS)
import AppKit

// Registering a servicesProvider is the one piece of the macOS Services menu
// integration SwiftUI's `App` protocol has no direct hook for — it has to
// happen through an NSApplicationDelegate.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Set by AltTextApp once the view model exists; the provider looks it up
    // lazily at invocation time rather than needing it at registration time.
    var viewModel: AltTextViewModel?

    private var serviceProvider: AltTextServiceProvider?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let provider = AltTextServiceProvider(viewModel: { [weak self] in self?.viewModel })
        serviceProvider = provider
        NSApplication.shared.servicesProvider = provider
    }
}
#endif
