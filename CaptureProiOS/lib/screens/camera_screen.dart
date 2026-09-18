import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/user_account.dart';
import '../services/storage_manager.dart';
import '../services/user_manager.dart';
import 'admin_panel_dialog.dart';
import 'lens_search_screen.dart';
import 'login_screen.dart';

class CameraScreen extends StatefulWidget {
  final UserAccount user;

  const CameraScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;

  final _tagNoController = TextEditingController();
  final _objectSizeController = TextEditingController();
  final _minQtyController = TextEditingController(text: "1");

  String _lastTagNo = "";
  int _currentTagCount = 0;
  String? _lastImagePath;

  bool _showSize = true;
  bool _identifyObject = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _tagNoController.addListener(_onTagNoChanged);
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        _minZoom = await _cameraController!.getMinZoomLevel();
        _maxZoom = await _cameraController!.getMaxZoomLevel();

        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void _onTagNoChanged() {
    final currentTag = _tagNoController.text.trim();
    if (currentTag != _lastTagNo) {
      _lastTagNo = currentTag;
      // Requirement 2: Text Field Auto reset when tag no changes
      _objectSizeController.clear();
    }
    _updateTagStats();
  }

  Future<void> _updateTagStats() async {
    final tag = _tagNoController.text.trim();
    if (tag.isEmpty) {
      setState(() {
        _currentTagCount = 0;
        _lastImagePath = null;
      });
      return;
    }

    final count = await StorageManager.getTagCount(widget.user.username, tag);
    final lastPath = await StorageManager.getLastImagePath(widget.user.username, tag);

    setState(() {
      _currentTagCount = count;
      _lastImagePath = lastPath;
    });
  }

  Future<void> _setZoom(double zoom) async {
    if (_cameraController == null || !_isCameraInitialized) return;
    final targetZoom = zoom.clamp(_minZoom, _maxZoom);
    await _cameraController!.setZoomLevel(targetZoom);
    setState(() => _currentZoom = targetZoom);
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isTakingPicture) return;
    try {
      final file = await _cameraController!.takePicture();
      final tagNo = _tagNoController.text.trim().isEmpty ? "UNTAGGED" : _tagNoController.text.trim();

      await StorageManager.savePhoto(
        username: widget.user.username,
        tagNo: tagNo,
        imagePath: file.path,
        objectSize: _objectSizeController.text.trim(),
      );

      _updateTagStats();
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: 400,
        child: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              setState(() {
                _tagNoController.text = barcodes.first.rawValue!;
              });
              Navigator.of(ctx).pop();
            }
          },
        ),
      ),
    );
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(UserManager.keyIsRemembered, false);
    await prefs.remove(UserManager.keyLoggedInUser);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tagNoController.dispose();
    _objectSizeController.dispose();
    _minQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A18),
        elevation: 4,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text("C", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(text: "Capture", style: TextStyle(color: Color(0xFFFF6D00), fontSize: 16, fontWeight: FontWeight.bold)),
                  TextSpan(text: " Pro", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.user.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFFFF6D00)),
              onPressed: () => showDialog(context: context, builder: (_) => const AdminPanelDialog()),
              tooltip: "Admin Panel",
            ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Top Location & Preview Header Card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF161B26),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Image Save Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          "dd-MM-yyyy & ${widget.user.username}",
                          style: const TextStyle(color: Color(0xFF8899AA), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_lastImagePath != null)
                    GestureDetector(
                      onTap: () => _showEnlargedImage(_lastImagePath!),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(6),
                          image: DecorationImage(image: FileImage(File(_lastImagePath!)), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E2A38), height: 1),

            // ── Controls: Tag No & Min Qty ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 60, child: Text("Tag No", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(
                        child: TextField(
                          controller: _tagNoController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Enter Tag No...",
                            hintStyle: const TextStyle(color: Color(0xFF8899AA)),
                            filled: true,
                            fillColor: const Color(0xFF1C2535),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        onPressed: _openBarcodeScanner,
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () {
                          _tagNoController.clear();
                          _objectSizeController.clear();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
                        child: const Text("Reset", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total images saved qty: $_currentTagCount",
                        style: const TextStyle(color: Color(0xFFFF6D00), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: [
                          const Text("Show Size", style: TextStyle(color: Colors.white, fontSize: 12)),
                          Switch(
                            value: _showSize,
                            activeColor: const Color(0xFFFF6D00),
                            onChanged: (val) => setState(() => _showSize = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Camera Preview Box + Target Overlay + Zoom Controls ──────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 380,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF6D00), width: 2),
              ),
              child: Stack(
                children: [
                  _isCameraInitialized && _cameraController != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CameraPreview(_cameraController!),
                        )
                      : const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),

                  // Measurement Target Overlay Box
                  if (_showSize)
                    Center(
                      child: Container(
                        width: 220,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFFF6D00), width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),

                  // Zoom Control Slider Overlay (+ / -) as requested
                  Positioned(
                    right: 8,
                    top: 20,
                    bottom: 20,
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_in, color: Colors.white, size: 28),
                          onPressed: () => _setZoom(_currentZoom + 0.5),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        ),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _currentZoom,
                              min: _minZoom,
                              max: _maxZoom,
                              activeColor: const Color(0xFFFF6D00),
                              inactiveColor: Colors.white30,
                              onChanged: (val) => _setZoom(val),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_out, color: Colors.white, size: 28),
                          onPressed: () => _setZoom(_currentZoom - 0.5),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  // Big Capture Photo Button overlaid at bottom center
                  Positioned(
                    bottom: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF7B1FA2),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Google Lens Visual Search Button ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: const Text("Google Lens Visual Search", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    if (_lastImagePath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("📷 Capture a photo first, then tap Search")),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LensSearchScreen(imagePath: _lastImagePath!),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEnlargedImage(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(child: Image.file(File(path))),
            Positioned(
              top: 30,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
