import AppKit
import SwiftUI

@MainActor
final class ToolbarTooltipController {
    static let shared = ToolbarTooltipController()

    private var panel: NSPanel?

    func show(_ text: String, near screenPoint: CGPoint) {
        guard !text.isEmpty else { return }

        let contentView = NSHostingView(rootView: ToolbarTooltipBubble(text: text))
        let size = contentView.fittingSize

        let panel = panel ?? makePanel()
        panel.contentView = contentView
        panel.setFrame(positionedFrame(size: size, near: screenPoint), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.isReleasedWhenClosed = false
        panel.level = DMWindowLevels.toolbarTooltip
        return panel
    }

    private func positionedFrame(size: CGSize, near point: CGPoint) -> CGRect {
        let visibleFrame = screen(containing: point)?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let paddedFrame = visibleFrame.insetBy(dx: 8, dy: 8)
        var origin = CGPoint(x: point.x - (size.width / 2), y: point.y + 18)

        if origin.y + size.height > paddedFrame.maxY {
            origin.y = point.y - size.height - 18
        }

        let maxX = Swift.max(paddedFrame.minX, paddedFrame.maxX - size.width)
        let maxY = Swift.max(paddedFrame.minY, paddedFrame.maxY - size.height)
        origin.x = Swift.min(Swift.max(origin.x, paddedFrame.minX), maxX)
        origin.y = Swift.min(Swift.max(origin.y, paddedFrame.minY), maxY)

        return CGRect(origin: origin, size: size)
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
}

private struct ToolbarTooltipBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 320, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 6, y: 2)
    }
}
