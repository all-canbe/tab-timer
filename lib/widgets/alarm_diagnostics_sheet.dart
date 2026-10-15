import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../services/platform_bridge.dart';
import '../state/services.dart';
import '../theme/app_theme.dart';

/// 提醒自检面板。
///
/// 起因：通知排期成功、权限也开了，但用户那边就是不弹——问题其实全在
/// 系统通知设置里（横幅未勾选 / 锁屏未勾选 / 铃声与振动关闭 / 电池优化压制）。
/// 与其反复口头描述路径，不如把这套自检做成面板：
/// 一键发测试提醒（3 秒后）、一键跳到对应的系统设置页。
Future<void> showAlarmDiagnosticsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SetBeatColors.surface,
    builder: (_) => const _AlarmDiagnosticsSheet(),
  );
}

class _AlarmDiagnosticsSheet extends ConsumerStatefulWidget {
  const _AlarmDiagnosticsSheet();

  @override
  ConsumerState<_AlarmDiagnosticsSheet> createState() =>
      _AlarmDiagnosticsSheetState();
}

class _AlarmDiagnosticsSheetState
    extends ConsumerState<_AlarmDiagnosticsSheet> {
  AlarmCapability? _capability;
  int? _pending;
  String? _testResult;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final NotificationService svc = ref.read(notificationServiceProvider);
    final AlarmCapability cap = await svc.checkCapability();
    final int pending = await svc.pendingNotificationCount();
    if (!mounted) return;
    setState(() {
      _capability = cap;
      _pending = pending;
      _busy = false;
    });
  }

  Future<void> _sendTest() async {
    setState(() {
      _busy = true;
      _testResult = null;
    });
    final NotificationService svc = ref.read(notificationServiceProvider);
    final bool ok = await svc.showTestAlert();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testResult = ok
          ? '已排期，3 秒后应出现通知。没看到就往下看系统设置要点。'
          : '排期失败：${svc.lastScheduleError ?? '未知原因'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AlarmCapability? cap = _capability;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Center(
              child: Text(
                '提醒自检',
                style: TextStyle(
                  color: SetBeatColors.text1,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StatusRow(
              label: '通知权限',
              ok: cap?.notificationsAllowed ?? false,
              detail: (cap?.notificationsAllowed ?? false) ? '已开启' : '未开启',
            ),
            _StatusRow(
              label: '精确闹钟（闹钟和提醒）',
              ok: cap?.exactAlarmsAllowed ?? false,
              detail: (cap?.exactAlarmsAllowed ?? false)
                  ? '已授权'
                  : '未授权 —— 已自动降级为「大致准时」，最多延迟几分钟',
            ),
            _StatusRow(
              label: '系统内已排期提醒',
              ok: (_pending ?? 0) > 0,
              detail: _pending == null
                  ? '查询中…'
                  : (_pending! > 0 ? '$_pending 条' : '暂无（先开始一次计时）'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SetBeatColors.accentSoft,
                borderRadius: BorderRadius.circular(SetBeatRadii.sm),
              ),
              child: const Text(
                '提醒要「弹出来」，除了允许通知，还必须在通知设置里勾选：\n'
                '· 横幅（悬浮弹出，不勾就永远不弹）\n'
                '· 锁屏（息屏时在锁屏上显示）\n'
                '· 铃声 / 振动（想要声音就打开）\n'
                '另外请确认手机没有开静音或勿扰，并把本应用的电池策略设为「无限制」。\n'
                '注意：短于 1 分钟的段位不弹边界提醒（避免刷屏），训练结束始终会提醒。',
                style: TextStyle(
                  color: SetBeatColors.text2,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ActionButton(
              label: '发送测试提醒（3 秒后）',
              primary: true,
              onTap: _busy ? null : _sendTest,
            ),
            if (_testResult != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _testResult!,
                style: const TextStyle(
                    color: SetBeatColors.text2, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            _ActionButton(
              label: '打开本应用的通知设置（横幅 / 锁屏）',
              onTap: () => PlatformBridge.openNotificationSettings(),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: '打开「闹钟和提醒」权限页',
              onTap: () => PlatformBridge.openExactAlarmSettings(),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: '打开应用详情（电池 / 自启动白名单）',
              onTap: () => PlatformBridge.openAppDetailsSettings(),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text(
                '重新检测',
                style: TextStyle(color: SetBeatColors.text3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.detail,
  });

  final String label;
  final bool ok;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                ok ? Icons.check_circle : Icons.error_outline,
                size: 16,
                color: ok ? SetBeatColors.teal : SetBeatColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      color: SetBeatColors.text1,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                        color: SetBeatColors.text3, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: primary ? Colors.transparent : SetBeatColors.surface2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Ink(
              height: 48,
              decoration: primary
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          SetBeatColors.accent,
                          SetBeatColors.accent2
                        ],
                      ),
                    )
                  : null,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primary ? Colors.white : SetBeatColors.text2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
