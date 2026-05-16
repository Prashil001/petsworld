# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Razorpay — keep all classes to avoid payment flow crashes
-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# image_picker / Glide
-keep class com.bumptech.glide.** { *; }

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep R fields (required for resource resolution)
-keep class **.R$* {
    public static <fields>;
}

# Strip verbose logs in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
