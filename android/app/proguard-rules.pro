# Proguard Rules for ZamZam (Shazam for Malaysian Birds)

# Flutter general rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# TensorFlow Lite JNI rules
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# FFmpeg Kit JNI rules
-keep class com.arthurhrn.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthurhrn.ffmpegkit.**
-dontwarn com.arthenica.ffmpegkit.**

# SQLite / Sqflite rules
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Record plugin rules
-keep class com.ryandens.record.** { *; }
-dontwarn com.ryandens.record.**

# Ignore Google Play Core dynamic delivery warnings
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.tasks.**
