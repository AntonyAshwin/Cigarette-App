//
//  BreathingModifier.swift
//  Cigarette App
//
//  Created by Ashwin, Antony on 13/09/25.
//

import SwiftUI

private struct BreathingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    var scale: CGFloat   = 0.02   // ±2% size
    var lift: CGFloat    = 2      // slight vertical drift
    var duration: Double = 1.2

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content
            } else {
                content
                    .scaleEffect(breathe ? 1 + scale : 1 - scale)
                    .offset(y: breathe ? -lift : lift)
                    .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true),
                               value: breathe)
                    .onAppear { breathe = true }
            }
        }
    }
}

extension View {
    /// Apply subtle “breathing” animation.
    func breathing(scale: CGFloat = 0.02, lift: CGFloat = 2, duration: Double = 1.2) -> some View {
        modifier(BreathingModifier(scale: scale, lift: lift, duration: duration))
    }
}
