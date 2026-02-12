plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
}

android {
    // Match your existing Kotlin package folder: com/example/stylebridge_ai
    namespace = "com.example.stylebridge_ai"

    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.stylebridge_ai"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
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
    // Flutter handles Firebase packages via pubspec.yaml
}
