plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    
}

apply(plugin = "com.google.gms.google-services")

android {
    namespace = "com.example.explore_easy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17  // Updated to 17
        targetCompatibility = JavaVersion.VERSION_17  // Updated to 17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()  // Updated to 17
    }

    defaultConfig {
        applicationId = "com.example.explore_easy"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-firestore")
}