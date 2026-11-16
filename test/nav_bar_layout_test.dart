import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:way/ui/widgets/nav_bar.dart';

const _tabs = [
  FloatingNavTab(
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield_rounded,
      label: 'Главная'),
  FloatingNavTab(
      icon: Icons.dns_outlined, activeIcon: Icons.dns_rounded, label: 'Серверы'),
  FloatingNavTab(
      icon: Icons.terminal_outlined,
      activeIcon: Icons.terminal_rounded,
      label: 'Логи'),
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
        bottomNavigationBar: FloatingNavBar(
          currentIndex: 0,
          onTap: (_) {},
          tabs: _tabs,
        ),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final view = tester.view;
    final windowH = view.physicalSize.height / view.devicePixelRatio;

    final barRect = tester.getRect(find.byType(FloatingNavBar));
    expect(barRect.height, closeTo(64 + 12 + 4, 0.5),
        reason: 'bar total height should be 64 content + 16 padding, '
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
              child: FloatingNavBar(
                currentIndex: 0,
                onTap: (_) {},
                tabs: _tabs,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(FloatingNavBar));
    expect(barRect.height, closeTo(400, 0.5),
        reason: 'host gave 400dp — the bar must fill exactly what the host '
            'bounded, never more');

    final bodyRect = tester.getRect(find.byKey(const Key('body-marker')));
    expect(bodyRect.height, greaterThan(0));
  });

  testWidgets('tapping tabs and the settings circle switches destinations',
      (tester) async {
    int selected = 0;
    late StateSetter setState;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setter) {
        setState = setter;
        return MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            bottomNavigationBar: FloatingNavBar(
              currentIndex: selected,
              onTap: (i) => setState(() => selected = i),
              tabs: _tabs,
            ),
          ),
        );
      },
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final barRectBefore = tester.getRect(find.byType(FloatingNavBar));
    await tester.tap(find.text('Логи'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(selected, 2);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(selected, 3);

    final barRectAfter = tester.getRect(find.byType(FloatingNavBar));
    expect(barRectAfter.height, closeTo(barRectBefore.height, 0.5));
  });
}
