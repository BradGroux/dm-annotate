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
        let scaled = CGRect(
            x: floor(standardized.minX * scaleX),
            y: floor(standardized.minY * scaleY),
            width: ceil(standardized.width * scaleX),
            height: ceil(standardized.height * scaleY)
        )

        let clipped = scaled.intersection(bounds)
        return clipped.isNull ? .zero : clipped.standardized
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
