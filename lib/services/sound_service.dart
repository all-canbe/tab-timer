import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'tone_synth.dart';

/// 声音服务：把原版 Web Audio 合成音完整搬到 Flutter。
///
/// 原版实现在 `src/composables/useSound.ts`：
///   tick   880Hz / 0.08s / 音量 0.3   —— 阶段切换 & 最后 3 秒
///   chime  660Hz / 0.30s / 音量 0.4   —— 暂停后继续
///   finish 5 秒 8 音上行旋律           —— 训练完成
///
/// 三条音全部在首次初始化时一次性合成完毕（约 0.5MB 内存），
/// 之后播放走 `setSourceBytes` 预热 + `seek/resume` 重放，
/// 不产生任何临时文件 IO，也没有音频资源要打包。
/// 三条音对应的播放器槽位。
enum _SoundChannel { tick, chime, finish }

class SoundService {
  bool enabled = true;

  // 播放器懒创建：首次真正要播时才建。
  // 启动期就建会在部分环境抛平台异常（audioplayers 全局初始化不可用），
  // 且测试环境下会留下无法收尾的异步任务。
  AudioPlayer? _tickPlayer;
  AudioPlayer? _chimePlayer;
  AudioPlayer? _finishPlayer;

  AudioPlayer get _tick => _tickPlayer ??= AudioPlayer(playerId: 'setbeat-tick');
  AudioPlayer get _chime =>
      _chimePlayer ??= AudioPlayer(playerId: 'setbeat-chime');
  AudioPlayer get _finish =>
      _finishPlayer ??= AudioPlayer(playerId: 'setbeat-finish');

  // 保留合成字节：预热路径失败时兜底重放用
  Uint8List? _tickBytes;
  Uint8List? _chimeBytes;
  Uint8List? _finishBytes;

  bool _ready = false;

  /// 结束旋律，频率与节拍与原版 `useSound.playFinish` 的 melody 表逐条一致
  static const List<ToneEvent> finishMelody = <ToneEvent>[
    ToneEvent(frequency: 523.25, startSeconds: 0.0, durationSeconds: 0.5), // C5
    ToneEvent(frequency: 659.25, startSeconds: 0.35, durationSeconds: 0.5), // E5
    ToneEvent(frequency: 783.99, startSeconds: 0.7, durationSeconds: 0.5), // G5
    ToneEvent(
        frequency: 1046.50, startSeconds: 1.05, durationSeconds: 0.8), // C6
    ToneEvent(frequency: 783.99, startSeconds: 1.9, durationSeconds: 0.4), // G5
    ToneEvent(frequency: 880.00, startSeconds: 2.3, durationSeconds: 0.4), // A5
    ToneEvent(
        frequency: 1046.50, startSeconds: 2.7, durationSeconds: 0.9), // C6
    ToneEvent(
        frequency: 1318.50, startSeconds: 3.2, durationSeconds: 1.8), // E6 长音
  ];

  /// 预合成全部音效并预热播放器。幂等。
  ///
  /// 整体 try/catch：声音是锦上添花，初始化失败绝不能拖垮 App 启动。
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      final Uint8List tick = ToneSynth.tone(
          frequency: 880, seconds: 0.08, volume: 0.3);
      final Uint8List chime = ToneSynth.tone(
          frequency: 660, seconds: 0.3, volume: 0.4);
      final Uint8List finish = ToneSynth.melody(finishMelody);
      _tickBytes = tick;
      _chimeBytes = chime;
      _finishBytes = finish;

      await _prepare(_tick, tick);
      await _prepare(_chime, chime);
      await _prepare(_finish, finish);
    } catch (_) {
      // 预热失败不致命：真正播放时会走兜底路径
    }
  }

  /// 阶段切换与最后 3 秒的短促「滴」
  Future<void> playTick() => _replay(_SoundChannel.tick);

  /// 暂停后继续的「叮」
  Future<void> playChime() => _replay(_SoundChannel.chime);

  /// 训练完成的 5 秒旋律
  Future<void> playFinish() => _replay(_SoundChannel.finish);

  Future<void> dispose() async {
    for (final AudioPlayer? p in <AudioPlayer?>[
      _tickPlayer,
      _chimePlayer,
      _finishPlayer
    ]) {
      if (p == null) continue;
      try {
        await p.dispose();
      } catch (_) {
        // 播放器销毁失败（如平台未就绪）不值得让调用方感知
      }
    }
    _ready = false;
  }

  // ------------------------------------------------------------------ 内部

  Uint8List? _bytesFor(_SoundChannel ch) => switch (ch) {
        _SoundChannel.tick => _tickBytes,
        _SoundChannel.chime => _chimeBytes,
        _SoundChannel.finish => _finishBytes,
      };

  AudioPlayer _playerFor(_SoundChannel ch) => switch (ch) {
        _SoundChannel.tick => _tick,
        _SoundChannel.chime => _chime,
        _SoundChannel.finish => _finish,
      };

  Future<void> _prepare(AudioPlayer player, Uint8List bytes) async {
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      // 平台通道挂死的兜底：audioplayers 的 setSourceBytes 在个别机型上
      // 可能永远不返回，超时放弃而不是把启动链路堵死
      await player
          .setSourceBytes(bytes, mimeType: 'audio/wav')
          .timeout(const Duration(seconds: 3));
      await player.stop();
    } catch (_) {
      // 预热失败不致命：真正播放时会走兜底路径
    }
  }

  /// 重放预热的音源。
  ///
  /// 预热成功时走 seek+resume（零 IO）；失败或无音源时兜底用
  /// `play(BytesSource)` 直播内存字节——某些机型上 setSourceBytes 预热
  /// 可能静默失败，若没有这条兜底，训练完成时会一声不响。
  ///
  /// 注意：播放器通过 [_SoundChannel] 惰性解析——**守卫（enabled/_ready）
  /// 必须在创建播放器之前执行**，否则「未初始化就调用 playXxx」也会凭空
  /// 建出一个播放器，其异步销毁还会污染测试。
  Future<void> _replay(_SoundChannel ch) async {
    if (!enabled || !_ready) return;
    final AudioPlayer player = _playerFor(ch);
    try {
      await player.stop();
      await player.seek(Duration.zero);
      await player.resume();
      return;
    } catch (_) {
      // 走兜底
    }
    final Uint8List? bytes = _bytesFor(ch);
    if (bytes != null) {
      try {
        await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
      } catch (_) {
        // 声音失败绝不能打断计时流程
      }
    }
  }
}
