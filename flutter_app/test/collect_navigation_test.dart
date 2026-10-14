import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moali.itlens/app/theme/app_theme.dart';
import 'package:moali.itlens/features/shell/floating_nav_bar.dart';

void main() {
  for (final mouseInput in [false, true]) {
    testWidgets(
      'Mobile collect return stays interactive with ${mouseInput ? 'mouse' : 'touch'} input',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var taps = 0;
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                extendBody: true,
                body: Center(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Dashboard action'),
                  ),
                ),
                floatingActionButton: CollectFab(
                  tooltip: 'Collect census',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Collect census')),
                          body: const Text('Unsubmitted census'),
                        ),
                      ),
                    );
                  },
                ),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.centerDocked,
                bottomNavigationBar: FloatingNavBar(
                  selectedIndex: selected,
                  onSelect: (index) => setState(() => selected = index),
                  items: const [
                    FloatingNavItem(
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard,
                      label: 'Home',
                    ),
                    FloatingNavItem(
                      icon: Icons.tune_outlined,
                      selectedIcon: Icons.tune,
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final TestGesture? mouse = mouseInput
            ? await tester.createGesture(kind: PointerDeviceKind.mouse)
            : null;
        if (mouse != null) {
          await mouse.addPointer(
            location: tester.getCenter(find.text('Settings')),
          );
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byType(CollectFab));
          await tester.pumpAndSettle();
          expect(find.text('Unsubmitted census'), findsOneWidget);
          if (i == 1) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byType(BackButton));
          }
          // Keep the pointer over the bar as the dashboard is revealed. This
          // exercises hit testing before the bar's next paint as well as after.
          for (var frame = 0; frame < 35; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
            if (mouse != null) await mouse.moveBy(const Offset(0.1, 0));
          }
          await tester.pumpAndSettle();
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
          expect(selected, 1);
          await tester.tap(find.text('Home'));
          await tester.pumpAndSettle();
          expect(selected, 0);
          await tester.tap(find.text('Dashboard action'));
          await tester.pumpAndSettle();
          expect(taps, i + 1);
        }
        await mouse?.removePointer();
        await tester.pumpAndSettle();
      },
    );
  }
}
