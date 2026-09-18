import 'package:flutter/material.dart';
import '../models/user_account.dart';
import '../services/user_manager.dart';
import 'create_account_dialog.dart';

class AdminPanelDialog extends StatefulWidget {
  const AdminPanelDialog({Key? key}) : super(key: key);

  @override
  State<AdminPanelDialog> createState() => _AdminPanelDialogState();
}

class _AdminPanelDialogState extends State<AdminPanelDialog> {
  List<UserAccount> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await UserManager.getAllUsers();
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  void _showCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => const CreateAccountDialog(),
    );
    if (created == true) {
      _loadUsers();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Manage Users",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                  label: const Text(
                    "Create User",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Admin panel · Create, edit expiry & remove users",
              style: TextStyle(color: Color(0xFF8899AA), fontSize: 11),
            ),
            const Divider(color: Color(0xFF1E2A38), height: 24),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _users.map((acc) => _buildUserRow(acc)).toList(),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(UserAccount acc) {
    final isExp = !acc.isAdmin && UserManager.isExpired(acc.expiryDate);
    final statusText = acc.isAdmin
        ? "No Expiry"
        : (isExp ? "Expired" : "Active");
    final statusColor = acc.isAdmin
        ? const Color(0xFFFF6D00)
        : (isExp ? Colors.redAccent : Colors.greenAccent);

    final expController = TextEditingController(text: acc.expiryDate ?? UserManager.defaultUserExpiry);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2535),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                acc.username + (acc.isAdmin ? " (Admin)" : ""),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          if (!acc.isAdmin) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: expController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "dd-MM-yyyy",
                      hintStyle: const TextStyle(color: Color(0xFF8899AA)),
                      filled: true,
                      fillColor: const Color(0xFF161B26),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () async {
                    final newExp = expController.text.trim();
                    if (newExp.isEmpty || !RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(newExp)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter date as dd-MM-yyyy")),
                      );
                      return;
                    }
                    await UserManager.updateUserExpiry(acc.username, newExp);
                    _loadUsers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: const Text("Save", style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () async {
                    await UserManager.removeUser(acc.username);
                    _loadUsers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  child: const Text("Remove", style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              "Full Access · Permanent Account",
              style: TextStyle(color: Color(0xFF8899AA), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
