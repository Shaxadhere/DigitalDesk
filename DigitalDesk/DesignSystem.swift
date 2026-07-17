import SwiftUI

// MARK: - Shared Design Tokens
// Internal (not fileprivate) so every file in the target can use these.

extension Color {
    /// Deep charcoal – main window background.
    static let dsBackground = Color(red: 0.10,  green: 0.10,  blue: 0.115)
    /// Slightly lighter charcoal – card / box surfaces.
    static let dsSurface    = Color(red: 0.155, green: 0.155, blue: 0.175)
    /// Subtle border around cards.
    static let dsBorder     = Color(white: 0.22)
    /// Neon green (#39FF14) – glow accent.
    static let neon         = Color(red: 0.224, green: 1.00, blue: 0.078)
    /// Primary text.
    static let dsText       = Color(white: 0.93)
    /// Secondary / muted text.
    static let dsMuted      = Color(white: 0.48)
}
