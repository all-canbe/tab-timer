import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../services/platform_bridge.dart';
import '../services/rom_compat.dart';
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

  /// 是否已豁免电池优化。null = 平台未实现（Web / 非 Android）。
  ///
  /// 这一项比「通知权限」更值得盯：国产 ROM 上未豁免的应用退后台会被冻结/强杀，
  /// 而 force-stop 会连同 AlarmManager 闹钟一起清空 —— 排期明明成功，到点却什么都没有。
  bool? _batteryExempt;

  /// 当前 ROM。用来把引导文案换成该厂商实际存在的菜单路径 ——
  /// 给 ColorOS 用户看「省电策略 → 无限制」（那是 MIUI 的措辞）纯属添乱。
  RomVendor? _vendor;

  /// 前台服务（常驻通知）是否真的在跑。这是问系统的，不是读缓存。
  bool _foregroundRunning = false;

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
    final bool? batteryExempt =
        await PlatformBridge.isIgnoringBatteryOptimizations();
    final RomVendor vendor = await RomCompat.detect();
    final bool foregroundRunning =
        await ref.read(foregroundServiceProvider).isRunning;
    if (!mounted) return;
    setState(() {
      _capability = cap;
      _pending = pending;
      _batteryExempt = batteryExempt;
      _vendor = vendor;
      _foregroundRunning = foregroundRunning;
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

  /// 按当前 ROM 生成引导文案。
  ///
  /// 存在的意义是「别给用户看他不存在的菜单」——ColorOS 上没有「省电策略」，
  /// MIUI 上没有「耗电管理」，原生 Android 上两者都没有。
  String _guidanceText() {
    final RomVendor vendor = _vendor ?? RomVendor.unknown;
    final StringBuffer b = StringBuffer();

    b.writeln('① 通知设置里勾选「横幅」与「锁屏」；铃声 / 振动按需打开。');
    b.writeln('② 通知设置页滚到底部，打开「桌面角标」（数字角标的总开关）。');

    final List<String> steps = vendor.keepAliveSteps;
    if (steps.isEmpty) {
      b.writeln('③ 当前是 ${vendor.displayName}，没有额外的后台保活闸门，'
          '只要电池策略不是「受限」即可。');
    } else {
      b.writeln('③ ${vendor.displayName} 必须手动放开的闸门（默认全是关的）：');
      for (final String step in steps) {
        b.writeln('   · $step');
      }
    }

    b.writeln('④ 三者缺一不可：自启动让进程起得来，后台运行让它活得下去，'
        '加锁让它不被一键清理连带杀掉。缺任何一个，计时排好的闹钟都可能'
        '被系统连同进程一起清空。');
    b.write('注意：短于 1 分钟的段位不弹边界提醒（避免刷屏），训练结束始终会提醒。');
    return b.toString();
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
              label: '系统 ROM',
              ok: true,
              detail: '${(_vendor ?? RomVendor.unknown).displayName}'
                  '${(_vendor ?? RomVendor.unknown).keepAliveSteps.isEmpty ? '（无需额外保活设置）' : '（需要手动放开后台保活）'}',
            ),
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
              label: '电池优化豁免',
              ok: _batteryExempt ?? true,
              detail: switch (_batteryExempt) {
                null => '本平台不适用',
                true => '已豁免，退后台不会被冻结',
                false => '未豁免 —— 退后台可能被强杀，闹钟会被系统清空',
              },
            ),
            _StatusRow(
              label: '常驻通知（前台服务）',
              ok: _foregroundRunning,
              detail: _foregroundRunning
                  ? '运行中 —— 进程不会被 ROM 随手清掉'
                  : '未运行 —— 开始一次计时就会拉起（这是提醒能到达的前提）',
            ),
            _StatusRow(
              label: '系统内已武装的提醒',
              ok: (_pending ?? 0) > 0,
              // 这个数字是逐个探测系统闹钟拿到的，不是本地记录 ——
              // 应用被 force-stop 后系统清空了闹钟，它会如实变成 0。
              // （旧实现读本地记录，在那种情况下会报出旧数字，把排查带偏过。）
              detail: _pending == null
                  ? '查询中…'
                  : (_pending! > 0
                      ? '$_pending 条（直接来自系统闹钟）'
                      : '暂无（先开始一次计时）'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SetBeatColors.accentSoft,
                borderRadius: BorderRadius.circular(SetBeatRadii.sm),
              ),
              child: Text(
                _guidanceText(),
                style: const TextStyle(
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
            if (_batteryExempt == false)
              _ActionButton(
                label: '申请豁免电池优化（弹系统对话框）',
                primary: true,
                onTap: () async {
                  await PlatformBridge.requestIgnoreBatteryOptimizations();
                  await _refresh();
                },
              ),
            if (_batteryExempt == false) const SizedBox(height: 10),
            // 这两个入口点一次就到位，比让用户自己翻五层菜单现实得多。
            // 厂商 ROM 的组件名随版本改名，跳转失败会兜底到应用详情页，
            // 所以按钮永远可用。
            if (_vendor?.hasAutoStartPage ?? false)
              _ActionButton(
                label: '打开「自启动管理」',
                onTap: () => RomCompat.openAutoStart(),
              ),
            if (_vendor?.hasAutoStartPage ?? false) const SizedBox(height: 10),
            _ActionButton(
              label: '打开「耗电管理 / 省电策略」',
              onTap: () => RomCompat.openPowerManager(),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: '打开应用详情',
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
