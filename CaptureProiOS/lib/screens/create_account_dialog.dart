import 'package:flutter/material.dart';
import '../services/user_manager.dart';

class CreateAccountDialog extends StatefulWidget {
  const CreateAccountDialog({Key? key}) : super(key: key);

  @override
  State<CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<CreateAccountDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  void _submit() async {
    final u = _usernameController.text.trim();
    final p = _passwordController.text.trim();

    final result = await UserManager.registerUser(u, p);
    switch (result) {
      case RegisterResult.emptyFields:
        setState(() => _errorMessage = "Username and password cannot be empty.");
        break;
      case RegisterResult.userAlreadyExists:
        setState(() => _errorMessage = "Username '$u' already exists.");
        break;
      case RegisterResult.success:
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create New Account",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Enter username and password to create account",
              style: TextStyle(color: Color(0xFF8899AA), fontSize: 11),
            ),
            const SizedBox(height: 16),
            const Text(
              "Username",
              style: TextStyle(color: Color(0xFF8899AA), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Enter username",
                hintStyle: const TextStyle(color: Color(0xFF8899AA)),
                filled: true,
                fillColor: const Color(0xFF1C2535),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Password",
              style: TextStyle(color: Color(0xFF8899AA), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Enter password",
                hintStyle: const TextStyle(color: Color(0xFF8899AA)),
                filled: true,
                fillColor: const Color(0xFF1C2535),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00), // Orange background
                    foregroundColor: Colors.white,            // Explicit WHITE text
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text(
                    "Create Account",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
