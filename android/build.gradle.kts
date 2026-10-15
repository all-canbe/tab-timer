allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ---------------------------------------------------------------------------
// 统一插件库模块的 compileSdk
//
// 背景：本机 Android SDK 只装了 android-29/35/36，且 dl.google.com 不可达、
// sdkmanager 无法联网补装。而各插件声明的 compileSdk 不一
// （如 vibration 声明 34），缺哪个平台整个构建就挂。
//
// 这里在插件工程求值结束后，把所有 com.android.library 模块的 compileSdk
// 统一改写为 36（与本工程 app 模块一致，且为当前依赖集里的最大值）。
// 向上调高是安全的：高版本 SDK 是低版本的超集，运行时行为不受影响。
//
// 用反射调用是因为根脚本的 classpath 上没有 AGP 类型，无法静态转型；
// 只在插件存在时才动它，不影响不声明 android 库的纯 Dart 包。
// ---------------------------------------------------------------------------
subprojects {
    plugins.withId("com.android.library") {
        afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            runCatching {
                val setter = androidExt::class.java.methods
                    .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
                    ?: androidExt::class.java.methods
                        .firstOrNull { it.name == "setCompileSdkVersion" && it.parameterCount == 1 }
                setter?.invoke(androidExt, 36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
