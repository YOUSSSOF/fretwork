/// Injectable time source.
///
/// Every piece of date logic in the app — day rollover, streaks, routine
/// generation — goes through this rather than calling `DateTime.now()`
/// directly, so tests can pin a date instead of being written around whatever
/// day they happen to run on.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value;

  void advance(Duration by) => _now = _now.add(by);
}
