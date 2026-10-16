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
// ---------------------------------------------------------------------------
// 统一插件库模块的 compileSdk（第二版 —— 第一版从来没生效过）
//
// ## 要解决什么问题
//
// 本机 SDK 的 `platforms/android-35` 是一个**残缺安装**：目录在、package.xml 在，
// 但**没有 android.jar**。任何声明 `compileSdk 35` 的插件都会在
// `:<plugin>:compileDebugJavaWithJavac` 上报：
//
//     Cannot query the value of this provider because it has no value available.
//
// 这句话完全看不出跟 SDK 有关，实际根因是 AGP 拿不到 bootclasspath。
// flutter_foreground_task 11.0.3 正是声明 `compileSdk 35` 的插件，
// 一装上就让整个构建挂掉。
//
// 绕开办法：把所有库模块统一抬到本机**真正可用**的最高平台。
// 向上调高是安全的 —— 高版本 SDK 是低版本的超集，运行时行为不受影响。
//
// ## 为什么必须重写
//
// 第一版挂在 `afterEvaluate` 上，AGP 9 会抛：
//
//     AgpDslLockedException: It is too late to set compileSdk
//
// 而外层 `runCatching` 把它吞了 —— 于是「改了，但一次都没生效」，
// 而且没有任何日志。之所以一直没人发现，是既有插件恰好都声明了本机完整的
// 平台（24/34/36），从来不需要这段逻辑。直到新插件撞上残缺的 35 才暴露。
//
// 教训写在这里：**沉默的兜底比不兜底更危险**。第二版做了三件事：
//   1. 挂到 `androidComponents.finalizeDsl` —— AGP 提供的、锁 DSL 之前
//      唯一的正式回调点；
//   2. 目标平台**逐个校验 android.jar 是否存在**，不只看目录名，
//      否则会选中同一个残缺平台；
//   3. 任何异常/跳过都打日志，绝不再静默。
// ---------------------------------------------------------------------------

/// 选出本机**真正可用**的最高平台号。
///
/// 「真正可用」= 目录名下存在 `android.jar`。只看目录名会踩到残缺安装 ——
/// 本机的 android-35 就是这种。
fun resolveAvailableCompileSdk(): Int? {
    val props = java.util.Properties()
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        localProps.inputStream().use { props.load(it) }
    }
    val sdkDir = listOf(
        props.getProperty("sdk.dir"),
        System.getenv("ANDROID_HOME"),
        System.getenv("ANDROID_SDK_ROOT"),
    ).firstOrNull { !it.isNullOrBlank() } ?: return null

    val platforms = File(sdkDir, "platforms")
    if (!platforms.isDirectory) return null

    return platforms.listFiles()
        ?.asSequence()
        ?.filter { it.isDirectory }
        ?.mapNotNull { dir ->
            // 只认 android-<纯数字>，排除 android-36.1 / 预览版这类
            val level = Regex("""^android-(\d+)$""")
                .find(dir.name)
                ?.groupValues
                ?.get(1)
                ?.toIntOrNull()
            level?.takeIf { File(dir, "android.jar").isFile }
        }
        ?.maxOrNull()
}

/// 把 [module] 的 compileSdk 抬到 [target]（只在当前值更低时动手）。
///
/// 全程反射：根脚本的 classpath 上没有 AGP 类型，无法静态转型。
fun unifyCompileSdk(module: Project, target: Int) {
    val components = module.extensions.findByName("androidComponents")
    if (components == null) {
        module.logger.info("[compileSdk] ${module.path} 没有 androidComponents，跳过")
        return
    }

    // finalizeDsl 有三个重载（Groovy Closure / Kotlin Function1 / Gradle Action）。
    // 只有 Function1 那个能直接 invoke，传另外两种都会 argument type mismatch。
    val finalizeDsl = components::class.java.methods.firstOrNull {
        it.name == "finalizeDsl" &&
            it.parameterCount == 1 &&
            it.parameterTypes[0].name == "kotlin.jvm.functions.Function1"
    }
    if (finalizeDsl == null) {
        module.logger.warn("[compileSdk] ${module.path} 找不到 finalizeDsl(Function1) 重载")
        return
    }

    val callback = object : kotlin.jvm.functions.Function1<Any, Unit> {
        override fun invoke(extension: Any) {
            val cls = extension::class.java
            val current = runCatching {
                cls.methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
                    ?.invoke(extension) as? Int
            }.getOrNull()

            if (current != null && current >= target) return

            val setter = cls.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterCount == 1 &&
                    (it.parameterTypes[0] == Integer::class.java ||
                        it.parameterTypes[0] == Int::class.javaPrimitiveType)
            }
            if (setter == null) {
                module.logger.warn("[compileSdk] ${module.path} 找不到可用的 setCompileSdk")
                return
            }
            runCatching { setter.invoke(extension, target) }
                .onSuccess {
                    module.logger.lifecycle("[compileSdk] ${module.path}: $current -> $target")
                }
                .onFailure {
                    module.logger.warn("[compileSdk] ${module.path} 调整失败: ${it.cause ?: it}")
                }
        }
    }

    runCatching { finalizeDsl.invoke(components, callback) }
        .onFailure {
            module.logger.warn(
                "[compileSdk] ${module.path} 注册 finalizeDsl 失败: ${it.cause ?: it}",
            )
        }
}

subprojects {
    val module = this
    plugins.withId("com.android.library") {
        val target = resolveAvailableCompileSdk() ?: 36
        unifyCompileSdk(module, target)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
