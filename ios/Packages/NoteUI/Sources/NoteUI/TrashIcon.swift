import SwiftUI

/// DESIGN.md's trash: a lid with its handle over a tapered can with two ribs, drawn in a 24-point square and scaled to
/// the frame it is given. Stroke it with `style`.
nonisolated struct TrashIcon: Shape {
    static let style = StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)

    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
        }
        var path = Path()
        path.addLines([point(4, 7), point(20, 7)])
        path.addLines([point(9.5, 7), point(9.5, 4.5), point(14.5, 4.5), point(14.5, 7)])
        path.addLines([point(6, 7), point(7, 20), point(17, 20), point(18, 7)])
        path.addLines([point(10.5, 10.5), point(10.5, 16.5)])
        path.addLines([point(13.5, 10.5), point(13.5, 16.5)])
        return path
    }
}
