import AppKit
import DMAnnotateCore
import UniformTypeIdentifiers

@MainActor
final class ScreenshotController {
    private let store: AnnotationStore
    private let preferences: PreferencesController
    private let overlayController: OverlayController
    private var regionSelectionWindow: RegionSelectionWindow?
    private var lastSavedScreenshotURL: URL?

    init(store: AnnotationStore, preferences: PreferencesController, overlayController: OverlayController) {
        self.store = store
        self.preferences = preferences
        self.overlayController = overlayController
    }

    func captureFullDisplay(destination: ScreenshotDestination = .preferred) {
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            showError("No display is available for capture.")
            return
        }

        capture(screen: screen, region: nil, destination: destination)
    }

    func captureRegion(destination: ScreenshotDestination = .preferred) {
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            showError("No display is available for capture.")
            return
        }

        let window = RegionSelectionWindow(screen: screen) { [weak self] region in
            self?.regionSelectionWindow = nil
            guard let region, !region.isEmpty else { return }
            self?.capture(screen: screen, region: region, destination: destination)
        }

        regionSelectionWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func revealLastScreenshot() {
        if let lastSavedScreenshotURL {
            NSWorkspace.shared.activateFileViewerSelecting([lastSavedScreenshotURL])
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([preferences.expandedScreenshotFolderURL()])
    }

    private func capture(screen: NSScreen, region: CGRect?, destination: ScreenshotDestination) {
        let image = overlayController.temporarilyHideForCapture {
            composedImage(screen: screen, region: region)
        }

        guard let image else {
            showError("Screenshot failed. Grant Screen Recording permission in System Settings and try again.")
            return
        }

        switch resolvedOutput(for: destination) {
        case .clipboard:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        case .file:
            save(image)
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

    private func composedImage(screen: NSScreen, region: CGRect?) -> NSImage? {
        guard let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screen.displayID)) else {
            return nil
        }

        let fullImage = NSImage(size: screen.frame.size)
        fullImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cgImage, size: screen.frame.size).draw(in: CGRect(origin: .zero, size: screen.frame.size))

        if store.whiteboardModeEnabled {
            AnnotationRenderer.drawWhiteboard(in: CGRect(origin: .zero, size: screen.frame.size), background: store.whiteboardBackground)
        }

        if store.isVisible {
            store.annotations
                .filter { $0.displayID == screen.displayID }
                .forEach(AnnotationRenderer.draw)
        }

        fullImage.unlockFocus()

        guard let region else { return fullImage }

        let cropped = NSImage(size: region.size)
        cropped.lockFocus()
        fullImage.draw(
            in: CGRect(origin: .zero, size: region.size),
            from: region,
            operation: .copy,
            fraction: 1
        )
        cropped.unlockFocus()
        return cropped
    }

    private func save(_ image: NSImage) {
        let folder = preferences.expandedScreenshotFolderURL()

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            guard let data = pngData(for: image) else {
                showError("Screenshot failed because the PNG encoder returned no data.")
                return
            }

            let file = try destinationFile(in: folder)
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

    private func destinationFile(in folder: URL) throws -> URL {
        guard preferences.snapshot.confirmScreenshotFilename else {
            return ScreenshotNamer.uniqueFileURL(in: folder) { FileManager.default.fileExists(atPath: $0.path) }
        }

        let panel = NSSavePanel()
        panel.title = "Save Screenshot"
        panel.directoryURL = folder
        panel.nameFieldStringValue = ScreenshotNamer.fileName()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            throw ScreenshotError.cancelled
        }

        return url
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
        hasShadow = false
        level = .screenSaver
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

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.22).setFill()
        bounds.fill()

        guard let rect = selectionRect else { return }

        NSColor.clear.setFill()
        rect.fill(using: .clear)

        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        NSColor.systemBlue.setStroke()
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
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
