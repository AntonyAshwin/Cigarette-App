import SwiftUI

/// Renders "lungs.png" from Assets (or bundle).
/// - If you want crisp single-color tinting, set the asset’s **Render As** to **Template Image** in Assets.
/// - Pass `tint:` to color the lungs, and `breathing: true` for a subtle inhale/exhale.
public struct LungShape: View {
    public var height: CGFloat
    public var tint: Color?
    public var breathing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    public init(height: CGFloat = 160, tint: Color? = nil, breathing: Bool = false) {
        self.height = height
        self.tint = tint
        self.breathing = breathing
    }

    // Build the base Image once
    private var baseImage: Image {
        #if canImport(UIKit)
        if let ui = UIImage(named: "lungs") {
            return Image(uiImage: ui)
        } else {
            return Image("lungs")
        }
        #else
        return Image("lungs")
        #endif
    }

    // The image with optional tint applied (done on Image, not via a generic modifier)
    @ViewBuilder
    private var tintedImage: some View {
        if let tint {
            // Preferred: template + foregroundStyle (set asset Render As: Template Image)
            baseImage
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)

            // If you don't want to set Template in Assets, you can instead use:
            // baseImage.resizable().scaledToFit().colorMultiply(tint)
        } else {
            baseImage
                .resizable()
                .scaledToFit()
        }
    }

    public var body: some View {
        let img = tintedImage

        Group {
            if breathing && !reduceMotion {
                img
                    .scaleEffect(breathe ? 1.02 : 0.98)
                    .offset(y: breathe ? -2 : 2)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathe)
                    .onAppear { breathe = true }
            } else {
                img
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
