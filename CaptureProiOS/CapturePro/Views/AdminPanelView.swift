import SwiftUI

struct AdminPanelView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var accounts: [UserManager.UserAccount] = []
    @State private var showCreateUserSheet: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var expiryInputs: [String: String] = [:]

    var body: some View {
        ZStack {
            Color(red: 22/255, green: 27/255, blue: 38/255)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Users")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Admin panel · Create, edit expiry & remove users")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
                    }

                    Spacer()

                    Button(action: { showCreateUserSheet = true }) {
                        Text("+ Create User")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
                            .cornerRadius(6)
                    }
                }

                Divider()
                    .background(Color(red: 30/255, green: 42/255, blue: 56/255))

                // User Accounts List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(accounts) { acc in
                            UserRowView(
                                acc: acc,
                                expiryText: Binding(
                                    get: { expiryInputs[acc.username] ?? acc.expiryDate ?? UserManager.defaultUserExpiry },
                                    set: { expiryInputs[acc.username] = $0 }
                                ),
                                onSave: { newExp in saveExpiry(for: acc, newExp: newExp) },
                                onRemove: { removeUser(acc) }
                            )
                        }
                    }
                }

                // Close Button
                HStack {
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Close")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 40)
                            .background(Color(red: 198/255, green: 40/255, blue: 40/255))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(20)
        }
        .onAppear(perform: loadAccounts)
        .sheet(isPresented: $showCreateUserSheet) {
            CreateAccountView { _, _ in
                loadAccounts()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func loadAccounts() {
        accounts = UserManager.shared.getAllUserAccounts()
        for acc in accounts {
            expiryInputs[acc.username] = acc.expiryDate ?? UserManager.defaultUserExpiry
        }
    }

    private func saveExpiry(for acc: UserManager.UserAccount, newExp: String) {
        let clean = newExp.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^\d{2}-\d{2}-\d{4}$"#
        guard clean.range(of: regex, options: .regularExpression) != nil else {
            alertTitle = "Invalid Format"
            alertMessage = "Please enter date in dd-MM-yyyy format."
            showAlert = true
            return
        }

        if UserManager.shared.updateUserExpiry(username: acc.username, newExpiry: clean) {
            alertTitle = "Success"
            alertMessage = "Updated '\(acc.username)' expiry → \(clean)"
            showAlert = true
            loadAccounts()
        }
    }

    private func removeUser(_ acc: UserManager.UserAccount) {
        if UserManager.shared.removeUser(username: acc.username) {
            alertTitle = "User Removed"
            alertMessage = "Removed user '\(acc.username)'."
            showAlert = true
            loadAccounts()
        }
    }
}

struct UserRowView: View {
    let acc: UserManager.UserAccount
    @Binding var expiryText: String
    let onSave: (String) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(acc.username + (acc.isAdmin ? " (Admin)" : ""))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if acc.isAdmin || acc.expiryDate == nil {
                    Text("No Expiry")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 109/255, blue: 0/255))
                } else if let exp = acc.expiryDate, UserManager.shared.isExpired(exp) {
                    Text("Expired")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 255/255, green: 82/255, blue: 82/255))
                } else {
                    Text("Active")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            if !acc.isAdmin {
                HStack(spacing: 8) {
                    TextField("dd-MM-yyyy", text: $expiryText)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(Color(red: 22/255, green: 27/255, blue: 38/255))
                        .foregroundColor(.white)
                        .cornerRadius(6)

                    Button(action: { onSave(expiryText) }) {
                        Text("Save")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 38)
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
                            .cornerRadius(6)
                    }

                    Button(action: onRemove) {
                        Text("Remove")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 65, height: 38)
                            .background(Color(red: 198/255, green: 40/255, blue: 40/255))
                            .cornerRadius(6)
                    }
                }
            } else {
                Text("Full Access · Permanent Account")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 136/255, green: 153/255, blue: 170/255))
            }
        }
        .padding(12)
        .background(Color(red: 28/255, green: 37/255, blue: 53/255))
        .cornerRadius(10)
    }
}
