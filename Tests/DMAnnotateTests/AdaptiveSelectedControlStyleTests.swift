import AppKit
import Testing
@testable import DMAnnotate

@Test func standardMacOSAccentSamplesChooseACompliantForeground() {
    let accents: [(name: String, red: Double, green: Double, blue: Double)] = [
        ("graphite", 0.557, 0.557, 0.576),
        ("red", 1.000, 0.231, 0.188),
        ("orange", 1.000, 0.584, 0.000),
        ("yellow", 1.000, 0.800, 0.000),
        ("green", 0.204, 0.780, 0.349),
        ("blue", 0.000, 0.478, 1.000),
        ("purple", 0.686, 0.321, 0.871),
        ("pink", 1.000, 0.176, 0.333)
    ]

    for accent in accents {
        let foreground = AdaptiveSelectedControlContrast.foreground(
            red: accent.red,
            green: accent.green,
            blue: accent.blue
        )
        let ratio = AdaptiveSelectedControlContrast.contrastRatio(
            foreground: foreground,
            backgroundRed: accent.red,
            green: accent.green,
            blue: accent.blue
        )

        #expect(
            ratio >= AdaptiveSelectedControlContrast.minimumRatio,
            "\(accent.name) selected foreground contrast was \(ratio):1"
        )
    }
}

@Test func adaptiveForegroundMeetsContrastAcrossTheLuminanceRange() {
    for step in 0...100 {
        let component = Double(step) / 100
        let foreground = AdaptiveSelectedControlContrast.foreground(
            red: component,
            green: component,
            blue: component
        )
        let ratio = AdaptiveSelectedControlContrast.contrastRatio(
            foreground: foreground,
            backgroundRed: component,
            green: component,
            blue: component
        )

        #expect(ratio >= AdaptiveSelectedControlContrast.minimumRatio)
    }
}

@Test func lightYellowUsesDarkContentAndDarkBlueUsesLightContent() {
    #expect(
        AdaptiveSelectedControlContrast.foreground(red: 1, green: 0.8, blue: 0) == .black
    )
    #expect(
        AdaptiveSelectedControlContrast.foreground(red: 0, green: 0.22, blue: 0.48) == .white
    )
}

@MainActor
@Test func selectedDisabledControlsStaySelectedUnlessTheCallerSuppressesUnavailableActions() {
    #expect(
        AdaptiveSelectedControlStyle.selectionIsVisible(
            selected: true,
            isEnabled: false,
            suppressSelectionWhenDisabled: false
        )
    )
    #expect(
        !AdaptiveSelectedControlStyle.selectionIsVisible(
            selected: true,
            isEnabled: false,
            suppressSelectionWhenDisabled: true
        )
    )
}

@MainActor
@Test func semanticSelectedColorsResolveWithCompliantContrastAcrossAppearancesAndActivity() throws {
    let appearanceNames: [NSAppearance.Name] = [
        .aqua,
        .darkAqua,
        .accessibilityHighContrastAqua,
        .accessibilityHighContrastDarkAqua
    ]

    for appearanceName in appearanceNames {
        let appearance = try #require(NSAppearance(named: appearanceName))
        for isActive in [true, false] {
            let pair = AdaptiveSelectedControlColors.resolvedPair(
                isActive: isActive,
                appearance: appearance
            )
            let dynamicForeground = AdaptiveSelectedControlColors.resolvedDynamicForeground(
                isActive: isActive,
                appearance: appearance
            )
            let expectedForeground = pair.foreground.nsColor.usingColorSpace(.sRGB) ?? pair.foreground.nsColor

            #expect(
                pair.contrastRatio >= AdaptiveSelectedControlContrast.minimumRatio,
                "\(appearanceName.rawValue), active=\(isActive), contrast=\(pair.contrastRatio):1"
            )
            #expect(dynamicForeground.redComponent == expectedForeground.redComponent)
            #expect(dynamicForeground.greenComponent == expectedForeground.greenComponent)
            #expect(dynamicForeground.blueComponent == expectedForeground.blueComponent)
        }
    }
}

@MainActor
@Test func selectedPressFeedbackIsImmediateAndDoesNotApplyToReleasedOrDisabledControls() {
    #expect(
        AdaptiveSelectedControlStyle.selectedScale(
            selectedIsVisible: true,
            isEnabled: true,
            isPressed: true
        ) == 0.94
    )
    #expect(
        AdaptiveSelectedControlStyle.selectedScale(
            selectedIsVisible: true,
            isEnabled: true,
            isPressed: false
        ) == 1
    )
    #expect(
        AdaptiveSelectedControlStyle.selectedScale(
            selectedIsVisible: true,
            isEnabled: false,
            isPressed: true
        ) == 1
    )
}

@MainActor
@Test func increasedContrastAndExplicitHighContrastExposeTheSharedSelectionOutline() {
    #expect(
        AdaptiveSelectedControlStyle.contrastOutlineIsVisible(
            selectedIsVisible: true,
            emphasizeContrast: false,
            increasedContrast: true
        )
    )
    #expect(
        AdaptiveSelectedControlStyle.contrastOutlineIsVisible(
            selectedIsVisible: true,
            emphasizeContrast: true,
            increasedContrast: false
        )
    )
    #expect(
        !AdaptiveSelectedControlStyle.contrastOutlineIsVisible(
            selectedIsVisible: false,
            emphasizeContrast: true,
            increasedContrast: true
        )
    )
}
