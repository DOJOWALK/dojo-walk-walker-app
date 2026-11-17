plugins {
    id("com.google.gms.google-services")
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val walkerKeystoreFile = System.getenv("WALKER_KEYSTORE_FILE")
val walkerKeystorePassword = System.getenv("WALKER_KEYSTORE_PASSWORD")
val walkerKeyAlias = System.getenv("WALKER_KEY_ALIAS")
val walkerKeyPassword = System.getenv("WALKER_KEY_PASSWORD")
val hasWalkerReleaseSigning = listOf(
    walkerKeystoreFile,
    walkerKeystorePassword,
    walkerKeyAlias,
    walkerKeyPassword
).all { !it.isNullOrBlank() }

android {
    namespace = "com.example.dojo_partner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.dojo_partner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasWalkerReleaseSigning) {
            create("walkerRelease") {
                storeFile = file(walkerKeystoreFile!!)
                storePassword = walkerKeystorePassword
                keyAlias = walkerKeyAlias
                keyPassword = walkerKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // CI may use the debug key for non-distributable test builds.
            // The dedicated signed-release workflow supplies all four secrets.
            signingConfig = if (hasWalkerReleaseSigning) {
                signingConfigs.getByName("walkerRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
