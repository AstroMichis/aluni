# Hotwire Native
-keep class dev.hotwire.** { *; }

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class us.aluni.**$$serializer { *; }
-keepclassmembers class us.aluni.** { *** Companion; }
-keepclasseswithmembers class us.aluni.** { kotlinx.serialization.KSerializer serializer(...); }
