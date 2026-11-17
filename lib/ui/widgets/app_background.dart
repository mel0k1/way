import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'wallpaper_backdrop.dart' show wallpaperFileExists;

/// Ambient gradient wash: four radial gradients drifting at ~9 fps on a
/// timer, hidden entirely behind a wallpaper, paused while the app is
/// hidden, honoring the system "remove animations" setting.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with WidgetsBindingObserver {
  static const int _periodMs = 110;
  static const _loop = Duration(seconds: 28);

  Timer? _drift;
  double _t = 0;
  bool _appPaused = true;
  bool _animationsOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused = state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive;
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsOff = MediaQuery.disableAnimationsOf(context);
    if (_animationsOff) _t = 0;
    _syncTimer();
  }

  void _syncTimer() {
    final need = !_appPaused && !_animationsOff && !_hiddenByWallpaper;
    if (need && _drift == null) {
      _drift = Timer.periodic(
        const Duration(milliseconds: _periodMs),
        (_) {
          if (!mounted) return;
          setState(() => _t = (_t + _periodMs / _loop.inMilliseconds) % 1.0);
        },
      );
    } else if (!need && _drift != null) {
      _drift?.cancel();
      _drift = null;
    }
  }

  bool _hiddenByWallpaper = false;

  @override
  Widget build(BuildContext context) {
    // Same existence check as WallpaperBackdrop: the wash must hide exactly
    // when the wallpaper is really drawn, else a stale path leaves black.
    _hiddenByWallpaper =
        wallpaperFileExists(context.watch<AppState>().wallpaperPath);
    _syncTimer();

    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    if (_hiddenByWallpaper) return const SizedBox.shrink();

    final t = _animationsOff ? 0.0 : _t;
    final o1 = math.sin(t * 2 * math.pi);
    final o2 = math.sin((t + 0.38) * 2 * math.pi);

    return RepaintBoundary(
      child: ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: [
            _wash(
              center: Alignment(1.15 + 0.14 * o1, -1.05 + 0.12 * o2),
              radius: 1.45,
              color: scheme.primary,
              alpha: dark ? 0.20 : 0.12,
            ),
            _wash(
              center: Alignment(-1.25 + 0.16 * o2, 1.15 + 0.13 * o1),
              radius: 1.35,
              color: scheme.tertiary,
              alpha: dark ? 0.17 : 0.10,
            ),
            _wash(
              center: const Alignment(-0.85, -0.95),
              radius: 0.95,
              color: scheme.secondary,
              alpha: dark ? 0.07 : 0.05,
            ),
            _wash(
              center: Alignment(0.9 + 0.1 * o2, 1.2 - 0.08 * o1),
              radius: 0.9,
              color: scheme.primary,
              alpha: dark ? 0.10 : 0.06,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wash({
    required Alignment center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
