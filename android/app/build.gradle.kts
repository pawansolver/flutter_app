import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()Executing (default): SHOW INDEX FROM `email_otps`
Executing (default): SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_NAME = 'refresh_tokens' AND TABLE_SCHEMA = 'u963801592_SmartGali'
Executing (default): SHOW INDEX FROM `refresh_tokens`
Models synchronized.
Redis pubClient error: connect ECONNREFUSED 127.0.0.1:6379
Redis subClient error: connect ECONNREFUSED 127.0.0.1:6379
Redis cacheClient error: connect ECONNREFUSED 127.0.0.1:6379
âš ï¸  Redis unavailable (Connection is closed.). Falling back to in-process mode. Multi-instance scaling will NOT work.
⚠️  Socket.IO emitter: Redis unavailable — worker emits will not reach API clients
Uncaught Exception: listen EADDRINUSE: address already in use 0.0.0.0:5000
[nodemon] clean exit - waiting for changes before restart

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
android {
    namespace = "com.nighwantech.smartgali"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

   defaultConfig {
        applicationId = "com.nighwantech.smartgali"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            val storeFileProperty = keystoreProperties.getProperty("storeFile")
            if (storeFileProperty != null) {
                storeFile = file(storeFileProperty)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
