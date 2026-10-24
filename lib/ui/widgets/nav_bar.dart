import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// One destination for [ExpressiveNavBar].
class ExpressiveNavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const ExpressiveNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Material 3 Expressive navigation bar.
///
/// A floating stadium bar with a pill indicator that glides between
/// destinations using real spring physics (interruptible, velocity-carrying —
/// the Flutter counterpart of MotionScheme.expressive() spatial springs),
/// squishes while moving fast, and pops the active icon with an overshoot
/// bounce. Icons crossfade outlined → filled.
class ExpressiveNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ExpressiveNavDestination> destinations;

  const ExpressiveNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  @override
  State<ExpressiveNavBar> createState() => _ExpressiveNavBarState();
}

class _ExpressiveNavBarState extends State<ExpressiveNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mover =
      AnimationController.unbounded(vsync: this);

  /// Expressive spatial spring: dampingRatio 0.68 → a lively overshoot.
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.68,
  );

  double _lastWidth = 0;
  bool _snapped = false;

  double get _pillSize => 68.0;

  double _targetX(double width, int index) =>
      width / widget.destinations.length * (index + 0.5);

  void _snapTo(double width) {
    _mover.value = _targetX(width, widget.currentIndex);
    _lastWidth = width;
    _snapped = true;
  }

  @override
  void didUpdateWidget(ExpressiveNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && _snapped) {
      final target = _targetX(_lastWidth, widget.currentIndex);
      _mover.animateWith(SpringSimulation(
        _spring,
        _mover.value,
        target,
        _mover.velocity,
      ));
    }
  }

  @override
  void dispose() {
    _mover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        // Fixed-height wrapper: the bar always reports exactly 74 + 16 dp to
        // its parent slot, whatever constraints the slot provides. An
        // expanding Center here would fill any bounded slot (e.g. if a host
        // scaffold ever hands it body-like constraints) and swallow the body.
        child: SizedBox(
          height: 74,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                height: 74,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer.withValues(
                    alpha: dark ? 0.96 : 0.98,
                  ),
                  borderRadius: BorderRadius.circular(37),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(
                        alpha: dark ? 0.36 : 0.12,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    if (!_snapped || w != _lastWidth) {
                      // First layout or window resize: snap without animation.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _snapTo(w));
                      });
                    }
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Sliding, squishing pill indicator.
                        if (_snapped)
                          AnimatedBuilder(
                            animation: _mover,
                            builder: (context, _) {
                              final x = _mover.value.clamp(0.0, w);
                              final v = _mover.velocity.abs();
                              final stretch = (1.0 + v / 3200)
                                  .clamp(1.0, 1.22);
                              final half = _pillSize * stretch / 2;
                              return Positioned(
                                left: (x - half).clamp(
                                  5.0,
                                  math.max(5.0, w - half * 2 - 5),
                                ),
                                top: (74 - 46) / 2,
                                child: Transform.scale(
                                  scaleX: stretch,
                                  scaleY: 2.0 - stretch,
                                  child: Container(
                                    width: _pillSize,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer,
                                      borderRadius:
                                          BorderRadius.circular(23),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        Row(
                          children: [
                            for (var i = 0;
                                i < widget.destinations.length;
                                i++)
                              Expanded(
                                child: _NavDestination(
                                  destination: widget.destinations[i],
                                  selected: i == widget.currentIndex,
                                  onTap: () => widget.onTap(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  final ExpressiveNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scheme_ = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(selected),
            tween: Tween(begin: selected ? 0.78 : 1.0, end: 1.0),
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutBack,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: SizedBox(
              width: 44,
              height: 30,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: Icon(
                  selected ? destination.activeIcon : destination.icon,
                  key: ValueKey(selected),
                  size: 25,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: scheme_.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
