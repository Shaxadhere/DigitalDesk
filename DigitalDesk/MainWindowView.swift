import SwiftUI

// MARK: - Design System ─────────────────────────────────────────────────────────

fileprivate extension Color {
    /// Deep charcoal — main window background.
    static let dsBackground = Color(red: 0.10, green: 0.10, blue: 0.115)
    /// Slightly lighter charcoal — card/box surfaces.
    static let dsSurface    = Color(red: 0.155, green: 0.155, blue: 0.175)
    /// Subtle border around cards.
    static let dsBorder     = Color(white: 0.22)
    /// Neon green for glows (#39FF14).
    static let neon         = Color(red: 0.224, green: 1.00, blue: 0.078)
    /// Primary text.
    static let dsText       = Color(white: 0.93)
    /// Secondary / muted text.
    static let teal      = Color(white: 0.48)
}

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
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: audioMonitor.isListening)
                }

                Text("DeskSlap")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.teal)
            }

            // Status badge
            HStack(spacing: 5) {
                Circle()
                    .fill(audioMonitor.isListening ? Color.blue : Color.teal)
                    .frame(width: 6, height: 6)
                    .shadow(color: audioMonitor.isListening ? .blue : .clear, radius: 4)
                Text(audioMonitor.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.teal)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.dsSurface))

            Spacer()

            // Sensitivity slider
            HStack(spacing: 8) {
                Image(systemName: "dial.low")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Slider(value: $audioMonitor.sensitivityThreshold, in: 0.01...0.5, step: 0.005)
                    .tint(.blue)
                    .frame(width: 130)
                    .controlSize(.small)
                Image(systemName: "dial.high")
                    .font(.caption)
                    .foregroundStyle(.teal)
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
            // If this number never exceeds your threshold when you slap,
            // drag the sensitivity slider to the left to lower the threshold.
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
            .buttonStyle(.plain)
        }
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

// MARK: - Action Box ─────────────────────────────────────────────────────────────

private struct ActionBox: View {
    let side: String
    let icon: String
    let actionName: String
    let detail: String
    let isGlowing: Bool

    var body: some View {
        VStack(spacing: 14) {
            // Side label
            Text(side)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(isGlowing ? Color.blue : Color.teal)

            // Icon
            ZStack {
                Circle()
                    .fill(isGlowing
                          ? Color.blue.opacity(0.18)
                          : Color.dsSurface.opacity(0.6))
                    .frame(width: 64, height: 64)
                    .shadow(
                        color: isGlowing ? Color.blue.opacity(0.5) : .clear,
                        radius: isGlowing ? 18 : 0
                    )
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(isGlowing ? Color.blue : Color(white: 0.65))
                    .shadow(color: isGlowing ? Color.blue : .clear, radius: 8)
            }

            // Action name
            Text(actionName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isGlowing ? Color.blue : Color.dsText)

            // Detail text
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.teal)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .frame(width: 165)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isGlowing ? Color.blue : Color.dsBorder,
                            lineWidth: isGlowing ? 1.8 : 1
                        )
                )
        )
        // Outer glow via drop shadow layered × 2
        .shadow(
            color: isGlowing ? Color.blue.opacity(0.55) : .clear,
            radius: 22, x: 0, y: 0
        )
        .shadow(
            color: isGlowing ? Color.blue.opacity(0.25) : .clear,
            radius: 40, x: 0, y: 0
        )
        .animation(.spring(duration: 0.18), value: isGlowing)
    }
}

// MARK: - MacBook Illustration ──────────────────────────────────────────────────

private struct MacBookIllustration: View {
    let leftGlowing: Bool
    let rightGlowing: Bool

    /// Subtle ambient glow on whichever side is active.
    private var ambientColor: Color {
        if leftGlowing || rightGlowing { return .blue }
        return .clear
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── SCREEN ──────────────────────────────────────────────────────────
            ZStack {
                // Outer bezel
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(white: 0.28), lineWidth: 1)
                    )

