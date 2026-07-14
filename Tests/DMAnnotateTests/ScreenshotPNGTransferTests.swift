import AppKit
import Testing
@testable import DMAnnotate

@MainActor
@Test func pngEncoderPreservesRetinaPixelDimensionsAndAlpha() throws {
    let bitmap = try #require(
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    )
    bitmap.size = NSSize(width: 2, height: 1)
    bitmap.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 0.5), atX: 1, y: 1)

    let image = NSImage(size: NSSize(width: 2, height: 1))
    image.addRepresentation(bitmap)

    let data = try ScreenshotPNGEncoder().encode(image)
    let decoded = try #require(NSBitmapImageRep(data: data))

    #expect(data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]))
    #expect(decoded.pixelsWide == 4)
    #expect(decoded.pixelsHigh == 2)
    #expect(decoded.hasAlpha)
    let decodedColor = try #require(decoded.colorAt(x: 1, y: 1))
    #expect(abs(decodedColor.alphaComponent - 0.5) < 0.02)
}

@MainActor
@Test func pasteboardWriterPublishesDecodablePNGOnIsolatedPasteboard() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let pngData = try testPNGData()

    try ScreenshotPasteboardWriter(pasteboard: pasteboard).write(pngData)

    #expect(pasteboard.types?.contains(.png) == true)
    let publishedData = try #require(pasteboard.data(forType: .png))
    #expect(publishedData == pngData)
    #expect(NSBitmapImageRep(data: publishedData) != nil)
}

@MainActor
private func testPNGData() throws -> Data {
    let bitmap = try #require(
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    )
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.addRepresentation(bitmap)
    return try ScreenshotPNGEncoder().encode(image)
}

@MainActor
@Test func pasteboardWriterStopsWhenClearFails() {
    let destination = TestPasteboardDestination(clearResult: false, writeResult: true)
    var capturedError: ScreenshotPasteboardError?

    do {
        try ScreenshotPasteboardWriter(destination: destination).write(Data([1, 2, 3]))
    } catch let error as ScreenshotPasteboardError {
        capturedError = error
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(capturedError == .clearFailed)
    #expect(destination.writeCount == 0)
}

@MainActor
@Test func pasteboardWriterReportsWriteFailureAfterClearing() {
    let destination = TestPasteboardDestination(clearResult: true, writeResult: false)
    var capturedError: ScreenshotPasteboardError?

    do {
        try ScreenshotPasteboardWriter(destination: destination).write(Data([1, 2, 3]))
    } catch let error as ScreenshotPasteboardError {
        capturedError = error
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(capturedError == .writeFailed)
    #expect(destination.writeCount == 1)
}

@MainActor
private final class TestPasteboardDestination: ScreenshotPasteboardDestination {
    private let clearResult: Bool
    private let writeResult: Bool
    private(set) var writeCount = 0

    init(clearResult: Bool, writeResult: Bool) {
        self.clearResult = clearResult
        self.writeResult = writeResult
    }

    func clearContents() -> Bool {
        clearResult
    }

    func setPNGData(_ data: Data) -> Bool {
        writeCount += 1
        return writeResult
    }
}
