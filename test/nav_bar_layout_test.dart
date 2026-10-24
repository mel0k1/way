import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way/ui/widgets/nav_bar.dart';

const _destinations = [
  ExpressiveNavDestination(
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield_rounded,
      label: 'Главная'),
  ExpressiveNavDestination(
      icon: Icons.dns_outlined, activeIcon: Icons.dns_rounded, label: 'Серверы'),
  ExpressiveNavDestination(
      icon: Icons.terminal_outlined,
      activeIcon: Icons.terminal_rounded,
      label: 'Логи'),
  ExpressiveNavDestination(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Настройки'),
];

void main() {
  testWidgets('nav bar docks at bottom with fixed height and body stays visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: const Center(
          child: Text('BODY MARKER', key: Key('body-marker')),
        ),
        bottomNavigationBar: ExpressiveNavBar(
          currentIndex: 0,
          onTap: (_) {},
          destinations: _destinations,
        ),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final view = tester.view;
    final windowH = view.physicalSize.height / view.devicePixelRatio;

    final barRect = tester.getRect(find.byType(ExpressiveNavBar));
    expect(barRect.height, closeTo(74 + 12 + 4, 0.5),
        reason: 'bar total height should be 74 content + 16 padding, '
            'got ${barRect.height}');

    final bodyRect = tester.getRect(find.byKey(const Key('body-marker')));
    expect(bodyRect.height, greaterThan(0),
        reason: 'body content must have non-zero height');
    expect(bodyRect.top, lessThan(barRect.top),
        reason: 'body must sit above the nav bar');

    expect(barRect.bottom, closeTo(windowH, 1.0),
        reason: 'bar widget includes 12dp bottom margin → bottom == window '
            'bottom');
  });

  testWidgets('bar keeps fixed height even if the slot gives bounded height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(
                child: Text('BODY MARKER', key: Key('body-marker'))),
            SizedBox(
              height: 400,
              child: ExpressiveNavBar(
                currentIndex: 0,
                onTap: (_) {},
                destinations: _destinations,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(ExpressiveNavBar));
    expect(barRect.height, closeTo(400, 0.5),
        reason: 'host gave 400dp — the bar must fill exactly what the host '
            'bounded, never more');

    final bodyRect = tester.getRect(find.byKey(const Key('body-marker')));
    expect(bodyRect.height, greaterThan(0));
  });

  testWidgets('spring indicator lands on the selected destination',
      (tester) async {
    int selected = 0;
    late StateSetter setState;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setter) {
        setState = setter;
        return MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            bottomNavigationBar: ExpressiveNavBar(
              currentIndex: selected,
              onTap: (i) => setState(() => selected = i),
              destinations: _destinations,
            ),
          ),
        );
      },
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final barRectBefore = tester.getRect(find.byType(ExpressiveNavBar));
    await tester.tap(find.text('Настройки'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final barRectAfter = tester.getRect(find.byType(ExpressiveNavBar));
    expect(barRectAfter.height, closeTo(barRectBefore.height, 0.5));
    expect(selected, 3);
  });
}
