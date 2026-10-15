import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/engine/engine_clock.dart';
import 'package:setbeat_flutter/engine/tick_source.dart';
import 'package:setbeat_flutter/engine/timer_engine.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/models/timer_state.dart';
import 'package:setbeat_flutter/models/training_preset.dart';

/// 事件录制器，把引擎抛出的事件按顺序记下来供断言。
class _Recorder extends TimerEvents {
  final List<String> log = <String>[];
  final List<double> ticks = <double>[];
  final List<CardChangeEvent> cardChanges = <CardChangeEvent>[];
  final List<int> countdowns = <int>[];
  int finishCount = 0;

  double lastRemaining = 0;
  double lastTotal = 0;

  @override
  void onTick(double remainingMs, double totalMs) {
    lastRemaining = remainingMs;
    lastTotal = totalMs;
    ticks.add(remainingMs);
  }

  @override
  void onCardChange(CardChangeEvent event) {
    cardChanges.add(event);
    log.add('card:${event.position}');
  }

  @override
  void onCountdownTick(int secondsLeft) {
    countdowns.add(secondsLeft);
    log.add('count:$secondsLeft');
  }

  @override
  void onFinish() {
    finishCount++;
    log.add('finish');
  }
}

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
  late ManualEngineClock clock;
  late ManualTickSource ticker;
  late TimerEngine engine;
  late _Recorder rec;

  setUp(() {
    // 单调时钟与墙钟都从非零值起，避免 0 掩盖符号错误
    clock = ManualEngineClock(startMs: 1000000, wallStart: 1800000000000);
    ticker = ManualTickSource();
    engine = TimerEngine(clock: clock, tickSource: ticker);
    rec = _Recorder();
  });

  /// 推进 [ms] 毫秒并模拟一帧
  void tick(int ms) {
    clock.advance(ms);
    ticker.pump();
  }

  group('开始与序列展开', () {
    test('开始时定位到首段，剩余时间为首段总时长', () {
      engine.start(_preset(<int>[60, 15], 3), rec);
      expect(engine.status, TimerStatus.running);
      expect(engine.totalPositions, 6);
      expect(engine.totalMs, 225000);
      expect(rec.cardChanges.single.position, 0);
      expect(rec.cardChanges.single.round, 1);
      expect(rec.cardChanges.single.totalRounds, 3);
      expect(rec.lastRemaining, 60000);
    });

    test('空卡片方案不会卡死，直接判定结束', () {
      engine.start(_preset(<int>[], 3), rec);
      expect(engine.status, TimerStatus.finished);
      expect(rec.finishCount, 1);
    });

    test('全零时长方案直接结束，不进入死循环', () {
      engine.start(_preset(<int>[0, 0], 2), rec);
      expect(engine.status, TimerStatus.finished);
    });
  });

  group('正常推进', () {
    test('逐帧推进，剩余时间与位置正确', () {
      engine.start(_preset(<int>[60, 15], 3), rec);
      tick(30000);
      expect(rec.lastRemaining, 30000);
      expect(engine.position, 0);

      tick(30000); // 累计 60s，刚好进入第二段
      expect(engine.position, 1);
      expect(rec.cardChanges.last.position, 1);
      expect(rec.cardChanges.last.round, 1);
      expect(rec.lastRemaining, 15000);
    });

    test('轮次推进正确：第 2 组开始时 round = 2', () {
      engine.start(_preset(<int>[60, 15], 3), rec);
      tick(76000); // 60 + 15 = 75s 后进入第 2 组首段
      expect(engine.position, 2);
      expect(rec.cardChanges.last.round, 2);
      expect(rec.cardChanges.last.card.duration, 60);
    });

    test('跑完整序列只触发一次结束，且剩余归零', () {
      engine.start(_preset(<int>[60, 15], 3), rec);
      tick(225000);
      expect(engine.status, TimerStatus.finished);
      expect(rec.finishCount, 1);
      expect(rec.lastRemaining, 0);
      expect(engine.remainingMs, 0);
    });

    test('结束后继续推进不产生任何事件', () {
      engine.start(_preset(<int>[10], 1), rec);
      tick(10000);
      final int finishBefore = rec.finishCount;
      final int tickCountBefore = rec.ticks.length;
      tick(5000);
      expect(rec.finishCount, finishBefore);
      expect(rec.ticks.length, tickCountBefore);
    });
  });

  group('掉帧鲁棒性（原版的核心缺陷）', () {
    test('单次推进 200 秒也不会丢时间——原版会因 delta 限幅 1000ms 而整体变慢', () {
      engine.start(_preset(<int>[60, 15], 3), rec);
      tick(200000);
      // cumulative(ms) = 0,60000,75000,135000,150000,210000,225000
      // 200000 落在 index 4（60s 卡片）内，剩余 10000
      expect(engine.position, 4);
      expect(rec.lastRemaining, closeTo(10000, 0.001));
      expect(rec.cardChanges.last.round, 3);
    });

    test('一次推进直接越过终点，判定结束而不是继续倒扣', () {
      engine.start(_preset(<int>[10, 5], 1), rec);
      tick(999999);
      expect(engine.status, TimerStatus.finished);
      expect(rec.finishCount, 1);
      expect(engine.remainingMs, 0);
    });

    test('大跨度推进时卡片切换事件被合并，不会瞬间爆发一堆事件', () {
      engine.start(_preset(<int>[1, 1], 10), rec); // 20 张 1 秒卡
      rec.cardChanges.clear();
      tick(15000);
      // 跨过 15 张卡片，但只应产生一次切换事件
      expect(rec.cardChanges.length, 1);
      expect(rec.cardChanges.single.position, 15);
    });
  });

  group('倒数提示', () {
    test('最后 3 秒每秒一次，序列为 3/2/1', () {
      engine.start(_preset(<int>[5], 1), rec);
      tick(2000); // 剩余 3000
      tick(1000); // 剩余 2000
      tick(1000); // 剩余 1000
      tick(1000); // 结束
      expect(rec.countdowns, <int>[3, 2, 1]);
    });

    test('剩余 3 秒以前不触发倒数', () {
      engine.start(_preset(<int>[10], 1), rec);
      tick(6900); // 剩余 3100
      expect(rec.countdowns, isEmpty);
    });
  });

  group('暂停 / 继续', () {
    test('暂停期间时钟推进不影响剩余时间', () {
      engine.start(_preset(<int>[60], 1), rec);
      tick(20000);
      engine.pause();
      expect(engine.status, TimerStatus.paused);

      clock.advance(60000); // 暂停中白白过了 60 秒
      ticker.pump();
      expect(engine.remainingMs, closeTo(40000, 0.001));
    });

    test('继续后从暂停点接着走，暂停时长不计入', () {
      engine.start(_preset(<int>[60], 1), rec);
      tick(20000);
      engine.pause();
      clock.advance(60000);
      engine.resume();
      expect(engine.status, TimerStatus.running);
      expect(engine.remainingMs, closeTo(40000, 0.001));
      tick(10000);
      expect(engine.remainingMs, closeTo(30000, 0.001));
    });

    test('暂停态下重复调用 pause / resume 是幂等的', () {
      engine.start(_preset(<int>[60], 1), rec);
      engine.pause();
      engine.pause();
      expect(engine.status, TimerStatus.paused);
      engine.resume();
      engine.resume();
      expect(engine.status, TimerStatus.running);
    });

    test('暂停态下推进不触发倒数提示', () {
      engine.start(_preset(<int>[5], 1), rec);
      tick(2000); // 剩余 3000，触发 3
      engine.pause();
      clock.advance(1000);
      ticker.pump();
      expect(rec.countdowns, <int>[3]);
    });
  });

  group('跳过', () {
    test('跳过进入下一段，并给足新段时长', () {
      engine.start(_preset(<int>[60, 15], 2), rec);
      tick(5000);
      engine.skip();
      expect(engine.position, 1);
      expect(rec.lastRemaining, 15000);
    });

    test('在最后一段跳过直接结束', () {
      engine.start(_preset(<int>[60], 1), rec);
      engine.skip();
      expect(engine.status, TimerStatus.finished);
      expect(rec.finishCount, 1);
    });

    test('暂停态下跳过保持暂停（原版会偷偷恢复运行）', () {
      engine.start(_preset(<int>[60, 15], 2), rec);
      engine.pause();
      engine.skip();
      expect(engine.position, 1);
      expect(engine.status, TimerStatus.paused);
      expect(ticker.isActive, isFalse);
    });

    test('已结束状态下跳过无副作用', () {
      engine.start(_preset(<int>[10], 1), rec);
      tick(10000);
      final int before = rec.finishCount;
      engine.skip();
      expect(rec.finishCount, before);
      expect(engine.status, TimerStatus.finished);
    });
  });

  group('重置', () {
    test('回到首段并以完整时长重新开始', () {
      engine.start(_preset(<int>[60, 15], 2), rec);
      tick(80000); // cumulative = 0/60/75/135/150 秒 -> 落在 index 2
      expect(engine.position, 2);
      engine.reset();
      expect(engine.position, 0);
      expect(engine.status, TimerStatus.running);
      expect(engine.remainingMs, 60000);
    });

    test('结束后重置可以重新跑', () {
      engine.start(_preset(<int>[10], 2), rec);
      tick(20000);
      expect(engine.status, TimerStatus.finished);
      engine.reset();
      expect(engine.status, TimerStatus.running);
      tick(10000);
      expect(engine.position, 1);
    });
  });

  group('跨进程恢复', () {
    test('运行态快照：把快照到现在的墙钟时间补进已跑时长', () {
      engine.start(_preset(<int>[60, 15], 3), rec);
      tick(65000); // 已跑 65s，位于第二段（15s 卡片）剩余 10s
      expect(engine.position, 1);
      expect(engine.remainingMs, closeTo(10000, 0.001));

      final RunningState snap = engine.snapshot()!;
      expect(snap.wasRunning, isTrue);
      expect(snap.position, 1);
      expect(snap.cardRemainingMs, closeTo(10000, 0.001));

      // 模拟进程被杀后过了 20 秒才重新打开
      clock.advanceWallOnly(20000);

      final TimerEngine restored =
          TimerEngine(clock: clock, tickSource: ticker);
      final _Recorder rec2 = _Recorder();
      expect(restored.restore(snap, rec2), RestoreOutcome.restored);
      expect(restored.status, TimerStatus.running);
      // 已跑 65 + 20 = 85s -> cumulative[3] = 135s，位置 2
      expect(restored.position, 2);
      expect(restored.remainingMs, closeTo(50000, 0.001));
    });

    test('暂停态快照：恢复后仍然暂停，不补时间', () {
      engine.start(_preset(<int>[60], 1), rec);
      tick(20000);
      engine.pause();
      final RunningState snap = engine.snapshot()!;
      expect(snap.wasRunning, isFalse);

      clock.advanceWallOnly(120000);

      final TimerEngine restored =
          TimerEngine(clock: clock, tickSource: ticker);
      final _Recorder rec2 = _Recorder();
      expect(restored.restore(snap, rec2), RestoreOutcome.restored);
      expect(restored.status, TimerStatus.paused);
      expect(restored.remainingMs, closeTo(40000, 0.001));
    });

    test('离开期间跑完的快照被判定为「已结束」而非「无内容」', () {
      engine.start(_preset(<int>[30], 1), rec);
      tick(10000);
      final RunningState snap = engine.snapshot()!;

      clock.advanceWallOnly(600000); // 早该结束了

      final TimerEngine restored =
          TimerEngine(clock: clock, tickSource: ticker);
      // 关键：要能和「没有快照」区分开，用户才不会以为被重置
      expect(restored.restore(snap, _Recorder()),
          RestoreOutcome.alreadyFinished);
    });

    test('暂停久到超过总时长的快照依然有效（暂停不计时）', () {
      engine.start(_preset(<int>[30], 1), rec);
      tick(10000);
      engine.pause();
      final RunningState snap = engine.snapshot()!;

      clock.advanceWallOnly(86400000); // 暂停了一整天

      final TimerEngine restored =
          TimerEngine(clock: clock, tickSource: ticker);
      expect(restored.restore(snap, _Recorder()), RestoreOutcome.restored);
      expect(restored.status, TimerStatus.paused);
      expect(restored.remainingMs, closeTo(20000, 0.001));
    });
  });

  group('状态导出', () {
    test('getState 反映当前进度', () {
      engine.start(_preset(<int>[60, 15], 2), rec);
      tick(70000);
      final TimerState? state = engine.getState();
      expect(state, isNotNull);
      expect(state!.position, 1);
      expect(state.totalPositions, 4);
      expect(state.status, TimerStatus.running);
      expect(state.remainingMs, closeTo(5000, 0.001));
      expect(state.preset.name, '测试方案');
    });

    test('destroy 后状态清空', () {
      engine.start(_preset(<int>[60], 1), rec);
      engine.destroy();
      expect(engine.status, TimerStatus.idle);
      expect(engine.getState(), isNull);
      expect(engine.snapshot(), isNull);
      expect(ticker.isActive, isFalse);
    });
  });

  group('事件顺序', () {
    test('切换卡片时先报卡片变化，再报该帧的 tick', () {
      engine.start(_preset(<int>[10, 5], 1), rec);
      rec.log.clear();
      tick(10000);
      expect(rec.log.first, 'card:1');
    });
  });
}
