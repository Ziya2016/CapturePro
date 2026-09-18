class UserAccount {
  final String username;
  final String password;
  final String? expiryDate; // Format: dd-MM-yyyy
  final bool isAdmin;

  UserAccount({
    required this.username,
    required this.password,
    this.expiryDate,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'expiryDate': expiryDate,
        'isAdmin': isAdmin,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        username: json['username'] ?? '',
        password: json['password'] ?? '',
        expiryDate: json['expiryDate'],
        isAdmin: json['isAdmin'] ?? false,
      );
}
