// [android/build.gradle.kts] 전체 내용 교체

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // ★★★ [Pla-Y NDK 강제 설정 구역] ★★★
    // 안드로이드 플러그인이 감지되면 즉시 NDK 버전을 26으로 고정합니다.
    // (타이밍 에러와 임포트 에러를 모두 피하는 안전한 방식)
    pluginManager.withPlugin("com.android.base") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                // 강제로 ndkVersion을 "26.1.10909125"로 주입 (Reflection 사용)
                val setNdkMethod = android.javaClass.getMethod("setNdkVersion", String::class.java)
                setNdkMethod.invoke(android, "26.1.10909125")
                println("✅ [Pla-Y] ${project.name} 프로젝트의 NDK 버전을 26으로 강제 설정했습니다.")
            } catch (e: Exception) {
                println("⚠️ NDK 설정 실패 (${project.name}): $e")
            }
        }
    }
}

// 이 부분은 순서상 마지막에 두는 것이 안전합니다.
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}