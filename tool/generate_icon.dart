// Draws the app icon.
//
// Generated rather than hand-drawn so the mark stays in step with the palette
// in app_colors.dart, and so there is no binary in the repo whose provenance
// nobody can explain. Run with: dart run tool/generate_icon.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int _size = 1024;

// Dark crimson, matching AccentPalette.darkCrimson.
const int _background = 0xFF141010;
const int _deep = 0xFF3B070A;
const int _accent = 0xFF8B1E24;
const int _string = 0xFFE8DEDC;

void main() {
  final icon = img.Image(width: _size, height: _size, numChannels: 4);

  _paintBackground(icon);
  _paintFrets(icon);
  _paintStrings(icon);
  _paintMarker(icon);

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(icon));

  // The adaptive foreground sits on a solid background layer, so it carries no
  // background of its own and is inset for Android's safe zone.
  final foreground = img.Image(width: _size, height: _size, numChannels: 4);
  _paintFrets(foreground, inset: 0.30);
  _paintStrings(foreground, inset: 0.30);
  _paintMarker(foreground, inset: 0.30);
  File(
    'assets/icon/foreground.png',
  ).writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln('wrote assets/icon/icon.png and foreground.png');
}

img.ColorRgba8 _rgba(int argb, [double opacity = 1]) => img.ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (((argb >> 24) & 0xFF) * opacity).round(),
);

/// A vertical wash from the deep accent to the near-black ground.
void _paintBackground(img.Image image) {
  for (var y = 0; y < _size; y++) {
    final t = y / _size;
    final colour = img.ColorRgba8(
      _lerpChannel(_deep, _background, t, 16),
      _lerpChannel(_deep, _background, t, 8),
      _lerpChannel(_deep, _background, t, 0),
      255,
    );
    img.drawLine(image, x1: 0, y1: y, x2: _size, y2: y, color: colour);
  }
}

int _lerpChannel(int from, int to, double t, int shift) {
  final a = (from >> shift) & 0xFF;
  final b = (to >> shift) & 0xFF;
  return (a + (b - a) * t).round();
}

/// Frets: vertical bars whose spacing narrows toward the right, the way frets
/// actually do.
void _paintFrets(img.Image image, {double inset = 0.18}) {
  final left = (_size * inset).round();
  final right = _size - left;
  final top = (_size * (inset + 0.06)).round();
  final bottom = _size - top;
  final span = right - left;

  // Real fret ratios: the nth fret sits at 1 - 2^(-n/12) along the string.
  // Normalising by the 12th fret's position stretches one octave across the
  // full width, so the mark reads as a fingerboard rather than a generic grid.
  const octave = 0.5; // 1 - 2^(-12/12)
  for (final fret in [0, 2, 4, 6, 8, 10, 12]) {
    final position = (1 - math.pow(2, -fret / 12).toDouble()) / octave;
    final width = fret == 0 ? 20 : 9;
    final x = left + (span * position).round() - (fret == 12 ? width : 0);
    img.fillRect(
      image,
      x1: x,
      y1: top,
      x2: x + width,
      y2: bottom,
      color: _rgba(_accent, fret == 0 ? 1.0 : 0.5),
    );
  }
}

/// Strings: horizontal lines, thinning from bass to treble.
void _paintStrings(img.Image image, {double inset = 0.18}) {
  final left = (_size * inset).round();
  final right = _size - left;
  final top = (_size * (inset + 0.06)).round();
  final bottom = _size - top;
  final gap = (bottom - top) / 5;

  for (var i = 0; i < 6; i++) {
    final y = (top + gap * i).round();
    final thickness = 10 - i;
    img.fillRect(
      image,
      x1: left,
      y1: y - thickness ~/ 2,
      x2: right,
      y2: y + thickness ~/ 2,
      color: _rgba(_string, 0.86),
    );
  }
}

/// The position dot, in the accent, where a 5th-fret marker would sit.
void _paintMarker(img.Image image, {double inset = 0.18}) {
  final left = (_size * inset).round();
  final right = _size - left;
  // Between the middle pair of strings, around where a 5th-fret dot sits.
  final centreX = left + ((right - left) * 0.36).round();
  img.fillCircle(
    image,
    x: centreX,
    y: _size ~/ 2,
    radius: (_size * 0.055).round(),
    color: _rgba(_accent),
  );
}
