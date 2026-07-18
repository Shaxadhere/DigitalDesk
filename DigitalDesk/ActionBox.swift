import SwiftUI

struct ActionBox: View {
    let side: String
    let isGlowing: Bool
    
    @Binding var actionType: SlapActionType
    @Binding var parameter: String

    @State private var showingParameterInput = false
    @State private var draftParameter = ""

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
        Menu {
            ForEach(SlapActionType.allCases) { type in
                Button {
                    actionType = type
                    // If it needs a parameter, open the input dialog automatically
                    if type == .openURL || type == .openAppFolder || type == .runShortcut {
                        draftParameter = parameter
                        showingParameterInput = true
                    }
                } label: {
                    Label(type.rawValue, systemImage: type.icon)
                }
            }
            
            // Allow editing parameter if already selected
            if actionType == .openURL || actionType == .openAppFolder || actionType == .runShortcut {
                Divider()
                Button {
                    draftParameter = parameter
                    showingParameterInput = true
                } label: {
                    Label("Configure: \(parameter.isEmpty ? "None" : parameter)", systemImage: "pencil")
                }
            }
            
        } label: {
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

                    Image(systemName: actionType.icon)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(iconFgColor)
                        .shadow(color: iconShadowColor, radius: 8)
                }

                Text(actionType.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(titleColor)

                Text(actionType.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(height: 30) // Fixed height to prevent jumping
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
            .contentShape(Rectangle()) // Make entire area clickable for Menu
        }
        .buttonStyle(.plain) // Remove default menu button styling
        .popover(isPresented: $showingParameterInput) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Configure \(actionType.rawValue)")
                    .font(.headline)
                
                TextField("Enter value...", text: $draftParameter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                if actionType == .openURL {
                    Text("Example: https://youtube.com").font(.caption).foregroundColor(.secondary)
                } else if actionType == .openAppFolder {
                    Text("Example: /Applications/Safari.app").font(.caption).foregroundColor(.secondary)
                } else if actionType == .runShortcut {
                    Text("Example: My Awesome Shortcut").font(.caption).foregroundColor(.secondary)
                }
                
                HStack {
                    Spacer()
                    Button("Done") {
                        parameter = draftParameter
                        showingParameterInput = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
    }
}
