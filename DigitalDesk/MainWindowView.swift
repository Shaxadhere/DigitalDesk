import SwiftUI

// MARK: - Main Window View ──────────────────────────────────────────────────────

struct MainWindowView: View {
    @EnvironmentObject var audioMonitor: AudioMonitor
    @EnvironmentObject var actionHandler: ActionHandler

    // Per-side glow state
    @State private var leftGlowing  = false
    @State private var rightGlowing = false

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                titleBar
                slapLayout
                controlBar
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
        }
        .preferredColorScheme(.dark)
        // Bring window to front when it first appears
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            // Wire AudioMonitor → ActionHandler (single source of truth)
            audioMonitor.onSlapDetected = { event in
                actionHandler.handle(event)
            }
            audioMonitor.startListening()
        }
        // React to every slap via the UUID trigger
        .onChange(of: audioMonitor.slapTrigger) { _, _ in
            triggerGlow(for: audioMonitor.lastSlapSide)
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 12) {
            // App icon + name
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.neon.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.neon)
                        .symbolEffect(.pulse, isActive: audioMonitor.isListening)
                }

                Text("DeskSlap")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsText)
            }

            // Status badge
            HStack(spacing: 5) {
                Circle()
                    .fill(audioMonitor.isListening ? Color.neon : Color.dsMuted)
                    .frame(width: 6, height: 6)
                    .shadow(color: audioMonitor.isListening ? Color.neon : .clear, radius: 4)
                Text(audioMonitor.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.dsMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.dsSurface))

            Spacer()

            // Sensitivity slider
            HStack(spacing: 8) {
                Image(systemName: "dial.low")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
                Slider(value: $audioMonitor.sensitivityThreshold, in: 0.01...0.5, step: 0.005)
                    .tint(Color.neon)
                    .frame(width: 130)
                    .controlSize(.small)
                Image(systemName: "dial.high")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
        }
    }

    // MARK: - Main Content Layout

    private var slapLayout: some View {
        HStack(spacing: 28) {
            // LEFT action box
            ActionBox(
                side: "LEFT",
                icon: "speaker.wave.2.fill",
                actionName: "System Beep",
                detail: "Plays a macOS\nsystem alert sound",
                isGlowing: leftGlowing
            )

            Spacer()

            // MacBook illustration (centre)
            MacBookIllustration(
                leftGlowing: leftGlowing,
                rightGlowing: rightGlowing
            )
            .frame(width: 230, height: 200)

            Spacer()

            // RIGHT action box
            ActionBox(
                side: "RIGHT",
                icon: "desktopcomputer",
                actionName: "Calculator",
                detail: "Opens the macOS\nCalculator app",
                isGlowing: rightGlowing
            )
        }
    }

    // MARK: - Control Bar

    // Peak level — hoisted out of @ViewBuilder to avoid compiler type-checker issues.
    private var currentPeak: Float { max(audioMonitor.leftLevel, audioMonitor.rightLevel) }

    private var controlBar: some View {
        HStack(spacing: 16) {
            // VU meters
            VStack(alignment: .leading, spacing: 5) {
                MiniMeter(label: "L", level: audioMonitor.leftLevel)
                MiniMeter(label: "R", level: audioMonitor.rightLevel)
            }
            .frame(width: 180)

            // Live PEAK readout — turns neon green when threshold is crossed.
            PeakView(peak: currentPeak, threshold: audioMonitor.sensitivityThreshold)

            Spacer()

            // Last action confirmation
            if actionHandler.lastActionDescription != "—" {
                Text(actionHandler.lastActionDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.neon)
                    .lineLimit(1)
                    .animation(.easeIn(duration: 0.2), value: actionHandler.lastActionDescription)
            }

            Spacer()

            // Listen / Pause toggle
            Button {
                if audioMonitor.isListening { audioMonitor.stopListening() }
                else                        { audioMonitor.startListening() }
            } label: {
                listenButtonContent
            }
            .buttonStyle(.plain)
        }
    }
    
    private var listenButtonContent: some View {
        HStack(spacing: 6) {
            Image(systemName: audioMonitor.isListening ? "pause.fill" : "mic.fill")
            Text(audioMonitor.isListening ? "Pause" : "Listen")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(audioMonitor.isListening ? Color.dsBackground : Color.neon)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(audioMonitor.isListening ? Color.neon : Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.neon, lineWidth: 1.5)
                )
        )
    }

    // MARK: - Glow Trigger

    private func triggerGlow(for side: SlapSide?) {
        guard let side else { return }
        withAnimation(.easeOut(duration: 0.1)) {
            if side == .left  { leftGlowing  = true }
            else              { rightGlowing = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeOut(duration: 0.5)) {
                leftGlowing  = false
                rightGlowing = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainWindowView()
        .environmentObject(AudioMonitor())
        .environmentObject(ActionHandler())
        .frame(width: 760, height: 430)
}
