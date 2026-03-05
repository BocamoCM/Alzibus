# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Stripe ProGuard Rules
-dontwarn com.stripe.android.**
-keep class com.stripe.android.** { *; }

# Google Play Core & GMS
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-keep class com.google.android.play.core.** { *; }

# General
-dontwarn android.util.Log
-dontwarn androidx.core.app.NotificationCompat*
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**

# Flutter TTS
-keep class com.tundez.flutter_tts.** { *; }
