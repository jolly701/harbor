import SwiftUI

struct HarborMark: View {
    var mode: HarborMode

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let stroke = max(1.4, side * 0.12)
            let bar = CGRect(
                x: side * 0.10,
                y: side * 0.16,
                width: stroke,
                height: side * 0.68
            )
            context.fill(
                Path(roundedRect: bar, cornerRadius: stroke / 2),
                with: .color(.primary)
            )

            let center = CGPoint(x: side * 0.64, y: side * 0.50)
            let radius = side * 0.28
            if mode == .running {
                let bounds = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: bounds), with: .color(.primary))
                return
            }

            var arc = Path()
            arc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(28),
                endAngle: .degrees(-28),
                clockwise: false
            )
            context.stroke(arc, with: .color(.primary), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            if mode == .stopped {
                let dot = side * 0.16
                let bounds = CGRect(
                    x: center.x - dot / 2,
                    y: center.y - dot / 2,
                    width: dot,
                    height: dot
                )
                context.fill(Path(ellipseIn: bounds), with: .color(.primary))
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityLabel(mode.accessibilityLabel)
    }
}

private extension HarborMode {
    var accessibilityLabel: String {
        switch self {
        case .loggedOut: "未登录"
        case .stopped: "已登录，服务未运行"
        case .running: "运行中"
        }
    }
}
