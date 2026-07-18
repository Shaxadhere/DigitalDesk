import AppKit
import Combine

enum SlapActionType: String, CaseIterable, Identifiable {
    case systemBeep = "System Beep"
    case openCalculator = "Calculator"
    case lockMac = "Lock Mac"
    case openURL = "Open URL"
    case openAppFolder = "Open App/Folder"
    case runShortcut = "Run Shortcut"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .systemBeep: return "speaker.wave.2.fill"
        case .openCalculator: return "number.square.fill"
        case .lockMac: return "lock.fill"
        case .openURL: return "safari.fill"
        case .openAppFolder: return "folder.fill"
        case .runShortcut: return "bolt.fill"
        }
    }
    
    var detail: String {
        switch self {
        case .systemBeep: return "Plays a macOS\nsystem alert sound"
        case .openCalculator: return "Opens the macOS\nCalculator app"
        case .lockMac: return "Instantly locks\nyour MacBook"
        case .openURL: return "Opens a website\nin default browser"
        case .openAppFolder: return "Opens a specific\napp or folder path"
        case .runShortcut: return "Runs a macOS\nShortcut by name"
        }
    }
}

@MainActor
final class ActionHandler: ObservableObject {

    @Published var lastActionDescription: String = "—"

    func execute(side: SlapSide, actionType: SlapActionType, parameter: String) {
        let sideStr = side == .left ? "← Left" : "→ Right"
        let timestamp = timeString(Date())
        
        switch actionType {
        case .systemBeep:
            if let sound = NSSound(named: "Glass") {
                sound.volume = 1.0
                sound.play()
            } else {
                NSSound.beep()
            }
            lastActionDescription = "\(sideStr) slap → Beep [\(timestamp)]"
            
        case .openCalculator:
            if let calcURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.calculator") {
                let cfg = NSWorkspace.OpenConfiguration()
                cfg.activates = true
                NSWorkspace.shared.openApplication(at: calcURL, configuration: cfg)
            } else {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calculator.app"))
            }
            lastActionDescription = "\(sideStr) slap → Calculator [\(timestamp)]"
            
        case .lockMac:
            runAppleScript("tell application \"System Events\" to keystroke \"q\" using {control down, command down}")
            lastActionDescription = "\(sideStr) slap → Lock Mac [\(timestamp)]"
            
        case .openURL:
            var urlString = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.lowercased().hasPrefix("http") && !urlString.isEmpty {
                urlString = "https://" + urlString
            }
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                lastActionDescription = "\(sideStr) slap → Open URL [\(timestamp)]"
            } else {
                lastActionDescription = "Invalid URL"
            }
            
        case .openAppFolder:
            let path = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                lastActionDescription = "\(sideStr) slap → Open Path [\(timestamp)]"
            } else {
                lastActionDescription = "Invalid Path"
            }
            
        case .runShortcut:
            let shortcutName = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
            if !shortcutName.isEmpty {
                let task = Process()
                task.launchPath = "/usr/bin/shortcuts"
                task.arguments = ["run", shortcutName]
                try? task.run()
                lastActionDescription = "\(sideStr) slap → Shortcut [\(timestamp)]"
            } else {
                lastActionDescription = "Invalid Shortcut"
            }
        }
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error { print("AppleScript error: \(error)") }
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
