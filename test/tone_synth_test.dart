import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:setbeat_flutter/services/tone_synth.dart';

/// 从 WAV 字节里解出 16bit PCM 采样，便于断言波形特征。
Int16List decodePcm(Uint8List wav) {
  expect(wav.length, greaterThanOrEqualTo(44));
  expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
  expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');

  final ByteData view = ByteData.sublistView(wav);
  final int channels = view.getUint16(22, Endian.little);
  final int sampleRate = view.getUint32(24, Endian.little);
  final int bits = view.getUint16(34, Endian.little);
  expect(channels, 1);
  expect(sampleRate, ToneSynth.sampleRate);
  expect(bits, 16);

  final int dataLength = view.getUint32(40, Endian.little);
  expect(wav.length, 44 + dataLength);
  expect(dataLength % 2, 0);

  final int count = dataLength ~/ 2;
  final Int16List out = Int16List(count);
  for (int i = 0; i < count; i++) {
    out[i] = view.getInt16(44 + i * 2, Endian.little);
  }
  return out;
}

void main() {
  group('WAV 容器', () {
    test('头部字段与长度自洽', () {
      final Uint8List wav = ToneSynth.tone(
          frequency: 440, seconds: 1.0, volume: 0.3);
      final Int16List pcm = decodePcm(wav);
      expect(pcm.length, ToneSynth.sampleRate); // 1 秒
      final ByteData view = ByteData.sublistView(wav);
      // RIFF 块大小 = 36 + data
      expect(view.getUint32(4, Endian.little), 36 + pcm.length * 2);
    });
  });

  group('单音合成', () {
    test('440Hz 一秒内约有 880 个过零点', () {
      final Int16List pcm = decodePcm(ToneSynth.tone(
          frequency: 440, seconds: 1.0, volume: 0.3));
      int crossings = 0;
      for (int i = 1; i < pcm.length; i++) {
        if ((pcm[i - 1] < 0 && pcm[i] >= 0)) crossings++;
      }
      // 正弦波每个周期向上过零一次，440Hz -> 440 次，允许边界误差
      expect(crossings, inInclusiveRange(435, 445));
    });

    test('峰值不超过设定音量（含 16bit 量化误差）', () {
      final Int16List pcm = decodePcm(ToneSynth.tone(
          frequency: 880, seconds: 0.5, volume: 0.3));
      int peak = 0;
      for (final int v in pcm) {
        final int a = v.abs();
        if (a > peak) peak = a;
      }
      final double peakNorm = peak / 32767.0;
      // 指数衰减包络下，峰值出现在起音结束后不久，应略低于 0.3
      expect(peakNorm, greaterThan(0.25));
      expect(peakNorm, lessThanOrEqualTo(0.32));
    });

    test('起音段是线性爬升（防爆音）', () {
      // 250Hz 的四分之一周期恰好是 1ms，因此 t=1/3/5ms 处正弦值均为 ±1，
      // 采样值能直接反映包络大小，不受波形相位干扰。
      final Int16List pcm = decodePcm(
          ToneSynth.tone(frequency: 250, seconds: 0.2, volume: 0.5));
      double norm(int index) => pcm[index].abs() / 32767.0;

      expect(norm(44), closeTo(0.5 * 1 / 10, 0.01)); // t=1ms  -> 包络 10%
      expect(norm(132), closeTo(0.5 * 3 / 10, 0.01)); // t=3ms -> 包络 30%
      expect(norm(220), closeTo(0.5 * 5 / 10, 0.01)); // t=5ms -> 包络 50%
    });

    test('结尾衰减到近似静音', () {
      final Int16List pcm = decodePcm(ToneSynth.tone(
          frequency: 880, seconds: 0.3, volume: 0.4));
      final int lastWindow = pcm.length - 220; // 最后 5ms
      int peak = 0;
      for (int i = lastWindow; i < pcm.length; i++) {
        final int a = pcm[i].abs();
        if (a > peak) peak = a;
      }
      expect(peak / 32767.0, lessThan(0.02));
    });
  });

  group('旋律合成', () {
    test('与原版 5 秒结束旋律等长，且多音叠加不削顶', () {
      final Int16List pcm = decodePcm(ToneSynth.melody(SoundMelodyFixtures
          .originalFinish));
      expect(pcm.length, (5.0 * ToneSynth.sampleRate).round()); // 220500
      int peak = 0;
      for (final int v in pcm) {
        final int a = v.abs();
        if (a > peak) peak = a;
      }
      expect(peak / 32767.0, lessThanOrEqualTo(0.95));
      // 各音错峰且指数衰减，叠加后实测峰值约 0.41，远低于削顶线
      expect(peak / 32767.0, greaterThan(0.35));
    });

    test('空旋律产出极短但合法的 WAV', () {
      final Int16List pcm = decodePcm(ToneSynth.melody(const <ToneEvent>[]));
      expect(pcm.length, 1);
    });
  });
}

/// 把结束旋律单独提出来供测试复用，数值与 `SoundService.finishMelody` 相同。
class SoundMelodyFixtures {
  static const List<ToneEvent> originalFinish = <ToneEvent>[
    ToneEvent(frequency: 523.25, startSeconds: 0.0, durationSeconds: 0.5),
    ToneEvent(frequency: 659.25, startSeconds: 0.35, durationSeconds: 0.5),
    ToneEvent(frequency: 783.99, startSeconds: 0.7, durationSeconds: 0.5),
    ToneEvent(frequency: 1046.50, startSeconds: 1.05, durationSeconds: 0.8),
    ToneEvent(frequency: 783.99, startSeconds: 1.9, durationSeconds: 0.4),
    ToneEvent(frequency: 880.00, startSeconds: 2.3, durationSeconds: 0.4),
    ToneEvent(frequency: 1046.50, startSeconds: 2.7, durationSeconds: 0.9),
    ToneEvent(frequency: 1318.50, startSeconds: 3.2, durationSeconds: 1.8),
  ];
}
