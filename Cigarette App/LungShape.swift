import SwiftUI

struct LungShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Left Lung
        path.addArc(center: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY - rect.height * 0.15),
                    radius: rect.width * 0.22,
                    startAngle: .degrees(220),
                    endAngle: .degrees(140),
                    clockwise: true)

        // Left lower curve
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.minX, y: rect.maxY))

        // Right Lung
        path.addArc(center: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.15),
                    radius: rect.width * 0.22,
                    startAngle: .degrees(320),
                    endAngle: .degrees(40),
                    clockwise: false)

        // Right lower curve
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))

        // Trachea
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addRect(CGRect(x: rect.midX - rect.width * 0.03, y: rect.minY, width: rect.width * 0.06, height: rect.height * 0.22))

        return path
    }
}

