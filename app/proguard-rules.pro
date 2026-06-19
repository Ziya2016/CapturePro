# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in the Android SDK's default proguard-android-optimize.txt file.

# Keep CameraX classes
-keep class androidx.camera.** { *; }

# Keep DocumentFile classes
-keep class androidx.documentfile.** { *; }
