plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.desertstorm.desertstorm"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ Use Java 11 (matches your current setup)
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // ✅ Enable desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.desertstorm.desertstorm"

        // 👇 Flutter requires minSdk >= 24
        minSdk = 26
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.tensorflow:tensorflow-lite:2.15.0")
// Core TFLite
    implementation("org.tensorflow:tensorflow-lite-select-tf-ops:2.15.0")
    // TensorFlow Lite GPU
    implementation("org.tensorflow:tensorflow-lite-gpu-api:+")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.15.0")

    // ✅ Updated desugaring libs required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

apply(plugin = "com.google.gms.google-services")