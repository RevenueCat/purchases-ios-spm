//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  GradientView.swift
//
//  Created by Mark Villacampa on 2024-11-24.

import SwiftUI

#if !os(macOS) && !os(tvOS) // For Paywalls V2

struct GradientView: View {
    enum GradientStyle {
        case linear(Int)
        case radial
    }

    @Environment(\.colorScheme)
    private var colorScheme

    let lightGradient: Gradient
    let darkGradient: Gradient?
    let gradientStyle: GradientStyle

    private var gradient: Gradient {
        switch colorScheme {
        case .light:
            return lightGradient
        case .dark:
            return darkGradient ?? lightGradient
        @unknown default:
            return lightGradient
        }
    }

    var body: some View {
        switch gradientStyle {
        case .linear(let degrees):
            LinearGradient(
                gradient: gradient,
                startPoint: UnitPoint(angle: Angle(degrees: Double(degrees))),
                endPoint: UnitPoint(angle: Angle(degrees: Double(degrees+180)))
            )
        case .radial:
            RadialGradient(
                gradient: gradient,
                center: .center,
                startRadius: 0,
                endRadius: 100
            )
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
struct GradientView_Previews: PreviewProvider {

    static private func gradientView(style: GradientView.GradientStyle) -> some View {
        GradientView(
            lightGradient: .init(colors: .init([.red, .black])),
            darkGradient: .init(colors: .init([.blue, .black])),
            gradientStyle: style
        )
    }

    static var previews: some View {
        GradientView(
            lightGradient: .init(colors: .init([.red, .white])),
            darkGradient: .init(colors: .init([.blue, .white])),
            gradientStyle: .radial
        )
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Radial - Dark (should be blue)")

        GradientView(
            lightGradient: .init(colors: .init([.red, .white])),
            darkGradient: .init(colors: .init([.blue, .white])),
            gradientStyle: .radial
        )
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Radial - Light (should be red)")

        GradientView(
            lightGradient: .init(colors: .init([.red, .white])),
            darkGradient: .init(colors: .init([.blue, .white])),
            gradientStyle: .linear(45)
        )
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Linear 45º - Dark (should be blue)")

        GradientView(
            lightGradient: .init(colors: .init([.red, .white])),
            darkGradient: .init(colors: .init([.blue, .white])),
            gradientStyle: .linear(90)
        )
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Linear 90º - Light (should be red)")

        VStack {
            LinearGradientPreview(label: "Linear 0º", degrees: 0)
            LinearGradientPreview(label: "Linear 45º", degrees: 45)
            LinearGradientPreview(label: "Linear 90º", degrees: 90)
            LinearGradientPreview(label: "Linear 135º", degrees: 135)
            LinearGradientPreview(label: "Linear 180º", degrees: 180)
            LinearGradientPreview(label: "Linear 225º", degrees: 225)
            LinearGradientPreview(label: "Linear 270º", degrees: 270)
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Linear")
    }

    /// Helper view to preview linear gradients with different angles. This is useful so to keep down the
    /// number of views in the container holding all of the previews to avoid compilation issues
    /// with the preview.
    private struct LinearGradientPreview: View {

        let label: String
        let degrees: Int

        var body: some View {
            VStack {
                Text(label)
                gradientView(style: .linear(degrees))
            }
        }
    }

}

extension UnitPoint {

    init(angle: Angle) {
        // Convert the angle to radians and negate to make clockwise
        // Subtract π/2 (90 degrees) to place an angle of 0 degrees at the top
        let radians = -angle.radians - (.pi / 2)

        // Calculate the normalized x and y positions
        let xPosition = cos(radians)
        let yPosition = sin(radians)

        // Determine the scaling factor to move the point to the edge of the enclosing square
        let scaleFactor = max(abs(xPosition), abs(yPosition))

        // Scale the x and y coordinates
        let scaledX = xPosition / scaleFactor
        let scaledY = yPosition / scaleFactor

        // Convert the scaled coordinates to a UnitPoint
        self.init(x: (scaledX + 1) / 2, y: (1 - scaledY) / 2)
    }

}

#endif
