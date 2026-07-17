import SwiftUI

// MARK: - Mini VU Meter ──────────────────────────────────────────────────────────

struct MiniMeter: View {
    let label: String
    let level: Float

    private var normalised: Double { min(Double(level) / 0.3, 1.0) }

    // Gradient defined as a property to avoid @ViewBuilder type-inference failure.
    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [Color.neon.opacity(0.5), Color.neon],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

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
                        .fill(barGradient)
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

struct PeakView: View {
    let peak: Float
    let threshold: Float

    private var isHot: Bool { peak >= threshold }
    
    private var borderColor: Color {
        isHot ? Color.neon.opacity(0.6) : Color.clear
    }
    
    private var textColor: Color {
        isHot ? Color.neon : Color.dsText
    }

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text("PEAK")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.dsMuted)
            Text(String(format: "%.4f", peak))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(textColor)
                .animation(.easeOut(duration: 0.05), value: isHot)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .animation(.easeOut(duration: 0.1), value: isHot)
    }
}
