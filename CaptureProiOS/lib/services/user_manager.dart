import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/user_account.dart';

enum LoginResultType { success, invalidCredentials, expired }

class LoginResult {
  final LoginResultType type;
  final UserAccount? user;
  final String? message;

  LoginResult(this.type, {this.user, this.message});
}

enum RegisterResult { success, emptyFields, userAlreadyExists }

class UserManager {
  static const String defaultUserExpiry = "31-12-2027";
  static const String keyUserAccounts = "user_accounts_v1";
  static const String keyLoggedInUser = "logged_in_user";
  static const String keyIsRemembered = "is_remembered";

  static final List<UserAccount> _defaultAccounts = [
    UserAccount(username: "Admin", password: "123", isAdmin: true),
    UserAccount(username: "Test", password: "123", expiryDate: defaultUserExpiry),
  ];

  static Future<List<UserAccount>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(keyUserAccounts);

    if (jsonString == null || jsonString.isEmpty) {
      await saveUsers(_defaultAccounts);
      return _defaultAccounts;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => UserAccount.fromJson(e)).toList();
    } catch (_) {
      return _defaultAccounts;
    }
  }

  static Future<void> saveUsers(List<UserAccount> users) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(users.map((e) => e.toJson()).toList());
    await prefs.setString(keyUserAccounts, jsonString);
  }

  static bool isExpired(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) return false;
    try {
      final format = DateFormat("dd-MM-yyyy");
      final expiry = format.parseStrict(expiryDate);
      final today = DateTime.now();
      final currentDate = DateTime(today.year, today.month, today.day);
      return currentDate.isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  static Future<LoginResult> authenticate(String username, String password) async {
    final users = await getAllUsers();
    final user = users.firstWhere(
      (u) => u.username.toLowerCase() == username.trim().toLowerCase() && u.password == password.trim(),
      orElse: () => UserAccount(username: '', password: ''),
    );

    if (user.username.isEmpty) {
      return LoginResult(LoginResultType.invalidCredentials, message: "Invalid username or password.");
    }

    if (!user.isAdmin && isExpired(user.expiryDate)) {
      return LoginResult(
        LoginResultType.expired,
        user: user,
        message: "Account '${user.username}' has expired.\nPlease contact Admin.",
      );
    }

    return LoginResult(LoginResultType.success, user: user);
  }

  static Future<RegisterResult> registerUser(String username, String password) async {
    final u = username.trim();
    final p = password.trim();

    if (u.isEmpty || p.isEmpty) return RegisterResult.emptyFields;

    final users = await getAllUsers();
    if (users.any((acc) => acc.username.toLowerCase() == u.toLowerCase())) {
      return RegisterResult.userAlreadyExists;
    }

    users.add(UserAccount(
      username: u,
      password: p,
      expiryDate: defaultUserExpiry,
      isAdmin: false,
    ));

    await saveUsers(users);
    return RegisterResult.success;
  }

  static Future<void> updateUserExpiry(String username, String newExpiry) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.username.toLowerCase() == username.toLowerCase());
    if (index != -1) {
      final updated = UserAccount(
        username: users[index].username,
        password: users[index].password,
        expiryDate: newExpiry,
        isAdmin: users[index].isAdmin,
      );
      users[index] = updated;
      await saveUsers(users);
    }
  }

  static Future<void> removeUser(String username) async {
    final users = await getAllUsers();
    users.removeWhere((u) => u.username.toLowerCase() == username.toLowerCase() && !u.isAdmin);
    await saveUsers(users);
  }
}
