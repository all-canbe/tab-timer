import 'package:flutter/scheduler.dart';

import 'tick_source.dart';

/// 基于 vsync 的生产级帧源，对应原版的 `requestAnimationFrame`。
///
/// 用 Ticker 而非 `Timer.periodic`：Ticker 与显示刷新同步，
/// 页面不可见时会自动静音（muted），不会在后台空转耗电；
/// 且它只负责「何时评估一次」，时间全部由引擎向时钟查询，
/// 因此掉帧、跳帧都不会引入误差。
class TickerTickSource implements TickSource {
  TickerTickSource(this._provider);

  final TickerProvider _provider;
  Ticker? _ticker;

  @override
  void start(void Function() onTick) {
    _release();
    _ticker = _provider.createTicker((_) => onTick())..start();
  }

  @override
  void stop() => _release();

  void _release() {
    if (_ticker != null) {
      if (_ticker!.isActive) _ticker!.stop();
      _ticker!.dispose();
      _ticker = null;
    }
  }
}

/// 不挂靠 Widget 的 Ticker 帧源。
///
/// 供状态层（Riverpod Notifier）使用——它没有 BuildContext，
/// 拿不到 TickerProvider。代价是失去「页面不可见时自动静音」，
/// 但引擎在暂停/结束时本就会 stop，实际影响可忽略。
class PlainTickerSource implements TickSource {
  Ticker? _ticker;

  @override
  void start(void Function() onTick) {
    _release();
    _ticker = Ticker((_) => onTick())..start();
  }

  @override
  void stop() => _release();

  void _release() {
    if (_ticker != null) {
      if (_ticker!.isActive) _ticker!.stop();
      _ticker!.dispose();
      _ticker = null;
    }
  }
}
