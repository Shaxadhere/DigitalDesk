import SwiftUI

@main
struct DeskSlapApp: App {
    @StateObject private var audioMonitor = AudioMonitor()
    @StateObject private var actionHandler = ActionHandler()

    var body: some Scene {
        // ── Main visual window ───────────────────────────────────────────────────
        Window("DeskSlap", id: "main") {
            MainWindowView()
                .environmentObject(audioMonitor)
                .environmentObject(actionHandler)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 430)

        // ── Menu bar extra (quick controls) ─────────────────────────────────────
        MenuBarExtra("DeskSlap", systemImage: "hand.raised.fill") {
            MenuBarView()
                .environmentObject(audioMonitor)
                .environmentObject(actionHandler)
        }
        .menuBarExtraStyle(.window)
    }
}
