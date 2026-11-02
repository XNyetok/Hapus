import SwiftUI

/// Design tokens. Keep the UI calm: one accent color, generous spacing, few borders.
enum Design {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 12
    }

    /// Keeps lines readable on large displays.
    static let readableWidth: CGFloat = 880

    /// Card fill and outline. Derived from `primary`, so they work in light and dark mode.
    static let surface = Color.primary.opacity(0.04)
    static let hairline = Color.primary.opacity(0.08)
}
