import SwiftUI
import UIKit

struct PullDownAddReveal: View {
    let pullOffset: CGFloat
    let threshold: CGFloat

    private var progress: CGFloat {
        min(1, max(0, pullOffset / threshold))
    }

    private var visibleHeight: CGFloat {
        min(threshold, max(0, pullOffset))
    }

    var body: some View {
        Text("Add transaction")
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.contentPadding * progress)
            .frame(height: visibleHeight, alignment: .topLeading)
            .opacity(Double(progress))
            .scaleEffect(0.9 + (0.1 * progress), anchor: .leading)
    }
}

struct PullDownAddGestureHandler {
    private(set) var peakPull: CGFloat = 0
    private var didCrossThreshold = false

    mutating func process(
        rawOffset: CGFloat,
        threshold: CGFloat,
        isEnabled: Bool,
        pullOffset: inout CGFloat
    ) {
        guard isEnabled else { return }

        pullOffset = max(0, rawOffset)

        if pullOffset > 0 {
            peakPull = max(peakPull, pullOffset)
            if peakPull >= threshold, !didCrossThreshold {
                didCrossThreshold = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else if peakPull > 0 {
            reset()
        }
    }

    mutating func consumeTrigger(threshold: CGFloat) -> Bool {
        let shouldTrigger = peakPull >= threshold
        reset()
        return shouldTrigger
    }

    mutating func reset() {
        peakPull = 0
        didCrossThreshold = false
    }
}
