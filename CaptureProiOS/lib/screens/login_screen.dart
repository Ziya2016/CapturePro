import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_manager.dart';
import 'create_account_dialog.dart';
import 'camera_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _passwordVisible = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  Future<void> _checkRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isRemembered = prefs.getBool(UserManager.keyIsRemembered) ?? false;
    final savedUser = prefs.getString(UserManager.keyLoggedInUser);

    if (isRemembered && savedUser != null && savedUser.isNotEmpty) {
      final users = await UserManager.getAllUsers();
      final user = users.firstWhere(
        (u) => u.username.toLowerCase() == savedUser.toLowerCase(),
        orElse: () => users.first,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CameraScreen(user: user)),
        );
      }
    } else if (savedUser != null) {
      _usernameController.text = savedUser;
      setState(() => _rememberMe = true);
    }
  }

  void _attemptLogin() async {
    final u = _usernameController.text.trim();
    final p = _passwordController.text.trim();

    if (u.isEmpty) {
      setState(() => _errorMessage = "Please enter your username.");
      return;
    }
    if (p.isEmpty) {
      setState(() => _errorMessage = "Please enter your password.");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await UserManager.authenticate(u, p);
    setState(() => _loading = false);

    switch (result.type) {
      case LoginResultType.invalidCredentials:
      case LoginResultType.expired:
        setState(() => _errorMessage = result.message);
        break;
      case LoginResultType.success:
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(UserManager.keyIsRemembered, _rememberMe);
        await prefs.setString(UserManager.keyLoggedInUser, result.user!.username);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => CameraScreen(user: result.user!)),
          );
        }
        break;
    }
  }

  void _showCreateAccount() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => const CreateAccountDialog(),
    );
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Account created successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Header Logo + Name ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("C", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(text: "Capture", style: TextStyle(color: Color(0xFFFF6D00), fontSize: 26, fontWeight: FontWeight.bold)),
                            TextSpan(text: " Pro", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Text("developed by Anees Ariyakkal", style: TextStyle(color: Color(0xFF8899AA), fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Login Form Card ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sign In", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Enter your credentials to continue", style: TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
                    const SizedBox(height: 22),

                    // Username Input
                    const Text("Username", style: TextStyle(color: Color(0xFF8899AA), fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Enter username",
                        hintStyle: const TextStyle(color: Color(0xFF8899AA)),
                        filled: true,
                        fillColor: const Color(0xFF1C2535),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    const Text("Password", style: TextStyle(color: Color(0xFF8899AA), fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Enter password",
                        hintStyle: const TextStyle(color: Color(0xFF8899AA)),
                        filled: true,
                        fillColor: const Color(0xFF1C2535),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF8899AA)),
                          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Remember me
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          activeColor: const Color(0xFFFF6D00),
                          onChanged: (val) => setState(() => _rememberMe = val ?? false),
                        ),
                        const Text("Remember me", style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _attemptLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1FA2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("SIGN IN", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Create Account Button - Ensure White Text on Orange Button as requested
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _showCreateAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6D00), // Solid Orange
                          foregroundColor: Colors.white,            // Explicit WHITE text
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text(
                          "CREATE NEW ACCOUNT",
                          style: TextStyle(
                            color: Colors.white,                  // Solid WHITE font
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("Capture Pro · Secure Access", style: TextStyle(color: Color(0xFF8899AA), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
