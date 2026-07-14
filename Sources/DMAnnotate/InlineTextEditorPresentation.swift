import AppKit
import DMAnnotateCore

/// Stable editor-only chrome for previewing an annotation color over arbitrary content.
/// Contrast decisions use the preview's display-resolved sRGB components.
/// Final annotation rendering continues to use the original `RGBAColor` unchanged.
@MainActor
struct InlineTextEditorPresentation {
    enum Surface: Equatable {
        case light
        case dark

        var color: NSColor {
            switch self {
            case .light: .white
            case .dark: .black
            }
        }
    }

    static let minimumContrastRatio = AdaptiveSelectedControlContrast.minimumRatio

    var surface: Surface
    var previewColor: NSColor
    var borderWidth: CGFloat
    var textContrastRatio: Double

    var surfaceColor: NSColor { surface.color }

    static func resolve(
        finalColor: RGBAColor,
        increaseContrast: Bool
    ) -> InlineTextEditorPresentation {
        let previewColor = NSColor(
            calibratedRed: finalColor.red,
            green: finalColor.green,
            blue: finalColor.blue,
            alpha: 1
        )
        guard let displayedColor = previewColor.usingColorSpace(.sRGB) else {
            preconditionFailure("Calibrated RGB editor colors must resolve into sRGB")
        }
        let displayedRed = Double(displayedColor.redComponent)
        let displayedGreen = Double(displayedColor.greenComponent)
        let displayedBlue = Double(displayedColor.blueComponent)
        let contrastingMonochrome = AdaptiveSelectedControlContrast.foreground(
            red: displayedRed,
            green: displayedGreen,
            blue: displayedBlue
        )
        let surface: Surface = contrastingMonochrome == .white ? .light : .dark
        let ratio = AdaptiveSelectedControlContrast.contrastRatio(
            foreground: contrastingMonochrome,
            backgroundRed: displayedRed,
            green: displayedGreen,
            blue: displayedBlue
        )

        return InlineTextEditorPresentation(
            surface: surface,
            previewColor: previewColor,
            borderWidth: increaseContrast ? 2 : 1,
            textContrastRatio: ratio
        )
    }

    func apply(to textView: NSTextView) {
        textView.textColor = previewColor
        textView.backgroundColor = surfaceColor
        textView.drawsBackground = true
        textView.insertionPointColor = previewColor
        textView.selectedTextAttributes = [
            .backgroundColor: previewColor,
            .foregroundColor: surfaceColor
        ]
        textView.wantsLayer = true
        textView.layer?.cornerRadius = 6
        textView.layer?.borderWidth = borderWidth
        textView.layer?.borderColor = previewColor.cgColor
    }
}
