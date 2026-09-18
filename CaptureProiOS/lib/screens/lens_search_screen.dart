import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LensSearchScreen extends StatefulWidget {
  final String imagePath;

  const LensSearchScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<LensSearchScreen> createState() => _LensSearchScreenState();
}

class _LensSearchScreenState extends State<LensSearchScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize WebViewController targeting Google Lens visual search engine
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse("https://lens.google.com/search?p=capturepro"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A18),
        elevation: 0,
        title: const Text(
          "Google Lens Search Results",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Permanent Close (X) button requested by user
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: "Close Lens Results",
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6D00)),
            ),
        ],
      ),
    );
  }
}
