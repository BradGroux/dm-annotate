import CoreGraphics

public enum ToolbarLayoutMetrics {
    public static let actionButtonCount = 8
    public static let buttonSize: CGFloat = 30
    public static let gridSpacing: CGFloat = 6
    public static let wideButtonWidth: CGFloat = (buttonSize * 2) + gridSpacing
    public static let compactColumnCount = 2
    public static let paletteColumnCount = 5
    public static let valueGridColumnCount = 4
    public static let valueButtonWidth: CGFloat = 42
    public static let menuControlWidth: CGFloat = 66
    public static let collapsedContentSize = CGSize(width: 50, height: buttonSize)
    public static let collapsedPanelSize = CGSize(width: 62, height: 42)
    public static let compactVerticalPanelWidth: CGFloat = 86
    public static let compactHorizontalPanelHeight: CGFloat = 48
    public static let verticalContentWidth: CGFloat = 72
    public static let verticalPanelWidth: CGFloat = 86
    public static let horizontalPanelHeight: CGFloat = 48

    public static func preferredSize(
        for snapshot: PreferencesSnapshot,
        visibleFrame: CGRect,
        statusControlCount: Int,
        selectedActionButtonCount: Int = 0
    ) -> CGSize {
        if snapshot.toolbarCollapsed {
            return collapsedPanelSize
        }

        if snapshot.toolbarCompactMode {
            return compactPreferredSize(for: snapshot, visibleFrame: visibleFrame, statusControlCount: statusControlCount)
        }

        switch snapshot.toolbarOrientation {
        case .vertical:
            let availableHeight = max(collapsedPanelSize.height, visibleFrame.height - 24)
            return CGSize(
                width: verticalPanelWidth,
                height: min(
                    estimatedVerticalToolbarHeight(
                        for: snapshot,
                        statusControlCount: statusControlCount,
                        selectedActionButtonCount: selectedActionButtonCount
                    ),
                    availableHeight
                )
            )
        case .horizontal:
            let availableWidth = max(120, visibleFrame.width - 24)
            return CGSize(
                width: min(
                    estimatedHorizontalToolbarWidth(
                        for: snapshot,
                        statusControlCount: statusControlCount,
                        selectedActionButtonCount: selectedActionButtonCount
                    ),
                    availableWidth
                ),
                height: horizontalPanelHeight
            )
        }
    }

    private static func compactPreferredSize(
        for snapshot: PreferencesSnapshot,
        visibleFrame: CGRect,
        statusControlCount: Int
    ) -> CGSize {
        let compactButtonCount = 8 + statusControlCount

        switch snapshot.toolbarOrientation {
        case .vertical:
            let outerPadding: CGFloat = 12
            let dragHandleHeight: CGFloat = 16
            let contentBottomPadding: CGFloat = 6
            let height = outerPadding +
                dragHandleHeight +
                gridHeight(itemCount: compactButtonCount, columns: compactColumnCount) +
                gridSpacing +
                contentBottomPadding
            return CGSize(width: compactVerticalPanelWidth, height: min(height, max(collapsedPanelSize.height, visibleFrame.height - 24)))
        case .horizontal:
            let outerPadding: CGFloat = 12
            let dragHandleWidth: CGFloat = 16
            let availableWidth = max(120, visibleFrame.width - 24)
            let width = outerPadding +
                dragHandleWidth +
                CGFloat(compactButtonCount) * buttonSize +
                CGFloat(compactButtonCount) * gridSpacing
            return CGSize(width: min(width, availableWidth), height: compactHorizontalPanelHeight)
        }
    }

    public static func gridHeight(itemCount: Int, columns: Int) -> CGFloat {
        let rowCount = max(1, Int(ceil(Double(itemCount) / Double(columns))))
        return CGFloat(rowCount) * buttonSize + CGFloat(max(rowCount - 1, 0)) * gridSpacing
    }

    private static func estimatedVerticalToolbarHeight(
        for snapshot: PreferencesSnapshot,
        statusControlCount: Int,
        selectedActionButtonCount: Int
    ) -> CGFloat {
        let outerPadding: CGFloat = 12
        let contentBottomPadding: CGFloat = 6
        let dragHandleHeight: CGFloat = 16
        let dividerHeight: CGFloat = 5
        let menuControlHeight = buttonSize
        let childCount = 10
        let menuControlCount = 2
        let topControlsHeight = verticalTopControlsHeight(statusControlCount: statusControlCount)
        let toolControls = snapshot.visibleTools.count
        let colorControls = min(snapshot.paletteColors.count, 4) + 2
        let actionControls = actionButtonCount + max(selectedActionButtonCount, 0)

        return outerPadding +
            dragHandleHeight +
            topControlsHeight +
            dividerHeight +
            gridHeight(itemCount: toolControls, columns: compactColumnCount) +
            dividerHeight +
            gridHeight(itemCount: colorControls, columns: compactColumnCount) +
            CGFloat(menuControlCount) * menuControlHeight +
            dividerHeight +
            gridHeight(itemCount: actionControls, columns: compactColumnCount) +
            CGFloat(childCount - 1) * gridSpacing +
            contentBottomPadding
    }

    private static func verticalTopControlsHeight(statusControlCount: Int) -> CGFloat {
        let baseHeight = buttonSize + gridSpacing + buttonSize
        guard statusControlCount > 0 else { return baseHeight }
        return baseHeight + gridSpacing + gridHeight(itemCount: statusControlCount, columns: compactColumnCount)
    }

    private static func estimatedHorizontalToolbarWidth(
        for snapshot: PreferencesSnapshot,
        statusControlCount: Int,
        selectedActionButtonCount: Int
    ) -> CGFloat {
        let outerPadding: CGFloat = 12
        let dragHandleWidth: CGFloat = 16
        let dividerWidth: CGFloat = 5
        let menuControlCount = 2
        let fixedButtons = 3
        let toolButtons = snapshot.visibleTools.count
        let colorButtons = min(snapshot.paletteColors.count, 4) + 2
        let actionControls = actionButtonCount + max(selectedActionButtonCount, 0)
        let buttonCount = fixedButtons + statusControlCount + toolButtons + colorButtons + actionControls
        let elementCount = 1 + buttonCount + 3 + menuControlCount

        return outerPadding +
            dragHandleWidth +
            CGFloat(buttonCount) * buttonSize +
            CGFloat(3) * dividerWidth +
            CGFloat(menuControlCount) * menuControlWidth +
            CGFloat(max(elementCount - 1, 0)) * gridSpacing
    }
}
