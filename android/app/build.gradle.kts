import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kredensial signing rilis dibaca dari android/key.properties (di luar git).
// Catatan: di Kotlin DSL, `java` di scope Project menunjuk ke JavaPluginExtension,
// sehingga `java.util.Properties()` gagal ("Unresolved reference 'util'").
// Karena itu Properties/FileInputStream diimpor eksplisit di atas.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "id.pkgenerus.pkgenerus_app"
    // compileSdk 37 diperlukan oleh flutter_secure_storage 11.x (AAR metadata
    // menolak compile di bawah 37).
    //
    // Catatan lingkungan: SDK manager pada toolchain portabel memasang platform
    // ini sebagai direktori `platforms/android-37.0` dengan
    // `AndroidVersion.ApiLevel=37.0`, sementara Gradle mencari `android-37`.
    // Direktori `platforms/android-37` (ApiLevel=37) sudah disiapkan di
    // E:\hermes\tools\android-sdk; lihat docs/RANCANGAN-FLUTTER.md.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 19.x memakai API java.time lewat
        // desugaring; tanpa flag ini build release gagal pada minSdk < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.pkgenerus.pkgenerus_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Diisi hanya bila android/key.properties tersedia; kalau tidak,
            // biarkan kosong agar `flutter build apk --debug` tetap bisa jalan.
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // APK rilis WAJIB ditandatangani keystore sendiri. Tanpa
            // key.properties build release gagal cepat, bukan diam-diam
            // memakai kunci debug (APK debug tidak boleh dibagikan ke publik).
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "android/key.properties tidak ditemukan. " +
                        "Build release butuh keystore rilis; lihat docs/mobile-release.md."
                )
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

dependencies {
    // Dibutuhkan oleh isCoreLibraryDesugaringEnabled di atas.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
