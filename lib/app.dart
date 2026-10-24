import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'state/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/app_background.dart';
import 'ui/widgets/nav_bar.dart';
import 'ui/widgets/onboarding.dart';
import 'ui/widgets/update_dialog.dart';

class WayApp extends StatelessWidget {
  const WayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final l10n = L10n(state.effectiveLocale);
        return L10nScope(
          data: l10n,
          child: DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              final useDynamic = state.dynamicColors;
              return MaterialApp(
                title: 'Way',
                debugShowCheckedModeBanner: false,
                themeMode: _mode(state.themeMode),
                theme: WayTheme.light(useDynamic ? lightDynamic : null),
                darkTheme: WayTheme.dark(useDynamic ? darkDynamic : null),
                builder: (context, child) => Stack(
                  children: [
                    const Positioned.fill(child: AppBackground()),
                    child ?? const SizedBox.shrink(),
                  ],
                ),
                home: state.onboardingDone
                    ? const WayShell()
                    : const OnboardingScreen(),
              );
            },
          ),
        );
      },
    );
  }

  ThemeMode _mode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class WayShell extends StatefulWidget {
  const WayShell({super.key});

  @override
  State<WayShell> createState() => _WayShellState();
}

class _WayShellState extends State<WayShell> {
  int _index = 0;
  bool _updateShown = false;
  bool _batteryShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    final update = state.pendingUpdate;
    if (!_updateShown && update != null) {
      _updateShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showUpdateDialog(context, update);
        if (mounted) context.read<AppState>().clearPendingUpdate();
      });
    }
    if (state.pendingBatteryAsk && !_batteryShown) {
      _batteryShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final l10n = L10nScope.of(context);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.batteryDialogTitle),
            content: Text(l10n.batteryDialogText),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.later),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<AppState>().requestBatteryIgnore();
                },
                child: Text(l10n.batteryAsk),
              ),
            ],
          ),
        );
        if (mounted) context.read<AppState>().consumeBatteryAsk();
      });
    }
    if (state.pendingTab >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _index = state.pendingTab);
        state.consumeDeepLinkTab();
        final l10n = L10nScope.of(context);
        final message = state.lastImportWasSub
            ? l10n.deepLinkSub
            : state.lastImportCount > 0
                ? l10n.deepLinkProfiles(state.lastImportCount)
                : l10n.deepLinkInvalid;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), width: 320, behavior: SnackBarBehavior.floating),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final screens = [
      const HomeScreen(),
      const ServersScreen(),
      const LogsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Easing.emphasizedDecelerate,
        switchOutCurve: Easing.emphasizedAccelerate,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: screens[_index],
        ),
      ),
      bottomNavigationBar: ExpressiveNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        destinations: [
          ExpressiveNavDestination(
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield_rounded,
            label: l10n.navHome,
          ),
          ExpressiveNavDestination(
            icon: Icons.dns_outlined,
            activeIcon: Icons.dns_rounded,
            label: l10n.navServers,
          ),
          ExpressiveNavDestination(
            icon: Icons.terminal_outlined,
            activeIcon: Icons.terminal_rounded,
            label: l10n.navLogs,
          ),
          ExpressiveNavDestination(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
