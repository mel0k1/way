import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n.dart';
import 'state/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/logs_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/app_background.dart';
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
          child: MaterialApp(
            title: 'Way',
            debugShowCheckedModeBanner: false,
            themeMode: _mode(state.themeMode),
            theme: _theme(ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D53))),
            darkTheme: _theme(ColorScheme.fromSeed(
              seedColor: const Color(0xFF9BDDB4),
              brightness: Brightness.dark,
            )),
            builder: (context, child) => Stack(
              children: [
                const Positioned.fill(child: AppBackground()),
                child ?? const SizedBox.shrink(),
              ],
            ),
            home: state.onboardingDone
                ? const WayShell()
                : const OnboardingScreen(),
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

  ThemeData _theme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
      ),
    );
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
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: screens[_index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dns_outlined),
            selectedIcon: const Icon(Icons.dns_rounded),
            label: l10n.navServers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.terminal_outlined),
            selectedIcon: const Icon(Icons.terminal_rounded),
            label: l10n.navLogs,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
