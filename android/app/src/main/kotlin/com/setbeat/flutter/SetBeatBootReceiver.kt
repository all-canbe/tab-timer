package com.setbeat.flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 开机 / 应用更新后重新武装提醒。
 *
 * 系统在重启时会清空 AlarmManager 里**全部**闹钟（这是 AOSP 行为，
 * 不是厂商限制），不重新排一次的话，用户重启手机后所有提醒就没了。
 *
 * [SetBeatAlerts.rearm] 会丢掉已经过期的那些，不会补发一串过去的提醒。
 *
 * 注意：应用被用户手动 force-stop 之后，这个接收器**不会**被触发 ——
 * 那是系统的设计，任何应用都绕不过去。对应的用户侧解法是把应用加进
 * 厂商 ROM 的「自启动」白名单，自检面板里有直达入口。
 */
class SetBeatBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            // 部分 HTC / 老机型用这个私有 action 代替 BOOT_COMPLETED
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> SetBeatAlerts.rearm(context)
        }
    }
}
