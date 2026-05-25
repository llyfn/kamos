// KAMOS — Regression test for KamosPillButton. The widget exists to
// solve the Profile + Beverage-Detail bug where the primary/secondary
// pills next to each other rendered at different heights. The first
// test pins that down: same label, same height. Additional tests
// confirm `onPressed: null` disables both variants and that the
// `expand` toggle correctly switches between bare and Expanded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamos/app/theme.dart';
import 'package:kamos/shared/widgets/kamos_pill_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildKamosTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );

// `getSize` on a KamosPillButton (when `expand: true`) returns the size
// of its child render box, which is the ConstrainedBox we wrap the
// Material in. That's the value we care about — the rendered pill
// height.
Size _pillSize(WidgetTester tester, Key k) =>
    tester.getSize(find.byKey(k));

void main() {
  group('KamosPillButton', () {
    testWidgets('primary and secondary render at the same height',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KamosPillButton.primary(
                key: const Key('primary'),
                label: 'Edit profile',
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              KamosPillButton.secondary(
                key: const Key('secondary'),
                label: 'Settings',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final primary = _pillSize(tester, const Key('primary'));
      final secondary = _pillSize(tester, const Key('secondary'));
      expect(primary.height, secondary.height,
          reason: 'primary + secondary pill heights must match');
      expect(primary.height, greaterThanOrEqualTo(44),
          reason: 'pill must respect 44 px min tap target');
    });

    testWidgets('icon variant matches no-icon variant height',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KamosPillButton.primary(
                key: const Key('plain'),
                label: 'Check-in',
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              KamosPillButton.secondary(
                key: const Key('with-icon'),
                label: 'List',
                icon: Icons.bookmark_outline,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final plain = _pillSize(tester, const Key('plain'));
      final withIcon = _pillSize(tester, const Key('with-icon'));
      expect(plain.height, withIcon.height,
          reason: 'leading icon must not push the icon variant taller');
    });

    testWidgets('onPressed: null disables both variants', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              KamosPillButton.primary(
                key: Key('primary'),
                label: 'Edit profile',
                onPressed: null,
              ),
              SizedBox(width: 12),
              KamosPillButton.secondary(
                key: Key('secondary'),
                label: 'Settings',
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The InkWell inside each variant has its `onTap` cleared when
      // `onPressed` is null, which is what makes the pill inert.
      final primaryInk = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const Key('primary')),
          matching: find.byType(InkWell),
        ),
      );
      final secondaryInk = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const Key('secondary')),
          matching: find.byType(InkWell),
        ),
      );
      expect(primaryInk.onTap, isNull,
          reason: 'primary InkWell must be inert when disabled');
      expect(secondaryInk.onTap, isNull,
          reason: 'secondary InkWell must be inert when disabled');
    });

    testWidgets(
        'default expand differs by variant — primary expands, secondary is intrinsic',
        (tester) async {
      // Primary defaults to expand:true (Expanded); secondary defaults
      // to expand:false (intrinsic-width). Pins the asymmetric default
      // so the primary CTA is wider than the secondary action.
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              KamosPillButton.primary(
                key: const Key('primary-default'),
                label: 'Edit profile',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              KamosPillButton.secondary(
                key: const Key('secondary-default'),
                label: 'Settings',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('primary-default')),
          matching: find.byType(Expanded),
        ),
        findsOneWidget,
        reason: 'primary should default to Expanded',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('secondary-default')),
          matching: find.byType(Expanded),
        ),
        findsNothing,
        reason: 'secondary should default to intrinsic width',
      );
      final primary = _pillSize(tester, const Key('primary-default'));
      final secondary = _pillSize(tester, const Key('secondary-default'));
      expect(primary.width, greaterThan(secondary.width),
          reason: 'primary CTA should render wider than the secondary');
      expect(primary.height, secondary.height,
          reason: 'asymmetric width must not break the matched-height contract');
    });

    testWidgets('expand: false yields a bare button (no Expanded)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          KamosPillButton.primary(
            key: const Key('standalone'),
            label: 'Ok',
            onPressed: () {},
            expand: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('standalone')),
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
    });

    testWidgets('expand: true wraps the button in an Expanded',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              KamosPillButton.primary(
                key: const Key('expanded'),
                label: 'Ok',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('expanded')),
          matching: find.byType(Expanded),
        ),
        findsOneWidget,
      );
    });
  });
}
