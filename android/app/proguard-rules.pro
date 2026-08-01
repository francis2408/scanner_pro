# Proguard rules for Scanner Pro binary size optimization & code shrinking

-keep class com.google.mlkit.** { *; }
-keep class androidx.camera.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**
