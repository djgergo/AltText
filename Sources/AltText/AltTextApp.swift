import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct AltTextApp: App {
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
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
