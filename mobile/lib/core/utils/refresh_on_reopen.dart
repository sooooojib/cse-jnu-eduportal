import 'package:flutter/widgets.dart';

/// S2-13: screens kept alive in tabs never reloaded when shown again. The
/// app shell pings [RefreshBus] when the app returns to the front or a tab
/// is selected; screens using [RefreshOnReopen] reload quietly, at most once
/// per [RefreshOnReopen.minGap] (free-plan reads).
class RefreshBus {
  RefreshBus._();
  static final ValueNotifier<int> ticks = ValueNotifier<int>(0);
  static void ping() => ticks.value++;
}

mixin RefreshOnReopen<T extends StatefulWidget> on State<T> {
  DateTime _lastLoad = DateTime.now();

  Duration get minGap => const Duration(seconds: 60);

  /// Reload quietly (keep showing the current data while loading).
  void onReopened();

  /// Call after a load to restart the minimum gap.
  void markLoaded() => _lastLoad = DateTime.now();

  void _onTick() {
    if (!mounted || DateTime.now().difference(_lastLoad) < minGap) return;
    _lastLoad = DateTime.now();
    onReopened();
  }

  @override
  void initState() {
    super.initState();
    RefreshBus.ticks.addListener(_onTick);
  }

  @override
  void dispose() {
    RefreshBus.ticks.removeListener(_onTick);
    super.dispose();
  }
}
