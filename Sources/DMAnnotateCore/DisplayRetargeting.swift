import CoreGraphics
import Foundation

/// The display facts needed to preserve annotation intent without depending on AppKit.
///
/// `globalBounds` describes arrangement in the desktop coordinate space. `usableBounds`
/// uses the overlay's local point coordinate space. `scale` records the source screen's
/// backing scale, but retargeting deliberately operates in logical points so mixed-scale
/// moves preserve the annotation's painted size.
public struct AnnotationDisplayGeometry: Codable, Equatable, Sendable {
    public var displayID: UInt32
    public var globalBounds: CGRect
    public var usableBounds: CGRect
    public var scale: CGFloat

    public init(
        displayID: UInt32,
        globalBounds: CGRect,
        globalUsableBounds: CGRect,
        scale: CGFloat
    ) {
        self.displayID = displayID
        self.globalBounds = globalBounds
        let localFrame = CGRect(origin: .zero, size: globalBounds.standardized.size)
        let localUsableBounds = globalUsableBounds.standardized
            .offsetBy(dx: -globalBounds.minX, dy: -globalBounds.minY)
            .intersection(localFrame)
        usableBounds = localUsableBounds.isEmpty ? localFrame : localUsableBounds
        self.scale = scale
    }
}

/// Maps annotations from unavailable displays to one usable display through a single,
/// deterministic interface shared by session import and live display changes.
public enum AnnotationDisplayRetargeter {
    public static func retarget(
        _ annotations: [AnnotationItem],
        sourceDisplays: [AnnotationDisplayGeometry],
        destinationDisplays: [AnnotationDisplayGeometry],
        fallbackDisplayID: UInt32?
    ) -> [AnnotationItem] {
        let destinations = usableDisplays(destinationDisplays)
        guard !destinations.isEmpty else { return annotations }

        let availableIDs = Set(destinations.map(\.displayID))
        let destination = destinations.first { $0.displayID == fallbackDisplayID }
            ?? destinations.min { $0.displayID < $1.displayID }!
        let sourcesByID = Dictionary(sourceDisplays.map { ($0.displayID, $0) }, uniquingKeysWith: { first, _ in first })

        return annotations.map { annotation in
            guard !availableIDs.contains(annotation.displayID) else { return annotation }
            return retarget(
                annotation,
                source: sourcesByID[annotation.displayID],
                destination: destination
            )
        }
    }

    private static func retarget(
        _ annotation: AnnotationItem,
        source: AnnotationDisplayGeometry?,
        destination: AnnotationDisplayGeometry
    ) -> AnnotationItem {
        let paintedBounds = annotation.boundingRect
        let destinationBounds = destination.usableBounds
        let intendedCenter = mappedCenter(
            paintedBounds: paintedBounds,
            sourceBounds: source.flatMap { usableBounds($0.usableBounds) },
            destinationBounds: destinationBounds
        )
        let fittedCenter = CGPoint(
            x: fittedCenter(
                intendedCenter.x,
                paintedLength: paintedBounds.width,
                destinationMinimum: destinationBounds.minX,
                destinationMaximum: destinationBounds.maxX
            ),
            y: fittedCenter(
                intendedCenter.y,
                paintedLength: paintedBounds.height,
                destinationMinimum: destinationBounds.minY,
                destinationMaximum: destinationBounds.maxY
            )
        )
        var translation = CGVector(
            dx: fittedCenter.x - paintedBounds.midX,
            dy: fittedCenter.y - paintedBounds.midY
        )
        if needsCoordinateConstraint(paintedBounds: paintedBounds, translation: translation) {
            let pointBounds = annotation.points.boundingRect
            translation.dx = saveableTranslation(
                translation.dx,
                minimumCoordinate: pointBounds.minX,
                maximumCoordinate: pointBounds.maxX,
                hasCoordinates: !annotation.points.isEmpty
            )
            translation.dy = saveableTranslation(
                translation.dy,
                minimumCoordinate: pointBounds.minY,
                maximumCoordinate: pointBounds.maxY,
                hasCoordinates: !annotation.points.isEmpty
            )
        }

        var copy = annotation
        copy.displayID = destination.displayID
        copy.points = annotation.points.map { point in
            CGPoint(x: point.x + translation.dx, y: point.y + translation.dy)
        }
        return copy
    }

    private static func mappedCenter(
        paintedBounds: CGRect,
        sourceBounds: CGRect?,
        destinationBounds: CGRect
    ) -> CGPoint {
        guard let sourceBounds else {
            return CGPoint(x: destinationBounds.midX, y: destinationBounds.midY)
        }

        let normalizedX = clamped((paintedBounds.midX - sourceBounds.minX) / sourceBounds.width)
        let normalizedY = clamped((paintedBounds.midY - sourceBounds.minY) / sourceBounds.height)
        return CGPoint(
            x: destinationBounds.minX + (normalizedX * destinationBounds.width),
            y: destinationBounds.minY + (normalizedY * destinationBounds.height)
        )
    }

    private static func fittedCenter(
        _ intended: CGFloat,
        paintedLength: CGFloat,
        destinationMinimum: CGFloat,
        destinationMaximum: CGFloat
    ) -> CGFloat {
        let destinationLength = destinationMaximum - destinationMinimum
        guard paintedLength <= destinationLength else {
            return destinationMinimum + (destinationLength / 2)
        }

        let halfPaintedLength = paintedLength / 2
        return min(
            max(intended, destinationMinimum + halfPaintedLength),
            destinationMaximum - halfPaintedLength
        )
    }

    private static func usableDisplays(
        _ displays: [AnnotationDisplayGeometry]
    ) -> [AnnotationDisplayGeometry] {
        displays.compactMap { display in
            guard let bounds = usableBounds(display.usableBounds) else { return nil }
            var copy = display
            copy.usableBounds = bounds
            return copy
        }
    }

    private static func usableBounds(_ bounds: CGRect) -> CGRect? {
        guard bounds.origin.x.isFinite,
              bounds.origin.y.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite,
              bounds.width > 0,
              bounds.height > 0 else {
            return nil
        }
        return bounds.standardized
    }

    private static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private static func saveableTranslation(
        _ desired: CGFloat,
        minimumCoordinate: CGFloat,
        maximumCoordinate: CGFloat,
        hasCoordinates: Bool
    ) -> CGFloat {
        guard hasCoordinates,
              minimumCoordinate.isFinite,
              maximumCoordinate.isFinite else {
            return desired
        }

        let limit = AnnotationSessionDocument.maximumCoordinateMagnitude
        let lowerBound = -limit - minimumCoordinate
        let upperBound = limit - maximumCoordinate
        guard lowerBound <= upperBound else { return desired }
        return min(max(desired, lowerBound), upperBound)
    }

    private static func needsCoordinateConstraint(
        paintedBounds: CGRect,
        translation: CGVector
    ) -> Bool {
        let limit = AnnotationSessionDocument.maximumCoordinateMagnitude
        return paintedBounds.minX + translation.dx < -limit
            || paintedBounds.maxX + translation.dx > limit
            || paintedBounds.minY + translation.dy < -limit
            || paintedBounds.maxY + translation.dy > limit
    }
}
