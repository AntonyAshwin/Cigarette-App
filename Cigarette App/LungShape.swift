import SwiftUI

/// Renders "lungs.png" from Assets (or bundle) and supports the breathing animation.
public struct LungShape: View {
    public var height: CGFloat = 160

    public init(height: CGFloat = 160) {
        self.height = height
    }

    public var body: some View {
        Group {
            #if canImport(UIKit)
            if let ui = UIImage(named: "lungs") {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                Image("lungs") // fallback to asset name
                    .resizable()
                    .scaledToFit()
            }
            #else
            Image("lungs")
                .resizable()
                .scaledToFit()
            #endif
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
