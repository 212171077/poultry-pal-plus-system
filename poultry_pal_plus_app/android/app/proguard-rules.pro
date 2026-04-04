# Keep error-prone annotations
-keep class com.google.errorprone.annotations.** { *; }

# Keep javax.annotation classes
-keep class javax.annotation.** { *; }

# Prevent R8 from removing these classes
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
