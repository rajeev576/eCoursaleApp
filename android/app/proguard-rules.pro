# Razorpay Flutter SDK — keep its classes so release (R8/ProGuard) builds don't
# strip the payment classes. Required by razorpay_flutter.
-keep class com.razorpay.** { *; }
-keep class proguard.annotation.** { *; }
-dontwarn com.razorpay.**
-dontwarn proguard.annotation.**
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
