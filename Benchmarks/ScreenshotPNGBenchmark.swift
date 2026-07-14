import AppKit
import CoreGraphics
import Foundation

@main
enum ScreenshotPNGBenchmark {
    static func main() throws {
        let mode = CommandLine.arguments.dropFirst().first ?? "direct"
        let width = Int(CommandLine.arguments.dropFirst(2).first ?? "6016") ?? 6_016
        let height = Int(CommandLine.arguments.dropFirst(3).first ?? "3384") ?? 3_384
        let image = try makeImage(width: width, height: height)

        let started = CFAbsoluteTimeGetCurrent()
        let data: Data
        switch mode {
        case "direct":
            data = try ScreenshotPNGEncoder().encode(image)
        case "legacy-tiff":
            data = try legacyTIFFRoundTrip(image)
        case "direct-region":
            data = try directRegionPipeline(image)
        case "legacy-region":
            data = try legacyRegionPipeline(image)
        default:
            throw BenchmarkError.invalidMode(mode)
        }
        let durationMilliseconds = (CFAbsoluteTimeGetCurrent() - started) * 1_000

        print(
            "mode=\(mode) width=\(width) height=\(height) " +
                "duration_ms=\(String(format: "%.2f", durationMilliseconds)) bytes=\(data.count)"
        )
    }

    private static func makeImage(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BenchmarkError.imageCreationFailed
        }

        let colors = [
            CGColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 0.30),
            CGColor(red: 0.18, green: 0.55, blue: 0.92, alpha: 0.95),
            CGColor(red: 0.95, green: 0.36, blue: 0.12, alpha: 0.65)
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: context.colorSpace, colors: colors, locations: [0, 0.55, 1]) else {
            throw BenchmarkError.imageCreationFailed
        }
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: width, y: height),
            options: []
        )

        for index in 0..<1_200 {
            let x = CGFloat((index * 1_009) % width)
            let y = CGFloat((index * 613) % height)
            let red = CGFloat((index * 17) % 255) / 255
            let green = CGFloat((index * 41) % 255) / 255
            let blue = CGFloat((index * 73) % 255) / 255
            context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 0.55))
            context.fill(CGRect(x: x, y: y, width: 96, height: 64))
        }

        guard let image = context.makeImage() else {
            throw BenchmarkError.imageCreationFailed
        }
        return image
    }

    private static func legacyTIFFRoundTrip(_ image: CGImage) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: image)
        let nsImage = NSImage(size: NSSize(width: image.width, height: image.height))
        nsImage.addRepresentation(bitmap)
        guard let tiffData = nsImage.tiffRepresentation,
              let decoded = NSBitmapImageRep(data: tiffData),
              let pngData = decoded.representation(using: .png, properties: [:]) else {
            throw BenchmarkError.encodingFailed
        }
        return pngData
    }

    private static func directRegionPipeline(_ image: CGImage) throws -> Data {
        let cropRect = benchmarkCropRect(for: image)
        guard let cropped = image.cropping(to: cropRect) else {
            throw BenchmarkError.imageCreationFailed
        }
        let rendered = try render(cropped, width: cropped.width, height: cropped.height)
        return try ScreenshotPNGEncoder().encode(rendered)
    }

    private static func legacyRegionPipeline(_ image: CGImage) throws -> Data {
        let fullFrame = try render(image, width: image.width, height: image.height)
        let cropRect = benchmarkCropRect(for: fullFrame)
        guard let cropped = fullFrame.cropping(to: cropRect) else {
            throw BenchmarkError.imageCreationFailed
        }
        let rendered = try render(cropped, width: cropped.width, height: cropped.height)
        return try ScreenshotPNGEncoder().encode(rendered)
    }

    private static func benchmarkCropRect(for image: CGImage) -> CGRect {
        let width = min(1_200, image.width)
        let height = min(800, image.height)
        return CGRect(
            x: (image.width - width) / 2,
            y: (image.height - height) / 2,
            width: width,
            height: height
        )
    }

    private static func render(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw BenchmarkError.imageCreationFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let rendered = context.makeImage() else {
            throw BenchmarkError.imageCreationFailed
        }
        return rendered
    }
}

private enum BenchmarkError: LocalizedError {
    case encodingFailed
    case imageCreationFailed
    case invalidMode(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "The encoder returned no PNG data."
        case .imageCreationFailed:
            "The benchmark image could not be created."
        case let .invalidMode(mode):
            "Unknown benchmark mode: \(mode)."
        }
    }
}
