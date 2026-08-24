import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    /*
     * PowerShell 5 may write UTF-8 text with a BOM. Read the file as UTF-8,
     * remove that BOM when present, then parse the properties through a Reader.
     */
    val keyPropertiesText =
        keystorePropertiesFile
            .readText(Charsets.UTF_8)
            .removePrefix("\uFEFF")

    keystoreProperties.load(keyPropertiesText.reader())
}

val releaseKeyAlias =
    keystoreProperties.getProperty("keyAlias")?.trim()

val releaseKeyPassword =
    keystoreProperties.getProperty("keyPassword")

val releaseStoreFile =
    keystoreProperties.getProperty("storeFile")?.trim()

val releaseStorePassword =
    keystoreProperties.getProperty("storePassword")

val hasReleaseSigningProperties =
    !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank() &&
        !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank()

android {
    namespace = "ph.tabangnow.dao"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ph.tabangnow.dao"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        /*
         * Release signing exists only when ALL private values are valid.
         * Debug builds remain completely independent of release credentials.
         */
        if (hasReleaseSigningProperties) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile?.let { file(it) }
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            /*
             * Never fall back to the Android debug certificate for a
             * distributable TabangNow APK.
             *
             * tool/build_android_release.ps1 refuses to build unless the
             * private release signing configuration is present.
             */
            if (hasReleaseSigningProperties) {
                signingConfig = signingConfigs.getByName("release")
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
