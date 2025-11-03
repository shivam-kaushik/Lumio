plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.awarely"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Updated Java version (Fixes obsolete warning)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Match Java version for consistency
        jvmTarget = "17"
    }

    // Provide Google Maps API key to AndroidManifest via placeholders
    val mapsKey: String? = System.getenv("GOOGLE_MAPS_API_KEY")
        ?: project.findProperty("GOOGLE_MAPS_API_KEY") as String?
        ?: project.findProperty("MAPS_API_KEY") as String?

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.awarely"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Inject placeholder for AndroidManifest.xml meta-data
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsKey ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Core library desugaring (provides java.time and other JDK APIs on older devices)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    
    // Google Maps for Android
    implementation("com.google.android.gms:play-services-maps:18.2.0")
}

flutter {
    source = "../.."
}
