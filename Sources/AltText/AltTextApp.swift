import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct AltTextApp: App {
    // Owned here rather than inside ContentView so the macOS Services menu
    // handler (AltTextServiceProvider, wired through AppDelegate) can reach
    // the same instance the window displays instead of a second, invisible one.
    @State private var viewModel = AltTextViewModel()

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        // `swift run` launches a bare executable with no app bundle, so AppKit
        // treats it as background-only and it never gets a window. Xcode- or
        // Finder-launched builds don't need this — hence DEBUG-only.
        #if os(macOS) && DEBUG
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                #if os(macOS)
                .task {
                    appDelegate.viewModel = viewModel
                }
                #endif
        }
        .windowResizability(.contentMinSize)
    }
}
