import CoreGraphics
import Foundation

public struct LaserTrailPoint: Equatable, Sendable {
    public var point: CGPoint
    public var timestamp: Date

    public init(point: CGPoint, timestamp: Date) {
        self.point = point
        self.timestamp = timestamp
    }
}

public struct LaserTrail: Equatable, Sendable {
    public static let lifetime: TimeInterval = 1.5
    public static let maximumPointCount = 240
    public static let minimumPointDistance: CGFloat = 0.75

    public private(set) var points: [LaserTrailPoint]

    public init() {
        points = []
    }

    public var boundingRect: CGRect {
        guard let first = points.first?.point else { return .null }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        for sample in points.dropFirst() {
            minX = min(minX, sample.point.x)
            minY = min(minY, sample.point.y)
            maxX = max(maxX, sample.point.x)
            maxY = max(maxY, sample.point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public mutating func append(_ point: CGPoint, at timestamp: Date) {
        trim(at: timestamp)

        if let latest = points.last {
            let distance = hypot(point.x - latest.point.x, point.y - latest.point.y)
            guard distance >= Self.minimumPointDistance else { return }
        }

        points.append(LaserTrailPoint(point: point, timestamp: timestamp))
        if points.count > Self.maximumPointCount {
            points.removeFirst(points.count - Self.maximumPointCount)
        }
    }

    public mutating func trim(at timestamp: Date) {
        let cutoff = timestamp.addingTimeInterval(-Self.lifetime)
        if let firstLiveIndex = points.firstIndex(where: { $0.timestamp >= cutoff }) {
            if firstLiveIndex > points.startIndex {
                points.removeFirst(firstLiveIndex)
            }
        } else {
            points.removeAll(keepingCapacity: true)
        }
    }
}
