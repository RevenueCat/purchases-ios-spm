//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  ColorInformation+MultiScheme.swift
//
//  Created by Nacho Soto on 7/14/23.

import Foundation
import RevenueCat

#if canImport(SwiftUI) && canImport(UIKit) && !os(watchOS)

extension PaywallData.Configuration.ColorInformation {

    /// - Returns: `PaywallData.Configuration.Colors` combining `light` and `dark` if they're available
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    var multiScheme: PaywallData.Configuration.Colors {
        let light = self.light
        guard let dark = self.dark else {
            // With no dark information, simply use `light`.
            return light
        }

        return .combine(light: light, dark: dark)
    }

}

extension PaywallData.Configuration.Colors {

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    static func combine(light: Self, dark: Self) -> Self {
        return .init(
            background: .init(light: light.background, dark: dark.background),
            text1: .init(light: light.text1, dark: dark.text1),
            text2: .init(light: light.text2, dark: dark.text2),
            text3: .init(light: light.text3, dark: dark.text3),
            callToActionBackground: .init(light: light.callToActionBackground, dark: dark.callToActionBackground),
            callToActionForeground: .init(light: light.callToActionForeground, dark: dark.callToActionForeground),
            callToActionSecondaryBackground: .init(light: light.callToActionSecondaryBackground,
                                                   dark: dark.callToActionSecondaryBackground),
            accent1: .init(light: light.accent1, dark: dark.accent1),
            accent2: .init(light: light.accent2, dark: dark.accent2),
            accent3: .init(light: light.accent3, dark: dark.accent3),
            closeButton: .init(light: light.closeButton, dark: dark.closeButton),
            tierControlBackground: .init(light: light.tierControlBackground,
                                         dark: dark.tierControlBackground),
            tierControlForeground: .init(light: light.tierControlForeground,
                                         dark: dark.tierControlForeground),
            tierControlSelectedBackground: .init(light: light.tierControlSelectedBackground,
                                                 dark: dark.tierControlSelectedBackground),
            tierControlSelectedForeground: .init(light: light.tierControlSelectedForeground,
                                                 dark: dark.tierControlSelectedForeground)
        )
    }

}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
private extension PaywallColor {

    /// Creates a dynamic color for 2 ``ColorScheme``s from 2 optional colors.
    init?(light: PaywallColor?, dark: PaywallColor?) {
        if let light, let dark {
            self.init(light: light, dark: dark)
        } else if let light {
            self = light
        } else if let dark {
            self = dark
        } else {
            return nil
        }
    }

}

#else

extension PaywallData.Configuration.ColorInformation {

    /// - Returns: color for platforms that don't support changing light / dark mode.
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    var multiScheme: PaywallData.Configuration.Colors {
        #if os(watchOS)
        // watchOS uses "dark" appearance by default.
        return self.dark ?? self.light
        #else
        return self.light
        #endif
    }

}

#endif

extension PaywallData.Configuration {

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    var multiSchemeColorsByTier: [PaywallData.Tier: PaywallData.Configuration.Colors] {
        let colors = self.colorsByTier

        return .init(
            uniqueKeysWithValues: self.tiers
                .lazy
                .compactMap { tier in
                    guard let colors = colors[tier.id] else { return nil }
                    return (tier, colors.multiScheme)
                }
        )
    }

}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TemplateViewConfiguration {

    /// Whether dark mode colors have been configured in this paywall.
    var hasDarkMode: Bool {
        return self.configuration.colors.dark != nil
    }

}

#if canImport(SwiftUI)

import SwiftUI

// Helpful acessors
extension PaywallData.Configuration.Colors {

    var backgroundColor: Color { self.background?.underlyingColor ?? Self.defaultBackgroundColor }
    var text1Color: Color { self.text1?.underlyingColor ?? Self.defaultForegroundColor }
    var text2Color: Color { self.text2?.underlyingColor ?? self.text1Color }
    var text3Color: Color { self.text3?.underlyingColor ?? self.text2Color }
    var callToActionBackgroundColor: Color {
        self.callToActionBackground?.underlyingColor ?? Self.defaultBackgroundColor
    }
    var callToActionForegroundColor: Color {
        self.callToActionForeground?.underlyingColor ?? Self.defaultForegroundColor
    }
    var callToActionSecondaryBackgroundColor: Color? { self.callToActionSecondaryBackground?.underlyingColor }
    var accent1Color: Color { self.accent1?.underlyingColor ?? self.callToActionForegroundColor }
    var accent2Color: Color { self.accent2?.underlyingColor ?? self.accent1Color }
    var accent3Color: Color { self.accent3?.underlyingColor ?? self.accent2Color }
    var closeButtonColor: Color? { self.closeButton?.underlyingColor }
    var tierControlBackgroundColor: Color? { self.tierControlBackground?.underlyingColor }
    var tierControlForegroundColor: Color? { self.tierControlForeground?.underlyingColor }
    var tierControlSelectedBackgroundColor: Color? { self.tierControlSelectedBackground?.underlyingColor }
    var tierControlSelectedForegroundColor: Color? { self.tierControlSelectedForeground?.underlyingColor }

    #if os(watchOS)
    private static let defaultBackgroundColor: Color = .black
    #elseif canImport(UIKit) && !os(tvOS)
    private static let defaultBackgroundColor: Color = .init(UIColor.systemBackground)
    #else
    private static let defaultBackgroundColor: Color = .white
    #endif

    private static let defaultForegroundColor: Color = .primary

}

#endif
