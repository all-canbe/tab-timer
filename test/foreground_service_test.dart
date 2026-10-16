import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/engine/engine_clock.dart';
import 'package:setbeat_flutter/engine/tick_source.dart';
import 'package:setbeat_flutter/engine/timer_engine.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/models/training_preset.dart';
import 'package:setbeat_flutter/services/foreground_timer_service.dart';
import 'package:setbeat_flutter/services/rom_compat.dart';

/// 前台服务相关逻辑的单测。
///
/// 覆盖三块**纯函数**部分（都不碰平台通道，所以能在 CI 里跑）：
///   1. `TimerEngine.foregroundPhases()` —— 下发给后台 isolate 的时间轴；
///   2. `describeForeground()` —— 常驻通知的文案推导；
///   3. `RomCompat.classify()` —— 厂商识别。
///
/// 这三块是「真机上通知对不对」的实际决定者，而它们恰好也是最容易被
/// 后续改动悄悄改坏的（比如把 foregroundPhases 的过滤规则改成和
/// upcomingBoundaries 一样）。
TrainingPreset _preset(List<int> seconds, int loop) => TrainingPreset(
      id: 'p1',
      name: '测试方案',
      cards: <TimeCard>[
        for (int i = 0; i < seconds.length; i++)
          TimeCard(
            id: 'c$i',
            label: 'L$i',
            duration: seconds[i],
            color: '#ff6b35',
          ),
      ],
      loopCount: loop,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  group('TimerEngine.foregroundPhases', () {
    late ManualEngineClock clock;
    late ManualTickSource ticker;
    late TimerEngine engine;
    late TimerEvents events;

    setUp(() {
      clock = ManualEngineClock(startMs: 1000000, wallStart: 1800000000000);
      ticker = ManualTickSource();
      engine = TimerEngine(clock: clock, tickSource: ticker);
      events = const TimerEvents();
    });

    void tick(int ms) {
      clock.advance(ms);
      ticker.pump();
    }

    test('包含当前段位（而非只给后续切换点）', () {
      engine.start(_preset(<int>[60, 15], 1), events);

      final List<ForegroundPhase> phases = engine.foregroundPhases();
      expect(phases, hasLength(2));
      // 第一项就是「现在正在跑的这一段」，这是与 upcomingBoundaries 的关键差别
      expect(phases.first.label, 'L0');
      expect(phases.first.startWallMs, 1800000000000);
      expect(phases.first.endWallMs, 1800000060000);
    });

    test('不做「短于 1 分钟」过滤 —— 通知要显示每一段', () {
      // 15 秒的段位在 upcomingBoundaries 的消费者那里会被砍掉，
      // 但常驻通知必须显示它，否则用户会看到通知卡在上一段不动。
      engine.start(_preset(<int>[60, 15], 1), events);
      final List<ForegroundPhase> phases = engine.foregroundPhases();
      expect(phases.map((ForegroundPhase p) => p.label), <String>['L0', 'L1']);
    });

    test('随进度推进，已跑完的段位被丢弃', () {
      engine.start(_preset(<int>[60, 15], 1), events);
      tick(60000);

      final List<ForegroundPhase> phases = engine.foregroundPhases();
      expect(phases, hasLength(1));
      expect(phases.single.label, 'L1');
      // 起点被夹到「现在」，不会出现负数
      expect(phases.single.startWallMs, 1800000060000);
      expect(phases.single.endWallMs, 1800000075000);
    });

    test('多轮次时轮数正确', () {
      engine.start(_preset(<int>[10], 3), events);
      final List<ForegroundPhase> phases = engine.foregroundPhases();
      expect(phases.map((ForegroundPhase p) => p.round), <int>[1, 2, 3]);
      expect(phases.last.isLast, isTrue);
      expect(phases.first.isLast, isFalse);
    });

    test('超长方案被裁剪时，首尾两项必须保留', () {
      engine.start(_preset(<int>[10], 300), events);
      final List<ForegroundPhase> phases = engine.foregroundPhases(maxItems: 8);

      expect(phases, hasLength(8));
      // 首项 = 通知立刻要显示的当前段位
      expect(phases.first.startWallMs, 1800000000000);
      // 末项 = 整段结束，丢失的话后台 isolate 永远算不出「已完成」
      expect(phases.last.isLast, isTrue);
    });

    test('未开始时返回空列表', () {
      expect(engine.foregroundPhases(), isEmpty);
    });
  });

  group('describeForeground', () {
    final List<ForegroundPhase> phases = <ForegroundPhase>[
      const ForegroundPhase(
        label: '热身',
        startWallMs: 1000,
        endWallMs: 61000,
        round: 1,
        totalRounds: 2,
        isLast: false,
      ),
      const ForegroundPhase(
        label: '冲刺',
        startWallMs: 61000,
        endWallMs: 121000,
        round: 2,
        totalRounds: 2,
        isLast: true,
      ),
    ];

    test('运行中显示当前段位与秒级倒计时', () {
      final ({String title, String text}) d = describeForeground(
        presetName: 'HIIT',
        status: 'running',
        phases: phases,
        nowMs: 11000,
      );
      expect(d.title, '热身 · 第 1/2 轮');
      expect(d.text, '剩余 00:50');
    });

    test('倒计时向上取整，剩 1 毫秒也显示 00:01 而不是 00:00', () {
      final ({String title, String text}) d = describeForeground(
        presetName: 'HIIT',
        status: 'running',
        phases: phases,
        nowMs: 60999,
      );
      expect(d.text, '剩余 00:01');
    });

    test('单轮方案不显示轮数后缀', () {
      final List<ForegroundPhase> single = <ForegroundPhase>[
        const ForegroundPhase(
          label: '平板支撑',
          startWallMs: 0,
          endWallMs: 60000,
          round: 1,
          totalRounds: 1,
          isLast: true,
        ),
      ];
      final ({String title, String text}) d = describeForeground(
        presetName: '核心',
        status: 'running',
        phases: single,
        nowMs: 0,
      );
      expect(d.title, '平板支撑');
    });

    test('暂停时冻结在暂停剩余量上，不随 nowMs 走', () {
      final ({String title, String text}) d = describeForeground(
        presetName: 'HIIT',
        status: 'paused',
        phases: phases,
        nowMs: 30000,
        pausedRemainingMs: 40000,
      );
      expect(d.title, '已暂停 · 热身');
      expect(d.text, '剩余 00:40');
    });

    test('时间轴走完但状态仍是 running 时降级提示（主 isolate 被冻结的场景）', () {
      final ({String title, String text}) d = describeForeground(
        presetName: 'HIIT',
        status: 'running',
        phases: phases,
        nowMs: 999999,
      );
      expect(d.text, '时间轴已走完…');
    });

    test('完成态文案固定', () {
      final ({String title, String text}) d = describeForeground(
        presetName: 'HIIT',
        status: 'finished',
        phases: const <ForegroundPhase>[],
        nowMs: 0,
      );
      expect(d.title, '训练完成');
    });
  });

  group('RomCompat.classify', () {
    test('OPPO / realme / OnePlus 分别归到自己的 ROM', () {
      expect(RomCompat.classify('oppo', 'oppo'), RomVendor.colorOs);
      expect(RomCompat.classify('oppo', 'realme'), RomVendor.realmeUi);
      expect(RomCompat.classify('oneplus', 'oneplus'), RomVendor.oxygenOs);
    });

    test('小米系：MANUFACTURER 是 xiaomi，子品牌只体现在 BRAND 上', () {
      expect(RomCompat.classify('xiaomi', 'xiaomi'), RomVendor.miui);
      expect(RomCompat.classify('xiaomi', 'redmi'), RomVendor.miui);
      expect(RomCompat.classify('xiaomi', 'poco'), RomVendor.miui);
    });

    test('华为与荣耀必须区分（两者的自启动页组件名不同）', () {
      expect(RomCompat.classify('huawei', 'huawei'), RomVendor.emui);
      expect(RomCompat.classify('honor', 'honor'), RomVendor.magicOs);
    });

    test('vivo / iQOO', () {
      expect(RomCompat.classify('vivo', 'vivo'), RomVendor.funtouchOs);
      expect(RomCompat.classify('vivo', 'iqoo'), RomVendor.funtouchOs);
    });

    test('原生系 ROM 不需要保活指引', () {
      expect(RomCompat.classify('google', 'google'), RomVendor.stock);
      expect(RomVendor.stock.keepAliveSteps, isEmpty);
      expect(RomVendor.stock.hasAutoStartPage, isFalse);
    });

    test('空厂商信息不抛异常', () {
      expect(RomCompat.classify('', ''), RomVendor.unknown);
    });

    test('每个需要保活的 ROM 都必须给出至少一条可操作步骤', () {
      for (final RomVendor v in RomVendor.values) {
        if (v == RomVendor.stock || v == RomVendor.unknown) continue;
        expect(v.keepAliveSteps, isNotEmpty, reason: '$v 缺少保活步骤');
      }
    });
  });
}
