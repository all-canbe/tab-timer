package com.setbeat.flutter

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

                    else -> result.notImplemented()
                }
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
