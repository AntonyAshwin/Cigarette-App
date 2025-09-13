import SwiftUI

/// Shows lungs.png from your app bundle / Assets.
/// Keep the asset/file name exactly "lungs" (lungs.png).
struct LungShape: View {
    var height: CGFloat = 160

    var body: some View {
        Group {
            #if canImport(UIKit)
            // Try loading from bundle (works for plain PNG files too)
            if let ui = UIImage(named: "lungs") {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback to asset catalog name
                Image("lungs")
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
