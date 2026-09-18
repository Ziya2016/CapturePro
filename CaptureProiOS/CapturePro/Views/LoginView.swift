import SwiftUI

struct LoginView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUser") private var loggedInUser: String = ""
    @AppStorage("isAdmin") private var isAdmin: Bool = false
    @AppStorage("rememberedUser") private var rememberedUser: String = ""
    @AppStorage("isRemembered") private var isRemembered: Bool = false

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var rememberMe: Bool = false
    @State private var errorMessage: String = ""
    @State private var showCreateAccountSheet: Bool = false

    var body: some View {
        ZStack {
            Color(red: 13/255, green: 17/255, blue: 23/255)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 30)

                    // ── Logo + Title Header ──
                    HStack(spacing: 12) {
                        Text("C")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(red: 123/255, green: 31/255, blue: 162/255))
                            .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 0) {
                                Text("Capture")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0/255))
                                Text(" Pro")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("developed by Anees Ariyakkal")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                        }
                    }

                    // ── Login Card ──
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sign In")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Enter your credentials to continue")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                        }

                        // Username
                        VStack(alignment: .leading, spacing: 6) {
                            Text("USERNAME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                            TextField("Enter username", text: $username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal, 14)
                                .frame(height: 48)
                                .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 46/255, green: 64/255, blue: 96/255), lineWidth: 1)
                                )
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORD")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                            HStack {
                                if showPassword {
                                    TextField("Enter password", text: $password)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("Enter password", text: $password)
                                }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Color(red: 28/255, green: 37/255, blue: 53/255))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 46/255, green: 64/255, blue: 96/255), lineWidth: 1)
                            )
                        }

                        // Remember me
                        Toggle(isOn: $rememberMe) {
                            Text("Remember me")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                        .toggleStyle(CheckboxToggleStyle())

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 255/255, green: 82/255, blue: 82/255))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 2)
                        }

                        // SIGN IN BUTTON
                        Button(action: attemptLogin) {
                            Text("SIGN IN")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
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

                        // CREATE NEW ACCOUNT BUTTON (Solid Orange Background + Prominent WHITE Text)
                        Button(action: { showCreateAccountSheet = true }) {
                            Text("CREATE NEW ACCOUNT")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white) // Ensure White Text
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 255/255, green: 109/255, blue: 0/255),
                                            Color(red: 255/255, green: 143/255, blue: 0/255)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(Color(red: 22/255, green: 27/255, blue: 38/255))
                    .cornerRadius(16)

                    Text("Capture Pro · Secure Access")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            if isRemembered && !rememberedUser.isEmpty {
                username = rememberedUser
                rememberMe = true
            }
        }
        .sheet(isPresented: $showCreateAccountSheet) {
            CreateAccountView { newU, newP in
                username = newU
                password = newP
                attemptLogin()
            }
        }
    }

    private func attemptLogin() {
        errorMessage = ""
        let result = UserManager.shared.authenticate(username: username, password: password)
        switch result {
        case .invalidCredentials:
            errorMessage = "Invalid username or password."
        case .expired(let uname):
            errorMessage = "Account for '\(uname)' has expired.\nPlease contact Admin."
        case .success(let uname, let admin):
            if rememberMe {
                isRemembered = true
                rememberedUser = uname
            } else {
                isRemembered = false
                rememberedUser = ""
            }
            loggedInUser = uname
            isAdmin = admin
            isLoggedIn = true
        }
    }
}

// Custom Checkbox Toggle Style for SwiftUI
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? Color(red: 255/255, green: 109/255, blue: 0/255) : Color(red: 136/255, green: 153/255, blue: 170/255))
                configuration.label
            }
        }
    }
}
