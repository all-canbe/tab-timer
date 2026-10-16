package com.setbeat.flutter

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray

/**
 * 计时提醒的调度与投递 —— **全原生，不经 Dart**。
 *
 * ## 为什么要自己写，不用 flutter_local_notifications
 *
 * 因为那个插件的公开 API 里，**通知 id 同时就是 AlarmManager 的 requestCode**
 * （见 FlutterLocalNotificationsPlugin.zonedScheduleNotification：
 * `getBroadcastPendingIntent(context, notificationDetails.id, intent)`，
 * 而该 Intent 除了 extras 之外没有任何唯一标识）。后果：
 *
 *   · 想让多个提醒「共用一个通知槽位、新的顶掉旧的」→ 必须用同一个 id
 *     → requestCode 相同 + Intent filterEquals 相同 → PendingIntent 被判等
 *     → AlarmManager 只保留最后一个闹钟，**前面的提醒全部丢失**。
 *
 * 也就是说：在插件的公开 API 下，「一个槽位」和「每个边界都触发」
 * 是**互斥**的。要两者兼得，只能把通知 id 与闹钟 requestCode 解耦 —— 自己排。
 *
 * ## 顺带修掉的第二个隐患
 *
 * 插件用自己的一份 SharedPreferences 缓存来记录「排了哪些通知」，
 * `cancelAllPendingNotifications()` 是**照着缓存取消**的。缓存一旦失准
 * （反复重装、force-stop、进程被杀），旧闹钟就永久赖在系统里，
 * 之后某个时刻被 Doze / 冻结解除后的补发一次性全部投递 ——
 * 用户看到的就是「好几条通知同时弹出来」。
 *
 * 这里改成：requestCode 由固定的序号推导，取消时**直接问系统**
 * （`FLAG_NO_CREATE` 探测），不依赖任何本地记录。缓存失准无从谈起。
 *
 * ## 槽位划分
 *
 *   · [NOTIFICATION_ID]      —— 所有阶段提醒共用。新的顶掉旧的。
 *   · [TEST_NOTIFICATION_ID] —— 提醒测试专用，不去顶真实提醒。
 *   · [REQUEST_BASE] + 序号  —— 闹钟 requestCode，逐一独立，互不覆盖。
 */
object SetBeatAlerts {

    const val CHANNEL_ID = "setbeat_timer_alerts"
    const val CHANNEL_NAME = "计时提醒"
    const val CHANNEL_DESCRIPTION = "训练计时器的阶段切换与结束提醒"

    /** 阶段提醒共用的通知槽位。固定 id ⇒ 新的一条顶掉上一条。 */
    const val NOTIFICATION_ID = 0x5E7B0001

    /** 「提醒测试」专用槽位，与真实提醒互不干扰。 */
    const val TEST_NOTIFICATION_ID = 0x5E7B0FFF

    /**
     * 闹钟 requestCode 基址。**必须与通知 id 分开**，这是整个类的存在意义。
     * 取值避开 [NOTIFICATION_ID] 与 flutter_foreground_task 的服务 id。
     */
    private const val REQUEST_BASE = 0x5E7B2000

    /** 序号上限。与 Dart 侧 `upcomingBoundaries(maxItems)` 的量级保持一致。 */
    const val MAX_ALERTS = 64

    const val ACTION_FIRE = "com.setbeat.flutter.action.ALERT_FIRE"
    const val ACTION_URI_PREFIX = "setbeat://alert/"

    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_NOTIFICATION_ID = "notificationId"

    /** 是否是「整段计时结束」的那一条。是的话投递后顺带停掉常驻通知。 */
    const val EXTRA_FINAL = "isFinal"

    private const val PREFS = "setbeat_alerts_store"
    private const val KEY_PENDING = "pending_alerts"

    /** 品牌橙。与 App 主题一致。 */
    private const val ACCENT = 0xFFFF6B35.toInt()

    // ------------------------------------------------------------------ 渠道

