import AppKit
import DMAnnotateCore
import Testing
@testable import DMAnnotate

@MainActor
@Test func editorPresentationMeetsContrastForPaletteAndGrayscaleExtremes() throws {
    let denseCrossoverColors = (0...100).map { step in
        let component = 0.35 + (Double(step) * 0.0025)
        return RGBAColor(red: component, green: component, blue: component)
    }
    let customColors = [
        RGBAColor(red: 0.46, green: 0.46, blue: 0.46),
        RGBAColor(red: 0.18, green: 0.52, blue: 0.77),
        RGBAColor(red: 0.82, green: 0.38, blue: 0.12),
        RGBAColor(red: 0.27, green: 0.63, blue: 0.41)
    ]
    let colors = RGBAColor.palette + denseCrossoverColors + customColors
    let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: 220, height: 38))

    for color in colors {
        for increaseContrast in [false, true] {
            let presentation = InlineTextEditorPresentation.resolve(
                finalColor: color,
                increaseContrast: increaseContrast
            )
            presentation.apply(to: textView)
            let appliedRatio = displayedContrastRatio(
                try #require(textView.textColor),
                textView.backgroundColor
            )

            #expect(
                appliedRatio >= InlineTextEditorPresentation.minimumContrastRatio,
                "\(color) applied editor contrast was \(appliedRatio):1"
            )
            #expect(presentation.surfaceColor.alphaComponent == 1)
            #expect(presentation.previewColor.alphaComponent == 1)
        }
    }
}

@MainActor
@Test func activeEditorSnapshotsPreviewAndCommittedColorAcrossStoreChanges() throws {
    let sessionColor = RGBAColor(red: 0.46, green: 0.46, blue: 0.46, alpha: 0.35)
    let store = AnnotationStore(activeTool: .text, currentColor: sessionColor)
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), store: store, displayID: 7)

    overlay.beginTextEntry(at: CGPoint(x: 42, y: 64))
    let textView = try #require(overlay.subviews.compactMap { $0 as? NSTextView }.first)
    let initialPreview = try #require(textView.textColor)
    textView.string = "Stable session color"

    store.currentColor = .yellow
    overlay.refreshActiveTextEditorPresentation(increaseContrast: true)

    #expect(colorsMatch(try #require(textView.textColor), initialPreview))
    #expect(overlay.activeTextColor == sessionColor)
    #expect(overlay.handleTextCommand(
        #selector(NSResponder.insertNewline(_:)),
        in: textView,
        shiftPressed: false
    ))
    #expect(try #require(store.annotations.first).color == sessionColor)
    #expect(overlay.activeTextColor == nil)
}

@MainActor
@Test func activeEditorRefreshesIncreaseContrastChromeWithoutChangingItsColor() throws {
    let sessionColor = RGBAColor(red: 0.18, green: 0.52, blue: 0.77, alpha: 0.4)
    let store = AnnotationStore(activeTool: .text, currentColor: sessionColor)
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), store: store, displayID: 1)

    overlay.beginTextEntry(at: CGPoint(x: 42, y: 64))
    let textView = try #require(overlay.subviews.compactMap { $0 as? NSTextView }.first)
    let initialPreview = try #require(textView.textColor)

    overlay.refreshActiveTextEditorPresentation(increaseContrast: false)
    #expect(textView.layer?.borderWidth == 1)
    overlay.refreshActiveTextEditorPresentation(increaseContrast: true)
    #expect(textView.layer?.borderWidth == 2)
    #expect(colorsMatch(try #require(textView.textColor), initialPreview))
    #expect(overlay.activeTextColor == sessionColor)

    let systemIncreaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    overlay.refreshActiveTextEditorPresentation(increaseContrast: !systemIncreaseContrast)
    NSWorkspace.shared.notificationCenter.post(
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
    )
    #expect(textView.layer?.borderWidth == (systemIncreaseContrast ? 2 : 1))
    #expect(colorsMatch(try #require(textView.textColor), initialPreview))
}

@MainActor
@Test func cancelAndToolTransitionClearActiveTextColor() throws {
    let store = AnnotationStore(activeTool: .text, currentColor: .purple)
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), store: store, displayID: 1)

    overlay.beginTextEntry(at: CGPoint(x: 42, y: 64))
    let textView = try #require(overlay.subviews.compactMap { $0 as? NSTextView }.first)
    #expect(overlay.activeTextColor == .purple)
    #expect(overlay.handleTextCommand(
        #selector(NSResponder.cancelOperation(_:)),
        in: textView,
        shiftPressed: false
    ))
    #expect(overlay.activeTextColor == nil)

    store.setActiveTool(.text)
    overlay.beginTextEntry(at: CGPoint(x: 42, y: 64))
    store.setActiveTool(.pen)
    overlay.syncInteractionState()

    #expect(overlay.activeTextColor == nil)
    #expect(overlay.subviews.compactMap { $0 as? NSTextView }.isEmpty)
}

@MainActor
@Test func blackUsesLightChromeAndWhiteUsesDarkChrome() {
    let black = InlineTextEditorPresentation.resolve(finalColor: .black, increaseContrast: false)
    let white = InlineTextEditorPresentation.resolve(finalColor: .white, increaseContrast: false)

    #expect(black.surface == .light)
    #expect(white.surface == .dark)
    #expect(black.borderWidth == 1)
    #expect(white.borderWidth == 1)
}

