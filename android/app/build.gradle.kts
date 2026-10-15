import java.io.File
import java.io.FileInputStream
import java.security.KeyStore
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ddemart.dde_vendor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ddemart.dde_vendor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties["storeFile"] as String
                // storeFile in key.properties is conventionally relative to
                // the app module dir (e.g. ../hometry-upload-key.jks).
                // Try app dir, then android dir, then Flutter root.
                val candidates = listOf(
                    file(storeFilePath),
                    rootProject.file(storeFilePath),
                    rootProject.projectDir.parentFile?.let { File(it, storeFilePath) },
                ).filterNotNull()
                val resolvedStoreFile = candidates.firstOrNull { it.exists() }
                    ?: file(storeFilePath)
                val alias = keystoreProperties["keyAlias"] as String
                val storePass = keystoreProperties["storePassword"] as String
                val keyPass = keystoreProperties["keyPassword"] as String
                // Fall back to the store password when the configured key
                // password cannot unlock the key (keeps existing keystores
                // building without touching key.properties).
                val effectiveKeyPass = try {
                    val ks = KeyStore.getInstance(resolvedStoreFile, storePass.toCharArray())
                    try {
                        ks.getKey(alias, keyPass.toCharArray())
                        keyPass
                    } catch (_: Exception) {
                        storePass
                    }
                } catch (_: Exception) {
                    keyPass
                }
                storeFile = resolvedStoreFile
                keyAlias = alias
                keyPassword = effectiveKeyPass
                storePassword = storePass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    // Required by flutter_local_notifications (Java 8+ APIs on older runtimes).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
