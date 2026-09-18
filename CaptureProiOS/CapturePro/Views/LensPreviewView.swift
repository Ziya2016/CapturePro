import SwiftUI
import WebKit

struct LensPreviewView: View {
    @Environment(\.presentationMode) var presentationMode
    let targetURL: URL

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and Close (X) button
            HStack {
                Text("Google Lens Search")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Close")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 198/255, green: 40/255, blue: 40/255))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 10/255, green: 10/255, blue: 24/255))

            WebViewHolder(url: targetURL)
        }
        .background(Color(red: 13/255, green: 17/255, blue: 23/255).ignoresSafeArea())
    }
}

struct WebViewHolder: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
