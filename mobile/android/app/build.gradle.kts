import java.io.File

fun incrementPubspecVersion() {
    val pubspecFile = File(projectDir, "../../pubspec.yaml")
    if (!pubspecFile.exists()) {
        println("pubspec.yaml not found at ${pubspecFile.absolutePath}")
        return
    }

    val lines = pubspecFile.readLines()
    var currentVersionCode = 1
    var currentVersionName = "1.0.0"
    var newVersionCode = 2

    val updatedLines = lines.map { line ->
        if (line.trim().startsWith("version:")) {
            val parts = line.split(":")
            if (parts.size == 2) {
                val versionStr = parts[1].trim()
                val versionParts = versionStr.split("+")
                if (versionParts.size == 2) {
                    val versionName = versionParts[0]
                    val versionCode = versionParts[1].toIntOrNull() ?: 1
                    currentVersionCode = versionCode
                    currentVersionName = versionName
                    newVersionCode = versionCode + 1
                    println("Auto-incrementing app version: $versionStr -> $versionName+$newVersionCode")
                    "version: $versionName+$newVersionCode"
                } else {
                    line
                }
            } else {
                line
            }
        } else {
            line
        }
    }
    pubspecFile.writeText(updatedLines.joinToString("\n"))

    // Write the actual compiled versionCode to the backend's version.json
    val versionJsonFile = File(projectDir, "../../../backend/public/version.json")
    if (versionJsonFile.exists()) {
        println("Syncing compiled version code $newVersionCode to backend version.json")
        versionJsonFile.writeText("""{
  "versionCode": $newVersionCode,
  "versionName": "$currentVersionName",
  "isMandatory": true
}
""")
    }
}

val runTasks = gradle.startParameter.taskNames
val isBuildTask = runTasks.any { task ->
    task.contains("assemble", ignoreCase = true) ||
    task.contains("bundle", ignoreCase = true) ||
    task.contains("build", ignoreCase = true)
}
if (isBuildTask) {
    try {
        incrementPubspecVersion()
    } catch (e: Exception) {
        println("Failed to auto-increment version: ${e.message}")
    }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chess.betting.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.chess.betting.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
