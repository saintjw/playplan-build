import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.geek.playplan"
    compileSdk = flutter.compileSdkVersion

    // [중요] 윈도우 전용 ndkPath("C:\\ndk")를 삭제했습니다.
    // 깃허브 서버가 스스로 NDK를 찾도록 비워두는 것이 정답입니다.
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            // GitHub Secrets에서 넣어준 값을 key.properties를 통해 읽어옵니다.
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.geek.playplan"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // 릴리즈 빌드 시 위에서 설정한 서명(signingConfigs)을 사용합니다.
            signingConfig = signingConfigs.getByName("release")
            
            // 난독화 및 최적화 설정 (필요 시 true로 변경 가능)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}