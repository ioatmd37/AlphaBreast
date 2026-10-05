import SwiftUI
import ScanCore

/// Front view of the torso with where each point goes. Normalised coordinates, viewer's
/// perspective: the patient's right side is on the left of the drawing.
struct TorsoDiagram: View {
    static let positions: [PointKey: CGPoint] = [
        .landmark(.sn): CGPoint(x: 0.50, y: 0.17),
        .landmark(.nR): CGPoint(x: 0.34, y: 0.47),
        .landmark(.nL): CGPoint(x: 0.66, y: 0.47),
        .landmark(.imfR): CGPoint(x: 0.34, y: 0.62),
        .landmark(.imfL): CGPoint(x: 0.66, y: 0.62),
        .landmark(.medR): CGPoint(x: 0.43, y: 0.47),
        .landmark(.latR): CGPoint(x: 0.20, y: 0.47),
        .landmark(.medL): CGPoint(x: 0.57, y: 0.47),
        .landmark(.latL): CGPoint(x: 0.80, y: 0.47),
        .reference(.xiphoid): CGPoint(x: 0.50, y: 0.58),
        .reference(.acromionR): CGPoint(x: 0.13, y: 0.15),
        .reference(.acromionL): CGPoint(x: 0.87, y: 0.15),
        .reference(.scaleA): CGPoint(x: 0.42, y: 0.86),
        .reference(.scaleB): CGPoint(x: 0.58, y: 0.86),
    ]

    var body: some View {
        Canvas { context, size in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * size.width, y: y * size.height)
            }

            var outline = Path()
            outline.move(to: point(0.42, 0.0))
            outline.addLine(to: point(0.42, 0.07))
            outline.addQuadCurve(to: point(0.10, 0.14), control: point(0.22, 0.08))
            outline.addQuadCurve(to: point(0.17, 0.34), control: point(0.06, 0.24))
            outline.addQuadCurve(to: point(0.26, 1.0), control: point(0.20, 0.70))
            outline.addLine(to: point(0.74, 1.0))
            outline.addQuadCurve(to: point(0.83, 0.34), control: point(0.80, 0.70))
            outline.addQuadCurve(to: point(0.90, 0.14), control: point(0.94, 0.24))
            outline.addQuadCurve(to: point(0.58, 0.07), control: point(0.78, 0.08))
            outline.addLine(to: point(0.58, 0.0))
            context.stroke(outline, with: .color(.secondary), lineWidth: 1.5)

            for (cx, side) in [(0.34, -1.0), (0.66, 1.0)] {
                var breast = Path()
                breast.move(to: point(cx - 0.14 * side, 0.45))
                breast.addQuadCurve(to: point(cx + 0.09 * side, 0.50), control: point(cx - 0.02 * side, 0.70))
                context.stroke(breast, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            }

            var scaleLine = Path()
            scaleLine.move(to: point(0.42, 0.86))
            scaleLine.addLine(to: point(0.58, 0.86))
            context.stroke(scaleLine, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            context.draw(Text("10.0 cm").font(.system(size: 9)).foregroundStyle(.secondary), at: point(0.50, 0.90))

            for (key, p) in Self.positions {
                let center = point(p.x, p.y)
                let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                let color = PointStyle.color(for: key)
                switch key {
                case .landmark where key.needsMarker:
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                case .landmark:
                    context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
                case .reference:
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: center.x, y: center.y - 5))
                    diamond.addLine(to: CGPoint(x: center.x + 5, y: center.y))
                    diamond.addLine(to: CGPoint(x: center.x, y: center.y + 5))
                    diamond.addLine(to: CGPoint(x: center.x - 5, y: center.y))
                    diamond.closeSubpath()
                    context.fill(diamond, with: .color(color))
                }
                let below = key == .landmark(.imfR) || key == .landmark(.imfL) || key == .reference(.xiphoid)
                    || key == .reference(.scaleA) || key == .reference(.scaleB)
                context.draw(
                    Text(key.rawValue).font(.system(size: 10, weight: .semibold)),
                    at: CGPoint(x: center.x, y: center.y + (below ? 12 : -12))
                )
            }

            context.draw(Text("ขวาผู้ป่วย").font(.caption2).foregroundStyle(.secondary), at: point(0.12, 0.97))
            context.draw(Text("ซ้ายผู้ป่วย").font(.caption2).foregroundStyle(.secondary), at: point(0.88, 0.97))
        }
        .accessibilityLabel("แผนภาพตำแหน่ง marker บนลำตัวส่วนหน้า")
    }
}

struct DiagramLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(Circle().fill(Color.primary), "แปะ marker")
            legendRow(Circle().stroke(Color.primary, lineWidth: 2), "ไม่ต้องแปะ (NAC)")
            legendRow(Rectangle().fill(Color.gray).rotationEffect(.degrees(45)), "จุดอ้างอิง (ไม่บังคับ แนะนำ)")
        }
        .font(.caption)
    }

    private func legendRow(_ shape: some View, _ text: String) -> some View {
        HStack(spacing: 8) {
            shape.frame(width: 9, height: 9)
            Text(text)
        }
    }
}

/// Colours shared by the diagram and the 3D landmark view.
enum PointStyle {
    static func color(for key: PointKey) -> Color {
        switch key {
        case .landmark(.sn): return .yellow
        case .landmark(let k) where k.rawValue.hasSuffix("R"): return .blue
        case .landmark: return .pink
        case .reference: return .gray
        }
    }
}
