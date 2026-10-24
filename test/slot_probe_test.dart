import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('probe: what constraints does the bottomNavigationBar slot give',
      (tester) async {
    BoxConstraints? captured;
    BuildContext? slotContext;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: const Text('body'),
        bottomNavigationBar: Builder(
          builder: (context) {
            slotContext = context;
            return LayoutBuilder(
              builder: (context, c) {
                captured = c;
                return Container(height: 74, color: Colors.red);
              },
            );
          },
        ),
      ),
    ));
    await tester.pump();
    // ignore: avoid_print
    print('SLOT CONSTRAINTS: $captured');
    final mq = MediaQuery.of(slotContext!);
    // ignore: avoid_print
    print('SLOT MediaQuery padding: ${mq.padding} viewPadding: ${mq.viewPadding}');
    expect(captured, isNotNull);
  });

  testWidgets('probe: Center behavior under those constraints',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: const Text('body'),
        bottomNavigationBar: Center(
          child: Container(height: 74, color: Colors.amber),
        ),
      ),
    ));
    await tester.pump();
    final size = tester.getSize(find.byWidgetPredicate(
      (w) => w is Container && w.color == Colors.amber,
    ));
    // ignore: avoid_print
    print('CENTER-WRAPPED CONTAINER SIZE: $size');
    final centerSize = tester.getSize(find.byType(Center));
    // ignore: avoid_print
    print('CENTER SIZE: $centerSize');
  });
}
