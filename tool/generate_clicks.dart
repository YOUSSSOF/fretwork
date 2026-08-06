// Generates the metronome click assets.
//
// The clicks are synthesised rather than shipped as recordings so the repo has
// no third-party audio in it and the sounds can be re-tuned by editing numbers.
// Run with: dart run tool/generate_clicks.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _sampleRate = 44100;

void main() {
  // Three tones per sound, not two. The downbeat has to be distinguishable
  // from beats 2-4, and beats from the subdivisions between them — otherwise
  // there is no way to hear where the bar restarts, which is the whole point
  // of a click.
  //
  // Pitch does the work rather than volume: an octave between the downbeat and
  // the subdivisions is unmistakable even at low listening levels, whereas a
  // loud accent just becomes a loud click.
  final specs = <String, _Click>{
    'click_down': const _Click(frequency: 1800, decay: 0.034, noise: 0.12),
    'click_beat': const _Click(frequency: 1200, decay: 0.030, noise: 0.10),
    'click_sub': const _Click(
      frequency: 900,
      decay: 0.024,
      noise: 0.06,
      amplitude: 0.55,
    ),
    'woodblock_down': const _Click(frequency: 1400, decay: 0.060, noise: 0.05),
    'woodblock_beat': const _Click(frequency: 950, decay: 0.055, noise: 0.04),
    'woodblock_sub': const _Click(
      frequency: 700,
      decay: 0.045,
      noise: 0.03,
      amplitude: 0.55,
    ),
    'beep_down': const _Click(frequency: 1760, decay: 0.075, noise: 0),
    'beep_beat': const _Click(frequency: 1175, decay: 0.070, noise: 0),
    'beep_sub': const _Click(
      frequency: 880,
      decay: 0.055,
      noise: 0,
      amplitude: 0.55,
    ),
  };

  Directory('assets/audio').createSync(recursive: true);
  for (final entry in specs.entries) {
    final file = File('assets/audio/${entry.key}.wav');
    file.writeAsBytesSync(_wav(entry.value.render()));
    stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  }
}

class _Click {
  const _Click({
    required this.frequency,
    required this.decay,
    required this.noise,
    this.amplitude = 0.85,
  });

  final double frequency;

  /// Seconds to silence. Short: a click that rings is a click you cannot place
  /// precisely against your own playing.
  final double decay;

  /// A little noise at the attack gives the transient something to bite on.
  final double noise;

  /// Subdivisions sit back a little so the pulse still reads as the pulse.
  final double amplitude;

  Float64List render() {
    final length = (decay * _sampleRate).round();
    final samples = Float64List(length);
    final random = math.Random(7);

    for (var i = 0; i < length; i++) {
      final t = i / _sampleRate;
      // Exponential decay, steep enough that the tail is inaudible well before
      // the next beat even at 260 bpm.
      final envelope = math.exp(-t / (decay / 5));
      final tone = math.sin(2 * math.pi * frequency * t);
      final attack = noise == 0
          ? 0.0
          : (random.nextDouble() * 2 - 1) * noise * math.exp(-t / 0.002);
      samples[i] = ((tone + attack) * envelope * amplitude).clamp(-1.0, 1.0);
    }
    return samples;
  }
}

Uint8List _wav(Float64List samples) {
  const channels = 1;
  const bitsPerSample = 16;
  const byteRate = _sampleRate * channels * bitsPerSample ~/ 8;
  const blockAlign = channels * bitsPerSample ~/ 8;
  final dataBytes = samples.length * 2;

  final builder = BytesBuilder();
  void writeString(String value) => builder.add(value.codeUnits);
  void writeUint32(int value) => builder.add(
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little),
  );
  void writeUint16(int value) => builder.add(
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little),
  );

  writeString('RIFF');
  writeUint32(36 + dataBytes);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(channels);
  writeUint32(_sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);
  writeString('data');
  writeUint32(dataBytes);

  final pcm = Uint8List(dataBytes);
  final view = pcm.buffer.asByteData();
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, (samples[i] * 32767).round(), Endian.little);
  }
  builder.add(pcm);

  return builder.toBytes();
}
