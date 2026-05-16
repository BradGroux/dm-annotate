import AppKit
import DMAnnotateCore

enum AnnotationRenderer {
    static func drawWhiteboard(in rect: CGRect, background: WhiteboardBackground) {
        switch background {
        case .white:
            NSColor.white.setFill()
            rect.fill()
        case .black:
            NSColor.black.setFill()
            rect.fill()
        case .lightGrid:
            NSColor.white.setFill()
            rect.fill()
            drawGrid(in: rect, color: NSColor(calibratedWhite: 0.82, alpha: 0.55))
        case .darkGrid:
            NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
            rect.fill()
            drawGrid(in: rect, color: NSColor(calibratedWhite: 0.28, alpha: 0.6))
        }
    }

    static func draw(_ annotation: AnnotationItem) {
        let color = NSColor(annotation.color)
        let path = NSBezierPath()
        path.lineWidth = annotation.kind == .highlighter ? annotation.lineWidth * 3 : annotation.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        switch annotation.kind {
        case .pen, .highlighter:
            guard let first = annotation.points.first else { return }
            if annotation.points.count == 1 {
                drawDot(at: first, color: color, width: path.lineWidth, alpha: annotation.kind == .highlighter ? 0.34 : color.alphaComponent)
                return
            }
            path.move(to: first)
            if annotation.points.count > 2 {
                for index in 1..<(annotation.points.count - 1) {
                    let current = annotation.points[index]
                    let next = annotation.points[index + 1]
                    let midpoint = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
                    path.curve(to: midpoint, controlPoint1: current, controlPoint2: current)
                }
                if let last = annotation.points.last {
                    path.line(to: last)
                }
            } else {
                for point in annotation.points.dropFirst() {
                    path.line(to: point)
                }
            }
            color.withAlphaComponent(annotation.kind == .highlighter ? 0.34 : color.alphaComponent).setStroke()
            path.stroke()
        case .line:
            drawLine(annotation.points, color: color, width: annotation.lineWidth)
        case .rectangle:
            guard annotation.points.count >= 2 else { return }
            let rect = annotation.points.boundingRect
            color.setStroke()
            path.appendRect(rect)
            path.stroke()
        case .ellipse:
            guard annotation.points.count >= 2 else { return }
            let rect = annotation.points.boundingRect
            color.setStroke()
            path.appendOval(in: rect)
            path.stroke()
        case .arrow:
            drawArrow(annotation.points, color: color, width: annotation.lineWidth)
        case .text:
            drawText(annotation)
        }
    }

    static func drawLaserTrail(_ points: [TimedPoint]) {
        guard points.count > 1 else { return }

        for index in 0..<(points.count - 1) {
            let age = Date().timeIntervalSince(points[index].timestamp)
            let alpha = max(0, 1 - age / 1.5)
            let path = NSBezierPath()
            path.lineWidth = 10
            path.lineCapStyle = .round
            path.move(to: points[index].point)
            path.line(to: points[index + 1].point)
            NSColor.systemRed.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }

        if let last = points.last {
            let pulse = NSBezierPath(ovalIn: CGRect(x: last.point.x - 9, y: last.point.y - 9, width: 18, height: 18))
            NSColor.systemRed.withAlphaComponent(0.78).setFill()
            pulse.fill()
        }
    }

    private static func drawLine(_ points: [CGPoint], color: NSColor, width: CGFloat) {
        guard points.count >= 2 else { return }
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.move(to: points[0])
        path.line(to: points[1])
        color.setStroke()
        path.stroke()
    }

    private static func drawDot(at point: CGPoint, color: NSColor, width: CGFloat, alpha: CGFloat) {
        let diameter = max(width, 2)
        let rect = CGRect(
            x: point.x - diameter / 2,
            y: point.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        color.withAlphaComponent(alpha).setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private static func drawArrow(_ points: [CGPoint], color: NSColor, width: CGFloat) {
        guard points.count >= 2 else { return }
        drawLine(points, color: color, width: width)

        let start = points[0]
        let end = points[1]
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength = max(width * 4, 18)
        let arrowAngle = CGFloat.pi / 7

        let left = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let right = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        let head = NSBezierPath()
        head.lineWidth = width
        head.lineCapStyle = .round
        head.lineJoinStyle = .round
        head.move(to: left)
        head.line(to: end)
        head.line(to: right)
        color.setStroke()
        head.stroke()
    }

    private static func drawText(_ annotation: AnnotationItem) {
        guard let point = annotation.points.first else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: NSFont.Weight(annotation.fontWeight)),
            .foregroundColor: NSColor(annotation.color)
        ]

        if annotation.text.contains("\n") {
            let textBounds = annotation.boundingRect
            let textRect = CGRect(
                x: point.x,
                y: point.y,
                width: max(textBounds.width - 16, 64),
                height: max(textBounds.height - 16, annotation.fontSize * 1.3)
            )
            annotation.text.draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )
        } else {
            annotation.text.draw(at: point, withAttributes: attributes)
        }
    }

    private static func drawGrid(in rect: CGRect, color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = 1

        stride(from: rect.minX, through: rect.maxX, by: 32).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: 32).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
        }

        color.setStroke()
        path.stroke()
    }
}

struct TimedPoint {
    var point: CGPoint
    var timestamp: Date
}

extension NSFont.Weight {
    init(_ weight: TextFontWeight) {
        switch weight {
        case .regular:
            self = .regular
        case .medium:
            self = .medium
        case .semibold:
            self = .semibold
        case .bold:
            self = .bold
        case .heavy:
            self = .heavy
        }
    }
}

extension NSColor {
    convenience init(_ color: RGBAColor) {
        self.init(
            calibratedRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }
}
