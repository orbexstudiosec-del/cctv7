import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de subida a Google Play (android/key.properties +
// android/upload-keystore.jks, ambos fuera de git -- ver android/.gitignore).
// Si se pierde, NO se pueden publicar actualizaciones sin pedirle a Google
// un reseteo de la clave de subida: hay que tenerla respaldada.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.orbexstudios.cctvcanal7"
    // compileSdk solo decide contra qué APIs compila (no afecta qué
    // dispositivos pueden instalar el APK — eso es targetSdk/minSdk, abajo).
    // Varios plugins (video_player_android, package_info_plus, wakelock_plus)
    // ya requieren 36, así que queda en flutter.compileSdkVersion.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        // Google Play exige API 36 (Android 16) para apps nuevas y
        // actualizaciones desde el 31/08/2026. Con 36, edge-to-edge es
        // obligatorio (la app ya lo usa) y en pantallas grandes se ignoran
        // las restricciones de orientación.
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Con key.properties presente firma con la clave de subida a Play;
            // sin él (otra máquina, CI) cae a debug para que el build local
            // no se rompa -- pero ese AAB Play lo rechaza.
            signingConfig = signingConfigs.findByName("upload")
                ?: signingConfigs.getByName("debug")
        }
    }

    // Un flavor = un build de la app (su propio applicationId, nombre de
    // app y google-services.json). Ver lib/flavors.dart.
    flavorDimensions += "cliente"
    productFlavors {
        create("canal7") {
            dimension = "cliente"
            applicationId = "com.orbexstudios.cctvcanal7"
            resValue("string", "app_name", "CCTV CANAL 7")
        }
        // App separada para Android TV/Google TV: mismo tenant, applicationId
        // propio para poder convivir instalada junto a la de celular. Ver
        // src/canal7tv/AndroidManifest.xml (Leanback, banner, horizontal
        // forzado) y lib/main_canal7_tv.dart (pantalla solo-reproductor).
        create("canal7tv") {
            dimension = "cliente"
            applicationId = "com.orbexstudios.cctvcanal7.tv"
            resValue("string", "app_name", "CCTV CANAL 7")
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
