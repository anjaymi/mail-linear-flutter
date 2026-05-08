import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

abstract final class SoundService {
  static const _channel = MethodChannel('outlook_mail_manager/window');
  static const _sampleRate = 44100;
  static final _files = <String, Future<File>>{};

  static const options = [
    SoundOption('mail', '清脆邮件', '双音阶新邮件提示'),
    SoundOption('soft', '轻提示', '低打扰柔和提示'),
    SoundOption('notice', '注意提示', '需要处理时使用'),
    SoundOption('success', '完成提示', '同步完成反馈'),
    SoundOption('urgent', '强提醒', '验证码或异常提醒'),
  ];

  static SoundOption optionOf(String value) {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return options.first;
  }

  static Future<void> play(String value) async {
    final option = optionOf(value);
    try {
      final file = await _toneFile(option.value);
      await _channel.invokeMethod<void>('playSoundFile', file.path);
    } on MissingPluginException {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<File> _toneFile(String tone) {
    return _files.putIfAbsent(tone, () async {
      final directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'OutlookMailManager${Platform.pathSeparator}sounds',
      );
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      final file = File(
        '${directory.path}${Platform.pathSeparator}$tone-v1.wav',
      );
      final bytes = _wavFor(_recipe(tone));
      await file.writeAsBytes(bytes, flush: true);
      return file;
    });
  }

  static List<_ToneSegment> _recipe(String tone) {
    return switch (tone) {
      'soft' => const [
        _ToneSegment(659.25, 120, gain: 0.20),
        _ToneSegment.silence(26),
        _ToneSegment(880.00, 120, gain: 0.18),
      ],
      'notice' => const [
        _ToneSegment(739.99, 82, gain: 0.25),
        _ToneSegment.silence(34),
        _ToneSegment(739.99, 82, gain: 0.25),
        _ToneSegment.silence(24),
        _ToneSegment(987.77, 110, gain: 0.22),
      ],
      'success' => const [
        _ToneSegment(523.25, 72, gain: 0.22),
        _ToneSegment(659.25, 82, gain: 0.24),
        _ToneSegment(783.99, 132, gain: 0.22),
      ],
      'urgent' => const [
        _ToneSegment(987.77, 72, gain: 0.30),
        _ToneSegment.silence(42),
        _ToneSegment(987.77, 72, gain: 0.30),
        _ToneSegment.silence(42),
        _ToneSegment(1318.51, 112, gain: 0.25),
      ],
      _ => const [
        _ToneSegment(880.00, 76, gain: 0.24),
        _ToneSegment.silence(28),
        _ToneSegment(1174.66, 126, gain: 0.22),
      ],
    };
  }

  static Uint8List _wavFor(List<_ToneSegment> recipe) {
    final totalSamples = recipe.fold<int>(
      0,
      (sum, segment) => sum + segment.sampleCount,
    );
    final dataSize = totalSamples * 2;
    final bytes = ByteData(44 + dataSize);
    _writeAscii(bytes, 0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');
    _writeAscii(bytes, 12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, _sampleRate, Endian.little);
    bytes.setUint32(28, _sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    _writeAscii(bytes, 36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (final segment in recipe) {
      for (var i = 0; i < segment.sampleCount; i++) {
        final sample = segment.silence ? 0 : _sample(segment, i);
        bytes.setInt16(offset, sample, Endian.little);
        offset += 2;
      }
    }
    return bytes.buffer.asUint8List();
  }

  static int _sample(_ToneSegment segment, int index) {
    final t = index / _sampleRate;
    final wave = math.sin(2 * math.pi * segment.frequency * t);
    final gloss = math.sin(2 * math.pi * segment.frequency * 2 * t) * 0.18;
    final value = (wave + gloss) * segment.gain * _envelope(index, segment);
    return (value * 32767).clamp(-32768, 32767).round();
  }

  static double _envelope(int index, _ToneSegment segment) {
    final count = segment.sampleCount;
    final attack = math.min(count, (_sampleRate * 0.012).round());
    final release = math.min(count, (_sampleRate * 0.038).round());
    var value = 1.0;
    if (attack > 0 && index < attack) {
      value *= index / attack;
    }
    final remaining = count - index;
    if (release > 0 && remaining < release) {
      value *= remaining / release;
    }
    return value.clamp(0.0, 1.0);
  }

  static void _writeAscii(ByteData bytes, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }
}

class SoundOption {
  const SoundOption(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;
}

class _ToneSegment {
  const _ToneSegment(this.frequency, this.durationMs, {this.gain = 0.24})
    : silence = false;

  const _ToneSegment.silence(this.durationMs)
    : frequency = 0,
      gain = 0,
      silence = true;

  final double frequency;
  final int durationMs;
  final double gain;
  final bool silence;

  int get sampleCount => (SoundService._sampleRate * durationMs / 1000).round();
}