@MainActor
@Test func increasedContrastStrengthensStaticChromeWithoutChangingColorPair() {
    let standard = InlineTextEditorPresentation.resolve(finalColor: .purple, increaseContrast: false)
    let increased = InlineTextEditorPresentation.resolve(finalColor: .purple, increaseContrast: true)

    #expect(standard.surface == increased.surface)
    #expect(colorsMatch(standard.previewColor, increased.previewColor))
    #expect(standard.borderWidth == 1)
    #expect(increased.borderWidth == 2)
}

@MainActor
@Test func applyingPresentationKeepsTextCaretBorderAndSelectionVisible() throws {
    let presentation = InlineTextEditorPresentation.resolve(finalColor: .yellow, increaseContrast: true)
    let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: 220, height: 38))

    presentation.apply(to: textView)

    #expect(textView.drawsBackground)
    #expect(colorsMatch(textView.backgroundColor, presentation.surfaceColor))
    #expect(colorsMatch(try #require(textView.textColor), presentation.previewColor))
    #expect(colorsMatch(textView.insertionPointColor, presentation.previewColor))
    #expect(textView.layer?.borderWidth == 2)
    #expect(colorsMatch(
        try #require(textView.selectedTextAttributes[.backgroundColor] as? NSColor),
        presentation.previewColor
    ))
    #expect(colorsMatch(
        try #require(textView.selectedTextAttributes[.foregroundColor] as? NSColor),
        presentation.surfaceColor
    ))
}

@MainActor
@Test func shiftReturnInsertsNewlineWithoutCommitting() {
    let store = AnnotationStore(activeTool: .text)
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), store: store, displayID: 1)
    let textView = NSTextView(frame: CGRect(x: 40, y: 50, width: 220, height: 38))
    textView.string = "First line"
    textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))

    let handled = overlay.handleTextCommand(
        #selector(NSResponder.insertNewline(_:)),
        in: textView,
        shiftPressed: true
    )

    #expect(handled)
    #expect(textView.string == "First line\n")
    #expect(store.annotations.isEmpty)
}

@MainActor
@Test func returnCommitsTheExactFinalAnnotationColorAndOrigin() throws {
    let finalColor = RGBAColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 0.35)
    let store = AnnotationStore(
        activeTool: .text,
        currentColor: finalColor,
        strokeWidth: 5,
        textFontSize: 32,
        textFontWeight: .bold
    )
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), store: store, displayID: 7)
    let textView = NSTextView(frame: CGRect(x: 42, y: 64, width: 220, height: 38))
    textView.string = "Final color"
    overlay.addSubview(textView)

    let handled = overlay.handleTextCommand(
        #selector(NSResponder.insertNewline(_:)),
        in: textView,
        shiftPressed: false
    )

    let annotation = try #require(store.annotations.first)
    #expect(handled)
    #expect(annotation.displayID == 7)
    #expect(annotation.kind == .text)
    #expect(annotation.points == [CGPoint(x: 42, y: 64)])
    #expect(annotation.color == finalColor)
    #expect(annotation.text == "Final color")
    #expect(annotation.fontSize == 32)
    #expect(annotation.fontWeight == .bold)
}

@MainActor
@Test func escapeCancelsTextAndReturnsToCursorMode() {
    let store = AnnotationStore(activeTool: .text)
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 480), store: store, displayID: 1)
    let textView = NSTextView(frame: CGRect(x: 40, y: 50, width: 220, height: 38))
    textView.string = "Discard"
    overlay.addSubview(textView)

    let handled = overlay.handleTextCommand(
        #selector(NSResponder.cancelOperation(_:)),
        in: textView,
        shiftPressed: false
    )

    #expect(handled)
    #expect(store.annotations.isEmpty)
    #expect(store.activeTool == .cursor)
    #expect(textView.superview == nil)
}

@MainActor
@Test func editorPositioningStaysInsideOverlayMargins() {
    let store = AnnotationStore(activeTool: .text)
    let overlay = OverlayView(frame: CGRect(x: 0, y: 0, width: 300, height: 150), store: store, displayID: 1)

    let frame = overlay.clampedTextEditorFrame(
        CGRect(x: 280, y: 140, width: 220, height: 38)
    )

    #expect(frame == CGRect(x: 72, y: 104, width: 220, height: 38))
}

@MainActor
private func colorsMatch(_ lhs: NSColor, _ rhs: NSColor) -> Bool {
    guard let left = lhs.usingColorSpace(.sRGB),
          let right = rhs.usingColorSpace(.sRGB) else {
        return false
    }
    let tolerance = 0.000_001
    return abs(left.redComponent - right.redComponent) < tolerance
        && abs(left.greenComponent - right.greenComponent) < tolerance
        && abs(left.blueComponent - right.blueComponent) < tolerance
        && abs(left.alphaComponent - right.alphaComponent) < tolerance
}

private func displayedContrastRatio(_ lhs: NSColor, _ rhs: NSColor) -> Double {
    guard let left = lhs.usingColorSpace(.sRGB),
          let right = rhs.usingColorSpace(.sRGB) else {
        return 0
    }
    let leftLuminance = displayedRelativeLuminance(left)
    let rightLuminance = displayedRelativeLuminance(right)
    return (max(leftLuminance, rightLuminance) + 0.05) /
        (min(leftLuminance, rightLuminance) + 0.05)
}

private func displayedRelativeLuminance(_ color: NSColor) -> Double {
    func linearized(_ component: CGFloat) -> Double {
        let value = Double(component)
        return value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * linearized(color.redComponent)
        + 0.7152 * linearized(color.greenComponent)
        + 0.0722 * linearized(color.blueComponent)
}
