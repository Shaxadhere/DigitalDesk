import SwiftUI

/// The dropdown panel that appears when the user clicks the menu-bar icon.
struct MenuBarView: View {
    @EnvironmentObject var audioMonitor: AudioMonitor
    @EnvironmentObject var actionHandler: ActionHandler

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ───────────────────────────────────────────────────────────
            HeaderSection()
                .environmentObject(audioMonitor)

            Divider().padding(.vertical, 4)

            // ── VU Meters ────────────────────────────────────────────────────────
            VUSection()
                .environmentObject(audioMonitor)

            Divider().padding(.vertical, 4)

            // ── Sensitivity ──────────────────────────────────────────────────────
            SensitivitySection()
                .environmentObject(audioMonitor)

            Divider().padding(.vertical, 4)

            // ── Last Action ──────────────────────────────────────────────────────
            LastActionSection()
                .environmentObject(actionHandler)

            Divider().padding(.vertical, 4)

            // ── Controls ─────────────────────────────────────────────────────────
            ControlsSection()
                .environmentObject(audioMonitor)
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            // MainWindowView owns the onSlapDetected → ActionHandler wiring.
            // We only ensure listening is active from here.
            audioMonitor.startListening()
        }
    }
}

// MARK: - Header

private struct HeaderSection: View {
    @EnvironmentObject var audioMonitor: AudioMonitor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.title2)
                .foregroundStyle(audioMonitor.isListening ? .green : .secondary)
                .symbolEffect(.pulse, isActive: audioMonitor.isListening)

            VStack(alignment: .leading, spacing: 2) {
                Text("DeskSlap")
                    .font(.headline)
                Text(audioMonitor.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Last slap side badge
            if let side = audioMonitor.lastSlapSide {
                Text(side == .left ? "← L" : "R →")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(side == .left ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                    )
                    .foregroundStyle(side == .left ? .blue : .orange)
            }
        }
    }
}

// MARK: - VU Meters

private struct VUSection: View {
    @EnvironmentObject var audioMonitor: AudioMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LEVELS")
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)

            ChannelBar(label: "L", level: audioMonitor.leftLevel,  color: .blue)
            ChannelBar(label: "R", level: audioMonitor.rightLevel, color: .orange)
        }
    }
}

private struct ChannelBar: View {
    let label: String
    let level: Float
    let color: Color

    /// Scale: 0.0 – 0.3 maps to full bar (typical speech/desk-slap range).
    private var normalised: Double { min(Double(level) / 0.3, 1.0) }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.monospacedDigit())
                .frame(width: 12)
                .foregroundStyle(color)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * normalised)
                        .animation(.easeOut(duration: 0.05), value: normalised)
                }
            }
            .frame(height: 8)

            Text(String(format: "%.3f", level))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Sensitivity

private struct SensitivitySection: View {
    @EnvironmentObject var audioMonitor: AudioMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Sensitivity threshold")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.3f", audioMonitor.sensitivityThreshold))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: $audioMonitor.sensitivityThreshold,
                in: 0.01...0.5,
                step: 0.005
            )
            .tint(.accentColor)

            HStack {
                Text("More sensitive")
                Spacer()
                Text("Less sensitive")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Last Action

private struct LastActionSection: View {
    @EnvironmentObject var actionHandler: ActionHandler

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LAST ACTION")
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(actionHandler.lastActionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Controls

private struct ControlsSection: View {
    @EnvironmentObject var audioMonitor: AudioMonitor

    var body: some View {
        HStack {
            // Toggle button
            Button {
                if audioMonitor.isListening {
                    audioMonitor.stopListening()
                } else {
                    audioMonitor.startListening()
                }
            } label: {
                Label(
                    audioMonitor.isListening ? "Pause" : "Listen",
                    systemImage: audioMonitor.isListening ? "pause.fill" : "mic.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(audioMonitor.isListening ? .orange : .accentColor)
            .controlSize(.small)

            Spacer()

            // Quit button
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environmentObject(AudioMonitor())
        .environmentObject(ActionHandler())
}
