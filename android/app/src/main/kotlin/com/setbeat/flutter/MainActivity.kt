package com.setbeat.flutter

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 提醒渠道要在任何通知投递之前建好。幂等，重复调用无副作用。
        SetBeatAlerts.ensureChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 返回 IANA 时区名，如 "Asia/Shanghai"，供 zonedSchedule 使用
                    "getTimeZone" -> result.success(TimeZone.getDefault().id)

                    // 直达本应用的通知设置页（横幅 / 锁屏 / 铃声开关都在那一页）
                    "openNotificationSettings" -> result.success(
                        startSettings(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        )
                    )

                    // 直达「闹钟和提醒」权限页（Android 12+）
                    "openExactAlarmSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                .setData(Uri.parse("package:$packageName"))
                        } else {
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                        }
                        result.success(startSettings(intent))
                    }

                    // 应用详情页（电池策略 / 自启动白名单在这里）
                    "openAppDetailsSettings" -> result.success(
                        startSettings(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                        )
                    )

                    // 是否已豁免电池优化。国产 ROM 上这是闹钟能不能到点触发的分水岭：
                    // 未豁免 → 应用退后台后被冻结/强杀 → AlarmManager 闹钟被系统撤销。
                    "isIgnoringBatteryOptimizations" -> result.success(
                        isIgnoringBatteryOptimizations()
                    )

                    // 弹系统对话框申请豁免电池优化（部分 ROM 会二次确认）
                    "requestIgnoreBatteryOptimizations" -> result.success(
                        requestIgnoreBatteryOptimizations()
                    )

                    // 厂商标识（小写），供 Dart 侧挑选对应的引导文案
                    "getManufacturer" -> result.success(
                        Build.MANUFACTURER.lowercase(Locale.ROOT)
                    )
                    "getBrand" -> result.success(
                        Build.BRAND.lowercase(Locale.ROOT)
                    )

                    // 直达各家 ROM 的「自启动管理」页。这是国产 ROM 三道闸里
                    // 唯一没有标准 API 的一道，只能按厂商试各自的组件名。
                    "openAutoStartSettings" -> result.success(
                        openAutoStartSettings()
                    )

                    // 直达「耗电管理 / 省电策略」页，对应 ColorOS 的
                    //「允许完全后台行为」、MIUI 的「无限制」。
                    "openPowerManagerSettings" -> result.success(
                        openPowerManagerSettings()
                    )

                    // ----------------------------------------------------------
                    // 提醒排期与投递。走自己的原生实现而不是 flutter_local_notifications，
                    // 原因见 SetBeatAlerts 的类注释：那个插件的通知 id 同时是闹钟的
                    // requestCode，无法做到「多个提醒共用一个通知槽位」。
                    // ----------------------------------------------------------

                    // alerts 是 JSON 数组：[{seq, atMs, title, body}]
                    "scheduleTimerAlerts" -> result.success(
                        SetBeatAlerts.schedule(
                            this,
                            call.argument<String>("alerts").orEmpty(),
                        )
                    )

                    "cancelTimerAlerts" -> {
                        SetBeatAlerts.cancel(this)
                        result.success(null)
                    }

                    // 系统里真实存在的闹钟数（不是本地记录）—— 应用被 force-stop
                    // 后系统会清空闹钟，这个值会如实变成 0。
                    "armedAlertCount" -> result.success(SetBeatAlerts.armedCount(this))

                    "showTestAlert" -> result.success(SetBeatAlerts.scheduleTest(this))

                    // 升级期一次性清理：收掉旧版本用插件排下的残留闹钟。
                    // 不收的话它们会在之后某个时刻补发，表现为「多条通知一起弹」。
                    "cancelLegacyAlerts" -> {
                        SetBeatAlerts.cancelLegacyScheduledAlerts(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 本应用是否在电池优化白名单里。
     *
     * 低于 Android 6.0 的设备没有电池优化这回事，一律按「已豁免」处理，
     * 免得自检面板对着老机器报一个不存在的红色警告。
     */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * 申请豁免电池优化。
     *
     * 走 ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS（会弹标准对话框），
     * 而不是直接跳设置列表页——少点三次，用户才不会中途放弃。
     * 需要 manifest 声明 REQUEST_IGNORE_BATTERY_OPTIMIZATIONS。
     *
     * 注意：国产 ROM（ColorOS / MIUI / EMUI）即使豁免了电池优化，
     * 仍可能另有「自启动」「允许后台运行」「应用速冻」三道闸，
     * 所以这里失败或成功都不能当作问题已解决，必须配合应用详情页一起检查。
     */
    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        if (isIgnoringBatteryOptimizations()) return true
        return startSettings(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:$packageName"))
        )
    }

    /**
     * 逐个尝试候选组件，命中第一个能起来的就返回。
     *
     * 刻意**不用** `packageManager.resolveActivity()` 预筛：Android 11+ 的包可见性
     * 规则下，没在 `<queries>` 里声明过的包一律解析为 null，会把本来存在的页面
     * 误判成不存在。直接 startActivity + 捕获异常反而更可靠。
     *
     * 需要说明的是：这仍然不是 100% 可靠。厂商 ROM 的组件名随版本改名、或因
     * 权限收紧而拒绝外部调用（MIUI 尤其如此）。所以每个入口都留了
     * 「应用详情页」兜底，由用户自己点进去。
     */
    private fun startFirstResolvable(candidates: List<Pair<String, String>>): Boolean {
        for ((pkg, cls) in candidates) {
            val intent = Intent()
                .setComponent(ComponentName(pkg, cls))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (startSettings(intent)) return true
        }
        return false
    }

    /** 自启动管理页。无标准 API，只能按厂商试。 */
    private fun openAutoStartSettings(): Boolean {
        if (startFirstResolvable(autoStartCandidates())) return true
        return startSettings(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
        )
    }

    /** 耗电管理 / 省电策略页。 */
    private fun openPowerManagerSettings(): Boolean {
        if (startFirstResolvable(powerManagerCandidates())) return true
        return startSettings(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
        )
    }

    private fun manufacturerKey(): String =
        (Build.MANUFACTURER + " " + Build.BRAND).lowercase(Locale.ROOT)

    private fun autoStartCandidates(): List<Pair<String, String>> {
        val m = manufacturerKey()
        return when {
            m.contains("xiaomi") || m.contains("redmi") || m.contains("poco") -> listOf(
                "com.miui.securitycenter" to
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )

            m.contains("huawei") || m.contains("honor") -> listOf(
                "com.huawei.systemmanager" to
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                "com.huawei.systemmanager" to
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                "com.hihonor.systemmanager" to
                    "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                "com.hihonor.systemmanager" to
                    "com.hihonor.systemmanager.optimize.process.ProtectActivity"
            )

            // ColorOS / realme UI / OxygenOS 共用同一套安全中心
            m.contains("oppo") || m.contains("realme") || m.contains("oneplus") -> listOf(
                "com.coloros.safecenter" to
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                "com.coloros.safecenter" to
                    "com.coloros.safecenter.startupapp.StartupAppListActivity",
                "com.oplus.safecenter" to
                    "com.oplus.safecenter.permission.startup.StartupAppListActivity",
                "com.oppo.safe" to
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                "com.oneplus.security" to
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
            )

            m.contains("vivo") || m.contains("iqoo") -> listOf(
                "com.vivo.permissionmanager" to
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.iqoo.secure" to
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                "com.iqoo.secure" to
                    "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
            )

            m.contains("samsung") -> listOf(
                "com.samsung.android.lool" to
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                "com.samsung.android.sm" to
                    "com.samsung.android.sm.ui.battery.BatteryActivity"
            )

            m.contains("meizu") -> listOf(
                "com.meizu.safe" to "com.meizu.safe.permission.SmartBGActivity",
                "com.meizu.safe" to "com.meizu.safe.security.SHOW_APPSEC"
            )

            m.contains("asus") -> listOf(
                "com.asus.mobilemanager" to
                    "com.asus.mobilemanager.powersaver.PowerSaverSettings",
                "com.asus.mobilemanager" to
                    "com.asus.mobilemanager.autostart.AutoStartActivity"
            )

            m.contains("nokia") -> listOf(
                "com.evenwell.powersaving.g3" to
                    "com.evenwell.powersaving.g3.exception.PowerSaverExceptionActivity"
            )

            m.contains("letv") -> listOf(
                "com.letv.android.letvsafe" to
                    "com.letv.android.letvsafe.AutobootManageActivity"
            )

            else -> emptyList()
        }
    }

    private fun powerManagerCandidates(): List<Pair<String, String>> {
        val m = manufacturerKey()
        return when {
            // ColorOS 的「允许完全后台行为」就在这一页
            m.contains("oppo") || m.contains("realme") || m.contains("oneplus") -> listOf(
                "com.oplus.battery" to
                    "com.oplus.powermanager.fuelgaue.PowerUsageModelActivity",
                "com.coloros.oppoguardelf" to
                    "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity",
                "com.coloros.oppoguardelf" to
                    "com.coloros.powermanager.fuelgaue.PowerConsumptionActivity"
            )

            m.contains("xiaomi") || m.contains("redmi") || m.contains("poco") -> listOf(
                "com.miui.powerkeeper" to
                    "com.miui.powerkeeper.ui.HiddenAppsContainerManagementActivity",
                "com.miui.powerkeeper" to
                    "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
            )

            m.contains("huawei") || m.contains("honor") -> listOf(
                "com.huawei.systemmanager" to
                    "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
                "com.huawei.systemmanager" to
                    "com.huawei.systemmanager.power.ui.HwPowerManagerActivity"
            )

            m.contains("vivo") || m.contains("iqoo") -> listOf(
                "com.vivo.permissionmanager" to
                    "com.vivo.permissionmanager.activity.PurviewTabActivity",
                "com.iqoo.secure" to "com.iqoo.secure.safeguard.PurviewTabActivity"
            )

            else -> emptyList()
        }
    }

    /** 启动系统设置页；失败返回 false 而不是抛异常 */
    private fun startSettings(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    private companion object {
        const val CHANNEL = "setbeat/platform"
    }
}
