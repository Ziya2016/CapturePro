import SwiftUI

struct CreateAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newUsername: String = ""
    @State private var newPassword: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    var onSuccess: ((String, String) -> Void)?

    var body: some View {
        ZStack {
            Color(red: 22/255, green: 27/255, blue: 38/255)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Create New Account")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Enter username and password to create account")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                VStack(alignment: .leading, spacing: 6) {
                    Text("USERNAME")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                    TextField("Enter username", text: $newUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("PASSWORD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                    SecureField("Enter password", text: $newPassword)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(red: 198/255, green: 40/255, blue: 40/255))
                            .cornerRadius(8)
                    }

                    Button(action: handleCreate) {
                        Text("Create Account")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 123/255, green: 31/255, blue: 162/255),
                                        Color(red: 171/255, green: 71/255, blue: 188/255)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                }
            }
            .padding(24)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func handleCreate() {
        let result = UserManager.shared.registerUser(username: newUsername, password: newPassword)
        switch result {
        case .emptyFields:
            alertMessage = "Username and password cannot be empty."
            showAlert = true
        case .userAlreadyExists:
            alertMessage = "Username '\(newUsername)' already exists."
            showAlert = true
        case .success:
            let u = newUsername
            let p = newPassword
            presentationMode.wrappedValue.dismiss()
            onSuccess?(u, p)
        }
    }
}
