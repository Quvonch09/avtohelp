import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "uz.avtohelp.master_help"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "uz.avtohelp.master_help"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["googleMapsApiKey"] = (project.findProperty("GOOGLE_MAPS_API_KEY") ?: System.getenv("GOOGLE_MAPS_API_KEY") ?: "") as String
    }

    signingConfigs {
        create("release") {
            enableV1Signing = true
            enableV2Signing = true
            val keystoreInApp = file("avtohelp-release.jks")
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties.getProperty("keyAlias") ?: "avtohelp"
                keyPassword = keyProperties.getProperty("keyPassword") ?: "avtohelp2024"
                storePassword = keyProperties.getProperty("storePassword") ?: "avtohelp2024"
                val propStore = keyProperties.getProperty("storeFile") ?: "avtohelp-release.jks"
                storeFile = if (file(propStore).exists()) {
                    file(propStore)
                } else if (rootProject.file("app/$propStore").exists()) {
                    rootProject.file("app/$propStore")
                } else {
                    file("avtohelp-release.jks")
                }
            } else if (keystoreInApp.exists()) {
                keyAlias = "avtohelp"
                keyPassword = "avtohelp2024"
                storePassword = "avtohelp2024"
                storeFile = keystoreInApp
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            if (releaseSigning != null && releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                signingConfig = releaseSigning
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
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