                // Display panel
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.09, blue: 0.14),
                                Color(red: 0.04, green: 0.05, blue: 0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(7)

                // "Glowing screen" overlay when a slap fires
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.blue.opacity(leftGlowing || rightGlowing ? 0.06 : 0))
                    .padding(7)
                    .animation(.easeOut(duration: 0.15), value: leftGlowing || rightGlowing)

                // Apple logo
                Image(systemName: "apple.logo")
                    .font(.system(size: 22, weight: .thin))
                    .foregroundStyle(Color(white: 0.18))

                // Webcam dot
                Circle()
                    .fill(Color(white: 0.25))
                    .frame(width: 5, height: 5)
                    .offset(y: -52)
            }
            .frame(width: 200, height: 132)

            // ── HINGE LINE ──────────────────────────────────────────────────────
            HStack(spacing: 0) {
                // Left side highlight (glows on left slap)
                Rectangle()
                    .fill(leftGlowing ? Color.blue.opacity(0.8) : Color(white: 0.24))
                    .animation(.easeOut(duration: 0.12), value: leftGlowing)
                Rectangle()
                    .fill(rightGlowing ? Color.blue.opacity(0.8) : Color(white: 0.24))
                    .animation(.easeOut(duration: 0.12), value: rightGlowing)
            }
            .frame(width: 214, height: 2.5)

            // ── BASE / KEYBOARD ─────────────────────────────────────────────────
            ZStack(alignment: .top) {
                // Base shell
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 5,
                    bottomTrailingRadius: 5, topTrailingRadius: 0
                )
                .fill(Color(red: 0.14, green: 0.14, blue: 0.16))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 5,
                        bottomTrailingRadius: 5, topTrailingRadius: 0
                    )
                    .stroke(Color(white: 0.22), lineWidth: 1)
                )

                VStack(spacing: 0) {
                    // Keyboard rows
                    VStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { row in
                            HStack(spacing: 2.5) {
                                ForEach(0..<(row == 0 ? 14 : 12), id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color(white: 0.22))
                                        .frame(
                                            width: row == 0 ? 10 : 12,
                                            height: row == 0 ? 6 : 7
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                    Spacer()

                    // Trackpad
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.17))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(white: 0.25), lineWidth: 0.5)
                        )
                        .frame(width: 70, height: 40)
                        .padding(.bottom, 6)
                }
            }
            .frame(width: 214, height: 88)
        }
        // Ambient glow underneath the whole machine when a slap fires
        .shadow(
            color: ambientColor.opacity(0.18),
            radius: 30, x: 0, y: 8
        )
        .animation(.easeOut(duration: 0.15), value: leftGlowing || rightGlowing)
    }
}

// MARK: - Mini VU Meter ──────────────────────────────────────────────────────────

private struct MiniMeter: View {
    let label: String
    let level: Float

    private var normalised: Double { min(Double(level) / 0.3, 1.0) }

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dsMuted)
                .frame(width: 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.12))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.neon.opacity(0.5), Color.neon],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * normalised, 0))
                        .animation(.easeOut(duration: 0.05), value: normalised)
                }
            }
            .frame(height: 5)

            Text(String(format: "%.3f", level))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.dsMuted)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Peak View ───────────────────────────────────────────────────────────────
/// Extracted as a dedicated struct to avoid @ViewBuilder type-checker failures
/// that occur when `let` bindings with complex conditional foregroundStyle
/// are placed directly inside an HStack closure.

private struct PeakView: View {
    let peak: Float
    let threshold: Float

    private var isHot: Bool { peak >= threshold }

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text("PEAK")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dsMuted)
            Text(String(format: "%.4f", peak))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isHot ? Color.neon : Color.dsText)
                .animation(.easeOut(duration: 0.05), value: isHot)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHot ? Color.neon.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.1), value: isHot)
    }
}

// MARK: - Preview

#Preview {
    MainWindowView()
        .environmentObject(AudioMonitor())
        .environmentObject(ActionHandler())
        .frame(width: 760, height: 430)
}
