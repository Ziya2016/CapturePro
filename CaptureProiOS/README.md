# Capture Pro - Cross-Platform Flutter App (iOS & Android)

A high-performance photo capture, barcode scanning, tag count management, and visual object identification app built with Flutter.

---

## Features
- **User Authentication & Default Expiry**:
  - Test accounts default expiry date set to `31-12-2027`.
  - Admin account (`Admin`) with permanent access and full user management capabilities.
  - Create Account button styled with prominent **WHITE text** on solid orange background.
- **Dynamic Image Directory Structure**:
  - Automatically saves images under `dd-MM-yyyy & Username` subfolders (e.g. `17-09-2026 & Admin`).
- **Live Camera Controls**:
  - Real-time camera preview with target overlay box.
  - Zoom in / Zoom out slider and quick toggle buttons (+/-).
  - High-res photo capture.
- **Barcode & Tag Management**:
  - Auto-resets Object Size input field whenever Tag No changes.
  - Mobile scanner integration for instant barcode scanning.
  - Real-time Tag No image quantity counter.
- **Google Lens Visual Search**:
  - Integrated visual search engine viewer.
  - Permanent top-right Close (X) button to cleanly close Google Lens results and return to camera preview.

---

## How to Build & Run

### For iOS (`.ipa` / Xcode):
1. Copy the `CaptureProiOS` directory to your Mac.
2. Open terminal in the directory and run:
   ```bash
   flutter pub get
   flutter build ipa
   ```
3. Open `ios/Runner.xcworkspace` in Xcode to run on iOS Simulators or physical iPhones.

### For Android (`.apk`):
```bash
flutter pub get
flutter build apk --release
```
