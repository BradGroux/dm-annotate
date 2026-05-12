import AppKit
import DMAnnotateCore

@MainActor
final class ToolbarColorPanelController: NSObject {
    static let shared = ToolbarColorPanelController()

    private var onChange: ((RGBAColor) -> Void)?

    func show(currentColor: RGBAColor, store: AnnotationStore) {
        show(currentColor: currentColor) { color in
            store.currentColor = color
        }
    }

    func show(currentColor: RGBAColor, onChange: @escaping (RGBAColor) -> Void) {
        self.onChange = onChange

        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.color = NSColor(currentColor)
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        onChange?(RGBAColor(sender.color))
    }
}

extension RGBAColor {
    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? .white
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent)
        )
    }
}
