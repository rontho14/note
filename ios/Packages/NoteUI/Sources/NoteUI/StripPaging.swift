import SwiftUI

/// Pages the strip one screen at a time: a drag lands on the screen nearest where its momentum would carry it, at
/// most one screen from where it began. While `holdsLastPage`, a drag that began on the last screen and would land
/// before it springs back to it instead and reports itself through `onHeldSwipe`, outside this target calculation. A
/// drag that springs back anyway, or began anywhere else, reports nothing.
struct StripPaging: ScrollTargetBehavior {
    let holdsLastPage: Bool
    let onHeldSwipe: () -> Void

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let width = context.containerSize.width
        guard width > 0 else {
            return
        }
        let start = (context.originalTarget.rect.minX / width).rounded()
        let landing = (target.rect.minX / width).rounded().clamped(to: start - 1...start + 1)
        let lastPage = ((context.contentSize.width - width) / width).rounded()
        if holdsLastPage, start == lastPage, landing < start {
            target.rect.origin.x = start * width
            Task { onHeldSwipe() }
        } else {
            target.rect.origin.x = landing * width
        }
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
