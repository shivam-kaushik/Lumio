import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "io.lumio.app"
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
    // Try multiple sources: .env file, environment variables, gradle properties, local.properties
    
    // 1. Try reading from .env file (root directory)
    fun readEnvFile(): String? {
        val envFile = rootProject.file("../.env")
        if (envFile.exists()) {
            try {
                envFile.readLines().forEach { line ->
                    val trimmed = line.trim()
                    if (trimmed.startsWith("GOOGLE_MAPS_API_KEY=") && !trimmed.startsWith("#")) {
                        val value = trimmed.substringAfter("=").trim()
                        if (value.isNotEmpty()) {
                            println("✅ Found GOOGLE_MAPS_API_KEY in .env file")
                            return value
                        }
                    }
                }
            } catch (e: Exception) {
                println("⚠️ Error reading .env file: ${e.message}")
            }
        }
        return null
    }
    
    // Load keystore properties for release signing
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    val localProperties = Properties().apply {
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use(::load)
        }
    }

    val mapsKey: String? = readEnvFile()
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: project.findProperty("GOOGLE_MAPS_API_KEY") as String?
        ?: project.findProperty("MAPS_API_KEY") as String?
        ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: localProperties.getProperty("MAPS_API_KEY")

    if (mapsKey.isNullOrBlank()) {
        println(
            "⚠️  WARNING: GOOGLE_MAPS_API_KEY is not set. " +
            "Add it to .env file, local.properties, gradle.properties, or your environment " +
            "to enable Google Maps tiles."
        )
    } else {
        println("✅ GOOGLE_MAPS_API_KEY found (length: ${mapsKey.length})")
    }

    defaultConfig {
        // Application ID for Play Store
        applicationId = "io.lumio.app"
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

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            // Use release signing if keystore is configured, otherwise fall back to debug
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
    
    // Disable lint checks to avoid memory issues during release builds
    lint {
        checkReleaseBuilds = false
        abortOnError = false
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
