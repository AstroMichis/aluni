plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "us.aluni"
    compileSdk = 35

    defaultConfig {
        applicationId = "us.aluni.app"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        buildConfigField("String", "BASE_URL", "\"https://aluni.us\"")
    }

    buildTypes {
        debug {
            // Local Rails: run `adb reverse tcp:3000 tcp:3000` so the device's
            // localhost:3000 reaches the Mac. localhost (not 10.0.2.2) because
            // passkeys need a secure context and only localhost is exempt.
            buildConfigField("String", "BASE_URL", "\"http://localhost:3000\"")
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(libs.hotwire.core)
    implementation(libs.hotwire.navigation.fragments)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.material)
    implementation(libs.androidx.webkit)
    // Compiles without Firebase; FCM only works once google-services.json exists.
    implementation(libs.firebase.messaging)
}

// Apply Google services only when app/google-services.json exists (a free
// Firebase project); until then the app builds and FCM simply has no token.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
