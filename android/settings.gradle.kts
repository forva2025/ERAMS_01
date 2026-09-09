pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Downgraded from 9.0.1: AGP 9.x enforces a strict per-artifact namespace
    // uniqueness check that Agora's native SDK (4.5.2) fails, since its many
    // capability modules (core RTC engine included) all share the legacy
    // manifest package "io.agora.rtc". AGP 8.13 is the last pre-9.0 release
    // and predates this stricter validation.
    id("com.android.application") version "8.13.2" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
