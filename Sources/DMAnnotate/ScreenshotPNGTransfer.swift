import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ScreenshotPNGEncoder: Sendable {
    func encode(_ image: CGImage) throws -> Data {
        guard let encodedData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  encodedData,
                  UTType.png.identifier as CFString,
                  1,
                  nil
              ) else {
            throw ScreenshotPNGError.encodingFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenshotPNGError.encodingFailed
        }

        return encodedData as Data
    }
}

struct ScreenshotPNGFileWriter: Sendable {
    private let encoder = ScreenshotPNGEncoder()

    func write(_ image: CGImage, to file: URL) throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(image)
        try data.write(to: file, options: .atomic)
    }
}

actor ScreenshotPNGOutputProcessor {
    private let encoder = ScreenshotPNGEncoder()
    private let fileWriter = ScreenshotPNGFileWriter()

    func encode(_ image: CGImage) throws -> Data {
        try encoder.encode(image)
    }

    func write(_ image: CGImage, to file: URL) throws {
        try fileWriter.write(image, to: file)
    }
}

enum ScreenshotPNGError: LocalizedError, Equatable {
    case encodingFailed

    var errorDescription: String? {
        "The PNG encoder returned no data."
    }
}

@MainActor
protocol ScreenshotPasteboardDestination: AnyObject {
    func clearContents() -> Bool
    func setPNGData(_ data: Data) -> Bool
}

@MainActor
final class AppKitScreenshotPasteboardDestination: ScreenshotPasteboardDestination {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
    }

    func clearContents() -> Bool {
        let changeCount = pasteboard.clearContents()
        return pasteboard.changeCount == changeCount && (pasteboard.types?.isEmpty ?? true)
    }

    func setPNGData(_ data: Data) -> Bool {
        pasteboard.setData(data, forType: .png)
    }
}

@MainActor
struct ScreenshotPasteboardWriter {
    private let destination: any ScreenshotPasteboardDestination

    init(pasteboard: NSPasteboard) {
        destination = AppKitScreenshotPasteboardDestination(pasteboard: pasteboard)
    }

    init(destination: any ScreenshotPasteboardDestination) {
        self.destination = destination
    }

    func write(_ pngData: Data) throws {
        guard destination.clearContents() else {
            throw ScreenshotPasteboardError.clearFailed
        }
        guard destination.setPNGData(pngData) else {
            throw ScreenshotPasteboardError.writeFailed
        }
    }
}

enum ScreenshotPasteboardError: LocalizedError, Equatable {
    case clearFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .clearFailed:
            "The clipboard could not be cleared."
        case .writeFailed:
            "The PNG data could not be written to the clipboard."
        }
    }
}
