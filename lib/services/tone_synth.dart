import 'dart:math' as math;
import 'dart:typed_data';

/// 单音事件（用于旋律合成）
class ToneEvent {
  /// 频率（Hz）
  final double frequency;

  /// 起始时刻（秒）
  final double startSeconds;

  /// 持续时长（秒）
  final double durationSeconds;

  /// 峰值音量 0..1
  final double volume;

  const ToneEvent({
    required this.frequency,
    required this.startSeconds,
    required this.durationSeconds,
    this.volume = 0.4,
  });
}

/// 纯 Dart 的正弦波合成器：直接产出可播放的 16bit PCM WAV 字节。
///
/// 为什么要自己合成而不是打包音频文件：
///   - 原版 SetBeat 用 Web Audio 的 `OscillatorNode` 实时合成，APK 里一个音频文件都没有；
///   - Flutter 没有内置振荡器，`audioplayers` 却支持从内存字节播放（`BytesSource`）；
///   - 于是把「合成」放在 Dart 侧完成，既保住零音频资源的传统，又比 Web Audio
///     更可控——包络曲线、时长、音量全部是确定值，实机上不会因设备采样率不同而漂移。
///
/// 包络完全复刻原版 Web Audio 的写法：
/// ```
/// gain.setValueAtTime(0, t0)
/// gain.linearRampToValueAtTime(volume, t0 + 0.01)      // 10ms 线性起音，防爆音
/// gain.exponentialRampToValueAtTime(0.001, t0 + duration)  // 指数衰减到近似静音
/// ```
class ToneSynth {
  ToneSynth._();

  /// 44.1kHz：旋律最高音 E6(1318.5Hz)，远低于奈奎斯特频率，采样率减半也够，
  /// 但保持 44.1k 可与原版 Web Audio 的输出完全一致。
  static const int sampleRate = 44100;

  static const int _bitsPerSample = 16;

  /// 起音时长（秒），与原版 `linearRampToValueAtTime(volume, currentTime + 0.01)` 对齐
  static const double attackSeconds = 0.01;

  /// 指数衰减的收尾值，与原版 `exponentialRampToValueAtTime(0.001, ...)` 对齐
  static const double decayFloor = 0.001;

  // ------------------------------------------------------------------ 公开 API

  /// 合成单个正弦音，返回完整 WAV 文件字节。
  static Uint8List tone({
    required double frequency,
    required double seconds,
    required double volume,
  }) {
    final int count = math.max(1, (seconds * sampleRate).round());
    final Float64List buf = Float64List(count);
    for (int i = 0; i < count; i++) {
      final double t = i / sampleRate;
      buf[i] = math.sin(2 * math.pi * frequency * t) *
          _envelope(t, seconds, volume);
    }
    return encodeWav(buf);
  }

  /// 合成多音叠加的旋律，返回完整 WAV 文件字节。
  ///
  /// 各音可以重叠（原版就是这么排的：C5 还没衰减完 E5 就进来了）。
  /// 叠加后统一做一次峰值归一化，避免多个音叠加处削顶失真。
  static Uint8List melody(List<ToneEvent> events) {
    double totalSeconds = 0;
    for (final ToneEvent e in events) {
      totalSeconds =
          math.max(totalSeconds, e.startSeconds + e.durationSeconds);
    }
    final int count = math.max(1, (totalSeconds * sampleRate).round());
    final Float64List buf = Float64List(count);

    for (final ToneEvent e in events) {
      final int start = (e.startSeconds * sampleRate).round();
      final int length = (e.durationSeconds * sampleRate).round();
      for (int i = 0; i < length; i++) {
        final int index = start + i;
        if (index < 0 || index >= count) continue;
        final double t = i / sampleRate;
        buf[index] += math.sin(2 * math.pi * e.frequency * t) *
            _envelope(t, e.durationSeconds, e.volume);
      }
    }

    double peak = 0;
    for (int i = 0; i < count; i++) {
      final double a = buf[i].abs();
      if (a > peak) peak = a;
    }
    if (peak > 0.95) {
      final double scale = 0.95 / peak;
      for (int i = 0; i < count; i++) {
        buf[i] *= scale;
      }
    }
    return encodeWav(buf);
  }

  /// Float64 采样（范围 -1..1）→ 单声道 16bit PCM WAV 字节。
  static Uint8List encodeWav(Float64List samples) {
    final int dataLength = samples.length * 2;
    final ByteData pcm = ByteData(dataLength);
    for (int i = 0; i < samples.length; i++) {
      double v = samples[i];
      if (v > 1.0) v = 1.0;
      if (v < -1.0) v = -1.0;
      pcm.setInt16(i * 2, (v * 32767).round(), Endian.little);
    }

    final int byteRate = sampleRate * _bitsPerSample ~/ 8;
    final ByteData header = ByteData(44);
    void ascii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk 长度
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // 单声道
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, _bitsPerSample ~/ 8, Endian.little); // blockAlign
    header.setUint16(34, _bitsPerSample, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, dataLength, Endian.little);

    final BytesBuilder builder = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm.buffer.asUint8List());
    return builder.takeBytes();
  }

  // ------------------------------------------------------------------ 内部

  /// 与原版 Web Audio 增益包络一一对应的振幅函数。
  static double _envelope(double t, double duration, double volume) {
    if (t <= 0 || t >= duration) return 0;
    if (t < attackSeconds) {
      return volume * (t / attackSeconds);
    }
    final double span = duration - attackSeconds;
    if (span <= 0) return volume;
    final double k = (t - attackSeconds) / span;
    return volume * math.pow(decayFloor / volume, k).toDouble();
  }
}
