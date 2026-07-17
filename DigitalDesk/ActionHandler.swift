import AppKit
import Combine

/// Handles the real-world action that fires in response to a SlapEvent.
///
/// Design: All action logic lives in one place.  Swap out or add new actions
/// by editing the two `handleLeft()` / `handleRight()` methods or inserting
/// new strategies without touching the audio layer at all.
@MainActor
final class ActionHandler: ObservableObject {

    // ─── Observability ───────────────────────────────────────────────────────────
    @Published var lastActionDescription: String = "—"

    // MARK: - Entry Point

    /// Route a SlapEvent to the appropriate side handler.
    func handle(_ event: SlapEvent) {
        print("╔══ ActionHandler.handle called ══╗")
        print("║ Side : \(event.side == .left ? "LEFT" : "RIGHT")")
        print("║ L-RMS: \(String(format: "%.5f", event.leftAmplitude))")
        print("║ R-RMS: \(String(format: "%.5f", event.rightAmplitude))")
        print("╚═════════════════════════════════╝")

        switch event.side {
        case .left:  handleLeft(event)
        case .right: handleRight(event)
        }
    }

    // MARK: - Left Slap Action

    /// LEFT SLAP → System beep + console log.
    private func handleLeft(_ event: SlapEvent) {
        print("▶ LEFT action: playing system beep")

        // Play a louder beep by sending NSSound named "Glass" first,
        // falling back to the system beep if the sound file isn't found.
        if let sound = NSSound(named: "Glass") {
            sound.volume = 1.0
            sound.play()
        } else {
            NSSound.beep()
        }

        lastActionDescription = "← Left slap → Beep  [\(timeString(event.timestamp))]"
    }

    // MARK: - Right Slap Action

    /// RIGHT SLAP → Open / activate Calculator + console log.
    private func handleRight(_ event: SlapEvent) {
        print("▶ RIGHT action: opening Calculator")

        // Resolve Calculator by bundle ID — works regardless of macOS version or path.
        if let calcURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.calculator"
        ) {
            print("  Calculator found at: \(calcURL.path)")
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: calcURL, configuration: cfg) { _, error in
                if let error {
                    print("  ✖ openApplication error: \(error.localizedDescription)")
                } else {
                    print("  ✔ Calculator launched / activated successfully")
                }
            }
        } else {
            // Fallback: try the well-known path
            print("  Bundle ID lookup failed – trying hardcoded path")
            let fallback = URL(fileURLWithPath: "/System/Applications/Calculator.app")
            NSWorkspace.shared.open(fallback)
        }

        lastActionDescription = "→ Right slap → Calculator  [\(timeString(event.timestamp))]"
    }

    // MARK: - Future Extension Points (Stubs)

    /// Runs an AppleScript string synchronously on a background queue.
    /// Uncomment and call from handleLeft / handleRight as needed.
    /*
    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error { print("AppleScript error: \(error)") }
            }
        }
    }
    */

    /// Simulates a global key-press via CGEvent.
    /// Requires Accessibility permission in System Settings.
    /*
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags   = flags
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
    */

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
