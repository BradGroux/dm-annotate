import AppKit
import DMAnnotateCore
import UniformTypeIdentifiers

@MainActor
final class ScreenshotController {
    typealias CaptureChromeHider = ((() -> NSImage?) -> NSImage?)

    private let store: AnnotationStore
    private let preferences: PreferencesController
    private let overlayController: OverlayController
    private var regionSelectionWindow: RegionSelectionWindow?
    private var lastSavedScreenshotURL: URL?
    private var captureChromeHider: CaptureChromeHider?

    init(store: AnnotationStore, preferences: PreferencesController, overlayController: OverlayController) {
        self.store = store
        self.preferences = preferences
        self.overlayController = overlayController
    }

    func setCaptureChromeHider(_ hider: @escaping CaptureChromeHider) {
        captureChromeHider = hider
    }

    func captureFullDisplay(destination: ScreenshotDestination = .preferred, renderMode: ScreenshotRenderMode = .flattened) {
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            showError("No display is available for capture.")
            return
        }

        capture(screen: screen, region: nil, destination: destination, renderMode: renderMode)
    }

    func captureRegion(destination: ScreenshotDestination = .preferred, renderMode: ScreenshotRenderMode = .flattened) {
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            showError("No display is available for capture.")
            return
        }

        let window = RegionSelectionWindow(screen: screen) { [weak self] region in
            self?.regionSelectionWindow = nil
            guard let region, !region.isEmpty else { return }
            self?.capture(screen: screen, region: region, destination: destination, renderMode: renderMode)
        }

        regionSelectionWindow = window
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func revealLastScreenshot() {
        if let lastSavedScreenshotURL {
            NSWorkspace.shared.activateFileViewerSelecting([lastSavedScreenshotURL])
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([preferences.expandedScreenshotFolderURL()])
    }

    private func capture(screen: NSScreen, region: CGRect?, destination: ScreenshotDestination, renderMode: ScreenshotRenderMode) {
        let captureWork = { [self] in
            overlayController.temporarilyHideForCapture {
                composedImage(screen: screen, region: region, renderMode: renderMode)
            }
        }
        let image = captureChromeHider?(captureWork) ?? captureWork()

        guard let image else {
            showError("Screenshot failed. Grant Screen Recording permission in System Settings and try again.")
            return
        }

        switch resolvedOutput(for: destination) {
        case .clipboard:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        case .file:
            save(image, renderMode: renderMode)
        }
    }

    private func resolvedOutput(for destination: ScreenshotDestination) -> ScreenshotOutput {
        switch destination {
        case .preferred:
            preferences.snapshot.screenshotOutput
        case .clipboard:
            .clipboard
        case .file:
            .file
        }
    }

    private func composedImage(screen: NSScreen, region: CGRect?, renderMode: ScreenshotRenderMode) -> NSImage? {
        switch renderMode {
        case .flattened:
            return flattenedImage(screen: screen, region: region)
        case .annotationsOnly:
            return annotationsOnlyImage(screen: screen, region: region)
        }
    }

    private func flattenedImage(screen: NSScreen, region: CGRect?) -> NSImage? {
        guard let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screen.displayID)) else {
            return nil
        }

        let pointSize = screen.frame.size
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard let fullImage = renderedImage(cgImage: cgImage, displayID: screen.displayID, pointSize: pointSize, pixelSize: pixelSize) else {
            return nil
        }

        return crop(fullImage, to: region, pointSize: pointSize, pixelSize: pixelSize)
    }

    private func annotationsOnlyImage(screen: NSScreen, region: CGRect?) -> NSImage? {
        let pointSize = screen.frame.size
        let pixelSize = displayPixelSize(for: screen)
        guard let fullImage = renderedAnnotationsOnlyImage(displayID: screen.displayID, pointSize: pointSize, pixelSize: pixelSize) else {
            return nil
        }

        return crop(fullImage, to: region, pointSize: pointSize, pixelSize: pixelSize)
    }

    private func displayPixelSize(for screen: NSScreen) -> CGSize {
        let displayID = CGDirectDisplayID(screen.displayID)
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        if width > 0, height > 0 {
            return CGSize(width: width, height: height)
        }

        let scale = screen.backingScaleFactor
        return CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale)
    }

    private func crop(_ image: NSImage, to region: CGRect?, pointSize: CGSize, pixelSize: CGSize) -> NSImage? {
        guard let region else { return image }

        let pixelRegion = ScreenshotGeometry.pixelRect(forRegion: region, pointSize: pointSize, pixelSize: pixelSize)
        let cropped = NSImage(size: pixelRegion.size)
        cropped.lockFocus()
        image.draw(
            in: CGRect(origin: .zero, size: pixelRegion.size),
            from: pixelRegion,
            operation: .copy,
            fraction: 1
        )
        cropped.unlockFocus()
        return cropped
    }

    private func renderedImage(cgImage: CGImage, displayID: UInt32, pointSize: CGSize, pixelSize: CGSize) -> NSImage? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.current = previousContext }

        let pixelRect = CGRect(origin: .zero, size: pixelSize)
        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: cgImage, size: pixelSize).draw(in: pixelRect)

        let scaleX = pixelSize.width / pointSize.width
        let scaleY = pixelSize.height / pointSize.height
        context.cgContext.saveGState()
        context.cgContext.scaleBy(x: scaleX, y: scaleY)
        drawAnnotations(displayID: displayID, pointSize: pointSize, includeWhiteboard: true)
        context.cgContext.restoreGState()

        let image = NSImage(size: pixelSize)
        image.addRepresentation(bitmap)
        return image
    }

    private func renderedAnnotationsOnlyImage(displayID: UInt32, pointSize: CGSize, pixelSize: CGSize) -> NSImage? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.current = previousContext }

        let pixelRect = CGRect(origin: .zero, size: pixelSize)
        context.cgContext.clear(pixelRect)

        let scaleX = pixelSize.width / pointSize.width
        let scaleY = pixelSize.height / pointSize.height
        context.cgContext.saveGState()
        context.cgContext.scaleBy(x: scaleX, y: scaleY)
        drawAnnotations(displayID: displayID, pointSize: pointSize, includeWhiteboard: false)
        context.cgContext.restoreGState()

        let image = NSImage(size: pixelSize)
        image.addRepresentation(bitmap)
        return image
    }

    private func drawAnnotations(displayID: UInt32, pointSize: CGSize, includeWhiteboard: Bool) {
        if includeWhiteboard, store.whiteboardModeEnabled {
            AnnotationRenderer.drawWhiteboard(in: CGRect(origin: .zero, size: pointSize), background: store.whiteboardBackground)
        }

        guard store.isVisible else { return }

        store.annotations
            .filter { $0.displayID == displayID }
            .forEach(AnnotationRenderer.draw)
    }

    private func save(_ image: NSImage, renderMode: ScreenshotRenderMode) {
        let folder = preferences.expandedScreenshotFolderURL()

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            guard let data = pngData(for: image) else {
                showError("Screenshot failed because the PNG encoder returned no data.")
                return
            }

            let file = try destinationFile(in: folder, renderMode: renderMode)
            try data.write(to: file, options: .atomic)
            lastSavedScreenshotURL = file

            if preferences.snapshot.revealScreenshotAfterSave {
                NSWorkspace.shared.activateFileViewerSelecting([file])
            }
        } catch ScreenshotError.cancelled {
            return
        } catch {
            showError("Screenshot save failed: \(error.localizedDescription)")
        }
    }

    private func destinationFile(in folder: URL, renderMode: ScreenshotRenderMode) throws -> URL {
        let nameComponent = nameComponent(for: renderMode)
        guard preferences.snapshot.confirmScreenshotFilename else {
            return ScreenshotNamer.uniqueFileURL(in: folder, nameComponent: nameComponent) { FileManager.default.fileExists(atPath: $0.path) }
        }

        let panel = NSSavePanel()
        panel.title = renderMode == .annotationsOnly ? "Save Annotations PNG" : "Save Screenshot"
        panel.directoryURL = folder
        panel.nameFieldStringValue = ScreenshotNamer.fileName(nameComponent: nameComponent)
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            throw ScreenshotError.cancelled
        }

        return url
    }

    private func nameComponent(for renderMode: ScreenshotRenderMode) -> String? {
        switch renderMode {
        case .flattened:
            return nil
        case .annotationsOnly:
            return "annotations"
        }
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Digital Meld Annotate"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private enum ScreenshotError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Screenshot save was cancelled."
        }
    }
}

