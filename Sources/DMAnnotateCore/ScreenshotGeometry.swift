import CoreGraphics
import Foundation

public enum ScreenshotGeometry {
    public static func pixelRect(forRegion region: CGRect, pointSize: CGSize, pixelSize: CGSize) -> CGRect {
        let bounds = CGRect(origin: .zero, size: pixelSize)
        guard pointSize.width > 0, pointSize.height > 0, pixelSize.width > 0, pixelSize.height > 0 else {
            return .zero
        }

        let scaleX = pixelSize.width / pointSize.width
        let scaleY = pixelSize.height / pointSize.height
        return pixelRect(forRegion: region, scaleX: scaleX, scaleY: scaleY, bounds: bounds)
    }

    public static func pixelRect(forRegion region: CGRect, scaleX: CGFloat, scaleY: CGFloat, bounds: CGRect) -> CGRect {
        guard region.isFinite, scaleX.isFinite, scaleY.isFinite, scaleX > 0, scaleY > 0 else {
            return .zero
        }

        let standardized = region.standardized
        let minX = floor(standardized.minX * scaleX)
        let minY = floor(standardized.minY * scaleY)
        let maxX = ceil(standardized.maxX * scaleX)
        let maxY = ceil(standardized.maxY * scaleY)
        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else {
            return .zero
        }
        let scaled = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        let clipped = scaled.intersection(bounds)
        return clipped.isNull ? .zero : clipped.standardized
    }

    /// Converts the app's lower-left pixel coordinates into Core Graphics image
    /// coordinates, whose origin is at the upper-left of the captured image.
    public static func cgImageCropRect(forPixelRect pixelRect: CGRect, imageSize: CGSize) -> CGRect {
        guard pixelRect.isFinite,
              imageSize.width.isFinite,
              imageSize.height.isFinite,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return .zero
        }

        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let clipped = pixelRect.standardized.intersection(imageBounds)
        guard !clipped.isNull, !clipped.isEmpty else { return .zero }

        return CGRect(
            x: clipped.minX,
            y: imageSize.height - clipped.maxY,
            width: clipped.width,
            height: clipped.height
        )
    }

    /// Maps a local AppKit region into the upper-left display coordinate space
    /// accepted by Core Graphics display capture APIs.
    public static func displayCaptureRect(
        forRegion region: CGRect,
        pointSize: CGSize,
        displayBounds: CGRect
    ) -> CGRect {
        guard region.isFinite,
              pointSize.width.isFinite,
              pointSize.height.isFinite,
              pointSize.width > 0,
              pointSize.height > 0,
              displayBounds.isFinite else {
            return .zero
        }

        let pointBounds = CGRect(origin: .zero, size: pointSize)
        let clipped = region.standardized.intersection(pointBounds)
        guard !clipped.isNull, !clipped.isEmpty else { return .zero }
        let integral = clipped.integral.intersection(pointBounds)

        return CGRect(
            x: displayBounds.minX + integral.minX,
            y: displayBounds.minY + pointSize.height - integral.maxY,
            width: integral.width,
            height: integral.height
        )
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite &&
            origin.y.isFinite &&
            size.width.isFinite &&
            size.height.isFinite
    }
}
