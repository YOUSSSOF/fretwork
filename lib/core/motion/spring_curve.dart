import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Wraps a [SpringSimulation] so a spring can be used anywhere a [Curve] is
/// accepted — including implicit animations, which is most of the app.
///
/// A [Curve] is sampled over a normalised 0..1 input, so the simulation has to
/// be given a wall-clock duration. [settleDuration] is measured once at
/// construction by advancing the simulation until it reports done, which means
/// callers can pass it straight to an `AnimationController` and get the spring's
/// natural timing rather than an arbitrary duration that clips the tail.
class SpringCurve extends Curve {
  SpringCurve(this.description, {this.initialVelocity = 0})
    : _simulation = SpringSimulation(description, 0, 1, initialVelocity) {
    _settleSeconds = _measureSettleSeconds(_simulation);
  }

  final SpringDescription description;
  final double initialVelocity;
  final SpringSimulation _simulation;
  late final double _settleSeconds;

  Duration get settleDuration =>
      Duration(microseconds: (_settleSeconds * 1e6).round());

  @override
  double transformInternal(double t) => _simulation.x(t * _settleSeconds);

  /// Steps the simulation on a 1 ms grid until it settles, capped at 4 s so a
  /// pathological (undamped) description cannot hang the app.
  static double _measureSettleSeconds(SpringSimulation simulation) {
    const step = 0.001;
    const cap = 4.0;
    var time = 0.0;
    while (time < cap) {
      time += step;
      if (simulation.isDone(time)) break;
    }
    return time;
  }
}
