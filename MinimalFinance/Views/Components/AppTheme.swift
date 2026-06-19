import SwiftUI

enum AppTheme {
    static let background = Color.white
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let contentPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 32
    /// Pull reveal height: top inset + one line of subheadline text.
    static let pullRevealHeight: CGFloat = contentPadding + 20
}