final class RegionSelectionWindow: NSPanel {
    init(screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        let view = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size), completion: completion)

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        contentView = view
        isOpaque = false
        backgroundColor = .clear
        acceptsMouseMovedEvents = true
        hasShadow = false
        level = DMWindowLevels.regionSelection
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
}

final class RegionSelectionView: NSView {
    private let completion: (CGRect?) -> Void
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var hoverPoint: CGPoint?
    private var trackingArea: NSTrackingArea?

    init(frame: CGRect, completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        window?.acceptsMouseMovedEvents = true
        if let window {
            hoverPoint = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            needsDisplay = true
        }
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let nextTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(nextTrackingArea)
        trackingArea = nextTrackingArea
        super.updateTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.22).setFill()
        bounds.fill()

        if let crosshairPoint {
            drawCrosshair(at: crosshairPoint)
        }

        guard let rect = selectionRect else { return }

        drawSelectionRect(rect)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        hoverPoint = currentPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        hoverPoint = currentPoint
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        hoverPoint = convert(event.locationInWindow, from: nil)
        NSCursor.crosshair.set()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        let rect = selectionRect?.standardized
        window?.close()
        completion(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.close()
            completion(nil)
            return
        }

        super.keyDown(with: event)
    }

    private var crosshairPoint: CGPoint? {
        currentPoint ?? hoverPoint
    }

    private func drawCrosshair(at point: CGPoint) {
        let horizontal = NSBezierPath()
        horizontal.lineWidth = 1
        horizontal.move(to: CGPoint(x: bounds.minX, y: point.y))
        horizontal.line(to: CGPoint(x: bounds.maxX, y: point.y))

        let vertical = NSBezierPath()
        vertical.lineWidth = 1
        vertical.move(to: CGPoint(x: point.x, y: bounds.minY))
        vertical.line(to: CGPoint(x: point.x, y: bounds.maxY))

        NSColor.white.withAlphaComponent(0.72).setStroke()
        horizontal.stroke()
        vertical.stroke()

        let accent = NSBezierPath(ovalIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
        accent.lineWidth = 1.5
        NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
        accent.stroke()
    }

    private func drawSelectionRect(_ rect: CGRect) {
        NSColor.clear.setFill()
        rect.fill(using: .clear)

        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        NSColor.systemBlue.setStroke()
        path.stroke()
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        let rect = CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )

        return rect.width >= 4 && rect.height >= 4 ? rect : nil
    }
}

extension NSScreen {
    static var screenContainingMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }
}
