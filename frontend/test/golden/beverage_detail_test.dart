// KAMOS — Golden: beverage detail screen.
//
// Deferred per CONTRIBUTING.md "Golden baselines": baselines are captured
// on CI's Linux runner. Remove the `@Skip` once the baseline lands.

@Skip('golden baselines pending CI Linux capture')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('beverage detail golden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Placeholder()),
    );
    await expectLater(
      find.byType(Placeholder),
      matchesGoldenFile('goldens/beverage_detail.png'),
    );
  });
}
