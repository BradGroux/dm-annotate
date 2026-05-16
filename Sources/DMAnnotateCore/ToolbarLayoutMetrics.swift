import CoreGraphics

public enum ToolbarLayoutMetrics {
    public static let actionButtonCount = 8
    public static let buttonSize: CGFloat = 30
    public static let gridSpacing: CGFloat = 6
    public static let compactColumnCount = 2
    public static let paletteColumnCount = 5
    public static let valueGridColumnCount = 4
    public static let valueButtonWidth: CGFloat = 42
    public static let menuControlWidth: CGFloat = 66
    public static let collapsedContentSize = CGSize(width: 50, height: buttonSize)
    public static let collapsedPanelSize = CGSize(width: 62, height: 42)
    public static let verticalContentWidth: CGFloat = 72
    public static let verticalPanelWidth: CGFloat = 86
    public static let horizontalPanelHeight: CGFloat = 48

    public static func preferredSize(
        for snapshot: PreferencesSnapshot,
        visibleFrame: CGRect,
        statusControlCount: Int
    ) -> CGSize {
        if snapshot.toolbarCollapsed {
            return collapsedPanelSize
        }

        switch snapshot.toolbarOrientation {
        case .vertical:
            let availableHeight = max(collapsedPanelSize.height, visibleFrame.height - 24)
            return CGSize(
                width: verticalPanelWidth,
                height: min(estimatedVerticalToolbarHeight(for: snapshot, statusControlCount: statusControlCount), availableHeight)
            )
        case .horizontal:
            let availableWidth = max(120, visibleFrame.width - 24)
            return CGSize(
                width: min(estimatedHorizontalToolbarWidth(for: snapshot, statusControlCount: statusControlCount), availableWidth),
                height: horizontalPanelHeight
            )
        }
    }

    public static func gridHeight(itemCount: Int, columns: Int) -> CGFloat {
        let rowCount = max(1, Int(ceil(Double(itemCount) / Double(columns))))
        return CGFloat(rowCount) * buttonSize + CGFloat(max(rowCount - 1, 0)) * gridSpacing
    }

    private static func estimatedVerticalToolbarHeight(
        for snapshot: PreferencesSnapshot,
        statusControlCount: Int
    ) -> CGFloat {
        let outerPadding: CGFloat = 12
        let contentBottomPadding: CGFloat = 6
        let dragHandleHeight: CGFloat = 16
        let dividerHeight: CGFloat = 5
        let menuControlHeight = buttonSize
        let childCount = 10
        let menuControlCount = 2
        let topControls = 2 + statusControlCount
        let toolControls = snapshot.visibleTools.count
        let colorControls = min(snapshot.paletteColors.count, 4) + 2

        return outerPadding +
            dragHandleHeight +
            gridHeight(itemCount: topControls, columns: compactColumnCount) +
            dividerHeight +
            gridHeight(itemCount: toolControls, columns: compactColumnCount) +
            dividerHeight +
            gridHeight(itemCount: colorControls, columns: compactColumnCount) +
            CGFloat(menuControlCount) * menuControlHeight +
            dividerHeight +
            gridHeight(itemCount: actionButtonCount, columns: compactColumnCount) +
            CGFloat(childCount - 1) * gridSpacing +
            contentBottomPadding
    }

    private static func estimatedHorizontalToolbarWidth(
        for snapshot: PreferencesSnapshot,
        statusControlCount: Int
    ) -> CGFloat {
        let outerPadding: CGFloat = 12
        let dragHandleWidth: CGFloat = 16
        let dividerWidth: CGFloat = 5
        let menuControlCount = 2
        let fixedButtons = 2
        let toolButtons = snapshot.visibleTools.count
        let colorButtons = min(snapshot.paletteColors.count, 4) + 2
        let buttonCount = fixedButtons + statusControlCount + toolButtons + colorButtons + actionButtonCount
        let elementCount = 1 + buttonCount + 3 + menuControlCount

        return outerPadding +
            dragHandleWidth +
            CGFloat(buttonCount) * buttonSize +
            CGFloat(3) * dividerWidth +
            CGFloat(menuControlCount) * menuControlWidth +
            CGFloat(max(elementCount - 1, 0)) * gridSpacing
    }
}
