import SwiftUI

struct ExpiredView: View {
    var body: some View {
        ZStack {
            Color(red: 13/255, green: 17/255, blue: 23/255)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("App Expired")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("This application has expired and is no longer available.")
                    .font(.body)
                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

struct ExpiredView_Previews: PreviewProvider {
    static var previews: some View {
        ExpiredView()
    }
}
