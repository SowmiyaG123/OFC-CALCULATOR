plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must be applied after Android + Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services (for Firebase/Supabase)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.niorixtech.ofc_cal" // ✅ must match your Firebase package
    compileSdk = 36  // ✅ Android 14

    defaultConfig {
        applicationId = "com.niorixtech.ofc_cal"
        minSdk = flutter.minSdkVersion  // keep compatible with Flutter
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        debug {
            // ✅ Use existing Flutter debug signing key
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // ✅ Temporarily use debug key for release too (until you add your own keystore)
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ✅ Fix for some Flutter plugin builds
    buildFeatures {
        viewBinding = true
    }
}

flutter {
    source = "../.."
}