    /**
     * 建立提醒渠道并设为 HIGH 重要性 —— 这是「悬浮提醒（heads-up）」的前提。
     *
     * 渠道属性**创建后不可改**：如果用户设备上早已存在同名渠道（由旧版本的
     * flutter_local_notifications 建过），这里的设置不会生效，用户此前的
     * 重要性 / 铃声选择会被保留。这正是我们想要的行为 —— 升级不该重置用户设置。
     */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = CHANNEL_DESCRIPTION
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 400, 150, 400)
            enableLights(true)
            lightColor = ACCENT
            // 阶段提醒**应该**计入桌面角标：它是「有新事情发生」的信号。
            // 与常驻通知渠道（showBadge=false）刻意区分开。
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    // ------------------------------------------------------------------ 排期

    /**
     * 用 [alertsJson] 替换当前全部排期。
     *
     * JSON 形如：
     * ```
     * [{"seq":0,"atMs":1800000060000,"title":"训练完成","body":"..."}]
     * ```
     * `seq` 决定 requestCode，必须稳定 —— 恢复（rearm）时靠它找回同一个闹钟。
     *
     * 语义是「**整体替换**」而非追加：进来先无条件清空，杜绝任何形式的叠加。
     */
    fun schedule(context: Context, alertsJson: String): Boolean = try {
        ensureChannel(context)
        cancel(context)

        val array = JSONArray(alertsJson)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var armed = 0

        for (i in 0 until minOf(array.length(), MAX_ALERTS)) {
            val item = array.optJSONObject(i) ?: continue
            val atMs = item.optLong("atMs", 0L)
            // 已经过去的时刻不排 —— AlarmManager 收到过去时间会立刻触发，
            // 那才是真正意义上的「好几条一起弹」。
            if (atMs <= now) continue

            val seq = item.optInt("seq", i)
            val intent = fireIntent(
                context = context,
                seq = seq,
                title = item.optString("title", "SetBeat 计时提醒"),
                body = item.optString("body", ""),
                notificationId = NOTIFICATION_ID,
                isFinal = item.optBoolean("isFinal", false),
            )
            val pending = PendingIntent.getBroadcast(
                context,
                REQUEST_BASE + seq,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            armAlarm(alarmManager, atMs, pending)
            armed++
        }

        // 落盘一份，供重启后重新武装。
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING, alertsJson)
            .apply()
        armed > 0
    } catch (e: Exception) {
        false
    }

    /**
     * 「提醒测试」：3 秒后弹一条，走与真实提醒**完全相同**的排期与投递路径。
     *
     * 唯一区别是 requestCode 与通知槽位都独立，既不会顶掉真实提醒，
     * 也不会被 [cancel] 顺手清掉。这是「弹不出来」问题的终极自证手段：
     * 能看到它 → 链路正常；看不到 → 问题在系统通知设置或后台策略。
     */
    fun scheduleTest(context: Context): Boolean = try {
        ensureChannel(context)
        val seq = MAX_ALERTS
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_BASE + seq,
            fireIntent(
                context = context,
                seq = seq,
                title = "提醒测试",
                body = "看到这条说明系统提醒链路正常",
                notificationId = TEST_NOTIFICATION_ID,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        armAlarm(alarmManager, System.currentTimeMillis() + 3_000L, pending)
        true
    } catch (e: Exception) {
        false
    }

    /**
     * 取消全部排期。
     *
     * 关键：**逐个问系统要 PendingIntent**（`FLAG_NO_CREATE`），而不是照本地记录取消。
     * 本地记录一旦与实际不一致，照记录取消就会漏掉真正的闹钟。
     */
    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (seq in 0 until MAX_ALERTS) {
            val probe = PendingIntent.getBroadcast(
                context,
                REQUEST_BASE + seq,
                fireIntent(context, seq, null, null, NOTIFICATION_ID),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            ) ?: continue
            alarmManager.cancel(probe)
            probe.cancel()
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PENDING)
            .apply()
    }

    /**
     * 清掉**旧版本用 flutter_local_notifications 排下的**残留闹钟。
     *
     * 为什么需要这一步：旧版把提醒交给插件排期，那些闹钟此刻真实存在于系统中。
     * 升级后它们不会被新代码管理，但到点照样触发 —— 用户会莫名收到一条
     * 「训练完成」。更糟的是多次测试积累下来，几条一起补发，看起来像竞态。
     *
     * 实现上直接按插件的形状重建 PendingIntent：它的 requestCode 就是通知 id,
     * 而 Intent 里除 extras 外没有任何标识，所以「无 action、无 data、指定组件」
     * 就能和它对上（filterEquals 只比较 action / data / type / class / categories）。
     *
     * 这一条是**升级期的临时清理**，等旧版本用户升级完就可以删掉 —— 那时不会
     * 再有插件排下的闹钟存在。耦合了插件内部约定，所以单独标出来。
     */
    fun cancelLegacyScheduledAlerts(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // 旧实现的 id 基数，见上一版 NotificationService._baseId
        val legacyBaseId = 0x5E7B0000
        for (slot in 0 until MAX_ALERTS) {
            val id = legacyBaseId + slot
            val intent = Intent().setClassName(
                context,
                "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
            )
            val probe = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            ) ?: continue
            alarmManager.cancel(probe)
            probe.cancel()
        }
    }

    /**
     * 重启 / 应用更新后重新武装仍然有效的提醒。
     *
     * 丢掉已过期的那些：设备重启期间计时早就结束了，补发一串过去的提醒
     * 纯属骚扰。
     */
    fun rearm(context: Context) {
        val saved = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_PENDING, null) ?: return
        schedule(context, saved)
    }

    /**
     * 系统里**真实存在**的闹钟数量。
     *
     * 与旧实现（读插件的本地记录）的根本差别：这个数字是问系统要的，
     * 应用被 force-stop 后系统清空了闹钟，它会如实返回 0。
     * 用它做「排期到底成没成」的判断不会得到假阳性。
     */
    fun armedCount(context: Context): Int {
        var count = 0
        for (seq in 0 until MAX_ALERTS) {
            val probe = PendingIntent.getBroadcast(
                context,
                REQUEST_BASE + seq,
                fireIntent(context, seq, null, null, NOTIFICATION_ID),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (probe != null) count++
        }
        return count
    }

    // ------------------------------------------------------------------ 投递

    /** 投递一条通知。同一个 [id] 的调用会互相顶掉。 */
    fun post(context: Context, id: Int, title: String, body: String) {
        ensureChannel(context)
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return

        val openApp = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_setbeat)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setColor(ACCENT)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setTicker("SetBeat 计时提醒")
            .setVibrate(longArrayOf(0, 400, 150, 400))
            .setLights(ACCENT, 400, 150)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build()

        try {
            // 固定 id：这就是「新的顶掉旧的」的全部实现。
            manager.notify(id, notification)
        } catch (_: SecurityException) {
            // Android 13+ 未授予 POST_NOTIFICATIONS。静默失败，
            // 由自检面板负责引导用户去开。
        }
    }

    // ------------------------------------------------------------------ 内部

    private fun armAlarm(alarmManager: AlarmManager, atMs: Long, pending: PendingIntent) {
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        if (canExact) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pending)
        } else {
            // 没拿到精确闹钟权限时降级：仍会触发，只是可能被系统批处理推迟。
            // 远好于整条提醒链路静默失效。
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pending)
        }
    }

    /**
     * 构造触发用 Intent。
     *
     * `action` + `data` 共同构成 PendingIntent 的身份（filterEquals 只比这两者
     * 加上 type / class / categories，**不比 extras**）。所以 data 里带上 seq，
     * 即使将来有人误把 requestCode 改成相同值，闹钟也不会互相覆盖。
     */
    private fun fireIntent(
        context: Context,
        seq: Int,
        title: String?,
        body: String?,
        notificationId: Int,
        isFinal: Boolean = false,
    ): Intent = Intent(context, SetBeatAlertReceiver::class.java).apply {
        action = ACTION_FIRE
        data = Uri.parse("$ACTION_URI_PREFIX$seq")
        putExtra(EXTRA_NOTIFICATION_ID, notificationId)
        putExtra(EXTRA_FINAL, isFinal)
        if (title != null) putExtra(EXTRA_TITLE, title)
        if (body != null) putExtra(EXTRA_BODY, body)
    }

    /**
     * 停掉计时用的前台服务（连带它的常驻通知）。
     *
     * 结束提醒投递时调用：[SetBeatAlertReceiver] 判断 `isFinal` 后走这里。
     *
     * 不停的话，用户会同时看到两条「训练完成」—— 一条来自常驻通知
     * （`describeForeground` 把 finished 渲染成「训练完成」），一条来自刚刚
     * 触发的结束提醒。文案一模一样，用户的第一反应就是「怎么发了两条」。
     *
     * ⚠️ 这里按类名停服务，耦合了 flutter_foreground_task 的清单声明。
     * 插件升级改了类名会静默失效（表现为结束时多留一条常驻通知），
     * 不影响其他功能。
     */
    fun stopTimerForegroundService(context: Context) {
        try {
            context.stopService(
                Intent().setClassName(
                    context,
                    "com.pravera.flutter_foreground_task.service.ForegroundService",
                ),
            )
        } catch (_: Exception) {
        }
    }
}
