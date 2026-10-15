plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 与原版 Capacitor 工程（com.setbeat.app）刻意区分：
    // 两个 APK 必须能同机并存，才能并排做 A/B 对比。
    namespace = "com.setbeat.flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 的 zonedSchedule 依赖 java.time，
        // 低版本 Android 上需要 core library desugaring 才能编译。
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.setbeat.flutter"
        // 沿用 Flutter 默认 minSdk（24）。原版 Capacitor 为 22，差异影响 < 1% 设备。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: 正式发布前换成自己的 keystore。当前沿用 debug 签名，仅用于本地验证。
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
