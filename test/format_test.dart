import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/models/training_preset.dart';
import 'package:setbeat_flutter/utils/format.dart';

/// 判定基准来自原版 `src/utils/format.ts` 的行为，
/// 以及 openspec 变更记录里已经验证过的显示值。
void main() {
  TimeCard card(int seconds) => TimeCard(
        id: 'c$seconds',
        label: 'x',
        duration: seconds,
        color: '#ff6b35',
      );

  group('formatTime', () {
    test('分秒格式，两段均补零', () {
      expect(formatTime(0), '00:00');
      expect(formatTime(45), '00:45');
      expect(formatTime(60), '01:00');
      expect(formatTime(61), '01:01');
      expect(formatTime(600), '10:00');
      expect(formatTime(3599), '59:59');
    });

    test('跨小时为 h:mm:ss，小时段不补零', () {
      expect(formatTime(3600), '1:00:00');
      expect(formatTime(3661), '1:01:01');
      expect(formatTime(36000), '10:00:00');
    });

    test('负数按 0 处理，不产生 00:-1 之类的脏值', () {
      expect(formatTime(-5), '00:00');
    });
  });

  group('formatMs', () {
    test('向上取整到秒', () {
      expect(formatMs(0), '00:00');
      expect(formatMs(1), '00:01');
      expect(formatMs(999), '00:01');
      expect(formatMs(1000), '00:01');
      expect(formatMs(1001), '00:02');
      expect(formatMs(1500000), '25:00');
    });

    test('结束归零显示 00:00', () {
      expect(formatMs(0), '00:00');
    });
  });

  group('formatDurationShort', () {
    test('秒 / 分 / 小时三档', () {
      expect(formatDurationShort(15), '15s');
      expect(formatDurationShort(45), '45s');
      expect(formatDurationShort(60), '1min');
      expect(formatDurationShort(1500), '25min');
      // 与原版 Math.floor 语义一致：3599s = 59.98min -> 59min
      expect(formatDurationShort(3599), '59min');
      expect(formatDurationShort(3600), '1h');
      expect(formatDurationShort(5400), '1h30min');
    });

    test('进位修正：原版会把 7199 秒显示成 1h60min', () {
      expect(formatDurationShort(7199), '2h');
      expect(formatDurationShort(10799), '3h');
    });
  });

  group('calcTotalDuration / calcTotalDurationStr', () {
    test('总时长 = 卡片之和 × 循环次数', () {
      expect(calcTotalDuration(<TimeCard>[card(1500), card(300)], 4), 7200);
      expect(calcTotalDurationStr(<TimeCard>[card(1500), card(300)], 4), '2h');
    });

    test('openspec 中已验证过的显示值：45min × 6 = 4h30min', () {
      expect(calcTotalDurationStr(<TimeCard>[card(45 * 60)], 6), '4h30min');
    });

    test('1h + 45min，循环 6 次 = 10h30min', () {
      expect(calcTotalDurationStr(<TimeCard>[card(3600), card(2700)], 6), '10h30min');
    });

    test('不足一分钟回落秒单位', () {
      expect(calcTotalDurationStr(<TimeCard>[card(15)], 1), '15s');
    });
  });

  group('durationSequence', () {
    test('按卡片顺序以 + 连接', () {
      expect(durationSequence(<TimeCard>[card(1500), card(300)]), '25min+5min');
      expect(
        durationSequence(<TimeCard>[card(3600), card(2700), card(15)]),
        '1h+45min+15s',
      );
    });
  });

  group('generateId', () {
    test('非空且大量生成不重复', () {
      final Set<String> ids = <String>{};
      for (int i = 0; i < 5000; i++) {
        ids.add(generateId());
      }
      expect(ids.length, 5000);
      expect(generateId().length, greaterThan(6));
    });
  });

  group('TrainingPreset.expand', () {
    test('展开序列 = cards 平铺 loopCount 次', () {
      final TrainingPreset p = TrainingPreset(
        id: 'p1',
        name: '番茄钟',
        cards: <TimeCard>[card(1500), card(300)],
        loopCount: 3,
        createdAt: 0,
        updatedAt: 0,
      );
      final List<TimeCard> expanded = p.expand();
      expect(expanded.length, 6);
      expect(expanded[0].duration, 1500);
      expect(expanded[1].duration, 300);
      expect(expanded[5].duration, 300);
    });
  });

  group('模型 JSON 往返', () {
    test('TimeCard 键名与原版一致', () {
      final Map<String, dynamic> json = card(45).toJson();
      expect(json.keys.toSet(), <String>{'id', 'label', 'duration', 'color'});
      expect(json['duration'], 45);
    });

    test('TrainingPreset 往返后字段不变', () {
      final TrainingPreset original = TrainingPreset(
        id: 'p1',
        name: '晚间专注',
        cards: <TimeCard>[card(3600), card(2700)],
        loopCount: 6,
        createdAt: 1700000000000,
        updatedAt: 1700000001000,
      );
      final TrainingPreset restored =
          TrainingPreset.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.loopCount, original.loopCount);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.cards.length, 2);
      expect(restored.cards[0].duration, 3600);
      expect(restored.cards[0].color, '#ff6b35');
    });
  });
}
