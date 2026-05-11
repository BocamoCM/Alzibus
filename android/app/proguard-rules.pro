# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core & GMS
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-keep class com.google.android.play.core.** { *; }

# AdMob Mediation adapters (descomentar al activar la red)
# AppLovin
#-keep class com.applovin.** { *; }
#-dontwarn com.applovin.**
# Meta Audience Network
#-keep class com.facebook.ads.** { *; }
#-dontwarn com.facebook.ads.**
# Unity Ads
#-keep class com.unity3d.ads.** { *; }
#-keep class com.unity3d.services.** { *; }
#-dontwarn com.unity3d.**

# General
-dontwarn android.util.Log
-dontwarn androidx.core.app.NotificationCompat*
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**

# Flutter TTS
-keep class com.tundez.flutter_tts.** { *; }
