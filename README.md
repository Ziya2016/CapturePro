# Capture Pro — Android App

A native Android photo-capture app that saves images to a user-chosen folder,
named by a **Tag No** you enter. Duplicate tags are auto-suffixed `_2`, `_3`, etc.
The app has a built-in **licence expiry of 31 December 2026**.

---

## 📋 Requirements

| Tool | Minimum version |
|---|---|
| Android Studio | Hedgehog (2023.1.1) or newer |
| JDK | 17 |
| Android device / emulator | API 26 (Android 8.0) + |
| Gradle | 8.4 (downloaded automatically) |

---

## 🚀 How to Build & Install

### Option A — Android Studio (Recommended)

1. Open **Android Studio** → **File → Open**
2. Select this folder: `e:\Google Antigravity\Capture Pro`
3. Wait for Gradle sync to complete (it will download dependencies automatically)
4. Connect your Android device via USB (enable USB Debugging in Developer Options)
5. Press **▶ Run** or use **Build → Build APK(s)**

> **Note:** Android Studio will automatically download the `gradle-wrapper.jar`
> during the first sync. No manual setup is needed.

---

### Option B — Command Line

```bat
REM From the project root:
gradlew.bat assembleDebug
REM APK will be at: app\build\outputs\apk\debug\app-debug.apk
```

Then install on a connected device:
```bat
adb install app\build\outputs\apk\debug\app-debug.apk
```

---

## 📱 First-Time Setup on Device

1. Launch **Capture Pro**
2. Grant **Camera** and **Media** permissions when prompted
3. Tap **Change Location** → pick a folder where photos will be saved
4. Type a **Tag No** (e.g. `PUMP-001`)
5. Tap **CAPTURE PHOTO** → file saved as `PUMP-001.jpg`
6. Tap again → saved as `PUMP-001_2.jpg`, then `PUMP-001_3.jpg`, etc.

---

## 🗂️ File Naming Convention

| Tag No entered | Files already in folder | File saved |
|---|---|---|
| `ABC123` | *(none)* | `ABC123.jpg` |
| `ABC123` | `ABC123.jpg` | `ABC123_2.jpg` |
| `ABC123` | `ABC123.jpg`, `ABC123_2.jpg` | `ABC123_3.jpg` |

---

## ⏰ Licence Expiry

This app will **stop working after 31 December 2026**.  
After that date a full-screen "License Expired" message is displayed and
no camera or capture functionality is accessible.

---

## 📁 Project Structure

```
Capture Pro/
├── app/
│   ├── src/main/
│   │   ├── java/com/capturepro/app/
│   │   │   ├── MainActivity.kt       ← Main UI + camera + capture logic
│   │   │   ├── ExpiryGuard.kt        ← Expiry date check
│   │   │   ├── TagNoResolver.kt      ← Auto-suffix filename logic
│   │   │   └── PrefsManager.kt       ← SharedPreferences wrapper
│   │   ├── res/
│   │   │   ├── layout/               ← XML layouts
│   │   │   ├── drawable/             ← Button & frame drawables
│   │   │   ├── values/               ← Colors, strings, themes
│   │   │   └── mipmap-anydpi-v26/    ← Adaptive launcher icon
│   │   └── AndroidManifest.xml
│   └── build.gradle
├── build.gradle
├── settings.gradle
├── gradle.properties
└── gradlew.bat
```

---

## 🔑 Permissions Used

| Permission | Purpose |
|---|---|
| `CAMERA` | Live preview and photo capture |
| `READ_MEDIA_IMAGES` | Read images on Android 13+ |
| `WRITE_EXTERNAL_STORAGE` | Write files on Android ≤ 9 |

Folder access on Android 10+ uses the **Storage Access Framework** (SAF)
via `ACTION_OPEN_DOCUMENT_TREE` — no root access required.
