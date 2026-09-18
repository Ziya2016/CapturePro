import SwiftUI
import UIKit

struct FullScreenImageView: View {
    @Environment(\.presentationMode) var presentationMode
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 { scale = 1.0; lastScale = 1.0 }
                                }
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }

            // Close button
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(20)
            }
        }
    }
}
