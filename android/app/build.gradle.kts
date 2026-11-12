import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// `CODECORE_LITE=1` builds the flavor without yt-dlp (no Python/ffmpeg inside,
// no YouTube); pair it with `--dart-define=CODECORE_YOUTUBE=false`.
val lite = System.getenv("CODECORE_LITE") == "1"

// `CODECORE_PERF=1` installs as a separate app, com.freekmusic.player.perf, with
// its own data: the phase 28 measurements never touch the real library.
val perf = System.getenv("CODECORE_PERF") == "1"

// `CODECORE_X64=1` adds x86_64, so `flutter test integration_test -d <emulator>` finds an app to install.
val x64 = System.getenv("CODECORE_X64") == "1"

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.codecore.player"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // NewPipeExtractor uses Java 10+ APIs (URLDecoder.decode(String, Charset)) missing before API 33.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (perf) "com.freekmusic.player.perf" else "com.freekmusic.player"
        manifestPlaceholders["appLabel"] = if (perf) "FreeKmusic Perf" else "FreeKmusic"
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
        // Flutter's --split-per-abi sets its own ABI splits; filters conflict with them.
        if (!project.hasProperty("split-per-abi")) {
            ndk {
                abiFilters += listOf("arm64-v8a", "armeabi-v7a") + (if (x64) listOf("x86_64") else emptyList())
            }
        }
    }

    sourceSets["main"].java.srcDir(if (lite) "src/lite/kotlin" else "src/full/kotlin")

    packaging {
        jniLibs {
            // yt-dlp's Python and QuickJS are executed from the native lib dir.
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        create("release") {
            if (keyProps.isNotEmpty()) {
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // Personal keystore when android/key.properties exists (git-ignored).
            signingConfig = if (keyProps.isNotEmpty()) {
                signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.4")
    // yt-dlp + Python + QuickJS (JS challenge solver) embedded in the app.
    if (!lite) {
        implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
        implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
        implementation("com.github.TeamNewPipe:NewPipeExtractor:v0.26.5")
    }
}

flutter {
    source = "../.."
}
