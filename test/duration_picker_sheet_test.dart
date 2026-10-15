import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/models/time_card.dart';
import 'package:setbeat_flutter/widgets/duration_picker_sheet.dart';

/// 回归测试：真机上点「添加时长卡片」后整屏灰死。
/// 根因是弹层首次 build 期间读取了尚未 attach 的
/// FixedExtentScrollController.selectedItem（内部 `_positions.single`），
/// 抛 `Bad state: No element` 导致整个弹层渲染失败。
void main() {
  Widget host() => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => showDurationPickerSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('打开弹层不抛异常，且标题/滚轮/确认按钮齐备', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    // 之前在这里 build 抛 Bad state: No element，pump 时异常向上冒
    await tester.pumpAndSettle();

    expect(find.text('添加时长卡片'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    // 预设 chip
    expect(find.text('25min'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);
  });

  testWidgets('chip 一键填入后总时长正确，确认产出卡片', (WidgetTester tester) async {
    final List<TimeCard> captured = <TimeCard>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () async {
                final TimeCard? card =
                    await showDurationPickerSheet(context);
                if (card != null) captured.add(card);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 输入名称
    await tester.enterText(find.byType(TextField), '训练');
    await tester.pump();

    // 点 25min chip：时 0 / 分 25 / 秒 0
    await tester.tap(find.text('25min'));
    await tester.pumpAndSettle();

    // 确认按钮从禁用变为可用
    expect(tester.widget<Opacity>(find.widgetWithText(Opacity, '确认').first).opacity,
        1);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(captured, hasLength(1));
    expect(captured.single.label, '训练');
    expect(captured.single.duration, 25 * 60);
  });

  testWidgets('1h chip 填入 3600 秒', (WidgetTester tester) async {
    final List<TimeCard> captured = <TimeCard>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () async {
                final TimeCard? card =
                    await showDurationPickerSheet(context);
                if (card != null) captured.add(card);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '整点');
    await tester.pump();
    await tester.tap(find.text('1h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(captured.single.duration, 3600);
  });
}
