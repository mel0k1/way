import 'package:flutter/material.dart';

import '../motion.dart';

class FloatingNavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingNavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavTab> tabs;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  static const _barHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final settingsIndex = tabs.length;
    final settingsSelected = currentIndex == settingsIndex;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: SizedBox(
          height: _barHeight,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  Expanded(
                    child: _Pill(
                      child: Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: _PillItem(
                                tab: tabs[i],
                                selected: i == currentIndex,
                                onTap: () => onTap(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleButton(
                    selected: settingsSelected,
                    icon: settingsSelected
                        ? Icons.settings_rounded
                        : Icons.settings_outlined,
                    onTap: () => onTap(settingsIndex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;

  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: dark ? 0.36 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer
                  .withValues(alpha: dark ? 0.86 : 0.80),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final FloatingNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _PillItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showLabels = MediaQuery.widthOf(context) >= 420;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: AnimatedContainer(
        duration: WayMotion.medium,
        curve: WayMotion.emphasized,
        margin: const EdgeInsets.all(8),
        padding: EdgeInsets.symmetric(
          horizontal: selected && showLabels ? 12 : 0,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: WayMotion.fast,
              switchInCurve: WayMotion.springy,
              switchOutCurve: WayMotion.emphasizedIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: Icon(
                selected ? tab.activeIcon : tab.icon,
                key: ValueKey(selected),
                size: 24,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            AnimatedSize(
              duration: WayMotion.medium,
              curve: WayMotion.emphasized,
              alignment: Alignment.centerLeft,
              child: selected && showLabels
                  ? Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      key: ValueKey(selected),
      tween: Tween(begin: selected ? 0.82 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutBack,
      builder: (context, t, child) =>
          Transform.scale(scale: t, child: child),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: dark ? 0.36 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: WayMotion.medium,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? scheme.secondaryContainer.withValues(
                          alpha: dark ? 0.88 : 0.84,
                        )
                      : scheme.surfaceContainer.withValues(
                          alpha: dark ? 0.86 : 0.80,
                        ),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
