import SwiftUI

// MARK: - Action Box ──────────────────────────────────────────────────────────────
// Each complex expression is a computed property — never inline ternaries
// with Color arithmetic inside @ViewBuilder closures.

struct ActionBox: View {
    let side: String
    let icon: String
    let actionName: String
    let detail: String
    let isGlowing: Bool

    // ── Computed colour helpers ──────────────────────────────────────────────────
    private var labelColor:      Color { isGlowing ? Color.neon   : Color.dsMuted }
    private var iconFgColor:     Color { isGlowing ? Color.neon   : Color(white: 0.65) }
    private var iconBgColor:     Color { isGlowing ? Color.neon.opacity(0.18) : Color.dsSurface.opacity(0.6) }
    private var iconShadowColor: Color { isGlowing ? Color.neon   : Color.clear }
    private var titleColor:      Color { isGlowing ? Color.neon   : Color.dsText }
    private var borderColor:     Color { isGlowing ? Color.neon   : Color.dsBorder }
    private var borderWidth:     CGFloat { isGlowing ? 1.8 : 1 }
    private var glowColor1:      Color { isGlowing ? Color.neon.opacity(0.55) : Color.clear }
    private var glowColor2:      Color { isGlowing ? Color.neon.opacity(0.25) : Color.clear }
    private var iconShadowRadius: CGFloat { isGlowing ? 18 : 0 }

    var body: some View {
        VStack(spacing: 14) {
            Text(side)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(labelColor)

            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 64, height: 64)
                    .shadow(color: iconShadowColor.opacity(0.5), radius: iconShadowRadius)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(iconFgColor)
                    .shadow(color: iconShadowColor, radius: 8)
            }

            Text(actionName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(titleColor)

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.dsMuted)
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
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        )
        .shadow(color: glowColor1, radius: 22, x: 0, y: 0)
        .shadow(color: glowColor2, radius: 40, x: 0, y: 0)
        .animation(.spring(duration: 0.18), value: isGlowing)
    }
}
