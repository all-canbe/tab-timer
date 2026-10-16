package com.setbeat.flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 提醒闹钟的接收器。
 *
 * 由 [SetBeatAlerts] 用 `AlarmManager.setExactAndAllowWhileIdle` 排期，
 * 到点由**系统**触发 —— 与 App 进程是否存活无关。这是计时器类应用唯一可靠的
 * 提醒方式：不要指望自己的进程活着，要指望系统闹钟准时。
 *
 * 这里刻意只做两件事：
 *
 * 1. **投递通知**。所有阶段提醒都用同一个 id（[SetBeatAlerts.NOTIFICATION_ID]），
 *    所以后到的会顶掉先到的 —— 通知栏里永远只有一条「最近的提醒」，
 *    不会堆成一摞。
 * 2. **结束提醒顺带收掉常驻通知**。否则用户会同时看到两条「训练完成」：
 *    一条来自常驻通知（计时状态被渲染成完成态），一条来自刚触发的结束提醒。
 *
 * 全部在原生侧完成，**不依赖 Dart 进程是否存活** —— 这是它比在 App 内
 * 投递通知可靠的根本原因。
 */
class SetBeatAlertReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != SetBeatAlerts.ACTION_FIRE) return

        val title = intent.getStringExtra(SetBeatAlerts.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(SetBeatAlerts.EXTRA_BODY).orEmpty()
        val notificationId = intent.getIntExtra(
            SetBeatAlerts.EXTRA_NOTIFICATION_ID,
            SetBeatAlerts.NOTIFICATION_ID,
        )

        SetBeatAlerts.post(context, notificationId, title, body)

        if (intent.getBooleanExtra(SetBeatAlerts.EXTRA_FINAL, false)) {
            SetBeatAlerts.stopTimerForegroundService(context)
        }
    }
}
