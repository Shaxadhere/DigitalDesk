import SwiftUI

// MARK: - MacBook Illustration ────────────────────────────────────────────────────
// All Color ternaries and gradient construction are computed properties,
// never inline inside @ViewBuilder closures.

struct MacBookIllustration: View {
    let leftGlowing: Bool
    let rightGlowing: Bool

    // ── Computed helpers ─────────────────────────────────────────────────────────
    private var isAnyGlowing: Bool        { leftGlowing || rightGlowing }
    private var ambientColor: Color       { isAnyGlowing ? Color.neon : Color.clear }
    private var screenOverlayOpacity: Double { isAnyGlowing ? 0.06 : 0 }
    private var leftHingeColor:  Color    { leftGlowing  ? Color.neon : Color(white: 0.24) }
    private var rightHingeColor: Color    { rightGlowing ? Color.neon : Color(white: 0.24) }

    private var screenGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.09, blue: 0.14),
                Color(red: 0.04, green: 0.05, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            screenSection
            hingeSection
            baseSection
        }
        .shadow(color: ambientColor.opacity(0.18), radius: 30, x: 0, y: 8)
        .animation(.easeOut(duration: 0.15), value: isAnyGlowing)
    }

    // MARK: - Screen

    private var screenSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.28), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 7)
                .fill(screenGradient)
                .padding(7)

            RoundedRectangle(cornerRadius: 7)
                .fill(Color.neon.opacity(screenOverlayOpacity))
                .padding(7)
                .animation(.easeOut(duration: 0.15), value: screenOverlayOpacity)

            Image(systemName: "apple.logo")
                .font(.system(size: 22, weight: .thin))
                .foregroundStyle(Color(white: 0.18))

            Circle()
                .fill(Color(white: 0.25))
                .frame(width: 5, height: 5)
                .offset(y: -52)
        }
        .frame(width: 200, height: 132)
    }

    // MARK: - Hinge

    private var hingeSection: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(leftHingeColor)
                .animation(.easeOut(duration: 0.12), value: leftGlowing)
            Rectangle()
                .fill(rightHingeColor)
                .animation(.easeOut(duration: 0.12), value: rightGlowing)
        }
        .frame(width: 214, height: 2.5)
    }

    // MARK: - Base

    private var baseSection: some View {
        ZStack(alignment: .top) {
            baseShell
            VStack(spacing: 0) {
                keyboardSection
                Spacer()
                trackpad
            }
        }
        .frame(width: 214, height: 88)
    }

    private var baseShell: some View {
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
    }

    private var keyboardSection: some View {
        VStack(spacing: 3) {
            KeyboardRow(keyCount: 14, keyWidth: 10, keyHeight: 6)
            KeyboardRow(keyCount: 12, keyWidth: 12, keyHeight: 7)
            KeyboardRow(keyCount: 12, keyWidth: 12, keyHeight: 7)
            KeyboardRow(keyCount: 12, keyWidth: 12, keyHeight: 7)
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
    }

    private var trackpad: some View {
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

// MARK: - Keyboard Row

struct KeyboardRow: View {
    let keyCount: Int
    let keyWidth: CGFloat
    let keyHeight: CGFloat

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<keyCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.22))
                    .frame(width: keyWidth, height: keyHeight)
            }
        }
    }
}
