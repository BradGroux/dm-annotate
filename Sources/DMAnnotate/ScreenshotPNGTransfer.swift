import AppKit

@MainActor
struct ScreenshotPNGEncoder {
    func encode(_ image: NSImage) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotPNGError.encodingFailed
        }

        return data
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
